package agent

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"

	"google.golang.org/genai"

	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

func decideWith(t *testing.T, lang domain.Lang, now time.Time, req Request, final string, extra ...*genai.GenerateContentResponse) Response {
	t.Helper()
	replies := append([]*genai.GenerateContentResponse{reply(call("get_trip", nil), call("evaluate_departure", map[string]any{"mode": "car"}))}, extra...)
	replies = append(replies, reply(&genai.Part{Text: final}))
	s := session(t, now)
	s.Lang = lang
	resp, err := Decide(context.Background(), &Gemini{Gen: &scriptedGemini{replies: replies}, Model: "test"}, s, req, nil)
	if err != nil {
		t.Fatal(err)
	}
	return resp
}

func TestVerdictGuardIsSymmetric(t *testing.T) {
	tests := []struct {
		name string
		lang domain.Lang
		now  time.Time
		req  Request
		out  string
	}{
		{"engine leave_now, model says wait", domain.LangTH, at(16, 10), Request{Mode: "car"},
			`{"verdict":"wait","headline_th":"รอก่อน","summary_th":"รอสักพัก","confidence":0.99,"explanation":{"reason_why_th":"รอก่อนดีกว่า","factors_th":["ฝน"]}}`},
		{"engine switch_mode, model says dont_go", domain.LangTH, at(16, 10), Request{DepartAt: "18:00", Mode: "car"},
			`{"verdict":"dont_go","headline_th":"อย่าไป","summary_th":"อันตราย","confidence":0.99}`},
		{"english, unknown verdict", domain.LangEN, at(16, 10), Request{Mode: "car"},
			`{"verdict":"maybe","headline_th":"Maybe","summary_th":"Not sure","confidence":0.5}`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cs := session(t, tt.now)
			cs.Lang = tt.lang
			core, err := cs.Baseline(at(16, 10), domain.ModeCar)
			if tt.req.DepartAt != "" {
				core, err = cs.Baseline(at(18, 0), domain.ModeCar)
			}
			if err != nil {
				t.Fatal(err)
			}
			resp := decideWith(t, tt.lang, tt.now, tt.req, tt.out)
			if resp.Verdict != core.Verdict || resp.HeadlineTH != core.HeadlineTH || resp.SummaryTH != core.SummaryTH || resp.Confidence != core.Confidence {
				t.Fatalf("engine verdict and text must win: got %s %q %q %v", resp.Verdict, resp.HeadlineTH, resp.SummaryTH, resp.Confidence)
			}
			if resp.Explanation.ReasonWhyTH != core.Explanation.ReasonWhyTH {
				t.Errorf("Gemini's reason for a verdict it does not own must go, got %q", resp.Explanation.ReasonWhyTH)
			}
			last := resp.Reasoning[len(resp.Reasoning)-1]
			if last.Tool != GuardrailVerdictTool || domain.HasThai(last.SummaryTH) != (tt.lang == domain.LangTH) {
				t.Fatalf("guardrail_verdict step = %+v", last)
			}
		})
	}
}

func TestConfidenceIsTheEngines(t *testing.T) {
	out := `{"verdict":"leave_now","headline_th":"ออกเลย","summary_th":"ไปได้","confidence":0.31}`
	resp := decideWith(t, domain.LangTH, at(16, 10), Request{Mode: "car"}, out)
	core, _ := session(t, at(16, 10)).Baseline(at(16, 10), domain.ModeCar)
	if resp.Confidence != core.Confidence || resp.HeadlineTH != "ออกเลย" {
		t.Fatalf("confidence = %v, want %v; matching verdict keeps Gemini's text, got %q", resp.Confidence, core.Confidence, resp.HeadlineTH)
	}
}

func TestTextContradictingVerdictFallsBack(t *testing.T) {
	tests := []struct {
		lang domain.Lang
		out  string
	}{
		{domain.LangTH, `{"verdict":"switch_mode","headline_th":"เปลี่ยนไปนั่งรถไฟฟ้าดีกว่า","summary_th":"รถยนต์ออกได้เลย ไม่มีปัญหา"}`},
		{domain.LangEN, `{"verdict":"switch_mode","headline_th":"Switch to the train","summary_th":"You can leave now by car."}`},
	}
	for _, tt := range tests {
		cs := session(t, at(16, 10))
		cs.Lang = tt.lang
		core, _ := cs.Baseline(at(18, 0), domain.ModeCar)
		resp := decideWith(t, tt.lang, at(16, 10), Request{DepartAt: "18:00", Mode: "car"}, tt.out,
			reply(call("get_flood_spots_on_route", nil)))
		if resp.Verdict != decision.SwitchMode || core.Verdict != decision.SwitchMode {
			t.Fatalf("setup: %s / %s", resp.Verdict, core.Verdict)
		}
		if resp.SummaryTH != core.SummaryTH || resp.HeadlineTH != core.HeadlineTH {
			t.Errorf("contradicting text must fall back, got %q / %q", resp.HeadlineTH, resp.SummaryTH)
		}
		if last := resp.Reasoning[len(resp.Reasoning)-1]; last.Tool != GuardrailVerdictTool {
			t.Errorf("step = %+v", last)
		}
	}
}

