// Package vision asks Gemini to estimate flood depth from a community photo.
package vision

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"google.golang.org/genai"

	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

const prompt = `ภาพนี้ถ่ายโดยผู้ใช้บนถนนในกรุงเทพฯ ตอนฝนตก ประเมินระดับน้ำบนถนนจากภาพ
เทียบกับสิ่งที่รู้ความสูง: ขอบทางเท้า ~15 ซม., ครึ่งล้อรถเก๋ง ~30 ซม., ข้อเท้า ~10 ซม., เข่า ~45 ซม.
passable ของแต่ละพาหนะให้ตอบ yes, slow หรือ no (รถเก๋งเสี่ยงที่ 15 ซม. ขึ้นไป มอเตอร์ไซค์ไม่ควรผ่านที่ 10 ซม. ขึ้นไป รถไฟฟ้าไม่กระทบน้ำบนถนน)
description_th เป็นภาษาไทย 1-2 ประโยค บอกสิ่งที่เห็นและคำแนะนำ ถ้าภาพไม่ใช่ถนนหรือมองไม่เห็นน้ำ ให้ confidence ต่ำกว่า 0.3
is_flood_scene เป็น true เฉพาะเมื่อเป็นภาพถ่ายจริงของน้ำท่วมขังบนถนนหรือทางเท้า ไม่ใช่ภาพอื่น
looks_like_screenshot เป็น true ถ้าภาพดูเป็นภาพจับหน้าจอ ภาพตัดต่อ หรือภาพที่ไม่ได้ถ่ายเองหน้างาน
depth_cm ต้องเป็นระดับน้ำที่สมเหตุสมผลบนถนน (0-150 ซม.)`

// englishPrompt is appended for English requests so the description comes back
// in English; the JSON key stays description_th.
const englishPrompt = `

Write description_th in English instead of Thai: 1-2 short, friendly sentences saying what you see and what the traveller should do.`

func promptFor(l domain.Lang) string {
	if l == domain.LangEN {
		return prompt + englishPrompt
	}
	return prompt
}

// MinConfidence is the lowest confidence at which a photo counts as evidence.
const MinConfidence = 0.5

// MaxPlausibleDepthCM is the deepest street flooding a photo can claim; Gemini
// answers above it are treated as unusable.
const MaxPlausibleDepthCM = 150

// GeneratedByRejected marks an assessment of a photo that is not usable as
// flood evidence (not a flood scene, a screenshot, or too uncertain).
const GeneratedByRejected = "rejected"

// assessment is Gemini's structured answer: the report fields plus the
// authenticity checks that decide whether the photo counts as evidence.
type assessment struct {
	domain.Report
	IsFloodScene        bool `json:"is_flood_scene"`
	LooksLikeScreenshot bool `json:"looks_like_screenshot"`
}

var passEnum = []string{"yes", "slow", "no"}

var schema = &genai.Schema{
	Type: genai.TypeObject,
	Properties: map[string]*genai.Schema{
		"depth_cm_min":          {Type: genai.TypeInteger},
		"depth_cm_max":          {Type: genai.TypeInteger},
		"confidence":            {Type: genai.TypeNumber},
		"is_flood_scene":        {Type: genai.TypeBoolean},
		"looks_like_screenshot": {Type: genai.TypeBoolean},
		"description_th":        {Type: genai.TypeString},
		"passable": {Type: genai.TypeObject, Properties: map[string]*genai.Schema{
			"car": {Type: genai.TypeString, Enum: passEnum}, "transit": {Type: genai.TypeString, Enum: passEnum}, "moto": {Type: genai.TypeString, Enum: passEnum},
		}, Required: []string{"car", "transit", "moto"}},
	},
	Required: []string{"depth_cm_min", "depth_cm_max", "confidence", "description_th", "passable", "is_flood_scene", "looks_like_screenshot"},
}

