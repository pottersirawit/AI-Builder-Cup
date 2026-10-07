package agent

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"google.golang.org/genai"

	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
)

// Request is the body of POST /v1/decide.
type Request struct {
	TripID     string `json:"trip_id"`
	DepartAt   string `json:"depart_at"`
	Mode       string `json:"mode"`
	QuestionTH string `json:"question_th"`
}

// Response is the /v1/decide contract (docs/plan/merged-flow.md), plus the
// departure, mode and trip actually evaluated so the app can sync its slider.
type Response struct {
	Verdict      decision.Verdict      `json:"verdict"`
	HeadlineTH   string                `json:"headline_th"`
	SummaryTH    string                `json:"summary_th"`
	LeaveBy      *time.Time            `json:"leave_by"`
	Confidence   float64               `json:"confidence"`
	RainTimeline []domain.RainSample   `json:"rain_timeline"`
	ModeOptions  []decision.ModeOption `json:"mode_options"`
	FloodSpots   []decision.FloodSpot  `json:"flood_spots"`
	Reasoning    []planner.Call        `json:"reasoning"`
	Sources      []string              `json:"sources"`
	GeneratedBy  string                `json:"generated_by"`
	DepartAt     time.Time             `json:"depart_at"`
	Mode         domain.Mode           `json:"mode"`
	// Trip is the trip actually decided: the requested one, or the one the
	// question pointed at ("ไปสยามตอนหกโมง" -> adhoc-siam).
	Trip domain.Trip `json:"trip"`
}

var ErrBadRequest = errors.New("bad request")

// fallbackTools is the fixed investigation the deterministic path performs.
var fallbackTools = []string{"get_trip", "get_route", "get_rain_along_route", "get_flood_spots_on_route", "get_community_reports", "evaluate_departure"}

const maxAgentTurns = 8

// Decide answers one /v1/decide request. With Gemini it lets the agent call
// tools, decide and write the Thai explanation; without Gemini (or on any
// Gemini error) the same tools run in a fixed order and the deterministic
// engine writes the text. Numbers always come from the deterministic engine.
func Decide(ctx context.Context, g *Gemini, s *planner.Session, req Request, sources []string) (Response, error) {
	depart, mode := s.Now, s.Trip.Mode
	if req.DepartAt != "" {
		t, err := planner.ParseTime(req.DepartAt, s.Now)
		if err != nil {
			return Response{}, fmt.Errorf("%w: %v", ErrBadRequest, err)
		}
		depart = t
	}
	if req.Mode != "" {
		if !domain.Mode(req.Mode).Valid() {
			return Response{}, fmt.Errorf("%w: mode must be car, transit or moto", ErrBadRequest)
		}
		mode = domain.Mode(req.Mode)
	}
	var preface []planner.Call
	if q := strings.TrimSpace(req.QuestionTH); q != "" {
		intent, by := ParseQuestion(ctx, g, q, s.Now, s.Trip, s.Places())
		// A question without trip_id may name where to go; with trip_id the
		// app has already picked the trip.
		if req.TripID == "" && intent.Place != nil {
			if err := s.PlanTo(intent.Place.ID); err != nil {
				return Response{}, err
			}
			if req.Mode == "" {
				mode = s.Trip.Mode
			}
		}
		if intent.DepartAt != nil {
			depart = *intent.DepartAt
		}
		if intent.Mode != nil {
			mode = *intent.Mode
		}
		tool := "parse_question"
		if by == "fallback" {
			tool = "parse_question_fallback"
		}
		preface = append(preface, planner.Call{Tool: tool, SummaryTH: intent.SummaryTH()})
	}
	if depart.Before(s.Now) {
		depart = s.Now
	}

	baseline, err := s.Baseline(depart, mode)
	if err != nil {
		return Response{}, err
	}
	resp := Response{
		Verdict: baseline.Verdict, HeadlineTH: baseline.HeadlineTH, SummaryTH: baseline.SummaryTH,
		LeaveBy: baseline.LeaveBy, Confidence: baseline.Confidence,
		RainTimeline: baseline.RainTimeline, ModeOptions: baseline.ModeOptions, FloodSpots: baseline.FloodSpots,
		Sources: sources, GeneratedBy: "fallback", DepartAt: depart, Mode: mode, Trip: s.Trip,
	}
	if resp.FloodSpots == nil {
		resp.FloodSpots = []decision.FloodSpot{}
	}

	if g.Available() {
		out, err := runAgent(ctx, g, s, depart, mode, req.QuestionTH)
		if err == nil {
			applyAgent(&resp, out, baseline, s)
			resp.Reasoning = append(preface, resp.Reasoning...)
			return resp, nil
		}
		slog.Warn("gemini agent failed, using fallback", "err", err)
		s.ResetCalls()
	}

	for _, tool := range fallbackTools {
		args := map[string]any{"mode": string(mode), "depart_at": depart.Format(time.RFC3339)}
		_, _ = s.Call(tool, args)
	}
	resp.Reasoning = append(preface, s.Calls()...)
	return resp, nil
}

