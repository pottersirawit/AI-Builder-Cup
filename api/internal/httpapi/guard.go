package httpapi

import (
	"context"
	"crypto/subtle"
	"log/slog"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"google.golang.org/api/idtoken"
)

// TokenVerifier checks a Google-signed OIDC ID token and returns its email
// claim. It must accept the token when it was issued for any of audiences.
type TokenVerifier interface {
	Verify(ctx context.Context, token string, audiences []string) (email string, err error)
}

// GoogleVerifier verifies ID tokens against Google's public keys.
type GoogleVerifier struct {
	once sync.Once
	v    *idtoken.Validator
	err  error
}

func (g *GoogleVerifier) Verify(ctx context.Context, token string, audiences []string) (string, error) {
	g.once.Do(func() { g.v, g.err = idtoken.NewValidator(ctx) })
	if g.err != nil {
		return "", g.err
	}
	var last error
	for _, aud := range audiences {
		p, err := g.v.Validate(ctx, token, aud)
		if err != nil {
			last = err
			continue
		}
		email, _ := p.Claims["email"].(string)
		if verified, ok := p.Claims["email_verified"].(bool); ok && !verified {
			return "", errUnverifiedEmail
		}
		return email, nil
	}
	return "", last
}

type guardError string

func (e guardError) Error() string { return string(e) }

const errUnverifiedEmail = guardError("email not verified")

// InternalAuth protects /internal/* and /v1/ingest. A request passes with the
// shared secret in X-Internal-Token, or with an OIDC ID token (Cloud Tasks and
// Pub/Sub push attach one) whose email is one of AllowedSAs. With neither
// Token nor AllowedSAs set (local dev) everything stays open.
type InternalAuth struct {
	Token      string
	AllowedSAs []string
	Verifier   TokenVerifier
	// Audience, when set, is the only audience accepted; otherwise the request's
	// own URL (the default for Cloud Tasks and Pub/Sub push) or its origin.
	Audience string
}

var warnOpenOnce sync.Once

func (a *InternalAuth) enabled() bool { return a.Token != "" || len(a.AllowedSAs) > 0 }

// check returns the HTTP status to reject with, or 0 when the request may pass.
func (a *InternalAuth) check(r *http.Request) int {
	if !a.enabled() {
		warnOpenOnce.Do(func() {
			slog.Warn("internal auth not configured (INTERNAL_TOKEN / TASKS_INVOKER_SA unset): /internal/* and /v1/ingest are open")
		})
		return 0
	}
	if got := r.Header.Get("X-Internal-Token"); got != "" {
		if a.Token != "" && subtle.ConstantTimeCompare([]byte(got), []byte(a.Token)) == 1 {
			return 0
		}
		return http.StatusForbidden
	}
	token, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
	if !ok || strings.TrimSpace(token) == "" {
		return http.StatusUnauthorized
	}
	if len(a.AllowedSAs) == 0 {
		return http.StatusForbidden
	}
	verifier := a.Verifier
	if verifier == nil {
		verifier = defaultVerifier
	}
	email, err := verifier.Verify(r.Context(), strings.TrimSpace(token), a.audiences(r))
	if err != nil || email == "" {
		return http.StatusForbidden
	}
	for _, sa := range a.AllowedSAs {
		if strings.EqualFold(email, sa) {
			return 0
		}
	}
	return http.StatusForbidden
}

var defaultVerifier TokenVerifier = &GoogleVerifier{}

func (a *InternalAuth) audiences(r *http.Request) []string {
	if a.Audience != "" {
		return []string{a.Audience}
	}
	scheme := "https"
	if p := r.Header.Get("X-Forwarded-Proto"); p != "" {
		scheme = p
	}
	origin := scheme + "://" + r.Host
	return []string{origin + r.URL.Path, origin}
}

// require wraps h so that it only runs for authenticated internal callers.
func (a *InternalAuth) require(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch a.check(r) {
		case 0:
			h.ServeHTTP(w, r)
		case http.StatusUnauthorized:
			writeError(w, http.StatusUnauthorized, "authentication required")
		default:
			writeError(w, http.StatusForbidden, "forbidden")
		}
	})
}

// Limits bound what the public, Gemini-backed endpoints may cost. Zero values
// use the defaults below.
type Limits struct {
	DecideRPM        int // per client IP per minute
	PlacesRPM        int
	MaxBodyBytes     int64
	MaxQuestionRunes int
	// Clock is injectable for tests; nil means time.Now.
	Clock func() time.Time

	mu      sync.Mutex
	windows map[string]*window
}

type window struct {
	start time.Time
	n     int
}

const (
	defaultDecideRPM        = 30
	defaultPlacesRPM        = 60
	defaultMaxBodyBytes     = 1 << 20
	defaultMaxQuestionRunes = 500
)

func (l *Limits) decideRPM() int { return orDefault(l.DecideRPM, defaultDecideRPM) }
func (l *Limits) placesRPM() int { return orDefault(l.PlacesRPM, defaultPlacesRPM) }
func (l *Limits) maxBody() int64 {
	if l.MaxBodyBytes > 0 {
		return l.MaxBodyBytes
	}
	return defaultMaxBodyBytes
}
func (l *Limits) maxQuestion() int { return orDefault(l.MaxQuestionRunes, defaultMaxQuestionRunes) }

func orDefault(v, def int) int {
	if v > 0 {
		return v
	}
	return def
}

func (l *Limits) now() time.Time {
	if l.Clock != nil {
		return l.Clock()
	}
	return time.Now()
}

// allow counts one request for key in a fixed one-minute window.
func (l *Limits) allow(key string, perMinute int) bool {
	now := l.now()
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.windows == nil {
		l.windows = map[string]*window{}
	}
	if len(l.windows) > 10000 {
		for k, w := range l.windows {
			if now.Sub(w.start) >= time.Minute {
				delete(l.windows, k)
			}
		}
	}
	w := l.windows[key]
	if w == nil || now.Sub(w.start) >= time.Minute {
		w = &window{start: now}
		l.windows[key] = w
	}
	w.n++
	return w.n <= perMinute
}

// rateLimit limits h to perMinute requests per client IP, counted per bucket.
func (l *Limits) rateLimit(bucket string, perMinute int, h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !l.allow(bucket+"|"+clientIP(r), perMinute) {
			w.Header().Set("Retry-After", "60")
			writeError(w, http.StatusTooManyRequests, "too many requests; try again in a minute")
			return
		}
		h.ServeHTTP(w, r)
	})
}

// limitBody caps the request body so a JSON endpoint cannot be fed megabytes.
func (l *Limits) limitBody(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		r.Body = http.MaxBytesReader(w, r.Body, l.maxBody())
		h.ServeHTTP(w, r)
	})
}

// clientIP is the address Cloud Run appended to X-Forwarded-For (the last
// entry; earlier ones can be forged by the client), else the socket address.
func clientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		if ip := strings.TrimSpace(parts[len(parts)-1]); ip != "" {
			return ip
		}
	}
	if host, _, err := net.SplitHostPort(r.RemoteAddr); err == nil {
		return host
	}
	return r.RemoteAddr
}