func TestTraceKeepsToolSummariesAndDropsDuplicates(t *testing.T) {
	out := `{"verdict":"leave_now","headline_th":"ออกก่อน 16:45","summary_th":"ไปได้","reasoning":[{"tool":"get_trip","summary_th":"เรื่องแต่ง"}]}`
	flood := call("get_flood_spots_on_route", map[string]any{"mode": "car"})
	resp := decideWith(t, domain.LangTH, at(16, 10), Request{Mode: "car"}, out, reply(flood), reply(flood))
	count := map[string]int{}
	for _, c := range resp.Reasoning {
		count[c.Tool]++
		if c.Tool == "get_trip" && c.SummaryTH == "เรื่องแต่ง" {
			t.Error("tool summary overwritten by Gemini's")
		}
	}
	if count["get_flood_spots_on_route"] != 1 {
		t.Errorf("repeated identical tool steps must collapse: %v", count)
	}
}

func TestUngroundedNumbers(t *testing.T) {
	g := Grounding{}
	g.addNum("cm", 19, 15, 10)
	g.addNum("mmh", 52, 12)
	g.addNum("min", 50, 30)
	g.addNum("kmh", 40)
	tests := []struct {
		text string
		want []string
	}{
		{"น้ำท่วม 19 ซม. เกิน 15 ซม.", nil},
		{"น้ำท่วม 20 ซม.", nil}, // within one of rounding
		{"น้ำท่วม ๑๙ ซม.", nil}, // Thai digits
		{"น้ำท่วม 25 ซม.", []string{"25 ซม."}},
		{"น้ำท่วม 25ซม.", []string{"25ซม."}},
		{"ลึก  10-19   ซม.", nil},
		{"ลึก 10-30 ซม.", []string{"10-30 ซม."}},
		{"ฝนหนัก 52 มม./ชม.", nil},
		{"ฝนหนัก 80 มม./ชม.", []string{"80 มม./ชม."}},
		{"ใช้เวลา 50 นาที", nil},
		{"ใช้เวลา ๖๐ นาที", []string{"60 นาที"}},
		{"ลม 40 กม./ชม.", nil},
		{"ลม 90 กม./ชม.", []string{"90 กม./ชม."}},
		{"Water is 19 cm deep, over the 15 cm limit", nil},
		{"Water is 40 cm deep", []string{"40 cm"}},
		{"Water is 40 centimetres deep", []string{"40 centimetres"}},
		{"Rain peaks at 52 mm/h", nil},
		{"Rain peaks at 99 mm/h", []string{"99 mm/h"}},
		{"Rain peaks at 99 mm per hour", []string{"99 mm per hour"}},
		{"About 31 minutes", nil},
		{"About 75 min", []string{"75 min"}},
		{"Gusts of 70 km/h", []string{"70 km/h"}},
		{"Gusts of 41 km/h", nil},
		{"รอ 3 รอบ ไป 2 แยก", nil}, // no unit, no claim
	}
	for _, tt := range tests {
		got := g.UngroundedNumbers(tt.text)
		if strings.Join(got, "|") != strings.Join(tt.want, "|") {
			t.Errorf("%q: got %v, want %v", tt.text, got, tt.want)
		}
	}
}

func TestEngineThresholdsAreGrounded(t *testing.T) {
	g := NewGrounding(Response{}, decision.Result{})
	for _, text := range []string{
		"Water over 5 cm slows a sedan; 15 cm stalls it and 10 cm stalls a motorbike.",
		"Rain from 1 mm/h is light, 10 mm/h moderate and 35 mm/h heavy.",
		"Gusts of 30 km/h make riding harder and 45 km/h is dangerous.",
		"น้ำเกิน 5 ซม. ฝน 10 มม./ชม. ลม 45 กม./ชม.",
	} {
		if got := g.UngroundedNumbers(text); len(got) > 0 {
			t.Errorf("%q: engine thresholds flagged as ungrounded: %v", text, got)
		}
	}
}

