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
	"sync"
	"time"

	"google.golang.org/genai"
)

// DefaultFastModel is the right-sized lightweight model for structured NLU and extraction tasks.
const DefaultFastModel = "gemini-2.5-flash-lite"

// Generator is the slice of the genai client the agent uses; tests fake it.
type Generator interface {
	GenerateContent(ctx context.Context, model string, contents []*genai.Content, config *genai.GenerateContentConfig) (*genai.GenerateContentResponse, error)
}

// ContextCacher manages explicit Gemini CachedContent resources; *genai.Caches satisfies it.
type ContextCacher interface {
	Create(ctx context.Context, model string, config *genai.CreateCachedContentConfig) (*genai.CachedContent, error)
}

type cachedContextEntry struct {
	name    string
	expires time.Time
	failed  bool
}

type cachedResponseEntry struct {
	value   any
	expires time.Time
}

const maxResponseCacheEntries = 512

type geminiState struct {
	mu             sync.Mutex
	contextCaches  map[string]cachedContextEntry
	responseCaches map[string]cachedResponseEntry
}

// Gemini bundles a generator with the model name. A nil *Gemini means "no
// Gemini configured"; every caller falls back.
type Gemini struct {
	Gen   Generator
	Model string
	// FastModel is the lighter model used by GenerateFast (e.g. gemini-2.5-flash-lite)
	// before falling back to Model and Fallbacks.
	FastModel string
	// Fallbacks are tried in order by Generate when Model is not available to
	// this project (from the rest of a comma-separated GEMINI_MODEL).
	Fallbacks []string
	// Cacher optionally creates explicit Gemini context caches for SystemInstruction + Tools.
	Cacher ContextCacher

	stateMu sync.Mutex
	state   *geminiState
}

func (g *Gemini) ensureState() *geminiState {
	g.stateMu.Lock()
	defer g.stateMu.Unlock()
	if g.state == nil {
		g.state = &geminiState{
			contextCaches:  make(map[string]cachedContextEntry),
			responseCaches: make(map[string]cachedResponseEntry),
		}
	}
	return g.state
}

// GetCached retrieves an in-memory cached value scoped to this Gemini client if not expired.
func (g *Gemini) GetCached(key string) (any, bool) {
	if !g.Available() {
		return nil, false
	}
	st := g.ensureState()
	st.mu.Lock()
	defer st.mu.Unlock()
	entry, ok := st.responseCaches[key]
	if !ok {
		return nil, false
	}
	if !entry.expires.IsZero() && time.Now().After(entry.expires) {
		delete(st.responseCaches, key)
		return nil, false
	}
	return entry.value, true
}

// SetCached stores a value in the Gemini client's bounded in-memory TTL cache.
func (g *Gemini) SetCached(key string, value any, ttl time.Duration) {
	if !g.Available() || ttl <= 0 {
		return
	}
	st := g.ensureState()
	st.mu.Lock()
	defer st.mu.Unlock()
	now := time.Now()
	if len(st.responseCaches) >= maxResponseCacheEntries {
		for k, v := range st.responseCaches {
			if !v.expires.IsZero() && now.After(v.expires) {
				delete(st.responseCaches, k)
			}
		}
		if len(st.responseCaches) >= maxResponseCacheEntries {
			for k := range st.responseCaches {
				delete(st.responseCaches, k)
				break
			}
		}
	}
	st.responseCaches[key] = cachedResponseEntry{value: value, expires: now.Add(ttl)}
}

