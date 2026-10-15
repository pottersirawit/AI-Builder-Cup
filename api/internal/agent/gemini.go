// Package agent is the Gemini layer: a function-calling agent that decides and
// explains in Thai, a Thai question parser, and deterministic fallbacks for both.
package agent

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"os"
	"strings"

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
}

// NewGeminiFromEnv uses GEMINI_API_KEY (Gemini API) or GOOGLE_CLOUD_PROJECT
// (Vertex AI with Application Default Credentials). It returns nil when neither
// is set or the client cannot be built.
func NewGeminiFromEnv(ctx context.Context) *Gemini {
	model := os.Getenv("GEMINI_MODEL")
	if model == "" {
		model = "gemini-2.5-flash"
	}
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
	return &Gemini{Gen: client.Models, Model: model}
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
