package httpapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type fakeVerifier struct {
	emails map[string]string // token -> email
	seen   []string          // audiences passed in
}

func (f *fakeVerifier) Verify(_ context.Context, token string, audiences []string) (string, error) {
	f.seen = audiences
	if e, ok := f.emails[token]; ok {
		return e, nil
	}
	return "", errors.New("bad token")
}

func post(h http.Handler, path, body string, hdr map[string]string) *httptest.ResponseRecorder {
	r := httptest.NewRequest("POST", path, strings.NewReader(body))
	r.Header.Set("Content-Type", "application/json")
	for k, v := range hdr {
		r.Header.Set(k, v)
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	return w
}

func TestInternalAuth(t *testing.T) {
	const sa = "invoker@p.iam.gserviceaccount.com"
	v := &fakeVerifier{emails: map[string]string{"good": sa, "other": "evil@x.com", "extra": "second@p.iam.gserviceaccount.com"}}
	s := newTestServer(t, true)
	s.Internal = InternalAuth{Token: "s3cret", AllowedSAs: []string{sa, "second@p.iam.gserviceaccount.com"}, Verifier: v}
	h := s.Handler()
	body := `{"uid":"u","trip_id":"cal-dinner"}`
	tests := []struct {
		name string
		hdr  map[string]string
		want int
	}{
		{"no credentials", nil, 401},
		{"wrong shared token", map[string]string{"X-Internal-Token": "nope"}, 403},
		{"right shared token", map[string]string{"X-Internal-Token": "s3cret"}, 200},
		{"oidc invoker", map[string]string{"Authorization": "Bearer good"}, 200},
		{"oidc second allowed SA", map[string]string{"Authorization": "Bearer extra"}, 200},
		{"oidc other principal", map[string]string{"Authorization": "Bearer other"}, 403},
		{"oidc invalid token", map[string]string{"Authorization": "Bearer junk"}, 403},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			hdr := tt.hdr
			w := post(h, "/internal/tasks/check", body, hdr)
			if tt.want == 200 {
				if w.Code == 401 || w.Code == 403 {
					t.Fatalf("status %d: %s", w.Code, w.Body)
				}
				return
			}
			if w.Code != tt.want {
				t.Fatalf("status %d, want %d", w.Code, tt.want)
			}
		})
	}
	if w := post(h, "/internal/pubsub/raw", `{}`, nil); w.Code != 401 {
		t.Errorf("pubsub without credentials = %d", w.Code)
	}
}

func TestInternalAuthAudience(t *testing.T) {
	v := &fakeVerifier{emails: map[string]string{"good": "a@b"}}
	s := newTestServer(t, true)
	s.Internal = InternalAuth{AllowedSAs: []string{"a@b"}, Verifier: v}
	r := httptest.NewRequest("POST", "http://internal.test/internal/tasks/check", strings.NewReader(`{}`))
	r.Host = "svc-abc.a.run.app"
	r.Header.Set("X-Forwarded-Proto", "https")
	r.Header.Set("Authorization", "Bearer good")
	s.Handler().ServeHTTP(httptest.NewRecorder(), r)
	if len(v.seen) == 0 || v.seen[0] != "https://svc-abc.a.run.app/internal/tasks/check" {
		t.Errorf("audiences = %v", v.seen)
	}
}

func TestInternalAuthOpenWhenUnconfigured(t *testing.T) {
	h := newTestServer(t, true).Handler()
	if w := post(h, "/internal/tasks/check", `{"uid":"u","trip_id":"cal-dinner"}`, nil); w.Code == 401 || w.Code == 403 {
		t.Fatalf("dev mode should be open, got %d", w.Code)
	}
}

