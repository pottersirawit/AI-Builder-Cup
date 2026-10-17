package vision

import (
	"context"
	"errors"
	"strings"
	"testing"

	"google.golang.org/genai"

	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

type fakeGen struct {
	text string
	err  error
}

func (f fakeGen) GenerateContent(context.Context, string, []*genai.Content, *genai.GenerateContentConfig) (*genai.GenerateContentResponse, error) {
	if f.err != nil {
		return nil, f.err
	}
	return &genai.GenerateContentResponse{Candidates: []*genai.Candidate{{Content: &genai.Content{Parts: []*genai.Part{{Text: f.text}}}}}}, nil
}

func gem(text string) *agent.Gemini { return &agent.Gemini{Gen: fakeGen{text: text}} }

func TestAssess(t *testing.T) {
	good := `{"depth_cm_min":30,"depth_cm_max":40,"confidence":0.7,"is_flood_scene":true,"looks_like_screenshot":false,"description_th":"น้ำถึงครึ่งล้อ","passable":{"car":"no","transit":"yes","moto":"no"}}`
	tests := []struct {
		name    string
		g       *agent.Gemini
		wantBy  string
		wantMax int
	}{
		{"no gemini: hero fallback", nil, "fallback", 25},
		{"gemini answer", &agent.Gemini{Gen: fakeGen{text: good}}, "gemini", 40},
		{"gemini error", &agent.Gemini{Gen: fakeGen{err: errors.New("503")}}, "rejected", 0},
		{"not a flood scene", gem(`{"depth_cm_min":30,"depth_cm_max":40,"confidence":0.9,"is_flood_scene":false,"looks_like_screenshot":false,"description_th":"x","passable":{"car":"no","transit":"yes","moto":"no"}}`), "rejected", 0},
		{"screenshot", gem(`{"depth_cm_min":30,"depth_cm_max":40,"confidence":0.9,"is_flood_scene":true,"looks_like_screenshot":true,"description_th":"x","passable":{"car":"no","transit":"yes","moto":"no"}}`), "rejected", 0},
		{"low confidence", gem(`{"depth_cm_min":30,"depth_cm_max":40,"confidence":0.4,"is_flood_scene":true,"looks_like_screenshot":false,"description_th":"x","passable":{"car":"no","transit":"yes","moto":"no"}}`), "rejected", 0},
		{"depth above 150 cm is implausible", gem(`{"depth_cm_min":100,"depth_cm_max":200,"confidence":0.9,"is_flood_scene":true,"looks_like_screenshot":false,"description_th":"x","passable":{"car":"no","transit":"yes","moto":"no"}}`), "rejected", 0},
		{"implausible depth", &agent.Gemini{Gen: fakeGen{text: `{"depth_cm_min":50,"depth_cm_max":10,"confidence":0.5,"description_th":"x","passable":{"car":"no","transit":"yes","moto":"no"}}`}}, "rejected", 0},
		{"bad passable", &agent.Gemini{Gen: fakeGen{text: `{"depth_cm_min":5,"depth_cm_max":10,"confidence":0.5,"description_th":"x","passable":{"car":"maybe","transit":"yes","moto":"no"}}`}}, "rejected", 0},
		{"not JSON", &agent.Gemini{Gen: fakeGen{text: "ไม่ทราบ"}}, "rejected", 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r, by := Assess(context.Background(), tt.g, []byte("jpeg"), "image/jpeg", domain.LangTH)
			if by != tt.wantBy || r.DepthCMMax != tt.wantMax {
				t.Fatalf("got %s %+v", by, r)
			}
		})
	}
	r, _ := Assess(context.Background(), nil, nil, "", domain.LangTH)
	if r.DepthCMMin != 20 || r.Confidence != 0.84 || r.Passable.Moto != "no" || r.Passable.Car != "slow" {
		t.Fatalf("fallback should be the hero assessment, got %+v", r)
	}
}

type promptSpy struct{ prompt string }

func (p *promptSpy) GenerateContent(_ context.Context, _ string, contents []*genai.Content, _ *genai.GenerateContentConfig) (*genai.GenerateContentResponse, error) {
	for _, part := range contents[0].Parts {
		p.prompt += part.Text
	}
	return nil, errors.New("stop")
}

func TestPromptHasEnglishInstructionOnlyForEnglish(t *testing.T) {
	for _, lang := range []domain.Lang{domain.LangTH, domain.LangEN} {
		spy := &promptSpy{}
		Assess(context.Background(), &agent.Gemini{Gen: spy}, []byte("jpeg"), "image/jpeg", lang)
		if got := strings.Contains(spy.prompt, "in English instead of Thai"); got != (lang == domain.LangEN) {
			t.Errorf("%s: English instruction present = %v", lang, got)
		}
		if !strings.HasPrefix(spy.prompt, prompt) {
			t.Errorf("%s: Thai prompt must stay the base of the prompt", lang)
		}
		if lang == domain.LangTH && spy.prompt != prompt {
			t.Errorf("Thai prompt changed: %q", spy.prompt)
		}
	}
}

func TestEnglishFallbackDescription(t *testing.T) {
	r, by := Assess(context.Background(), nil, nil, "", domain.LangEN)
	if by != "fallback" || domain.HasThai(r.DescriptionTH) || r.DescriptionTH == "" {
		t.Fatalf("got %s %q", by, r.DescriptionTH)
	}
}

func TestRejectedPhotoExplainsAndIsNotEvidence(t *testing.T) {
	g := gem(`{"depth_cm_min":30,"depth_cm_max":40,"confidence":0.9,"is_flood_scene":false,"looks_like_screenshot":false,"description_th":"x","passable":{"car":"no","transit":"yes","moto":"no"}}`)
	for _, lang := range []domain.Lang{domain.LangTH, domain.LangEN} {
		r, by := Assess(context.Background(), g, []byte("jpeg"), "image/jpeg", lang)
		if IsEvidence(by) || r.DepthCMMax != 0 || r.DescriptionTH == "" || domain.HasThai(r.DescriptionTH) != (lang == domain.LangTH) {
			t.Errorf("%s: got %s %+v", lang, by, r)
		}
	}
	if IsEvidence("fallback") || !IsEvidence("gemini") {
		t.Error("only gemini assessments are evidence")
	}
}
