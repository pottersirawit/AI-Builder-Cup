package httpapi

import (
	"bytes"
	"encoding/json"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/homestatus"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
	"github.com/pottersirawit/fontokmai/api/internal/reports"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func newServer(t *testing.T) http.Handler {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	spots, err := floodspot.Load(filepath.Join(filepath.Dir(file), "..", "..", "..", "data", "bkk_flood_risk_points.json"))
	if err != nil {
		t.Fatal(err)
	}
	prov := planner.Providers{Weather: scenario.Weather{}, Routes: scenario.Routes{}, Canals: scenario.Canals{}, Reports: reports.NewMemoryStore(scenario.SeedReports()...)}
	s := &Server{DemoMode: true, Planner: &planner.Planner{Spots: spots, Trips: scenario.Trips}, Scenario: prov, Live: prov,
		Users: scenario.MockUsers(), Home: homestatus.Home(scenario.HomeProfile)}
	return s.Handler()
}

func do(t *testing.T, h http.Handler, method, path, demoClock string, body *bytes.Buffer, contentType string) (int, map[string]any) {
	t.Helper()
	if body == nil {
		body = &bytes.Buffer{}
	}
	r := httptest.NewRequest(method, path, body)
	if demoClock != "" {
		r.Header.Set("X-Demo-Clock", demoClock)
	}
	if contentType != "" {
		r.Header.Set("Content-Type", contentType)
	}
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Header().Get("Access-Control-Allow-Origin") != "*" {
		t.Errorf("%s %s: missing CORS header", method, path)
	}
	var out map[string]any
	if w.Body.Len() > 0 {
		if err := json.Unmarshal(w.Body.Bytes(), &out); err != nil {
			t.Fatalf("%s %s: not JSON: %s", method, path, w.Body.String())
		}
	}
	return w.Code, out
}

func TestEndpoints(t *testing.T) {
	h := newServer(t)
	tests := []struct {
		name, method, path, clock, body string
		wantStatus                      int
		check                           func(t *testing.T, out map[string]any)
	}{
		{"health", "GET", "/healthz", "", "", 200, func(t *testing.T, out map[string]any) {
			if out["ok"] != true {
				t.Fatal(out)
			}
		}},
		{"trips", "GET", "/v1/trips", "", "", 200, func(t *testing.T, out map[string]any) {
			trip := out["trips"].([]any)[0].(map[string]any)
			if trip["id"] != "cal-dinner" || trip["arrive_by"] != "2026-09-29T18:30:00+07:00" || trip["mode"] != "car" {
				t.Fatal(trip)
			}
		}},
		{"decide hero", "POST", "/v1/decide", "2026-09-29T16:10:00+07:00", `{"trip_id":"cal-dinner"}`, 200, func(t *testing.T, out map[string]any) {
			if out["verdict"] != "leave_now" || out["headline_th"] != "ออกก่อน 16:45" || out["leave_by"] != "2026-09-29T16:45:00+07:00" || out["generated_by"] != "fallback" {
				t.Fatal(out)
			}
			for _, k := range []string{"summary_th", "confidence", "rain_timeline", "mode_options", "flood_spots", "reasoning", "sources"} {
				if _, ok := out[k]; !ok {
					t.Errorf("missing %s", k)
				}
			}
		}},
		{"decide question", "POST", "/v1/decide", "16:10", `{"trip_id":"cal-dinner","question_th":"ถ้ารอถึงสองทุ่มค่อยกลับล่ะ"}`, 200, func(t *testing.T, out map[string]any) {
			if out["headline_th"] != "ออก 20:00 ได้ แต่เลยนัด 18:30" {
				t.Fatal(out["headline_th"])
			}
		}},
		{"decide empty body uses the first trip", "POST", "/v1/decide", "", "", 200, nil},
		{"decide unknown trip", "POST", "/v1/decide", "", `{"trip_id":"x"}`, 404, nil},
		{"decide bad mode", "POST", "/v1/decide", "", `{"mode":"boat"}`, 400, nil},
		{"decide bad JSON", "POST", "/v1/decide", "", `{`, 400, nil},
		{"bad demo clock", "GET", "/v1/trips", "yesterday", "", 400, nil},
		{"reports near Ratchada at 18:50", "GET", "/v1/reports?lat=13.8130&lng=100.5760&radius_m=300", "2026-09-29T18:50:00+07:00", "", 200, func(t *testing.T, out map[string]any) {
			if n := len(out["reports"].([]any)); n != 2 {
				t.Fatalf("got %d reports", n)
			}
		}},
		{"reports bad radius", "GET", "/v1/reports?radius_m=-1", "", "", 400, nil},
		{"home status 16:10", "GET", "/v1/home-status", "", "", 200, func(t *testing.T, out map[string]any) {
			if out["level"] != "watch" {
				t.Fatal(out)
			}
		}},
		{"home status flood mode", "GET", "/v1/home-status", "2026-09-29T21:40:00+07:00", "", 200, func(t *testing.T, out map[string]any) {
			canal := out["canal"].(map[string]any)
			if out["level"] != "danger" || out["headline_th"] != "น้ำจะถึงหน้าบ้านใน 40 นาที" || canal["level_m"] != 1.8 || canal["rise_cm_2h"] != 40.0 {
				t.Fatal(out)
			}
			if len(out["actions"].([]any)) != 3 {
				t.Fatal(out["actions"])
			}
		}},
		{"preflight", "OPTIONS", "/v1/decide", "", "", 204, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ct := ""
			if tt.body != "" {
				ct = "application/json"
			}
			status, out := do(t, h, tt.method, tt.path, tt.clock, bytes.NewBufferString(tt.body), ct)
			if status != tt.wantStatus {
				t.Fatalf("status = %d, want %d (%v)", status, tt.wantStatus, out)
			}
			if tt.check != nil {
				tt.check(t, out)
			}
		})
	}
}

