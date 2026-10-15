// Package agent is the Gemini layer: a function-calling agent that decides and
// explains in Thai, a Thai question parser, and deterministic fallbacks for both.
package agent

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"math/rand/v2"
	"os"
	"strings"
	"time"

	"google.golang.org/genai"
)

// Generator is the slice of the genai client the agent uses; tests fake it.
type Generator interface {
	GenerateContent(ctx context.Context, model string, contents []*genai.Content, config *genai.GenerateContentConfig) (*genai.GenerateContentResponse, error)
}

// Gemini bundles a generator with the model name. A nil *Gemini means "no
// Gemini configured"; every caller falls back.
type Gemini struct {
	Gen   Generator
	Model string
	// Fallbacks are tried in order by Generate when Model is not available to
	// this project (from the rest of a comma-separated GEMINI_MODEL).
	Fallbacks []string
}

// NewGeminiFromEnv uses GEMINI_API_KEY (Gemini API) or GOOGLE_CLOUD_PROJECT
// (Vertex AI with Application Default Credentials). It returns nil when neither
// is set or the client cannot be built.
func NewGeminiFromEnv(ctx context.Context) *Gemini {
	models := ParseModels(os.Getenv("GEMINI_MODEL"))
	var cfg *genai.ClientConfig
	switch {
	case os.Getenv("GEMINI_API_KEY") != "":
		cfg = &genai.ClientConfig{APIKey: os.Getenv("GEMINI_API_KEY"), Backend: genai.BackendGeminiAPI}
	case os.Getenv("GOOGLE_CLOUD_PROJECT") != "":
		loc := os.Getenv("GOOGLE_CLOUD_LOCATION")
		if loc == "" {
			loc = "us-central1"
		}
		cfg = &genai.ClientConfig{Project: os.Getenv("GOOGLE_CLOUD_PROJECT"), Location: loc, Backend: genai.BackendVertexAI}
	default:
		return nil
	}
	client, err := genai.NewClient(ctx, cfg)
	if err != nil {
		slog.Warn("gemini unavailable, using fallback", "err", err)
		return nil
	}
	return &Gemini{Gen: &RetryGenerator{Gen: client.Models}, Model: models[0], Fallbacks: models[1:]}
}

// ParseModels splits a comma-separated GEMINI_MODEL list; an empty one is the default model.
func ParseModels(list string) []string {
	var models []string
	for _, m := range strings.Split(list, ",") {
		if m = strings.TrimSpace(m); m != "" {
			models = append(models, m)
		}
	}
	if len(models) == 0 {
		models = []string{"gemini-2.5-flash"}
	}
	return models
}

// Generate is GenerateContent with Model first and then each fallback model
// that the previous one was refused for ("not found / not allowed"). It
// returns the model that answered.
func (g *Gemini) Generate(ctx context.Context, contents []*genai.Content, cfg *genai.GenerateContentConfig) (*genai.GenerateContentResponse, string, error) {
	models := append([]string{g.Model}, g.Fallbacks...)
	var err error
	for i, m := range models {
		var resp *genai.GenerateContentResponse
		resp, err = g.Gen.GenerateContent(ctx, m, contents, cfg)
		if err == nil {
			if i > 0 {
				slog.Warn("gemini model fallback", "tried", models[:i], "using", m)
			}
			return resp, m, nil
		}
		if !modelUnavailable(err) || i == len(models)-1 {
			break
		}
		slog.Warn("gemini model unavailable, trying next", "model", m, "err", err)
	}
	return nil, "", err
}

// only returns g narrowed to the one model, so a multi-turn loop stays on the
// model that answered its first turn.
func (g *Gemini) only(model string) *Gemini { return &Gemini{Gen: g.Gen, Model: model} }

// RetryGenerator retries transient errors (429, 503, 504) of Gen with
// jittered exponential backoff.
type RetryGenerator struct {
	Gen        Generator
	MaxRetries int           // 0 means 2
	Base       time.Duration // 0 means 400ms
	Sleep      func(time.Duration)
}

func (r *RetryGenerator) GenerateContent(ctx context.Context, model string, contents []*genai.Content, cfg *genai.GenerateContentConfig) (*genai.GenerateContentResponse, error) {
	retries, base := r.MaxRetries, r.Base
	if retries == 0 {
		retries = 2
	}
	if base == 0 {
		base = 400 * time.Millisecond
	}
	for attempt := 0; ; attempt++ {
		resp, err := r.Gen.GenerateContent(ctx, model, contents, cfg)
		if err == nil || attempt >= retries || !transient(err) || ctx.Err() != nil {
			return resp, err
		}
		wait := time.Duration(float64(base<<attempt) * (0.5 + rand.Float64()))
		slog.Warn("gemini transient error, retrying", "model", model, "attempt", attempt+1, "in", wait, "err", err)
		if r.Sleep != nil {
			r.Sleep(wait)
			continue
		}
		select {
		case <-time.After(wait):
		case <-ctx.Done():
			return nil, err
		}
	}
}

// errInfo is the HTTP status and lower-cased text of a Gemini error.
func errInfo(err error) (int, string) {
	code := 0
	var ae genai.APIError
	if errors.As(err, &ae) {
		code = ae.Code
	}
	var pe *genai.APIError
	if errors.As(err, &pe) && pe != nil {
		code = pe.Code
	}
	return code, strings.ToLower(err.Error())
}

func transient(err error) bool {
	code, text := errInfo(err)
	switch code {
	case 429, 503, 504:
		return true
	}
	return strings.Contains(text, "resource_exhausted") || strings.Contains(text, "unavailable") || strings.Contains(text, "429") || strings.Contains(text, "503")
}

// modelUnavailable is "this model does not exist or is not allowed here", as
// opposed to a problem with the request that another model would share.
func modelUnavailable(err error) bool {
	code, text := errInfo(err)
	if code == 404 || strings.Contains(text, "not_found") || strings.Contains(text, "not found") || strings.Contains(text, "not allowed") {
		return true
	}
	return (code == 403 || strings.Contains(text, "permission_denied")) && strings.Contains(text, "model")
}

func (g *Gemini) Available() bool { return g != nil && g.Gen != nil }

func temperature(v float32) *float32 { return &v }

// decodeJSON reads the first JSON object in a model reply, tolerating code fences.
func decodeJSON(text string, out any) error {
	start, end := strings.Index(text, "{"), strings.LastIndex(text, "}")
	if start < 0 || end <= start {
		return errors.New("no JSON object in model reply")
	}
	return json.Unmarshal([]byte(text[start:end+1]), out)
}
