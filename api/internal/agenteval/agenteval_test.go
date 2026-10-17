package agenteval

import (
	"context"
	"errors"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"testing"
	"time"

	"google.golang.org/genai"

	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func at(hh, mm int) time.Time { return time.Date(2026, 9, 29, hh, mm, 0, 0, domain.Bangkok) }

func demoPlanner(t *testing.T) *planner.Planner {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	spots, err := floodspot.Load(filepath.Join(filepath.Dir(file), "..", "..", "..", "data", "bkk_flood_risk_points.json"))
	if err != nil {
		t.Fatal(err)
	}
	return &planner.Planner{Spots: spots, Trips: scenario.Trips, Places: scenario.Places, Whereabouts: scenario.Whereabouts}
}

func check(t *testing.T, checks []Check, name string) Check {
	t.Helper()
	for _, c := range checks {
		if c.Name == name {
			return c
		}
	}
	t.Fatalf("check %s not run; got %+v", name, checks)
	return Check{}
}

// coreAt16 is the deterministic answer for the hero trip at 16:10 by car:
// leave by 16:45, low risk.
func coreAt16(t *testing.T) (agent.Response, decision.Result) {
	t.Helper()
	s, err := demoPlanner(t).NewSession(context.Background(), Providers(), at(16, 10), "cal-dinner")
	if err != nil {
		t.Fatal(err)
	}
	resp, err := agent.Decide(context.Background(), nil, s, agent.Request{TripID: "cal-dinner", Mode: "car"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	core, err := s.Baseline(resp.DepartAt, resp.Mode)
	if err != nil {
		t.Fatal(err)
	}
	return resp, core
}

func TestScoreFlagsATimeTheDataDoesNotSupport(t *testing.T) {
	resp, core := coreAt16(t)
	c := Case{Name: "hero", Now: at(16, 10), WantVerdict: decision.LeaveNow}
	if got := check(t, Score(c, resp, core), CheckGroundedTimes); !got.Pass {
		t.Fatalf("the engine's own text must be grounded: %+v (headline %q, summary %q)", got, resp.HeadlineTH, resp.SummaryTH)
	}

	resp.HeadlineTH = "ออกก่อน 16:23 นะ"
	got := check(t, Score(c, resp, core), CheckGroundedTimes)
	if got.Pass || !strings.Contains(got.Detail, "16:23") {
		t.Fatalf("a leave-by time 22 minutes off the data must fail and be named: %+v", got)
	}

	// 16:30 is on the rain timeline, but it is not the engine's leave-by.
	resp.HeadlineTH = "ออกก่อน 16:30"
	if got := check(t, Score(c, resp, core), CheckGroundedTimes); got.Pass || !strings.Contains(got.Detail, "16:30") {
		t.Fatalf("a leave-by that is not the engine's must fail even when the time exists elsewhere: %+v", got)
	}
}

func TestScoreSafetyAndAgreement(t *testing.T) {
	resp, core := coreAt16(t)
	c := Case{Name: "hero", Now: at(16, 10), WantVerdict: decision.LeaveNow}
	for _, name := range []string{CheckValidVerdict, CheckSafeForMode, CheckDemoScript, CheckAgreesWithCore, CheckRequiredTools, CheckHeadlineLength, CheckExplanation} {
		if got := check(t, Score(c, resp, core), name); !got.Pass {
			t.Errorf("fallback hero answer fails %s: %s", name, got.Detail)
		}
	}

	unsafe := resp
	unsafe.Verdict = decision.LeaveNow
	risky := core
	risky.Evals = map[domain.Mode]decision.Eval{domain.ModeCar: {Mode: domain.ModeCar, Risk: decision.RiskHigh}}
	if got := check(t, Score(c, unsafe, risky), CheckSafeForMode); got.Pass {
		t.Fatal("leave_now into high-risk water must fail the safety check")
	}

	wrong := resp
	wrong.Verdict = decision.Wait
	if check(t, Score(c, wrong, core), CheckDemoScript).Pass || check(t, Score(c, wrong, core), CheckAgreesWithCore).Pass {
		t.Fatal("a verdict that differs from the script and the core must fail both checks")
	}

	noScript := Score(Case{Name: "free"}, resp, core)
	for _, ch := range noScript {
		if ch.Name == CheckDemoScript {
			t.Fatal("cases without a scripted verdict skip the demo-script check")
		}
	}

	lazy := resp
	lazy.Reasoning = []planner.Call{{Tool: "get_trip"}}
	lazy.HeadlineTH = strings.Repeat("ฝ", 31)
	lazy.Explanation = decision.Explanation{}
	for _, name := range []string{CheckRequiredTools, CheckHeadlineLength, CheckExplanation} {
		if check(t, Score(c, lazy, core), name).Pass {
			t.Errorf("%s should fail", name)
		}
	}
	if got := check(t, Score(c, lazy, core), CheckRequiredTools); !strings.Contains(got.Detail, "evaluate_departure") {
		t.Errorf("missing tools should be named, got %q", got.Detail)
	}
}

func TestDemoCasesPassWithoutGemini(t *testing.T) {
	rep := Run(context.Background(), nil, demoPlanner(t), DemoCases(), Options{})
	if len(rep.Results) < 15 {
		t.Fatalf("want the demo times x modes plus questions, got %d cases", len(rep.Results))
	}
	for _, r := range rep.Results {
		if r.Err != "" {
			t.Errorf("%s: %s", r.Case, r.Err)
			continue
		}
		if r.GeneratedBy != "fallback" {
			t.Errorf("%s: generated_by %s without Gemini", r.Case, r.GeneratedBy)
		}
		for _, c := range r.Checks {
			if !c.Pass {
				t.Errorf("%s: %s failed: %s (headline %q)", r.Case, c.Name, c.Detail, r.HeadlineTH)
			}
		}
	}
	sum := rep.Summary()
	if sum.Cases != len(rep.Results) || sum.Passed != sum.Cases || sum.GeminiRate != 0 {
		t.Fatalf("summary %+v", sum)
	}
	md := rep.Markdown()
	for _, want := range []string{"| " + CheckSafeForMode, "fallback", DemoCases()[0].Name} {
		if !strings.Contains(md, want) {
			t.Errorf("markdown report missing %q", want)
		}
	}
}

// fakeGemini answers like a well-behaved agent: it calls the required tools,
// then replies with answer (its text may carry %s for the trip's leave-by time).
// The judge prompt gets judgeReply; anything else (the question parser) errors,
// so parsing falls back to rules.
type fakeGemini struct {
	answer     string
	judgeReply string
	calls      int
}

func (f *fakeGemini) GenerateContent(_ context.Context, _ string, contents []*genai.Content, cfg *genai.GenerateContentConfig) (*genai.GenerateContentResponse, error) {
	f.calls++
	sys := ""
	if cfg != nil && cfg.SystemInstruction != nil && len(cfg.SystemInstruction.Parts) > 0 {
		sys = cfg.SystemInstruction.Parts[0].Text
	}
	text := func(s string) *genai.GenerateContentResponse {
		return &genai.GenerateContentResponse{Candidates: []*genai.Candidate{{Content: &genai.Content{Role: genai.RoleModel, Parts: []*genai.Part{{Text: s}}}}}}
	}
	switch {
	case sys == judgePrompt:
		return text(f.judgeReply), nil
	case cfg != nil && len(cfg.Tools) > 0 && len(contents) == 1:
		var parts []*genai.Part
		for _, tool := range RequiredTools {
			parts = append(parts, &genai.Part{FunctionCall: &genai.FunctionCall{ID: tool, Name: tool, Args: map[string]any{}}})
		}
		return &genai.GenerateContentResponse{Candidates: []*genai.Candidate{{Content: &genai.Content{Role: genai.RoleModel, Parts: parts}}}}, nil
	case cfg != nil && len(cfg.Tools) > 0:
		return text(f.answer), nil
	}
	return nil, errors.New("not scripted")
}

func TestRunScoresGeminiAfterTheTimeGuardrail(t *testing.T) {
	fake := &fakeGemini{
		answer: `{"verdict":"leave_now","headline_th":"รีบออกก่อน 16:07","summary_th":"ฝนมาเร็ว","confidence":0.7,
			"explanation":{"reason_why_th":"ฝนหนักบนพระราม 4","factors_th":["ฝน"],"route_advice_th":"ใช้ทางด่วน","avoid_spots_th":[]}}`,
		judgeReply: `{"score":2,"note_th":"เวลาไม่ตรงกับข้อมูล"}`,
	}
	cases := []Case{{Name: "16:10 car", Now: at(16, 10), Req: agent.Request{TripID: "cal-dinner", Mode: "car"}, WantVerdict: decision.LeaveNow}}
	rep := Run(context.Background(), &agent.Gemini{Gen: fake, Model: "fake"}, demoPlanner(t), cases, Options{Judge: true})
	r := rep.Results[0]
	// The invented 16:07 never reaches the user: the engine's headline does.
	if r.GeneratedBy != "gemini" || r.HeadlineTH != "ออกก่อน 16:45" || !slices.Contains(r.Tools, agent.GuardrailTool) {
		t.Fatalf("got %s %q tools %v", r.GeneratedBy, r.HeadlineTH, r.Tools)
	}
	if !check(t, r.Checks, CheckGroundedTimes).Pass || !check(t, r.Checks, CheckRequiredTools).Pass {
		t.Fatalf("checks %+v", r.Checks)
	}
	if r.Judge == nil || r.Judge.Score != 2 || r.Judge.NoteTH == "" {
		t.Fatalf("judge = %+v", r.Judge)
	}
	sum := rep.Summary()
	if sum.GeminiRate != 1 || sum.Passed != 1 || sum.JudgeMean != 2 || sum.ChecksFailed[CheckGroundedTimes] != 0 {
		t.Fatalf("summary %+v", sum)
	}
	if rep.Model != "fake" {
		t.Errorf("model = %q", rep.Model)
	}
}

func TestJudgeFailureDoesNotFailTheCase(t *testing.T) {
	fake := &fakeGemini{
		answer: `{"verdict":"leave_now","headline_th":"ออกก่อน 16:45","summary_th":"ออกตอนนี้ถึงบ้านทันนัด 18:30","confidence":0.8,
			"explanation":{"reason_why_th":"ฝนถึงพระราม 4 หลังจากนั้น","factors_th":["ฝน"],"route_advice_th":"ใช้ทางด่วน","avoid_spots_th":[]}}`,
		judgeReply: "ขอโทษ",
	}
	cases := []Case{{Name: "16:10 car", Now: at(16, 10), Req: agent.Request{TripID: "cal-dinner", Mode: "car"}, WantVerdict: decision.LeaveNow}}
	rep := Run(context.Background(), &agent.Gemini{Gen: fake, Model: "fake"}, demoPlanner(t), cases, Options{Judge: true})
	r := rep.Results[0]
	if !r.Passed() || r.Judge != nil || r.JudgeErr == "" {
		t.Fatalf("a broken judge reply is reported, not scored: passed=%v judge=%+v err=%q checks=%+v", r.Passed(), r.Judge, r.JudgeErr, r.Checks)
	}
}

type judgeRecordingGen struct {
	models  []string
	configs []*genai.GenerateContentConfig
}

func (j *judgeRecordingGen) GenerateContent(_ context.Context, model string, _ []*genai.Content, cfg *genai.GenerateContentConfig) (*genai.GenerateContentResponse, error) {
	j.models = append(j.models, model)
	j.configs = append(j.configs, cfg)
	if model == "missing-primary" {
		return nil, errors.New("404 NOT_FOUND")
	}
	return &genai.GenerateContentResponse{
		Candidates: []*genai.Candidate{{Content: &genai.Content{Role: genai.RoleModel, Parts: []*genai.Part{{Text: `{"score":5,"note_th":"ดีมาก"}`}}}}},
	}, nil
}

func TestJudgeUsesGenerateWithThinkingDisabledAndFallbacks(t *testing.T) {
	resp, core := coreAt16(t)
	rec := &judgeRecordingGen{}
	g := &agent.Gemini{Gen: rec, Model: "missing-primary", Fallbacks: []string{"gemini-2.5-flash-lite"}}
	score, err := Judge(context.Background(), g, resp, core)
	if err != nil {
		t.Fatalf("Judge failed: %v", err)
	}
	if score.Score != 5 {
		t.Fatalf("score = %+v, want 5", score)
	}
	if !slices.Equal(rec.models, []string{"missing-primary", "gemini-2.5-flash-lite"}) {
		t.Fatalf("models = %v, want fallback to gemini-2.5-flash-lite", rec.models)
	}
	for i, cfg := range rec.configs {
		if cfg == nil || cfg.ThinkingConfig == nil || cfg.ThinkingConfig.ThinkingBudget == nil || *cfg.ThinkingConfig.ThinkingBudget != 0 {
			t.Fatalf("call %d missing ThinkingBudget=0: %+v", i, cfg)
		}
	}
}

