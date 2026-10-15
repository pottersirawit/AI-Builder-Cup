package agent

import (
	"context"
	"strings"
	"testing"

	"google.golang.org/genai"

	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func TestParseQuestionEnglish(t *testing.T) {
	now := at(16, 10)
	transit, moto, car := domain.ModeTransit, domain.ModeMoto, domain.ModeCar
	tests := []struct {
		q         string
		wantTime  string
		wantMode  *domain.Mode
		wantPlace string // saved place id
		wantQuery string
		wantKind  string
	}{
		{"Go home now", "16:10", nil, "home", "", ""},
		{"Go to work now", "16:10", nil, "work", "", ""},
		{"Go to the office now", "16:10", nil, "work", "", ""},
		{"Go to Siam now", "16:10", nil, "siam", "", ""},
		{"Go to Siam Paragon at 17:00 by car", "17:00", &car, "siam", "", ""},
		{"Leave at 17:00", "17:00", nil, "", "", ""},
		{"Leave by 5pm", "17:00", nil, "", "", ""},
		{"Leave at 5:30 pm by BTS", "17:30", &transit, "", "", ""},
		{"Leave in 30 minutes", "16:40", nil, "", "", ""},
		{"Leave in an hour", "17:10", nil, "", "", ""},
		{"Leave in 2 hours by motorbike", "18:10", &moto, "", "", ""},
		{"Go home at 7pm by MRT", "19:00", &transit, "home", "", ""},
		{"Go to Thonglor by train", "", &transit, "thonglor", "", ""},
		{"Head home on my bike", "", &moto, "home", "", ""},
		{"Go to Central World now", "16:10", nil, "", "Central World", ""},
		{"Go to Chatuchak at 6pm", "18:00", nil, "", "Chatuchak", ""},
	}
	for _, tt := range tests {
		t.Run(tt.q, func(t *testing.T) {
			in := parseFallback(tt.q, now, scenario.Places)
			got := ""
			if in.DepartAt != nil {
				got = in.DepartAt.Format("15:04")
			}
			if got != tt.wantTime {
				t.Errorf("time = %q, want %q", got, tt.wantTime)
			}
			if (in.Mode == nil) != (tt.wantMode == nil) || (in.Mode != nil && *in.Mode != *tt.wantMode) {
				t.Errorf("mode = %v, want %v", in.Mode, tt.wantMode)
			}
			id := ""
			if in.Place != nil {
				id = in.Place.ID
			}
			if id != tt.wantPlace {
				t.Errorf("place = %q, want %q", id, tt.wantPlace)
			}
			if tt.wantQuery != "" && in.PlaceQuery != tt.wantQuery {
				t.Errorf("place query = %q, want %q", in.PlaceQuery, tt.wantQuery)
			}
		})
	}
}

func TestEnglishHomeWithoutSavedHomeNeedsPlace(t *testing.T) {
	in := parseFallback("Go home now", at(16, 10), nil)
	if in.PlaceKind != domain.KindHome {
		t.Fatalf("kind = %q, want home", in.PlaceKind)
	}
}

func TestSystemPromptLanguage(t *testing.T) {
	if systemPromptFor(domain.LangTH) != systemPrompt || systemPromptFor("") != systemPrompt {
		t.Fatal("the Thai prompt must be unchanged")
	}
	en := systemPromptFor(domain.LangEN)
	if !strings.HasPrefix(en, systemPrompt) || !strings.Contains(en, "in short, friendly English") || !strings.Contains(en, "at most 30 characters") {
		t.Fatalf("English prompt lacks the instruction: %q", en[len(systemPrompt):])
	}
	if strings.Contains(systemPrompt, "English") {
		t.Fatal("Thai prompt mentions English")
	}
}

func TestDecideEnglishFallback(t *testing.T) {
	s := session(t, at(16, 10))
	s.Lang = domain.LangEN
	resp, err := Decide(context.Background(), nil, s, Request{TripID: "cal-dinner", QuestionTH: "Go home at 6pm"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	for what, text := range map[string]string{"headline": resp.HeadlineTH, "summary": resp.SummaryTH, "reason": resp.Explanation.ReasonWhyTH, "advice": resp.Explanation.RouteAdviceTH} {
		if text == "" || domain.HasThai(text) {
			t.Errorf("%s = %q", what, text)
		}
	}
	for _, c := range resp.Reasoning {
		if c.Tool == "parse_question_fallback" && !strings.Contains(c.SummaryTH, "leave at 18:00") {
			t.Errorf("question trace = %q", c.SummaryTH)
		}
	}
	if len(resp.Reasoning) == 0 {
		t.Fatal("no reasoning")
	}
}

func TestEnglishGeminiPromptAndGuardrail(t *testing.T) {
	// Gemini quotes 16:20 as the leave-by; the engine's is 16:45.
	final := `{"verdict":"leave_now","headline_th":"Leave by 16:20","summary_th":"Rain reaches Rama IV around 17:30.","leave_by":"16:20","confidence":0.8}`
	fake := &scriptedGemini{replies: []*genai.GenerateContentResponse{
		reply(call("get_trip", nil), call("get_rain_along_route", nil), call("evaluate_departure", map[string]any{"mode": "car"})),
		reply(&genai.Part{Text: final}),
	}}
	s := session(t, at(16, 10))
	s.Lang = domain.LangEN
	resp, err := Decide(context.Background(), &Gemini{Gen: fake, Model: "test"}, s, Request{}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if resp.HeadlineTH != "Leave by 16:45" || domain.HasThai(resp.SummaryTH) || resp.Verdict != decision.LeaveNow {
		t.Fatalf("guardrail should restore the English engine text: %q / %q", resp.HeadlineTH, resp.SummaryTH)
	}
	last := resp.Reasoning[len(resp.Reasoning)-1]
	if last.Tool != GuardrailTool || domain.HasThai(last.SummaryTH) || !strings.Contains(last.SummaryTH, "16:20") {
		t.Fatalf("guardrail step = %+v", last)
	}
	if got := fake.configs[0].SystemInstruction.Parts[0].Text; !strings.Contains(got, "friendly English") {
		t.Error("English request did not send the English instruction")
	}
	thai := &scriptedGemini{replies: []*genai.GenerateContentResponse{
		reply(call("get_trip", nil)), reply(&genai.Part{Text: final}),
	}}
	_, _ = Decide(context.Background(), &Gemini{Gen: thai, Model: "test"}, session(t, at(16, 10)), Request{}, nil)
	if got := thai.configs[0].SystemInstruction.Parts[0].Text; got != systemPrompt {
		t.Error("Thai request must use the Thai prompt unchanged")
	}
}

func TestUngroundedEnglishLeaveBy(t *testing.T) {
	g := Grounding{known: map[string]bool{"16:45": true, "17:00": true}, leaveBy: "16:45"}
	if got := g.Ungrounded("Leave by 16:45, arrive 17:00"); len(got) != 0 {
		t.Errorf("grounded text flagged: %v", got)
	}
	if got := g.Ungrounded("Leave before 17:00"); len(got) != 1 || got[0] != "17:00" {
		t.Errorf("want 17:00 flagged as a wrong leave-by, got %v", got)
	}
	if got := g.Ungrounded("Arrive around 18:10"); len(got) != 1 {
		t.Errorf("want 18:10 flagged, got %v", got)
	}
}
