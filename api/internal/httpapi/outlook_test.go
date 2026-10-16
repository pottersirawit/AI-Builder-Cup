package httpapi

import (
	"encoding/json"
	"net/http/httptest"
	"testing"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

func TestOutlookOnDemoClock(t *testing.T) {
	h := newServer(t)
	r := httptest.NewRequest("GET", "/v1/outlook?lat=13.81&lng=100.59", nil)
	r.Header.Set("X-Demo-Clock", "2026-09-29T16:10:00+07:00")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != 200 {
		t.Fatalf("status %d %s", w.Code, w.Body)
	}
	t.Logf("response: %s", w.Body)
	var out map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	hours := out["hours"].([]any)
	if len(hours) != 12 {
		t.Fatalf("got %d hours", len(hours))
	}
	if first := hours[0].(map[string]any)["time"]; first != "2026-09-29T16:00:00+07:00" {
		t.Errorf("first hour = %v", first)
	}
	if out["sunset"] != "2026-09-29T18:10:00+07:00" {
		t.Errorf("sunset = %v", out["sunset"])
	}
	if src := out["sources"].([]any); len(src) == 0 {
		t.Error("no sources")
	}
	for _, v := range append(hours, out["now"]) {
		hr := v.(map[string]any)
		for _, k := range []string{"time", "temp_c", "feels_like_c", "uv_index", "rain_prob_pct", "rain_mm_per_hr", "humidity_pct", "wind_kph", "condition", "condition_th"} {
			if _, ok := hr[k]; !ok {
				t.Errorf("hour %v missing %s", hr["time"], k)
			}
		}
	}
	if s := out["now"].(map[string]any)["condition_th"].(string); !domain.HasThai(s) {
		t.Errorf("Thai default condition = %q", s)
	}

	_, en := doEN(t, h, "GET", "/v1/outlook", "2026-09-29T16:10:00+07:00", nil, "")
	noThai(t, "now condition", en["now"].(map[string]any)["condition_th"])
	for _, v := range en["hours"].([]any) {
		noThai(t, "hour condition", v.(map[string]any)["condition_th"])
	}
}

func TestOutlookRejectsBadPoint(t *testing.T) {
	status, _ := do(t, newServer(t), "GET", "/v1/outlook?lat=abc&lng=100", "16:10", nil, "")
	if status != 400 {
		t.Errorf("status %d", status)
	}
}