type agentOutput struct {
	Verdict    string  `json:"verdict"`
	HeadlineTH string  `json:"headline_th"`
	SummaryTH  string  `json:"summary_th"`
	LeaveBy    string  `json:"leave_by"`
	Confidence float64 `json:"confidence"`
	Reasoning  []struct {
		Tool      string `json:"tool"`
		SummaryTH string `json:"summary_th"`
	} `json:"reasoning"`
}

const systemPrompt = `คุณคือ "ฝนตกไหม" ผู้ช่วยตัดสินใจเดินทางในกรุงเทพฯ ช่วงฝนตกและน้ำท่วม
หน้าที่: ตอบคำถามเดียวว่า "ควรออกเดินทางตอนไหน ด้วยอะไร" สำหรับทริปนี้ ด้วยภาษาไทยที่สั้น ชัด เหมือนเพื่อนบอก
กติกา:
1. ต้องเรียกเครื่องมือเพื่อดูข้อมูลจริงก่อนตัดสินใจ อย่างน้อย get_trip, get_rain_along_route, get_flood_spots_on_route และ evaluate_departure ของวิธีเดินทางที่ผู้ใช้เลือก ใช้ get_route, get_community_reports, get_canal_levels เมื่อช่วยให้คำตอบดีขึ้น
2. ห้ามขัดกับผลของ evaluate_departure: ถ้าความเสี่ยงสูง ห้ามบอกให้ออกด้วยวิธีนั้น ความสูงใต้ท้องรถ: รถเก๋งเสี่ยงที่น้ำ 15 ซม. มอเตอร์ไซค์ 10 ซม. หรือฝนหนัก รถไฟฟ้าไม่กระทบน้ำบนถนน
3. verdict เลือกหนึ่งใน leave_now, wait, switch_mode, dont_go
4. ระบุเวลาเป็นตัวเลข HH:MM บอกเหตุผลจากข้อมูล ไม่ใช่ข้อความสำเร็จรูป
เมื่อพร้อมตอบ ให้ตอบเป็น JSON อย่างเดียว ไม่มีข้อความอื่น:
{"verdict":"...","headline_th":"ไม่เกิน 30 ตัวอักษร เช่น ออกก่อน 16:45","summary_th":"1-2 ประโยค","leave_by":"HH:MM หรือว่าง","confidence":0.0-1.0,
 "reasoning":[{"tool":"ชื่อเครื่องมือที่เรียก","summary_th":"สิ่งที่ได้จากเครื่องมือนั้นใน 1 ประโยค"}]}`

func toolDeclarations() []*genai.Tool {
	var decls []*genai.FunctionDeclaration
	for _, t := range planner.Tools {
		props := map[string]*genai.Schema{}
		for name, p := range t.Params {
			typ := genai.TypeString
			if p.Type == "number" {
				typ = genai.TypeNumber
			}
			props[name] = &genai.Schema{Type: typ, Description: p.Description, Enum: p.Enum}
		}
		d := &genai.FunctionDeclaration{Name: t.Name, Description: t.Description}
		if len(props) > 0 {
			d.Parameters = &genai.Schema{Type: genai.TypeObject, Properties: props, Required: t.Required}
		}
		decls = append(decls, d)
	}
	return []*genai.Tool{{FunctionDeclarations: decls}}
}