// NewGeminiFromEnv uses GEMINI_API_KEY (Gemini API) or GOOGLE_CLOUD_PROJECT
// (Vertex AI with Application Default Credentials). It returns nil when neither
// is set or the client cannot be built.
func NewGeminiFromEnv(ctx context.Context) *Gemini {
	models := ParseModels(os.Getenv("GEMINI_MODEL"))
	fastModel := strings.TrimSpace(os.Getenv("GEMINI_FAST_MODEL"))
	if fastModel == "" {
		fastModel = DefaultFastModel
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
	var cacher ContextCacher
	if os.Getenv("GEMINI_CONTEXT_CACHE") == "1" && client.Caches != nil {
		cacher = client.Caches
	}
	return &Gemini{
		Gen:       &RetryGenerator{Gen: client.Models},
		Model:     models[0],
		FastModel: fastModel,
		Fallbacks: models[1:],
		Cacher:    cacher,
	}
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
	return g.generateWithModels(ctx, models, contents, cfg)
}

// GenerateFast tries FastModel first (when configured) for lightweight extraction
// and NLU tasks, falling back to Model and Fallbacks if FastModel is unavailable.
func (g *Gemini) GenerateFast(ctx context.Context, contents []*genai.Content, cfg *genai.GenerateContentConfig) (*genai.GenerateContentResponse, string, error) {
	var models []string
	if g.FastModel != "" && g.FastModel != g.Model {
		models = append(models, g.FastModel)
	}
	models = append(models, g.Model)
	models = append(models, g.Fallbacks...)
	return g.generateWithModels(ctx, models, contents, cfg)
}

func (g *Gemini) generateWithModels(ctx context.Context, models []string, contents []*genai.Content, cfg *genai.GenerateContentConfig) (*genai.GenerateContentResponse, string, error) {
	var err error
	for i, m := range models {
		wireCfg := g.prepareConfig(ctx, m, cfg)
		var resp *genai.GenerateContentResponse
		resp, err = g.Gen.GenerateContent(ctx, m, contents, wireCfg)
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

func (g *Gemini) prepareConfig(ctx context.Context, model string, cfg *genai.GenerateContentConfig) *genai.GenerateContentConfig {
	var out genai.GenerateContentConfig
	if cfg != nil {
		out = *cfg
	}
	if out.ThinkingConfig == nil {
		zero := int32(0)
		out.ThinkingConfig = &genai.ThinkingConfig{ThinkingBudget: &zero}
	}
	if g.Cacher != nil && out.CachedContent == "" && out.SystemInstruction != nil && out.ToolConfig == nil {
		if name := g.resolveCachedContent(ctx, model, &out); name != "" {
			out.CachedContent = name
			out.SystemInstruction = nil
			out.Tools = nil
		}
	}
	return &out
}

func (g *Gemini) resolveCachedContent(ctx context.Context, model string, cfg *genai.GenerateContentConfig) string {
	var sb strings.Builder
	sb.WriteString(model)
	sb.WriteByte('|')
	for _, p := range cfg.SystemInstruction.Parts {
		sb.WriteString(p.Text)
	}
	for _, t := range cfg.Tools {
		for _, fd := range t.FunctionDeclarations {
			sb.WriteByte('|')
			sb.WriteString(fd.Name)
		}
	}
	key := sb.String()
	now := time.Now()

	st := g.ensureState()
	st.mu.Lock()
	entry, ok := st.contextCaches[key]
	if ok {
		if entry.failed {
			st.mu.Unlock()
			return ""
		}
		if entry.name != "" && (entry.expires.IsZero() || now.Before(entry.expires)) {
			st.mu.Unlock()
			return entry.name
		}
	}
	st.mu.Unlock()

	cc, err := g.Cacher.Create(ctx, model, &genai.CreateCachedContentConfig{
		SystemInstruction: cfg.SystemInstruction,
		Tools:             cfg.Tools,
		TTL:               30 * time.Minute,
	})
	st.mu.Lock()
	defer st.mu.Unlock()
	if err != nil || cc == nil || cc.Name == "" {
		st.contextCaches[key] = cachedContextEntry{failed: true}
		return ""
	}
	st.contextCaches[key] = cachedContextEntry{name: cc.Name, expires: cc.ExpireTime}
	return cc.Name
}

// only returns g narrowed to the one model, so a multi-turn loop stays on the
// model that answered its first turn.
func (g *Gemini) only(model string) *Gemini {
	return &Gemini{Gen: g.Gen, Model: model, FastModel: g.FastModel, Cacher: g.Cacher, state: g.ensureState()}
}

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