func TestContradicts(t *testing.T) {
	tests := []struct {
		text    string
		verdict decision.Verdict
		want    bool
	}{
		{"ออกได้เลย", decision.Wait, true},
		{"You can leave now", decision.Wait, true},
		{"Leave now!", decision.DontGo, true},
		{"รอก่อน", decision.Wait, false},
		{"Leave by 16:45", decision.Wait, false},
		{"ไปรถไฟฟ้าดีกว่า", decision.SwitchMode, false},
		{"ออกได้เลย", decision.LeaveNow, false},
		{"Don't leave now, the road is flooded.", decision.Wait, false},
		{"Do not go now by car.", decision.SwitchMode, false},
		{"Never leave now in this rain.", decision.DontGo, false},
		{"อย่าไปได้เลย น้ำท่วม", decision.Wait, false},
		{"ยังไม่ออกได้เลย", decision.Wait, false},
		{"Don't worry, leave now.", decision.Wait, true},
		{"Ratchadaphisek floods. Leave now by BTS / MRT instead of driving.", decision.SwitchMode, false},
		{"ถนนรัชดาน้ำท่วม นั่งรถไฟฟ้าไปได้เลย", decision.SwitchMode, false},
		{"Leave now by BTS / MRT instead of driving.", decision.Wait, true},
		{"You can leave now by car. The train is slower.", decision.SwitchMode, true},
		{"รถยนต์ออกได้เลย ไม่มีปัญหา", decision.SwitchMode, true},
	}
	for _, tt := range tests {
		if got := Contradicts(tt.text, tt.verdict); got != tt.want {
			t.Errorf("Contradicts(%q, %s) = %v, want %v", tt.text, tt.verdict, got, tt.want)
		}
	}
}

func TestSwitchModeTextNamingTheTrainIsKept(t *testing.T) {
	out := `{"verdict":"switch_mode","headline_th":"Take BTS / MRT instead","summary_th":"Ratchadaphisek floods. Leave now by BTS / MRT instead of driving.","explanation":{"reason_why_th":"The train avoids the flooded road.","factors_th":["Flooding on the road"]}}`
	resp := decideWith(t, domain.LangEN, at(16, 10), Request{DepartAt: "18:00", Mode: "car"}, out)
	if resp.Verdict != decision.SwitchMode || resp.SummaryTH != "Ratchadaphisek floods. Leave now by BTS / MRT instead of driving." {
		t.Fatalf("Gemini's switch_mode text should be kept, got %s %q", resp.Verdict, resp.SummaryTH)
	}
}

func TestEnglishNumbersGuard(t *testing.T) {
	out := `{"verdict":"switch_mode","headline_th":"Take the train","summary_th":"Water is 80 cm deep on Rama IV."}`
	s := session(t, at(16, 10))
	s.Lang = domain.LangEN
	core, _ := s.Baseline(at(18, 0), domain.ModeCar)
	resp := decideWith(t, domain.LangEN, at(16, 10), Request{DepartAt: "18:00", Mode: "car"}, out, reply(call("get_flood_spots_on_route", nil)))
	if resp.SummaryTH != core.SummaryTH || domain.HasThai(resp.SummaryTH) {
		t.Fatalf("summary = %q", resp.SummaryTH)
	}
	if resp.Reasoning[len(resp.Reasoning)-1].Tool != GuardrailNumbersTool {
		t.Fatalf("trace = %+v", resp.Reasoning)
	}
}

func TestResponseModelAndLatencyJSON(t *testing.T) {
	fb, err := Decide(context.Background(), nil, session(t, at(16, 10)), Request{}, nil)
	if err != nil {
		t.Fatal(err)
	}
	b, _ := json.Marshal(fb)
	if strings.Contains(string(b), `"model"`) || !strings.Contains(string(b), `"latency_ms"`) {
		t.Errorf("fallback JSON should omit model and carry latency_ms: %s", b)
	}
	out := `{"verdict":"leave_now","headline_th":"ออกเลย","summary_th":"ไปได้"}`
	resp := decideWith(t, domain.LangTH, at(16, 10), Request{Mode: "car"}, out)
	if resp.Model != "test" {
		t.Errorf("model = %q", resp.Model)
	}
}

// seqGen returns errs in order, then a text answer, and records the models asked.
type seqGen struct {
	errs   []error
	models []string
	ctxs   []context.Context
}

func (f *seqGen) GenerateContent(ctx context.Context, model string, _ []*genai.Content, _ *genai.GenerateContentConfig) (*genai.GenerateContentResponse, error) {
	f.models = append(f.models, model)
	f.ctxs = append(f.ctxs, ctx)
	if len(f.errs) > 0 {
		err := f.errs[0]
		f.errs = f.errs[1:]
		return nil, err
	}
	return reply(&genai.Part{Text: `{"depart_at":"20:00"}`}), nil
}