func runAgent(ctx context.Context, g *Gemini, s *planner.Session, depart time.Time, mode domain.Mode, question string) (agentOutput, error) {
	ctx, cancel := context.WithTimeout(ctx, 45*time.Second)
	defer cancel()
	cfg := &genai.GenerateContentConfig{
		SystemInstruction: genai.NewContentFromText(systemPrompt, genai.RoleUser),
		Tools:             toolDeclarations(),
		Temperature:       temperature(0.2),
	}
	user := fmt.Sprintf("ตอนนี้ %s ทริป %s (%s จาก %s ไป %s) ผู้ใช้อยากรู้ว่าถ้าออก %s ด้วย %s เป็นอย่างไร",
		s.Now.Format(time.RFC3339), s.Trip.ID, s.Trip.TitleTH, s.Trip.Origin.NameTH, s.Trip.Destination.NameTH, depart.Format("15:04"), mode)
	if question != "" {
		user += fmt.Sprintf("\nคำถามของผู้ใช้: %q", question)
	}
	contents := []*genai.Content{genai.NewContentFromText(user, genai.RoleUser)}
	for turn := 0; turn < maxAgentTurns; turn++ {
		resp, err := g.Gen.GenerateContent(ctx, g.Model, contents, cfg)
		if err != nil {
			return agentOutput{}, err
		}
		if len(resp.Candidates) == 0 || resp.Candidates[0].Content == nil {
			return agentOutput{}, errors.New("empty Gemini response")
		}
		calls := resp.FunctionCalls()
		if len(calls) == 0 {
			var out agentOutput
			if err := decodeJSON(resp.Text(), &out); err != nil {
				return agentOutput{}, err
			}
			if len(s.Calls()) == 0 {
				return agentOutput{}, errors.New("agent answered without calling any tool")
			}
			return out, nil
		}
		contents = append(contents, resp.Candidates[0].Content)
		var parts []*genai.Part
		for _, fc := range calls {
			result, _ := s.Call(fc.Name, fc.Args)
			part := genai.NewPartFromFunctionResponse(fc.Name, result)
			part.FunctionResponse.ID = fc.ID
			parts = append(parts, part)
		}
		contents = append(contents, genai.NewContentFromParts(parts, genai.RoleUser))
	}
	return agentOutput{}, errors.New("agent did not finish within the turn limit")
}

// applyAgent takes the agent's verdict and Thai text, guarded by the
// deterministic engine: the agent may not send someone into high-risk water.
func applyAgent(resp *Response, out agentOutput, baseline decision.Result, s *planner.Session) {
	resp.GeneratedBy = "gemini"
	v := decision.Verdict(out.Verdict)
	unsafe := v == decision.LeaveNow && baseline.Evals[resp.Mode].Risk == decision.RiskHigh
	if v.Valid() && !unsafe && out.HeadlineTH != "" && out.SummaryTH != "" {
		resp.Verdict, resp.HeadlineTH, resp.SummaryTH = v, out.HeadlineTH, out.SummaryTH
		if out.LeaveBy == "" {
			resp.LeaveBy = nil
		} else if t, err := planner.ParseTime(out.LeaveBy, s.Now); err == nil {
			resp.LeaveBy = &t
		}
		if out.Confidence > 0 && out.Confidence <= 1 {
			resp.Confidence = out.Confidence
		}
	}
	explained := map[string][]string{}
	for _, r := range out.Reasoning {
		if r.SummaryTH != "" {
			explained[r.Tool] = append(explained[r.Tool], r.SummaryTH)
		}
	}
	for _, c := range s.Calls() {
		if texts := explained[c.Tool]; len(texts) > 0 {
			c.SummaryTH, explained[c.Tool] = texts[0], texts[1:]
		}
		resp.Reasoning = append(resp.Reasoning, c)
	}
}
