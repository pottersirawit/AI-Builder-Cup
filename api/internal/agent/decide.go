package agent

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
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
	// Origin and Destination, both set, are a trip the app chose; Origin
	// alone is where the phone is, the start of a trip a question names.
	Origin      *domain.Place `json:"origin"`
	Destination *domain.Place `json:"destination"`
	// Places are the user's saved places; questions resolve against them
	// instead of the demo user's. An empty list means none saved.
	Places []domain.SavedPlace `json:"places"`
}

// NeedsPlace is the answer to a question that names somewhere the server
// cannot place: a place the user has not saved, or home/work before they
// are set. The app asks the user to pick one and asks again.
type NeedsPlace struct {
	QueryTH string
	Kind    string // home or work when that is what is missing
}

func (n *NeedsPlace) Error() string { return "needs place: " + n.QueryTH }

// kindLabels are the default labels and the keywords of home and work.
var (
	kindLabels   = map[string]string{domain.KindHome: "บ้าน", domain.KindWork: "ที่ทำงาน"}
	kindKeywords = map[string][]string{
		domain.KindHome: {"บ้าน", "home"},
		domain.KindWork: {"ที่ทำงาน", "ทำงาน", "ออฟฟิศ", "office", "work"},
	}
	kindLabelsEN = map[string]string{domain.KindHome: "Home", domain.KindWork: "Work"}
)

func kindLabelFor(kind string, lang domain.Lang) string {
	if lang == domain.LangEN {
		return kindLabelsEN[kind]
	}
	return kindLabels[kind]
}

func validPoint(p domain.Place) bool {
	return (p.Lat != 0 || p.Lng != 0) && p.Lat >= -90 && p.Lat <= 90 && p.Lng >= -180 && p.Lng <= 180
}

// TripRequest is TripRequestFor in Thai.
func (r Request) TripRequest() (planner.TripRequest, error) {
	return r.TripRequestFor(domain.LangTH)
}

