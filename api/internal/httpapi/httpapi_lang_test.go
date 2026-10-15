package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

func doEN(t *testing.T, h http.Handler, method, path, demoClock string, body *bytes.Buffer, contentType string) (int, map[string]any) {
	t.Helper()
	if body == nil {
		body = &bytes.Buffer{}
	}
	r := httptest.NewRequest(method, path, body)
	r.Header.Set("Accept-Language", "en")
	if demoClock != "" {
		r.Header.Set("X-Demo-Clock", demoClock)
	}
	if contentType != "" {
		r.Header.Set("Content-Type", contentType)
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	var out map[string]any
	if w.Body.Len() > 0 {
		if err := json.Unmarshal(w.Body.Bytes(), &out); err != nil {
			t.Fatalf("%s %s: not JSON: %s", method, path, w.Body.String())
		}
	}
	return w.Code, out
}

func noThai(t *testing.T, field string, v any) {
	t.Helper()
	if s, ok := v.(string); ok && domain.HasThai(s) {
		t.Errorf("%s has Thai text in English mode: %q", field, s)
	}
}

func TestCreateReportAndListInEnglish(t *testing.T) {
	h := newServer(t)
	body, ct := multipartReport(t, "13.8130", "100.5760", true)
	status, out := doEN(t, h, "POST", "/v1/reports", "2026-09-29T18:52:00+07:00", body, ct)
	if status != 201 {
		t.Fatalf("status %d %v", status, out)
	}
	if d := out["description_th"].(string); !strings.Contains(d, "halfway up a car wheel") {
		t.Errorf("description = %q", d)
	}
	noThai(t, "description_th", out["description_th"])

	_, list := doEN(t, h, "GET", "/v1/reports?lat=13.8130&lng=100.5760&radius_m=300", "2026-09-29T18:55:00+07:00", nil, "")
	reps := list["reports"].([]any)
	if len(reps) != 2 {
		t.Fatalf("got %d reports", len(reps))
	}
	for _, r := range reps {
		noThai(t, "report description_th", r.(map[string]any)["description_th"])
	}
}

func TestHomeStatusInEnglish(t *testing.T) {
	h := newServer(t)
	for _, q := range []string{"", "?lat=13.6681&lng=100.6046", "?lat=18.79&lng=98.98", "?lat=13.8161&lng=100.5901"} {
		_, out := doEN(t, h, "GET", "/v1/home-status"+q, "21:40", nil, "")
		for _, k := range []string{"headline_th", "summary_th"} {
			noThai(t, q+" "+k, out[k])
		}
		for _, a := range out["actions"].([]any) {
			noThai(t, q+" action", a.(map[string]any)["text_th"])
		}
		for _, s := range out["sources"].([]any) {
			noThai(t, q+" source", s)
		}
		noThai(t, q+" place", out["place"].(map[string]any)["name_th"])
		if c, ok := out["canal"].(map[string]any); ok {
			noThai(t, q+" canal", c["name_th"])
		}
	}
	_, th := do(t, h, "GET", "/v1/home-status?lat=13.6681&lng=100.6046", "18:15", nil, "")
	if th["place"].(map[string]any)["name_th"] != "บ้าน" {
		t.Errorf("Thai default place name changed: %v", th["place"])
	}
}

func TestPlacesSearchAndReverseInEnglish(t *testing.T) {
	h := newServer(t)
	_, out := doEN(t, h, "GET", "/v1/places/search?q="+url.QueryEscape("พารากอน"), "", nil, "")
	first := out["places"].([]any)[0].(map[string]any)
	if first["name_th"] != "Siam Paragon" {
		t.Fatalf("search = %v", first)
	}
	_, rev := doEN(t, h, "GET", "/v1/places/reverse?lat=13.7441&lng=100.5431", "", nil, "")
	noThai(t, "reverse name", rev["name_th"])
}