// Assess returns depth, confidence, a description in lang (Thai or English) and per-mode passability.
// Without Gemini, or when Gemini's answer is not usable, it returns the scenario
// assessment of มิว's 18:52 photo and generatedBy "fallback". When Gemini says the
// photo is not a real flood scene, it returns zero depth, an explanation and
// generatedBy "rejected"; neither of those is evidence.
func Assess(ctx context.Context, g *agent.Gemini, photo []byte, mimeType string, lang domain.Lang) (domain.Report, string) {
	if !g.Available() {
		fallback := scenario.HeroAssessment()
		fallback.DescriptionTH = scenario.Text(fallback.DescriptionTH, lang)
		return fallback, "fallback"
	}
	r, err := assess(ctx, g, photo, mimeType, lang)
	if err != nil {
		slog.Warn("gemini vision failed, rejecting corrupt or invalid image", "err", err)
		return rejected(domain.Report{}, "corrupt_image", lang), GeneratedByRejected
	}
	if reason := notEvidence(r); reason != "" {
		return rejected(r.Report, reason, lang), GeneratedByRejected
	}
	return r.Report, "gemini"
}

// IsEvidence reports whether a generatedBy value marks an assessment that may be
// stored as a community report.
func IsEvidence(generatedBy string) bool {
	return generatedBy != "fallback" && generatedBy != GeneratedByRejected
}

func notEvidence(a assessment) string {
	switch {
	case !a.IsFloodScene:
		return "not_flood"
	case a.LooksLikeScreenshot:
		return "screenshot"
	case a.Confidence < MinConfidence:
		return "low_confidence"
	}
	return ""
}

func rejected(r domain.Report, reason string, lang domain.Lang) domain.Report {
	th := map[string]string{
		"not_flood":      "ภาพนี้ดูไม่ใช่น้ำท่วมบนถนน จึงยังไม่นำไปเตือนคนอื่น ลองถ่ายใหม่ให้เห็นระดับน้ำชัดๆ",
		"screenshot":     "ภาพนี้ดูเป็นภาพจับหน้าจอหรือภาพที่ไม่ได้ถ่ายหน้างาน จึงยังไม่นำไปเตือนคนอื่น",
		"low_confidence": "ภาพนี้ยังไม่ชัดพอจะประเมินระดับน้ำ จึงยังไม่นำไปเตือนคนอื่น ลองถ่ายใหม่ให้ใกล้ขึ้น",
		"corrupt_image":  "ไฟล์รูปภาพไม่ถูกต้องหรือเสียหาย ไม่สามารถประเมินได้",
	}
	en := map[string]string{
		"not_flood":      "This photo does not look like street flooding, so it was not shared as a warning. Try again with the water level in view.",
		"screenshot":     "This photo looks like a screenshot or an image not taken on the spot, so it was not shared as a warning.",
		"low_confidence": "This photo is too unclear to judge the water level, so it was not shared as a warning. Try again from closer.",
		"corrupt_image":  "The image file is invalid or corrupted and cannot be assessed.",
	}
	r.DepthCMMin, r.DepthCMMax = 0, 0
	r.DescriptionTH = th[reason]
	if lang == domain.LangEN {
		r.DescriptionTH = en[reason]
	}
	return r
}

func assess(ctx context.Context, g *agent.Gemini, photo []byte, mimeType string, lang domain.Lang) (assessment, error) {
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	zero := float32(0)
	contents := []*genai.Content{genai.NewContentFromParts([]*genai.Part{
		genai.NewPartFromBytes(photo, mimeType), genai.NewPartFromText(promptFor(lang)),
	}, genai.RoleUser)}
	resp, err := g.Gen.GenerateContent(ctx, g.Model, contents, &genai.GenerateContentConfig{
		Temperature: &zero, ResponseMIMEType: "application/json", ResponseSchema: schema,
	})
	if err != nil {
		return assessment{}, err
	}
	var out assessment
	if err := json.Unmarshal([]byte(resp.Text()), &out); err != nil {
		return assessment{}, fmt.Errorf("vision JSON: %w", err)
	}
	return out, validate(out.Report)
}

func validate(r domain.Report) error {
	valid := func(s string) bool { return s == "yes" || s == "slow" || s == "no" }
	switch {
	case r.DepthCMMin < 0 || r.DepthCMMax < r.DepthCMMin || r.DepthCMMax > MaxPlausibleDepthCM:
		return fmt.Errorf("implausible depth %d-%d", r.DepthCMMin, r.DepthCMMax)
	case r.Confidence < 0 || r.Confidence > 1:
		return fmt.Errorf("confidence %v out of range", r.Confidence)
	case r.DescriptionTH == "":
		return errors.New("missing description")
	case !valid(r.Passable.Car) || !valid(r.Passable.Transit) || !valid(r.Passable.Moto):
		return fmt.Errorf("bad passable %+v", r.Passable)
	}
	return nil
}