func TestRetryGenerator(t *testing.T) {
	busy := genai.APIError{Code: 503, Status: "UNAVAILABLE"}
	tests := []struct {
		name      string
		errs      []error
		wantCalls int
		wantErr   bool
	}{
		{"503 then ok", []error{busy}, 2, false},
		{"429 twice then ok", []error{errors.New("429 RESOURCE_EXHAUSTED"), errors.New("429")}, 3, false},
		{"gives up after two retries", []error{busy, busy, busy}, 3, true},
		{"permanent error is not retried", []error{errors.New("400 bad request")}, 1, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			inner := &seqGen{errs: tt.errs}
			var slept int
			r := &RetryGenerator{Gen: inner, Sleep: func(time.Duration) { slept++ }}
			_, err := r.GenerateContent(context.Background(), "m", nil, nil)
			if (err != nil) != tt.wantErr || len(inner.models) != tt.wantCalls || slept != tt.wantCalls-1 {
				t.Fatalf("err=%v calls=%d slept=%d", err, len(inner.models), slept)
			}
		})
	}
}

func TestGenerateFallsThroughUnavailableModels(t *testing.T) {
	tests := []struct {
		name      string
		errs      []error
		wantUsed  string
		wantCalls []string
		wantErr   bool
	}{
		{"first model works", nil, "a", []string{"a"}, false},
		{"404 falls to next", []error{genai.APIError{Code: 404, Message: "models/a is not found"}}, "b", []string{"a", "b"}, false},
		{"not allowed falls through twice", []error{errors.New("model not allowed"), errors.New("NOT_FOUND")}, "c", []string{"a", "b", "c"}, false},
		{"permission denied for model", []error{genai.APIError{Code: 403, Status: "PERMISSION_DENIED", Message: "model a denied"}}, "b", []string{"a", "b"}, false},
		{"other errors stop", []error{errors.New("500 boom")}, "", []string{"a"}, true},
		{"last model failing returns its error", []error{errors.New("not found"), errors.New("not found"), errors.New("not found")}, "", []string{"a", "b", "c"}, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			inner := &seqGen{errs: tt.errs}
			g := &Gemini{Gen: inner, Model: "a", Fallbacks: []string{"b", "c"}}
			_, used, err := g.Generate(context.Background(), nil, nil)
			if (err != nil) != tt.wantErr || used != tt.wantUsed || strings.Join(inner.models, ",") != strings.Join(tt.wantCalls, ",") {
				t.Fatalf("used=%q err=%v calls=%v", used, err, inner.models)
			}
		})
	}
}

func TestParseModels(t *testing.T) {
	for in, want := range map[string]string{"": "gemini-2.5-flash", " a , b,,": "a,b", "x": "x"} {
		if got := strings.Join(ParseModels(in), ","); got != want {
			t.Errorf("ParseModels(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestDecideReportsFallbackModel(t *testing.T) {
	inner := &seqGen{errs: []error{errors.New("model not found")}}
	g := &Gemini{Gen: inner, Model: "bad", Fallbacks: []string{"good"}}
	in, by := ParseQuestion(context.Background(), g, "ทุ่มนึง", at(16, 10), domain.Trip{}, nil)
	if by != "gemini" || in.DepartAt == nil {
		t.Fatalf("by=%s in=%+v", by, in)
	}
}

func TestTimeoutsAreBounded(t *testing.T) {
	inner := &seqGen{}
	ParseQuestion(context.Background(), &Gemini{Gen: inner, Model: "m"}, "ทุ่มนึง", at(16, 10), domain.Trip{}, nil)
	if dl, ok := inner.ctxs[0].Deadline(); !ok || time.Until(dl) > 8*time.Second {
		t.Errorf("ParseQuestion needs an 8 s deadline, got %v %v", dl, ok)
	}
	agentGen := &deadlineGen{}
	_, _ = Decide(context.Background(), &Gemini{Gen: agentGen, Model: "m"}, session(t, at(16, 10)), Request{}, nil)
	if !agentGen.ok || agentGen.left > 25*time.Second {
		t.Errorf("agent loop budget = %v (ok=%v), want <= 25s", agentGen.left, agentGen.ok)
	}
}

type deadlineGen struct {
	left time.Duration
	ok   bool
}

func (d *deadlineGen) GenerateContent(ctx context.Context, _ string, _ []*genai.Content, _ *genai.GenerateContentConfig) (*genai.GenerateContentResponse, error) {
	if dl, ok := ctx.Deadline(); ok {
		d.ok, d.left = true, time.Until(dl)
	}
	return nil, errors.New("stop")
}