// TripRequestFor validates the request's places and gives each saved place the
// words a question can name it by: its label, its name (without the
// "(district)" suffix) and, for home and work, the usual words for them.
// Default labels are written in lang.
func (r Request) TripRequestFor(lang domain.Lang) (planner.TripRequest, error) {
	tr := planner.TripRequest{TripID: r.TripID, Lang: lang}
	for _, end := range []struct {
		p    *domain.Place
		dst  **domain.Place
		name string
		def  string
	}{{r.Origin, &tr.Origin, "origin", lang.Pick("ตำแหน่งปัจจุบัน", "Current location")}, {r.Destination, &tr.Destination, "destination", lang.Pick("ปลายทาง", "Destination")}} {
		if end.p == nil {
			continue
		}
		if !validPoint(*end.p) {
			return tr, fmt.Errorf("%w: %s needs lat and lng", ErrBadRequest, end.name)
		}
		p := *end.p
		if strings.TrimSpace(p.NameTH) == "" {
			p.NameTH = end.def
		}
		*end.dst = &p
	}
	if r.Places == nil {
		return tr, nil
	}
	tr.Places = []domain.SavedPlace{}
	for _, p := range r.Places {
		switch p.Kind {
		case "":
			p.Kind = domain.KindOther
		case domain.KindHome, domain.KindWork, domain.KindOther:
		default:
			return tr, fmt.Errorf("%w: place kind must be home, work or other", ErrBadRequest)
		}
		if p.ID == "" || !validPoint(p.Place) {
			return tr, fmt.Errorf("%w: each place needs id, lat and lng", ErrBadRequest)
		}
		if p.LabelTH == "" {
			p.LabelTH = kindLabelFor(p.Kind, lang)
		}
		if p.LabelTH == "" {
			p.LabelTH = p.NameTH
		}
		short, _, _ := strings.Cut(p.NameTH, "(")
		p.Keywords = append([]string{p.LabelTH, p.NameTH, strings.TrimSpace(short)}, kindKeywords[p.Kind]...)
		tr.Places = append(tr.Places, p)
	}
	return tr, nil
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
	// Explanation details why the mode/time was chosen, factors evaluated,
	// and flood-avoidance route optimization advice.
	Explanation decision.Explanation `json:"explanation"`
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
		// A question without trip_id may name where to go; with trip_id or
		// coordinates the app has already picked the trip.
		if req.TripID == "" && req.Destination == nil {
			switch {
			case intent.Place != nil:
				if err := s.PlanTo(intent.Place.ID); err != nil {
					return Response{}, err
				}
				if req.Mode == "" {
					mode = s.Trip.Mode
				}
			case intent.PlaceKind != "":
				return Response{}, &NeedsPlace{QueryTH: kindLabelFor(intent.PlaceKind, s.Lang), Kind: intent.PlaceKind}
			case intent.PlaceQuery != "":
				return Response{}, &NeedsPlace{QueryTH: intent.PlaceQuery}
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
		preface = append(preface, planner.Call{Tool: tool, SummaryTH: intent.Summary(s.Lang)})
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
		Explanation: baseline.Explanation,
	}
	if resp.FloodSpots == nil {
		resp.FloodSpots = []decision.FloodSpot{}
	}

	if g.Available() {
		out, err := runAgent(ctx, g, s, depart, mode, req.QuestionTH, baseline)
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
	Verdict     string                `json:"verdict"`
	HeadlineTH  string                `json:"headline_th"`
	SummaryTH   string                `json:"summary_th"`
	LeaveBy     string                `json:"leave_by"`
	Confidence  float64               `json:"confidence"`
	Explanation *decision.Explanation `json:"explanation"`
	Reasoning   []struct {
		Tool      string `json:"tool"`
		SummaryTH string `json:"summary_th"`
	} `json:"reasoning"`
}

const systemPrompt = `คุณคือ "ฝนตกไหม" ผู้ช่วยตัดสินใจเดินทางในกรุงเทพฯ ช่วงฝนตกและน้ำท่วม
หน้าที่: ตอบคำถามเดียวว่า "ควรออกเดินทางตอนไหน ด้วยอะไร" สำหรับทริปนี้ พร้อมอธิบายเหตุผล ปัจจัยที่พิจารณา และคำแนะนำปรับเส้นทางเลี่ยงน้ำท่วม ด้วยภาษาไทยที่สั้น ชัด เหมือนเพื่อนบอก
กติกา:
1. ต้องเรียกเครื่องมือเพื่อดูข้อมูลจริงก่อนตัดสินใจ อย่างน้อย get_trip, get_rain_along_route, get_flood_spots_on_route และ evaluate_departure ของวิธีเดินทางที่ผู้ใช้เลือก ใช้ get_route, get_community_reports, get_canal_levels เมื่อช่วยให้คำตอบดีขึ้น
2. ห้ามขัดกับผลของ evaluate_departure: ถ้าความเสี่ยงสูง ห้ามบอกให้ออกด้วยวิธีนั้น ความสูงใต้ท้องรถ: รถเก๋งเสี่ยงที่น้ำ 15 ซม. มอเตอร์ไซค์ 10 ซม. หรือฝนหนัก รถไฟฟ้าไม่กระทบน้ำบนถนน
3. verdict เลือกหนึ่งใน leave_now, wait, switch_mode, dont_go
4. ระบุเวลาเป็นตัวเลข HH:MM บอกเหตุผลจากข้อมูล ไม่ใช่ข้อความสำเร็จรูป
5. ใน explanation:
   - reason_why_th: อธิบายเหตุผลชัดเจนว่าทำไมถึงแนะนำวิธีนี้และเวลานี้ (เช่น แนะนำออกก่อน 16:45 หรือเปลี่ยนเป็น BTS เพราะน้ำบนถนนรัชดาฯ สูง 25 ซม. เกินระยะพ้นน้ำรถเก๋ง)
   - factors_th: ระบุรายการปัจจัยที่นำมาพิจารณาเป็นข้อๆ (ปริมาณ/เวลาฝนตก, ความสูงน้ำท่วมขังเทียบกับความสูงใต้ท้องรถ, ความเร็วลม, กำหนดเวลานัดหมาย, รายงานน้ำท่วมจริง)
   - route_advice_th: ให้คำแนะนำเส้นทางเพื่อเลี่ยงน้ำท่วม (เช่น แนะนำเลี่ยงถนนที่มีน้ำท่วมขัง โดยใช้ทางด่วนยกระดับ หรือจอดรถแล้วต่อรถไฟฟ้า)
   - avoid_spots_th: ระบุรายชื่อจุดเสี่ยงหรือถนนที่ควรเลี่ยง (เช่น ["แยกรัชดาภิเษก-ลาดพร้าว"]) หากไม่มีให้เป็น array ว่าง
เมื่อพร้อมตอบ ให้ตอบเป็น JSON อย่างเดียว ไม่มีข้อความอื่น:
{"verdict":"...","headline_th":"ไม่เกิน 30 ตัวอักษร เช่น ออกก่อน 16:45","summary_th":"1-2 ประโยค","leave_by":"HH:MM หรือว่าง","confidence":0.0-1.0,
 "explanation":{"reason_why_th":"...","factors_th":["..."],"route_advice_th":"...","avoid_spots_th":["..."]},
 "reasoning":[{"tool":"ชื่อเครื่องมือที่เรียก","summary_th":"สิ่งที่ได้จากเครื่องมือนั้นใน 1 ประโยค"}]}`

// englishPrompt is appended to the system prompt for English readers.
const englishPrompt = `

LANGUAGE: the user reads English. Write every text field (headline_th, summary_th, explanation.reason_why_th, explanation.factors_th, explanation.route_advice_th and reasoning[].summary_th) in short, friendly English instead of Thai. Keep the JSON keys and schema exactly as above, including the _th suffixes, and keep every rule above: headline_th at most 30 characters (for example "Leave by 16:45"), times as HH:MM, never contradict evaluate_departure. Tool results may be in Thai; translate what you use. Names of places and roads from the data may stay as they are.`

// systemPromptFor is the system prompt in lang; the Thai one is unchanged.
func systemPromptFor(lang domain.Lang) string {
	if lang == domain.LangEN {
		return systemPrompt + englishPrompt
	}
	return systemPrompt
}

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

func formatRiskSummary(b decision.Result, depart time.Time, mode domain.Mode) string {
	leaveByStr := "ไม่มี"
	if b.LeaveBy != nil {
		leaveByStr = b.LeaveBy.Format("15:04")
	}
	summary := fmt.Sprintf("ข้อมูลวิเคราะห์ความเสี่ยงเบื้องต้น (Deterministic Risk Summary):\n"+
		"- ผลประเมินหลัก: verdict=%s, ออกก่อน=%s, ความเชื่อมั่น=%.2f\n"+
		"- ความเสี่ยงวิธีเดินทางที่เลือก (%s): %s (ETA %d นาที)\n"+
		"- จุดเสี่ยงน้ำท่วมบนเส้นทาง: %d จุด\n",
		b.Verdict, leaveByStr, b.Confidence, mode, b.Evals[mode].Risk, b.Evals[mode].Minutes, len(b.FloodSpots))
	for _, opt := range b.ModeOptions {
		summary += fmt.Sprintf("  * %s: verdict=%s, risk=%s, eta=%d นาที (%s)\n",
			opt.Mode, opt.Verdict, opt.Risk, opt.EtaMin, opt.NoteTH)
	}
	return summary
}

func runAgent(ctx context.Context, g *Gemini, s *planner.Session, depart time.Time, mode domain.Mode, question string, baseline decision.Result) (agentOutput, error) {
	ctx, cancel := context.WithTimeout(ctx, 45*time.Second)
	defer cancel()
	cfg := &genai.GenerateContentConfig{
		SystemInstruction: genai.NewContentFromText(systemPromptFor(s.Lang), genai.RoleUser),
		Tools:             toolDeclarations(),
		Temperature:       temperature(0.2),
	}
	user := fmt.Sprintf("ตอนนี้ %s ทริป %s (%s จาก %s ไป %s) ผู้ใช้อยากรู้ว่าถ้าออก %s ด้วย %s เป็นอย่างไร\n\n%s",
		s.Now.Format(time.RFC3339), s.Trip.ID, s.Trip.TitleTH, s.Trip.Origin.NameTH, s.Trip.Destination.NameTH, depart.Format("15:04"), mode, formatRiskSummary(baseline, depart, mode))
	if question != "" {
		user += fmt.Sprintf("\nคำถามของผู้ใช้: %q", question)
	}
	if s.Lang == domain.LangEN {
		user += "\nAnswer in English."
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
// deterministic engine: the agent may not send someone into high-risk water,
// numerical leave_by is strictly preserved from the deterministic core, and
// text quoting a time the tools never returned is replaced by the engine's.
func applyAgent(resp *Response, out agentOutput, baseline decision.Result, s *planner.Session) {
	resp.GeneratedBy = "gemini"
	v := decision.Verdict(out.Verdict)
	unsafe := v == decision.LeaveNow && baseline.Evals[resp.Mode].Risk == decision.RiskHigh
	if v.Valid() && !unsafe && out.HeadlineTH != "" && out.SummaryTH != "" {
		resp.Verdict, resp.HeadlineTH, resp.SummaryTH = v, out.HeadlineTH, out.SummaryTH
		// Guardrail: leave_by comes strictly from the deterministic core, never hallucinated by LLM.
		resp.LeaveBy = baseline.LeaveBy
		if out.Confidence > 0 && out.Confidence <= 1 {
			resp.Confidence = out.Confidence
		}
	}
	if out.Explanation != nil {
		if out.Explanation.ReasonWhyTH != "" {
			resp.Explanation.ReasonWhyTH = out.Explanation.ReasonWhyTH
		}
		if len(out.Explanation.FactorsTH) > 0 {
			resp.Explanation.FactorsTH = out.Explanation.FactorsTH
		}
		if out.Explanation.RouteAdviceTH != "" {
			resp.Explanation.RouteAdviceTH = out.Explanation.RouteAdviceTH
		}
		if len(out.Explanation.AvoidSpotsTH) > 0 {
			resp.Explanation.AvoidSpotsTH = out.Explanation.AvoidSpotsTH
		}
	}
	invented := groundTimes(resp, baseline, s)
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
	if len(invented) > 0 {
		resp.Reasoning = append(resp.Reasoning, planner.Call{Tool: GuardrailTool,
			SummaryTH: guardrailSummary(s.Lang, invented)})
	}
}

// groundTimes puts back the engine's text wherever Gemini quoted an HH:MM
// the data does not support, and lists those times. The headline and summary go back
// with the verdict and confidence they were written for.
func groundTimes(resp *Response, baseline decision.Result, s *planner.Session) []string {
	g := NewGrounding(*resp, baseline, ToolTimes(s, resp.DepartAt, resp.Mode, baseline)...)
	var invented []string
	check := func(texts ...string) bool {
		bad := g.Ungrounded(texts...)
		for _, t := range bad {
			if !slices.Contains(invented, t) {
				invented = append(invented, t)
			}
		}
		return len(bad) > 0
	}
	if check(resp.HeadlineTH, resp.SummaryTH) {
		resp.Verdict, resp.HeadlineTH, resp.SummaryTH, resp.Confidence = baseline.Verdict, baseline.HeadlineTH, baseline.SummaryTH, baseline.Confidence
	}
	e, base := &resp.Explanation, baseline.Explanation
	if check(e.ReasonWhyTH) {
		e.ReasonWhyTH = base.ReasonWhyTH
	}
	if check(e.FactorsTH...) {
		e.FactorsTH = base.FactorsTH
	}
	if check(e.RouteAdviceTH) {
		e.RouteAdviceTH = base.RouteAdviceTH
	}
	if len(invented) > 0 {
		slog.Warn("gemini quoted times not in tool data, using engine text", "times", invented)
	}
	return invented
}

func guardrailSummary(lang domain.Lang, times []string) string {
	list := strings.Join(times, ", ")
	if lang == domain.LangEN {
		return "The time " + list + " does not match the data, so the calculation engine's text was used instead"
	}
	return "เวลา " + list + " ไม่ตรงกับข้อมูล จึงใช้ข้อความจากระบบคำนวณแทน"
}