func TestIngestRequiresAuthUnlessOpen(t *testing.T) {
	body := `{"title":"กินข้าวที่สยาม","body":"พรุ่งนี้ 18:00"}`
	s := newTestServer(t, true)
	s.Internal = InternalAuth{Token: "s3cret"}
	if w := post(s.Handler(), "/v1/ingest", body, nil); w.Code != 401 {
		t.Errorf("ingest without credentials = %d", w.Code)
	}
	if w := post(s.Handler(), "/v1/ingest", body, map[string]string{"X-Internal-Token": "s3cret"}); w.Code == 401 || w.Code == 403 {
		t.Errorf("ingest with token = %d", w.Code)
	}
	s.IngestOpen = true
	if w := post(s.Handler(), "/v1/ingest", body, nil); w.Code == 401 || w.Code == 403 {
		t.Errorf("INGEST_OPEN should allow, got %d", w.Code)
	}
}

func TestRateLimitDecide(t *testing.T) {
	now := time.Date(2026, 10, 15, 10, 0, 0, 0, time.UTC)
	s := newTestServer(t, true)
	s.Limits = Limits{DecideRPM: 3, PlacesRPM: 2, Clock: func() time.Time { return now }}
	h := s.Handler()
	call := func(ip string) int {
		return post(h, "/v1/decide", `{"trip_id":"cal-dinner"}`, map[string]string{"X-Forwarded-For": "10.0.0.1, " + ip, "X-Demo-Clock": "16:10"}).Code
	}
	for i := 0; i < 3; i++ {
		if c := call("1.1.1.1"); c != 200 {
			t.Fatalf("call %d = %d", i, c)
		}
	}
	if c := call("1.1.1.1"); c != http.StatusTooManyRequests {
		t.Fatalf("4th call = %d, want 429", c)
	}
	if c := call("2.2.2.2"); c != 200 {
		t.Errorf("other IP = %d", c)
	}
	now = now.Add(61 * time.Second)
	if c := call("1.1.1.1"); c != 200 {
		t.Errorf("after the window = %d", c)
	}
	// health is never limited, and places have their own bucket
	for i := 0; i < 10; i++ {
		r := httptest.NewRequest("GET", "/v1/healthz", nil)
		r.Header.Set("X-Forwarded-For", "9.9.9.9, 1.1.1.1")
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		if w.Code != 200 {
			t.Fatalf("healthz limited: %d", w.Code)
		}
	}
	get := func() int {
		r := httptest.NewRequest("GET", "/v1/places/search?q=สยาม", nil)
		r.Header.Set("X-Forwarded-For", "9.9.9.9, 1.1.1.1")
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		return w.Code
	}
	if get() != 200 || get() != 200 || get() != http.StatusTooManyRequests {
		t.Error("places/search should allow 2 then 429")
	}
}

func TestDecideInputLimits(t *testing.T) {
	h := newTestServer(t, true).Handler()
	long := `{"question_th":"` + strings.Repeat("ก", 501) + `"}`
	if w := post(h, "/v1/decide", long, nil); w.Code != 400 {
		t.Errorf("501-rune question = %d, want 400", w.Code)
	}
	ok := `{"trip_id":"cal-dinner","question_th":"` + strings.Repeat("ก", 500) + `"}`
	if w := post(h, "/v1/decide", ok, map[string]string{"X-Demo-Clock": "16:10"}); w.Code == 400 && strings.Contains(w.Body.String(), "question_th") {
		t.Errorf("500-rune question rejected: %s", w.Body)
	}
	huge := `{"trip_id":"` + strings.Repeat("a", 2<<20) + `"}`
	if w := post(h, "/v1/decide", huge, nil); w.Code != 400 {
		t.Errorf("2MB body = %d, want 400", w.Code)
	}
}

func TestClientIP(t *testing.T) {
	r := httptest.NewRequest("GET", "/", nil)
	r.RemoteAddr = "9.9.9.9:1234"
	if got := clientIP(r); got != "9.9.9.9" {
		t.Errorf("no XFF: %q", got)
	}
	r.Header.Set("X-Forwarded-For", "6.6.6.6, 3.3.3.3")
	if got := clientIP(r); got != "3.3.3.3" {
		t.Errorf("XFF should use the hop Cloud Run appended, got %q", got)
	}
}
