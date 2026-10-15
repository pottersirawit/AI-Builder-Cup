package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

func doLang(t *testing.T, h http.Handler, method, path, lang, body string) (int, string) {
	t.Helper()
	r := httptest.NewRequest(method, path, strings.NewReader(body))
	r.Header.Set("X-Demo-Clock", "16:10")
	if lang != "" {
		r.Header.Set("Accept-Language", lang)
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	return w.Code, w.Body.String()
}

func TestDecideAnswersInEnglishWhenAsked(t *testing.T) {
	h := newServer(t)
	code, body := doLang(t, h, "POST", "/v1/decide", "en", `{"trip_id":"cal-dinner"}`)
	if code != 200 {
		t.Fatalf("status %d: %s", code, body)
	}
	for _, key := range []string{"headline_th", "summary_th", "reason_why_th", "route_advice_th", "note_th"} {
		if !strings.Contains(body, `"`+key+`"`) {
			t.Errorf("missing key %s", key)
		}
	}
	var out struct {
		Headline string `json:"headline_th"`
		Summary  string `json:"summary_th"`
		Trip     struct {
			Title string `json:"title_th"`
		} `json:"trip"`
		Reasoning []struct {
			Summary string `json:"summary_th"`
		} `json:"reasoning"`
	}
	decodeBody(t, body, &out)
	if out.Headline != "Leave by 16:45" || domain.HasThai(out.Summary) || out.Trip.Title != "Dinner with family" {
		t.Fatalf("got %q / %q / %q", out.Headline, out.Summary, out.Trip.Title)
	}
	if len(out.Reasoning) == 0 {
		t.Fatal("no reasoning")
	}
	for _, c := range out.Reasoning {
		if strings.Contains(c.Summary, "ความเสี่ยง") {
			t.Errorf("Thai reasoning step in English mode: %q", c.Summary)
		}
	}
}

func TestDecideEnglishQuestionAndThaiDefault(t *testing.T) {
	h := newServer(t)
	_, body := doLang(t, h, "POST", "/v1/decide", "en-US,en;q=0.9", `{"question_th":"Go to Siam now"}`)
	var out struct {
		Headline string `json:"headline_th"`
		Trip     struct {
			ID    string `json:"id"`
			Title string `json:"title_th"`
		} `json:"trip"`
	}
	decodeBody(t, body, &out)
	if out.Trip.ID != "adhoc-siam" || out.Trip.Title != "Go to Siam" || domain.HasThai(out.Headline) {
		t.Fatalf("got %+v", out)
	}
	for _, lang := range []string{"", "th", "th-TH,th;q=0.9"} {
		_, body := doLang(t, h, "POST", "/v1/decide", lang, `{"trip_id":"cal-dinner"}`)
		if !strings.Contains(body, `"headline_th":"ออกก่อน 16:45"`) {
			t.Errorf("Accept-Language %q: Thai headline changed: %s", lang, body[:200])
		}
	}
}

func TestPlacesAndTripsInEnglish(t *testing.T) {
	h := newServer(t)
	_, body := doLang(t, h, "GET", "/v1/places", "en", "")
	if !strings.Contains(body, `"label_th":"Home"`) || strings.Contains(body, `"label_th":"บ้าน"`) {
		t.Errorf("places: %s", body)
	}
	_, body = doLang(t, h, "GET", "/v1/trips", "en", "")
	if !strings.Contains(body, "Dinner with family") {
		t.Errorf("trips: %s", body)
	}
}

func decodeBody(t *testing.T, body string, v any) {
	t.Helper()
	if err := json.Unmarshal([]byte(body), v); err != nil {
		t.Fatalf("not JSON: %s", body)
	}
}
