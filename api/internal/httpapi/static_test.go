package httpapi

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestStaticPages(t *testing.T) {
	s := newTestServer(t, true)
	h := s.Handler()

	t.Run("home page", func(t *testing.T) {
		r := httptest.NewRequest("GET", "/", nil)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)

		if w.Code != http.StatusOK {
			t.Fatalf("GET / returned status %d, want 200", w.Code)
		}
		ct := w.Header().Get("Content-Type")
		if !strings.HasPrefix(ct, "text/html") {
			t.Errorf("GET / content-type = %q, want text/html", ct)
		}
		body := w.Body.String()
		if !strings.Contains(body, "Fontokmai") || !strings.Contains(body, "ฝนตกไหม") {
			t.Errorf("GET / missing app title in body")
		}
		if !strings.Contains(body, "/privacy") {
			t.Errorf("GET / missing link to /privacy")
		}
	})

	t.Run("privacy policy", func(t *testing.T) {
		r := httptest.NewRequest("GET", "/privacy", nil)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)

		if w.Code != http.StatusOK {
			t.Fatalf("GET /privacy returned status %d, want 200", w.Code)
		}
		ct := w.Header().Get("Content-Type")
		if !strings.HasPrefix(ct, "text/html") {
			t.Errorf("GET /privacy content-type = %q, want text/html", ct)
		}
		body := w.Body.String()
		if !strings.Contains(body, "Privacy Policy") {
			t.Errorf("GET /privacy missing Privacy Policy header")
		}
		if !strings.Contains(body, "calendar.readonly") {
			t.Errorf("GET /privacy missing Google Calendar scope disclosure")
		}
		if !strings.Contains(body, "Limited Use") {
			t.Errorf("GET /privacy missing Google Limited Use disclosure")
		}
	})

	t.Run("oauth2 callback without a signed state", func(t *testing.T) {
		r := httptest.NewRequest("GET", "/oauth2callback?code=mock_code_123&state=someone@example.com", nil)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)

		if w.Code == http.StatusFound {
			t.Fatalf("GET /oauth2callback redirected to %q, want the error page", w.Header().Get("Location"))
		}
		ct := w.Header().Get("Content-Type")
		if !strings.HasPrefix(ct, "text/html") {
			t.Errorf("GET /oauth2callback content-type = %q, want text/html", ct)
		}
		body := w.Body.String()
		if strings.Contains(body, "Connected") || !strings.Contains(body, "Back to ฝนตกไหม") {
			t.Errorf("GET /oauth2callback = %s, want an error page with a way back", body)
		}
	})

	t.Run("oauth2 callback error", func(t *testing.T) {
		r := httptest.NewRequest("GET", "/oauth2callback?error=access_denied", nil)
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)

		if w.Code != http.StatusOK {
			t.Fatalf("GET /oauth2callback returned status %d, want 200", w.Code)
		}
		body := w.Body.String()
		if !strings.Contains(body, "Cancelled") || !strings.Contains(body, "access_denied") || !strings.Contains(body, "Back to ฝนตกไหม") {
			t.Errorf("GET /oauth2callback missing error notice in body")
		}
	})
}