func multipartReport(t *testing.T, lat, lng string, photo bool) (*bytes.Buffer, string) {
	t.Helper()
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	if lat != "" {
		mw.WriteField("lat", lat)
		mw.WriteField("lng", lng)
	}
	if photo {
		fw, _ := mw.CreateFormFile("photo", "flood.jpg")
		fw.Write([]byte("\xff\xd8\xff\xe0 fake jpeg"))
	}
	mw.Close()
	return &buf, mw.FormDataContentType()
}

func TestCreateReportHero(t *testing.T) {
	h := newServer(t)
	body, ct := multipartReport(t, "13.8130", "100.5760", true)
	status, out := do(t, h, "POST", "/v1/reports", "2026-09-29T18:52:00+07:00", body, ct)
	if status != 201 {
		t.Fatalf("status %d %v", status, out)
	}
	want := map[string]any{"id": "r1", "depth_cm_min": 20.0, "depth_cm_max": 25.0, "confidence": 0.84, "notified_users": 27.0, "corroborating_reports": 2.0, "generated_by": "fallback"}
	for k, v := range want {
		if out[k] != v {
			t.Errorf("%s = %v, want %v", k, out[k], v)
		}
	}
	if p := out["passable"].(map[string]any); p["car"] != "slow" || p["transit"] != "yes" || p["moto"] != "no" {
		t.Errorf("passable = %v", p)
	}
	if !strings.Contains(out["description_th"].(string), "ครึ่งล้อ") {
		t.Errorf("description = %v", out["description_th"])
	}

	// The new report now shows up for others and pushes car drivers to the train.
	_, list := do(t, h, "GET", "/v1/reports?lat=13.8130&lng=100.5760&radius_m=300", "2026-09-29T18:55:00+07:00", nil, "")
	if n := len(list["reports"].([]any)); n != 3 {
		t.Fatalf("got %d reports after posting", n)
	}
	_, dec := do(t, h, "POST", "/v1/decide", "2026-09-29T18:55:00+07:00", bytes.NewBufferString(`{"mode":"car"}`), "application/json")
	if dec["verdict"] != "switch_mode" {
		t.Fatalf("decide after report: %v %v", dec["verdict"], dec["headline_th"])
	}
}

func TestCreateReportValidation(t *testing.T) {
	h := newServer(t)
	tests := []struct {
		name     string
		lat, lng string
		photo    bool
	}{
		{"missing photo", "13.8", "100.5", false},
		{"missing lat", "", "", true},
		{"bad lat", "north", "100.5", true},
	}
	for _, tt := range tests {
		body, ct := multipartReport(t, tt.lat, tt.lng, tt.photo)
		if status, _ := do(t, h, "POST", "/v1/reports", "", body, ct); status != 400 {
			t.Errorf("%s: status %d, want 400", tt.name, status)
		}
	}
	if status, _ := do(t, h, "POST", "/v1/reports", "", bytes.NewBufferString("{}"), "application/json"); status != 400 {
		t.Errorf("JSON body: status %d, want 400", status)
	}
}
