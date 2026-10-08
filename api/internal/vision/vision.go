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
description_th เป็นภาษาไทย 1-2 ประโยค บอกสิ่งที่เห็นและคำแนะนำ ถ้าภาพไม่ใช่ถนนหรือมองไม่เห็นน้ำ ให้ confidence ต่ำกว่า 0.3`

var passEnum = []string{"yes", "slow", "no"}

var schema = &genai.Schema{
	Type: genai.TypeObject,
	Properties: map[string]*genai.Schema{
		"depth_cm_min":   {Type: genai.TypeInteger},
		"depth_cm_max":   {Type: genai.TypeInteger},
		"confidence":     {Type: genai.TypeNumber},
		"description_th": {Type: genai.TypeString},
		"passable": {Type: genai.TypeObject, Properties: map[string]*genai.Schema{
			"car": {Type: genai.TypeString, Enum: passEnum}, "transit": {Type: genai.TypeString, Enum: passEnum}, "moto": {Type: genai.TypeString, Enum: passEnum},
		}, Required: []string{"car", "transit", "moto"}},
	},
	Required: []string{"depth_cm_min", "depth_cm_max", "confidence", "description_th", "passable"},
}

// Assess returns depth, confidence, Thai description and per-mode passability.
// Without Gemini, or when Gemini's answer is not usable, it returns the scenario
// assessment of มิว's 18:52 photo and generatedBy "fallback".
func Assess(ctx context.Context, g *agent.Gemini, photo []byte, mimeType string) (domain.Report, string) {
	fallback := scenario.HeroAssessment()
	if !g.Available() {
		return fallback, "fallback"
	}
	r, err := assess(ctx, g, photo, mimeType)
	if err != nil {
		slog.Warn("gemini vision failed, using fallback", "err", err)
		return fallback, "fallback"
	}
	return r, "gemini"
}

func assess(ctx context.Context, g *agent.Gemini, photo []byte, mimeType string) (domain.Report, error) {
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	zero := float32(0)
	contents := []*genai.Content{genai.NewContentFromParts([]*genai.Part{
		genai.NewPartFromBytes(photo, mimeType), genai.NewPartFromText(prompt),
	}, genai.RoleUser)}
	resp, err := g.Gen.GenerateContent(ctx, g.Model, contents, &genai.GenerateContentConfig{
		Temperature: &zero, ResponseMIMEType: "application/json", ResponseSchema: schema,
	})
	if err != nil {
		return domain.Report{}, err
	}
	var out domain.Report
	if err := json.Unmarshal([]byte(resp.Text()), &out); err != nil {
		return domain.Report{}, fmt.Errorf("vision JSON: %w", err)
	}
	return out, validate(out)
}

func validate(r domain.Report) error {
	valid := func(s string) bool { return s == "yes" || s == "slow" || s == "no" }
	switch {
	case r.DepthCMMin < 0 || r.DepthCMMax < r.DepthCMMin || r.DepthCMMax > 300:
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
