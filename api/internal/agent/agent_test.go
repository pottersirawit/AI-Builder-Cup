package agent

import (
	"context"
	"errors"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"google.golang.org/genai"

	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func at(hh, mm int) time.Time { return time.Date(2026, 9, 29, hh, mm, 0, 0, domain.Bangkok) }

func session(t *testing.T, now time.Time) *planner.Session {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	spots, err := floodspot.Load(filepath.Join(filepath.Dir(file), "..", "..", "..", "data", "bkk_flood_risk_points.json"))
	if err != nil {
		t.Fatal(err)
	}
	p := &planner.Planner{Spots: spots, Trips: scenario.Trips, Places: scenario.Places, Whereabouts: scenario.Whereabouts}
	prov := planner.Providers{Weather: scenario.Weather{}, Routes: scenario.Routes{}, Canals: scenario.Canals{}}
	s, err := p.NewSession(context.Background(), prov, now, "cal-dinner")
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func TestParseQuestionTH(t *testing.T) {
	now := at(16, 10)
	transit, moto, car := domain.ModeTransit, domain.ModeMoto, domain.ModeCar
	tests := []struct {
		q        string
		wantTime string // "" means no change
		wantMode *domain.Mode
	}{
		{"ถ้ารอถึงสองทุ่มค่อยกลับล่ะ", "20:00", nil},
		{"ไป BTS แทนดีไหม", "", &transit},
		{"นั่งมอไซค์ไปตอนห้าโมงครึ่งได้ไหม", "17:30", &moto},
		{"ทุ่มนึงค่อยออก", "19:00", nil},
		{"สามทุ่มครึ่งขับรถกลับ", "21:30", &car},
		{"ออก 18:45 ได้ไหม", "18:45", nil},
		{"ออก 19.15", "19:15", nil},
		{"หกโมงเย็นเรียกแท็กซี่", "18:00", &car},
		{"อีก 30 นาทีค่อยออก", "16:40", nil},
		{"อีกชั่วโมงนึง", "17:10", nil},
		{"อีกครึ่งชั่วโมง", "16:40", nil},
		{"บ่ายสามโมง", "15:00", nil}, // already past: moves to tomorrow, checked below
		{"ฝนตกไหม", "", nil},
	}
	for _, tt := range tests {
		t.Run(tt.q, func(t *testing.T) {
			got := ParseQuestionTH(tt.q, now)
			gotTime := ""
			if got.DepartAt != nil {
				gotTime = got.DepartAt.Format("15:04")
			}
			if gotTime != tt.wantTime {
				t.Errorf("time = %q, want %q", gotTime, tt.wantTime)
			}
			if (got.Mode == nil) != (tt.wantMode == nil) || (got.Mode != nil && *got.Mode != *tt.wantMode) {
				t.Errorf("mode = %v, want %v", got.Mode, tt.wantMode)
			}
		})
	}
	if got := ParseQuestionTH("บ่ายสามโมง", now); got.DepartAt.Day() != 30 {
		t.Errorf("a time already past should roll to tomorrow, got %v", got.DepartAt)
	}
}

func TestDecideFallbackHero(t *testing.T) {
	s := session(t, at(16, 10))
	resp, err := Decide(context.Background(), nil, s, Request{TripID: "cal-dinner"}, []string{"x"})
	if err != nil {
		t.Fatal(err)
	}
	if resp.GeneratedBy != "fallback" || resp.Verdict != decision.LeaveNow || resp.HeadlineTH != "ออกก่อน 16:45" {
		t.Fatalf("got %s %s %q", resp.GeneratedBy, resp.Verdict, resp.HeadlineTH)
	}
	var tools []string
	for _, c := range resp.Reasoning {
		tools = append(tools, c.Tool)
		if c.SummaryTH == "" {
			t.Errorf("empty summary for %s", c.Tool)
		}
	}
	if strings.Join(tools, ",") != strings.Join(fallbackTools, ",") {
		t.Fatalf("reasoning tools = %v", tools)
	}
	if resp.Explanation.ReasonWhyTH == "" || len(resp.Explanation.FactorsTH) == 0 || resp.Explanation.RouteAdviceTH == "" {
		t.Errorf("incomplete fallback explanation: %+v", resp.Explanation)
	}
}

func TestDecideRequests(t *testing.T) {
	tests := []struct {
		name         string
		req          Request
		wantVerdict  decision.Verdict
		wantHeadline string
		wantMode     domain.Mode
		wantFirst    string
		wantErr      bool
	}{
		{"question: wait until 20:00", Request{QuestionTH: "ถ้ารอถึงสองทุ่มค่อยกลับล่ะ"}, decision.LeaveNow, "ออก 20:00 ได้ แต่เลยนัด 18:30", domain.ModeCar, "parse_question_fallback", false},
		{"question: switch to BTS", Request{QuestionTH: "ไป BTS แทนดีไหม"}, decision.LeaveNow, "", domain.ModeTransit, "parse_question_fallback", false},
		{"slider: motorbike at 17:15", Request{DepartAt: "2026-09-29T17:15:00+07:00", Mode: "moto"}, decision.SwitchMode, "เปลี่ยนไปนั่งรถไฟฟ้าดีกว่า", domain.ModeMoto, "get_trip", false},
		{"bad mode", Request{Mode: "boat"}, "", "", "", "", true},
		{"bad time", Request{DepartAt: "soon"}, "", "", "", "", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp, err := Decide(context.Background(), nil, session(t, at(16, 10)), tt.req, nil)
			if tt.wantErr {
				if !errors.Is(err, ErrBadRequest) {
					t.Fatalf("want ErrBadRequest, got %v", err)
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			if resp.Verdict != tt.wantVerdict || resp.Mode != tt.wantMode || (tt.wantHeadline != "" && resp.HeadlineTH != tt.wantHeadline) {
				t.Fatalf("got %s %s %q", resp.Verdict, resp.Mode, resp.HeadlineTH)
			}
			if resp.Reasoning[0].Tool != tt.wantFirst {
				t.Fatalf("first reasoning step = %s, want %s", resp.Reasoning[0].Tool, tt.wantFirst)
			}
		})
	}
}

// scriptedGemini plays back canned responses and records what it was sent.
type scriptedGemini struct {
	replies []*genai.GenerateContentResponse
	err     error
	seen    [][]*genai.Content
	configs []*genai.GenerateContentConfig
}

func (f *scriptedGemini) GenerateContent(_ context.Context, _ string, contents []*genai.Content, cfg *genai.GenerateContentConfig) (*genai.GenerateContentResponse, error) {
	f.seen = append(f.seen, contents)
	f.configs = append(f.configs, cfg)
	if f.err != nil {
		return nil, f.err
	}
	if len(f.replies) == 0 {
		return nil, errors.New("script exhausted")
	}
	r := f.replies[0]
	f.replies = f.replies[1:]
	return r, nil
}

func reply(parts ...*genai.Part) *genai.GenerateContentResponse {
	return &genai.GenerateContentResponse{Candidates: []*genai.Candidate{{Content: &genai.Content{Role: genai.RoleModel, Parts: parts}}}}
}

func call(name string, args map[string]any) *genai.Part {
	return &genai.Part{FunctionCall: &genai.FunctionCall{ID: name + "-1", Name: name, Args: args}}
}

func TestDecideWithGeminiAgent(t *testing.T) {
	// Notice agent returns leave_by 16:30, but baseline core calculated 16:45.
	// The hardened decider must preserve 16:45 from baseline core.
	final := `{"verdict":"leave_now","headline_th":"ออกก่อน 16:45 นะ","summary_th":"ฝนก้อนใหญ่ถึงพระราม 4 ราวห้าโมงครึ่ง ออกตอนนี้ถึงบ้าน 17:00","leave_by":"16:30","confidence":0.8,
	  "reasoning":[{"tool":"get_rain_along_route","summary_th":"ฝนถึงพระราม 4 ราว 17:30"}]}`
	fake := &scriptedGemini{replies: []*genai.GenerateContentResponse{
		reply(call("get_trip", nil), call("get_rain_along_route", nil)),
		reply(call("evaluate_departure", map[string]any{"mode": "car"})),
		reply(&genai.Part{Text: "```json\n" + final + "\n```"}),
	}}
	resp, err := Decide(context.Background(), &Gemini{Gen: fake, Model: "test"}, session(t, at(16, 10)), Request{}, nil)
	if err != nil {
		t.Fatal(err)
	}
	core, err := session(t, at(16, 10)).Baseline(at(16, 10), domain.ModeCar)
	if err != nil {
		t.Fatal(err)
	}
	if resp.GeneratedBy != "gemini" || resp.HeadlineTH != "ออกก่อน 16:45 นะ" || resp.Confidence != core.Confidence || resp.LeaveBy.Format("15:04") != "16:45" {
		t.Fatalf("got %+v, want LeaveBy 16:45 and the engine's confidence", resp)
	}
	if resp.Model != "test" {
		t.Errorf("model = %q", resp.Model)
	}
	if len(resp.Reasoning) != 3 || resp.Reasoning[1].Tool != "get_rain_along_route" || resp.Reasoning[1].SummaryTH == "ฝนถึงพระราม 4 ราว 17:30" {
		t.Fatalf("the trace keeps what the tool returned, not Gemini's retelling: %+v", resp.Reasoning)
	}
	if !strings.Contains(resp.Reasoning[2].SummaryTH, "ความเสี่ยงต่ำ") {
		t.Fatalf("tools without agent text keep the tool summary, got %q", resp.Reasoning[2].SummaryTH)
	}
	// Round two must carry the function responses back to the model with matching IDs.
	last := fake.seen[1][len(fake.seen[1])-1]
	if last.Parts[0].FunctionResponse == nil || last.Parts[0].FunctionResponse.ID != "get_trip-1" {
		t.Fatalf("function response not sent back: %+v", last.Parts[0])
	}

	// Verify that the first prompt sent to Gemini includes the deterministic Risk Summary.
	firstUserMsg := fake.seen[0][0].Parts[0].Text
	if !strings.Contains(firstUserMsg, "Deterministic Risk Summary") || !strings.Contains(firstUserMsg, "verdict=leave_now") {
		t.Fatalf("initial user prompt missing seeded risk summary: %s", firstUserMsg)
	}
}

func TestGeminiAgentGuardrailsAndFallback(t *testing.T) {
	unsafe := `{"verdict":"leave_now","headline_th":"ไปเลย","summary_th":"ไม่เป็นไร","confidence":0.9}`
	tests := []struct {
		name        string
		gen         *scriptedGemini
		req         Request
		wantBy      string
		wantVerdict decision.Verdict
	}{
		{"API error falls back", &scriptedGemini{err: errors.New("quota")}, Request{}, "fallback", decision.LeaveNow},
		{"answer without tools falls back", &scriptedGemini{replies: []*genai.GenerateContentResponse{reply(&genai.Part{Text: unsafe})}}, Request{}, "fallback", decision.LeaveNow},
		{"unsafe leave_now into deep water is overridden", &scriptedGemini{replies: []*genai.GenerateContentResponse{
			reply(call("get_flood_spots_on_route", nil)), reply(&genai.Part{Text: unsafe}),
		}}, Request{DepartAt: "18:00", Mode: "car"}, "gemini", decision.SwitchMode},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp, err := Decide(context.Background(), &Gemini{Gen: tt.gen, Model: "test"}, session(t, at(16, 10)), tt.req, nil)
			if err != nil {
				t.Fatal(err)
			}
			if resp.GeneratedBy != tt.wantBy || resp.Verdict != tt.wantVerdict {
				t.Fatalf("got %s %s %q", resp.GeneratedBy, resp.Verdict, resp.HeadlineTH)
			}
		})
	}
}

func TestGeminiAgentInventedTimesFallBackToEngineText(t *testing.T) {
	// The engine's leave-by at 16:10 by car is 16:45; Gemini writes 16:30.
	invented := `{"verdict":"leave_now","headline_th":"ออกก่อน 16:30","summary_th":"ฝนมาราว 17:05 รีบออก","confidence":0.9,
"explanation":{"reason_why_th":"ฝนหนักเริ่ม 16:58","factors_th":["ฝน"],"route_advice_th":"ใช้ทางด่วนยกระดับ","avoid_spots_th":[]}}`
	gen := &scriptedGemini{replies: []*genai.GenerateContentResponse{
		reply(call("get_trip", nil), call("evaluate_departure", map[string]any{"mode": "car"})),
		reply(&genai.Part{Text: invented}),
	}}
	s := session(t, at(16, 10))
	core, err := s.Baseline(at(16, 10), domain.ModeCar)
	if err != nil {
		t.Fatal(err)
	}
	resp, err := Decide(context.Background(), &Gemini{Gen: gen, Model: "test"}, s, Request{Mode: "car"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if resp.HeadlineTH != core.HeadlineTH || resp.SummaryTH != core.SummaryTH || resp.Verdict != core.Verdict {
		t.Fatalf("invented times must fall back to the engine's text: got %q / %q, engine %q / %q", resp.HeadlineTH, resp.SummaryTH, core.HeadlineTH, core.SummaryTH)
	}
	if resp.Explanation.ReasonWhyTH != core.Explanation.ReasonWhyTH {
		t.Errorf("reason_why_th with an invented time must fall back, got %q", resp.Explanation.ReasonWhyTH)
	}
	if resp.Explanation.RouteAdviceTH != core.Explanation.RouteAdviceTH {
		t.Errorf("route advice is always the engine's, got %q", resp.Explanation.RouteAdviceTH)
	}
	if resp.GeneratedBy != "gemini" {
		t.Errorf("generated_by = %s", resp.GeneratedBy)
	}
	last := resp.Reasoning[len(resp.Reasoning)-1]
	if last.Tool != GuardrailTool || !strings.Contains(last.SummaryTH, "16:30") {
		t.Fatalf("the replacement must be recorded in reasoning, got %+v", resp.Reasoning)
	}
}

func TestGeminiAgentGroundedTimesPassThrough(t *testing.T) {
	grounded := `{"verdict":"leave_now","headline_th":"ออกก่อน 16:45 นะ","summary_th":"ออกตอนนี้ทันนัด","confidence":0.8,
"explanation":{"reason_why_th":"ออกตอน 16:10 ยังไม่เจอฝน","factors_th":["ฝน"],"route_advice_th":"ใช้ทางด่วน","avoid_spots_th":[]}}`
	gen := &scriptedGemini{replies: []*genai.GenerateContentResponse{
		reply(call("get_trip", nil), call("evaluate_departure", map[string]any{"mode": "car"})),
		reply(&genai.Part{Text: grounded}),
	}}
	resp, err := Decide(context.Background(), &Gemini{Gen: gen, Model: "test"}, session(t, at(16, 10)), Request{Mode: "car"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if resp.HeadlineTH != "ออกก่อน 16:45 นะ" || resp.Explanation.ReasonWhyTH != "ออกตอน 16:10 ยังไม่เจอฝน" {
		t.Fatalf("grounded text must pass through, got %q / %q", resp.HeadlineTH, resp.Explanation.ReasonWhyTH)
	}
	for _, c := range resp.Reasoning {
		if c.Tool == GuardrailTool {
			t.Fatalf("no guardrail entry for grounded text, got %+v", c)
		}
	}
}

func TestGeminiAgentExplanation(t *testing.T) {
	// 19 cm is what the flood tool returns for the car at 18:00; 25 cm is not.
	geminiReply := `{"verdict":"switch_mode","headline_th":"เปลี่ยนไปนั่งรถไฟฟ้าดีกว่า","summary_th":"รัชดาน้ำท่วม","confidence":0.85,
"explanation":{"reason_why_th":"น้ำท่วมสูง 19 ซม. เกินระยะพ้นน้ำ","factors_th":["น้ำท่วม 25 ซม."],"route_advice_th":"เลี่ยงถนนรัชดาภิเษก ขึ้นทางด่วนยกระดับ","avoid_spots_th":["แยกรัชดา-ลาดพร้าว"]}}`
	gen := &scriptedGemini{replies: []*genai.GenerateContentResponse{
		reply(call("get_flood_spots_on_route", nil)),
		reply(&genai.Part{Text: geminiReply}),
	}}
	s := session(t, at(16, 10))
	core, err := s.Baseline(at(18, 0), domain.ModeCar)
	if err != nil {
		t.Fatal(err)
	}
	resp, err := Decide(context.Background(), &Gemini{Gen: gen, Model: "test"}, s, Request{DepartAt: "18:00", Mode: "car"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if resp.GeneratedBy != "gemini" {
		t.Fatalf("expected generated_by gemini, got %s", resp.GeneratedBy)
	}
	e := resp.Explanation
	if e.ReasonWhyTH != "น้ำท่วมสูง 19 ซม. เกินระยะพ้นน้ำ" {
		t.Errorf("grounded reason is kept, got %q", e.ReasonWhyTH)
	}
	if strings.Join(e.FactorsTH, "|") != strings.Join(core.Explanation.FactorsTH, "|") {
		t.Errorf("factors with an ungrounded 25 cm fall back, got %v", e.FactorsTH)
	}
	if e.RouteAdviceTH != core.Explanation.RouteAdviceTH || strings.Join(e.AvoidSpotsTH, "|") != strings.Join(core.Explanation.AvoidSpotsTH, "|") {
		t.Errorf("route advice and avoid spots are the engine's, got %q / %v", e.RouteAdviceTH, e.AvoidSpotsTH)
	}
	last := resp.Reasoning[len(resp.Reasoning)-1]
	if last.Tool != GuardrailNumbersTool || !strings.Contains(last.SummaryTH, "25") {
		t.Errorf("numbers guard step = %+v", last)
	}
}

func TestDecideEvaluationHarness(t *testing.T) {
	// Evaluation harness across modes (car, transit, moto) asserting verdict coherence
	modes := []domain.Mode{domain.ModeCar, domain.ModeTransit, domain.ModeMoto}
	times := []struct {
		hh, mm int
	}{
		{16, 10},
		{17, 15},
		{18, 00},
	}

	for _, tm := range times {
		s := session(t, at(tm.hh, tm.mm))
		for _, m := range modes {
			req := Request{Mode: string(m)}
			resp, err := Decide(context.Background(), nil, s, req, nil)
			if err != nil {
				t.Fatalf("harness failed for %v mode %s: %v", tm, m, err)
			}
			if !resp.Verdict.Valid() {
				t.Fatalf("invalid verdict %s for %v mode %s", resp.Verdict, tm, m)
			}
			// When motorcycle meets high wind or high flood, verdict must not be LeaveNow
			if m == domain.ModeMoto && resp.Verdict == decision.LeaveNow {
				for _, opt := range resp.ModeOptions {
					if opt.Mode == domain.ModeMoto && opt.Risk == decision.RiskHigh {
						t.Fatalf("unsafe LeaveNow verdict allowed for high-risk motorcycle mode at %v", tm)
					}
				}
			}
		}
	}
}

func TestParseQuestionWithGemini(t *testing.T) {
	fake := &scriptedGemini{replies: []*genai.GenerateContentResponse{reply(&genai.Part{Text: `{"depart_at":"20:00","mode":"transit"}`})}}
	in, by := ParseQuestion(context.Background(), &Gemini{Gen: fake, Model: "test"}, "สองทุ่มนั่งรถไฟฟ้า", at(16, 10), scenario.Trips(at(16, 10))[0], scenario.Places)
	if by != "gemini" || in.DepartAt.Format("15:04") != "20:00" || *in.Mode != domain.ModeTransit {
		t.Fatalf("got %v %+v", by, in)
	}
	broken := &scriptedGemini{replies: []*genai.GenerateContentResponse{reply(&genai.Part{Text: "ขอโทษค่ะ"})}}
	in, by = ParseQuestion(context.Background(), &Gemini{Gen: broken, Model: "test"}, "สองทุ่ม", at(16, 10), domain.Trip{}, nil)
	if by != "fallback" || in.DepartAt.Format("15:04") != "20:00" {
		t.Fatalf("got %v %+v", by, in)
	}
}

func TestMatchPlace(t *testing.T) {
	tests := []struct{ q, want string }{
		{"ไปสยามตอนหกโมงดีไหม", "siam"},
		{"แวะพารากอนก่อนกลับ", "siam"},
		{"ไปทองหล่อกี่โมงดี", "thonglor"},
		{"คอนเสิร์ตที่อิมแพ็คเมืองทองธานี", "impact"},
		{"กลับบ้านตอนสองทุ่ม", "home"},
		{"จากสีลมไปสยาม", "siam"}, // "จาก" marks the origin, not the destination
		{"ไป Siam Paragon", "siam"},
		{"ถ้ารอถึงสองทุ่มค่อยกลับล่ะ", ""},
	}
	for _, tt := range tests {
		got, ok := MatchPlace(tt.q, scenario.Places)
		if got.ID != tt.want || ok != (tt.want != "") {
			t.Errorf("MatchPlace(%q) = %q %v, want %q", tt.q, got.ID, ok, tt.want)
		}
	}
}

func TestDecideAdHocDestination(t *testing.T) {
	tests := []struct {
		name       string
		req        Request
		wantTrip   string
		wantDepart string
	}{
		{"typed destination plans a new trip", Request{QuestionTH: "ไปสยามตอนหกโมงดีไหม"}, "adhoc-siam", "18:00"},
		{"home means tonight's dinner", Request{QuestionTH: "กลับบ้านตอนหนึ่งทุ่ม"}, "cal-dinner", "19:00"},
		{"an explicit trip id wins over the question", Request{TripID: "cal-dinner", QuestionTH: "ไปสยามตอนหกโมงดีไหม"}, "cal-dinner", "18:00"},
		{"no destination keeps the trip", Request{QuestionTH: "ถ้ารอถึงสองทุ่มค่อยกลับล่ะ"}, "cal-dinner", "20:00"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp, err := Decide(context.Background(), nil, session(t, at(16, 10)), tt.req, nil)
			if err != nil {
				t.Fatal(err)
			}
			if resp.Trip.ID != tt.wantTrip || resp.DepartAt.Format("15:04") != tt.wantDepart {
				t.Fatalf("got trip %s depart %s", resp.Trip.ID, resp.DepartAt.Format("15:04"))
			}
		})
	}
	resp, _ := Decide(context.Background(), nil, session(t, at(16, 10)), Request{QuestionTH: "ไปสยามตอนหกโมงดีไหม"}, nil)
	if resp.Trip.Origin != scenario.Silom || resp.Trip.Destination != scenario.Siam || !resp.Trip.ArriveBy.IsZero() {
		t.Fatalf("trip = %+v", resp.Trip)
	}
	if !strings.Contains(resp.Reasoning[0].SummaryTH, "ไปสยาม") {
		t.Errorf("parse step should name the destination, got %q", resp.Reasoning[0].SummaryTH)
	}
	for _, c := range resp.Reasoning {
		if strings.Contains(c.SummaryTH, "รัชดาภิเษก") || strings.Contains(c.SummaryTH, "บ้านลาดพร้าว") {
			t.Errorf("Siam trip still mentions the Lat Phrao trip: %s %q", c.Tool, c.SummaryTH)
		}
	}
}

func TestParseQuestionWithGeminiDestination(t *testing.T) {
	fake := &scriptedGemini{replies: []*genai.GenerateContentResponse{reply(&genai.Part{Text: `{"depart_at":"18:00","mode":"","destination":"thonglor"}`})}}
	in, by := ParseQuestion(context.Background(), &Gemini{Gen: fake, Model: "test"}, "หกโมงไปกินข้าวแถวสุขุมวิท 55", at(16, 10), scenario.Trips(at(16, 10))[0], scenario.Places)
	if by != "gemini" || in.Place == nil || in.Place.ID != "thonglor" || in.DepartAt.Format("15:04") != "18:00" {
		t.Fatalf("got %v %+v", by, in)
	}
	unknown := &scriptedGemini{replies: []*genai.GenerateContentResponse{reply(&genai.Part{Text: `{"depart_at":"","mode":"","destination":"moon"}`})}}
	in, _ = ParseQuestion(context.Background(), &Gemini{Gen: unknown, Model: "test"}, "ไปสยาม", at(16, 10), domain.Trip{}, scenario.Places)
	if in.Place == nil || in.Place.ID != "siam" {
		t.Fatalf("unknown Gemini place should fall back to keywords, got %+v", in.Place)
	}
}

func TestGeminiFailureMidLoopDoesNotDuplicateReasoning(t *testing.T) {
	fake := &scriptedGemini{replies: []*genai.GenerateContentResponse{
		reply(call("get_trip", nil), call("get_rain_along_route", nil)),
		// then the script runs out: the second round errors
	}}
	resp, err := Decide(context.Background(), &Gemini{Gen: fake, Model: "test"}, session(t, at(16, 10)), Request{}, nil)
	if err != nil {
		t.Fatal(err)
	}
	var tools []string
	for _, c := range resp.Reasoning {
		tools = append(tools, c.Tool)
	}
	if resp.GeneratedBy != "fallback" || strings.Join(tools, ",") != strings.Join(fallbackTools, ",") {
		t.Fatalf("got %s reasoning %v", resp.GeneratedBy, tools)
	}
}

func TestDestinationPhrase(t *testing.T) {
	tests := map[string]string{
		"ไปเซ็นทรัลเวิลด์ตอนหกโมงดีไหม":     "เซ็นทรัลเวิลด์",
		"หกโมงไปกินข้าวแถวสุขุมวิท 55":      "สุขุมวิท 55",
		"ไปที่ไอคอนสยามด้วยรถไฟฟ้า":         "ไอคอนสยาม",
		"ไป Central World ตอน 18:30 ได้ไหม": "Central World",
		"กลับบ้านตอนหนึ่งทุ่ม":              "บ้าน",
		"ไปทำงานพรุ่งนี้เช้า":               "ทำงาน",
		"ไป BTS แทนดีไหม":                   "",
		"ถ้ารอถึงสองทุ่มค่อยกลับล่ะ":        "",
		"ออกตอนนี้เลยดีไหม":                 "",
		"ไปถึงหลังสวนกี่โมง":                "หลังสวน",
	}
	for q, want := range tests {
		if got := DestinationPhrase(q); got != want {
			t.Errorf("DestinationPhrase(%q) = %q, want %q", q, got, want)
		}
	}
}

func TestRequestTripRequest(t *testing.T) {
	good := Request{
		Origin:      &domain.Place{Lat: 13.7466, Lng: 100.5393},
		Destination: &domain.Place{NameTH: "สยาม", Lat: 13.7456, Lng: 100.5341},
		Places: []domain.SavedPlace{
			{ID: "h1", Kind: "home", LabelTH: "บ้าน", Place: domain.Place{NameTH: "คอนโดบางนา", Lat: 13.6681, Lng: 100.6046}},
			{ID: "g1", LabelTH: "ยิม", Place: domain.Place{NameTH: "ฟิตเนส อารีย์ (พญาไท)", Lat: 13.7797, Lng: 100.5448}},
		},
	}
	tr, err := good.TripRequest()
	if err != nil {
		t.Fatal(err)
	}
	if tr.Origin.NameTH != "ตำแหน่งปัจจุบัน" || tr.Destination.NameTH != "สยาม" {
		t.Fatalf("origin/destination = %+v %+v", tr.Origin, tr.Destination)
	}
	if tr.Places[1].Kind != domain.KindOther {
		t.Fatalf("missing kind should be other, got %q", tr.Places[1].Kind)
	}
	for q, want := range map[string]string{"กลับบ้านกี่โมงดี": "h1", "ไปยิมตอนหกโมง": "g1", "ไปฟิตเนส อารีย์": "g1", "ไป home": "h1"} {
		if p, ok := MatchPlace(q, tr.Places); !ok || p.ID != want {
			t.Errorf("MatchPlace(%q) = %v %v, want %s", q, p.ID, ok, want)
		}
	}

	bad := []Request{
		{Origin: &domain.Place{}},
		{Destination: &domain.Place{Lat: 95, Lng: 100}},
		{Places: []domain.SavedPlace{{ID: "x", Kind: "boat", Place: domain.Place{Lat: 13.7, Lng: 100.5}}}},
		{Places: []domain.SavedPlace{{Kind: "home", Place: domain.Place{Lat: 13.7, Lng: 100.5}}}},
		{Places: []domain.SavedPlace{{ID: "x", Kind: "home"}}},
	}
	for _, r := range bad {
		if _, err := r.TripRequest(); !errors.Is(err, ErrBadRequest) {
			t.Errorf("%+v: want ErrBadRequest, got %v", r, err)
		}
	}
}

func userSession(t *testing.T, req Request) *planner.Session {
	t.Helper()
	tr, err := req.TripRequest()
	if err != nil {
		t.Fatal(err)
	}
	_, file, _, _ := runtime.Caller(0)
	spots, _ := floodspot.Load(filepath.Join(filepath.Dir(file), "..", "..", "..", "data", "bkk_flood_risk_points.json"))
	p := &planner.Planner{Spots: spots, Trips: scenario.Trips, Places: scenario.Places, Whereabouts: scenario.Whereabouts}
	prov := planner.Providers{Weather: scenario.Weather{}, Routes: scenario.Routes{}, Canals: scenario.Canals{}}
	s, err := p.Open(context.Background(), prov, at(16, 10), tr)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func TestDecideNeedsPlace(t *testing.T) {
	gps := &domain.Place{NameTH: "ตำแหน่งปัจจุบัน", Lat: 13.7466, Lng: 100.5393}
	gymOnly := []domain.SavedPlace{{ID: "g1", Kind: "other", LabelTH: "ยิม", Place: domain.Place{NameTH: "ฟิตเนส อารีย์", Lat: 13.7797, Lng: 100.5448}}}
	tests := []struct {
		name      string
		req       Request
		wantQuery string
		wantKind  string
	}{
		{"home asked but not saved", Request{QuestionTH: "กลับบ้านตอนหกโมง", Origin: gps, Places: gymOnly}, "บ้าน", "home"},
		{"work asked but not saved", Request{QuestionTH: "ไปทำงานกี่โมงดี", Origin: gps, Places: gymOnly}, "ที่ทำงาน", "work"},
		{"a place the user never saved", Request{QuestionTH: "ไปเซ็นทรัลเวิลด์ตอนหกโมงดีไหม", Origin: gps, Places: gymOnly}, "เซ็นทรัลเวิลด์", ""},
		{"a place the demo user never saved", Request{QuestionTH: "ไปไอคอนสยามตอนหกโมง"}, "ไอคอนสยาม", ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := Decide(context.Background(), nil, userSession(t, tt.req), tt.req, nil)
			var np *NeedsPlace
			if !errors.As(err, &np) {
				t.Fatalf("want NeedsPlace, got %v", err)
			}
			if np.QueryTH != tt.wantQuery || np.Kind != tt.wantKind {
				t.Fatalf("got %+v", np)
			}
		})
	}
}

func TestDecideUserPlaces(t *testing.T) {
	gps := &domain.Place{NameTH: "ตำแหน่งปัจจุบัน", Lat: 13.7466, Lng: 100.5393}
	places := []domain.SavedPlace{
		{ID: "h1", Kind: "home", LabelTH: "บ้าน", Place: domain.Place{NameTH: "คอนโดบางนา", Lat: 13.6681, Lng: 100.6046}},
		{ID: "g1", Kind: "other", LabelTH: "ยิม", Place: domain.Place{NameTH: "ฟิตเนส อารีย์", Lat: 13.7797, Lng: 100.5448}},
	}
	req := Request{QuestionTH: "ไปยิมตอนหกโมงด้วยรถไฟฟ้า", Origin: gps, Places: places}
	resp, err := Decide(context.Background(), nil, userSession(t, req), req, nil)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(resp.Trip.ID, planner.AppPrefix) || resp.Trip.TitleTH != "ไปยิม" || resp.Trip.Origin != *gps ||
		resp.Trip.Destination.NameTH != "ฟิตเนส อารีย์" || resp.Mode != domain.ModeTransit || resp.DepartAt.Format("15:04") != "18:00" {
		t.Fatalf("got %+v mode %s depart %s", resp.Trip, resp.Mode, resp.DepartAt.Format("15:04"))
	}

	// The slider follow-up sends the coordinates back and gets the same trip.
	follow := Request{TripID: resp.Trip.ID, Origin: &resp.Trip.Origin, Destination: &resp.Trip.Destination, Mode: "moto"}
	again, err := Decide(context.Background(), nil, userSession(t, follow), follow, nil)
	if err != nil || again.Trip.ID != resp.Trip.ID || again.Mode != domain.ModeMoto {
		t.Fatalf("follow-up got %+v %v", again.Trip, err)
	}
}
