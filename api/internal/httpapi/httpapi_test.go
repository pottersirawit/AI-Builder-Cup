package httpapi

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"google.golang.org/genai"

	"github.com/pottersirawit/fontokmai/api/internal/advise"
	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/geocode"
	"github.com/pottersirawit/fontokmai/api/internal/homestatus"
	"github.com/pottersirawit/fontokmai/api/internal/jobs"
	"github.com/pottersirawit/fontokmai/api/internal/notify"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
	"github.com/pottersirawit/fontokmai/api/internal/reports"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
	"github.com/pottersirawit/fontokmai/api/internal/users"
)

func newServer(t *testing.T) http.Handler { return newServerMode(t, true) }

func newServerMode(t *testing.T, demo bool) http.Handler { return newTestServer(t, demo).Handler() }

func newTestServer(t *testing.T, demo bool) *Server {
	t.Helper()
	if os.Getenv("GOOGLE_OAUTH_CLIENT_ID") == "" && os.Getenv("GOOGLE_CLIENT_ID") == "" {
		t.Setenv("GOOGLE_OAUTH_CLIENT_ID", "test-client-id.apps.googleusercontent.com")
	}
	if os.Getenv("GOOGLE_OAUTH_CLIENT_SECRET") == "" && os.Getenv("GOOGLE_CLIENT_SECRET") == "" {
		t.Setenv("GOOGLE_OAUTH_CLIENT_SECRET", "test-client-secret")
	}
	_, file, _, _ := runtime.Caller(0)
	spots, err := floodspot.Load(filepath.Join(filepath.Dir(file), "..", "..", "..", "data", "bkk_flood_risk_points.json"))
	if err != nil {
		t.Fatal(err)
	}
	landmarks, err := geocode.LoadLandmarks(filepath.Join(filepath.Dir(file), "..", "..", "..", "data", "bkk_landmarks.json"))
	if err != nil {
		t.Fatal(err)
	}
	prov := planner.Providers{Weather: scenario.Weather{}, Routes: scenario.Routes{}, Canals: scenario.Canals{}, Reports: reports.NewMemoryStore(scenario.SeedReports()...)}
	userStore := users.NewMemoryUserStore()
	memNotifier := notify.NewMemoryNotifier()
	eval := &advise.Evaluator{
		Planner:  &planner.Planner{Spots: spots, Trips: scenario.Trips, Places: scenario.Places, Whereabouts: scenario.Whereabouts},
		Users:    userStore,
		Notifier: memNotifier,
	}
	scheduler := jobs.NewInlineScheduler(eval, prov)

	s := &Server{
		DemoMode:  demo,
		Planner:   eval.Planner,
		Scenario:  prov,
		Live:      prov,
		Users:     scenario.MockUsers(),
		Home:      homestatus.Home(scenario.HomeProfile),
		Geocoder:  geocode.Local{Landmarks: landmarks},
		UserStore: userStore,
		Evaluator: eval,
		Scheduler: scheduler,
	}
	return s
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
		{"decide a week trip", "POST", "/v1/decide", "2026-09-29T16:10:00+07:00", `{"trip_id":"cal-lunch"}`, 200, func(t *testing.T, out map[string]any) {
			trip := out["trip"].(map[string]any)
			if trip["id"] != "cal-lunch" || trip["arrive_by"] != "2026-09-30T12:00:00+07:00" || trip["destination"].(map[string]any)["name_th"] != "สยาม" || out["mode"] != "transit" {
				t.Fatal(out)
			}
		}},
		{"decide question", "POST", "/v1/decide", "16:10", `{"trip_id":"cal-dinner","question_th":"ถ้ารอถึงสองทุ่มค่อยกลับล่ะ"}`, 200, func(t *testing.T, out map[string]any) {
			if out["headline_th"] != "ออก 20:00 ได้ แต่เลยนัด 18:30" {
				t.Fatal(out["headline_th"])
			}
		}},
		{"decide empty body uses the first trip", "POST", "/v1/decide", "", "", 200, func(t *testing.T, out map[string]any) {
			if trip := out["trip"].(map[string]any); trip["id"] != "cal-dinner" {
				t.Fatal(trip)
			}
		}},
		{"decide ad-hoc destination from the question", "POST", "/v1/decide", "16:10", `{"question_th":"ไปสยามตอนหกโมงดีไหม"}`, 200, func(t *testing.T, out map[string]any) {
			trip := out["trip"].(map[string]any)
			dest, origin := trip["destination"].(map[string]any), trip["origin"].(map[string]any)
			if trip["id"] != "adhoc-siam" || dest["name_th"] != "สยาม" || origin["name_th"] != "สีลม ซอย 3" || out["depart_at"] != "2026-09-29T18:00:00+07:00" {
				t.Fatal(out)
			}
			if _, ok := trip["arrive_by"]; ok {
				t.Errorf("ad-hoc trip has no deadline, got arrive_by %v", trip["arrive_by"])
			}
		}},
		{"decide follow-up on an ad-hoc trip id", "POST", "/v1/decide", "16:10", `{"trip_id":"adhoc-siam","mode":"transit"}`, 200, func(t *testing.T, out map[string]any) {
			if out["trip"].(map[string]any)["id"] != "adhoc-siam" || out["mode"] != "transit" {
				t.Fatal(out)
			}
		}},
		{"places", "GET", "/v1/places", "16:10", "", 200, func(t *testing.T, out map[string]any) {
			places := out["places"].([]any)
			first := places[0].(map[string]any)
			if len(places) != 5 || first["id"] != "home" || first["label_th"] != "บ้าน" || first["lat"] != 13.816 || out["current_place_id"] != "work" {
				t.Fatal(out)
			}
		}},
		{"places at night", "GET", "/v1/places", "22:00", "", 200, func(t *testing.T, out map[string]any) {
			if out["current_place_id"] != "home" {
				t.Fatal(out)
			}
		}},
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
		{"ingest calendar meeting to siam", "POST", "/v1/ingest", "16:10", `{"source":"calendar","title":"ไปสยาม ตอนหกโมงเย็น","body":"นัดคุยงานที่สยาม"}`, 200, func(t *testing.T, out map[string]any) {
			payload := out["payload"].(map[string]any)
			if payload["is_trip"] != true {
				t.Fatalf("expected payload is_trip = true, got %+v", payload)
			}
			trip := out["trip"].(map[string]any)
			dest := trip["destination"].(map[string]any)
			if dest["name_th"] != "สยาม" {
				t.Fatalf("expected dest = สยาม, got %+v", dest)
			}
		}},
		{"ingest newsletter not a trip", "POST", "/v1/ingest", "16:10", `{"source":"gmail","title":"โปรโมชั่น","body":"ลดราคาพิเศษ"}`, 200, func(t *testing.T, out map[string]any) {
			payload := out["payload"].(map[string]any)
			if payload["is_trip"] == true && out["trip"] != nil {
				t.Fatalf("expected non-trip for promo email, got %+v", out)
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
	want := map[string]any{"id": "", "depth_cm_min": 20.0, "depth_cm_max": 25.0, "confidence": 0.84, "notified_users": 27.0, "corroborating_reports": 2.0, "generated_by": "fallback"}
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

	// The fallback assessment is shown to the poster but is not evidence: it is
	// not stored, and the two seeded Ratchada reports still push drivers to the train.
	_, list := do(t, h, "GET", "/v1/reports?lat=13.8130&lng=100.5760&radius_m=300", "2026-09-29T18:55:00+07:00", nil, "")
	if n := len(list["reports"].([]any)); n != 2 {
		t.Fatalf("got %d reports after posting a fallback assessment, want the 2 seeded", n)
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

func TestLiveModeTripsFollowTheRealClock(t *testing.T) {
	h := newServerMode(t, false)
	before := time.Now()
	_, out := do(t, h, "GET", "/v1/trips", "", nil, "")
	arrive, err := time.Parse(time.RFC3339, out["trips"].([]any)[0].(map[string]any)["arrive_by"].(string))
	if err != nil {
		t.Fatal(err)
	}
	if arrive.Before(before.Add(-4*time.Hour)) || arrive.After(before.Add(28*time.Hour)) {
		t.Fatalf("live dinner %v is not around now %v", arrive, before)
	}
	_, dec := do(t, h, "POST", "/v1/decide", "", bytes.NewBufferString(`{}`), "application/json")
	if dec["trip"].(map[string]any)["arrive_by"] != out["trips"].([]any)[0].(map[string]any)["arrive_by"] {
		t.Fatalf("decide trip %v differs from /v1/trips", dec["trip"])
	}
}

const gpsChitLom = `{"name_th":"ตำแหน่งปัจจุบัน","lat":13.7441,"lng":100.5431}`

func TestDecideFromTheApp(t *testing.T) {
	h := newServer(t)
	tests := []struct {
		name, body string
		wantStatus int
		check      func(t *testing.T, out map[string]any)
	}{
		{"coordinates make an app trip", `{"origin":` + gpsChitLom + `,"destination":{"name_th":"สยามพารากอน","lat":13.746,"lng":100.5347}}`, 200, func(t *testing.T, out map[string]any) {
			trip := out["trip"].(map[string]any)
			if !strings.HasPrefix(trip["id"].(string), "app-") || trip["source"] != "app" || trip["title_th"] != "ไปสยามพารากอน" || out["verdict"] == nil {
				t.Fatal(out)
			}
		}},
		{"a saved place in the question", `{"question_th":"ไปยิมตอนหกโมง","origin":` + gpsChitLom + `,"places":[{"id":"g1","kind":"other","label_th":"ยิม","name_th":"ฟิตเนส อารีย์","lat":13.7797,"lng":100.5448}]}`, 200, func(t *testing.T, out map[string]any) {
			trip := out["trip"].(map[string]any)
			if trip["title_th"] != "ไปยิม" || trip["destination"].(map[string]any)["name_th"] != "ฟิตเนส อารีย์" || out["depart_at"] != "2026-09-29T18:00:00+07:00" {
				t.Fatal(out)
			}
		}},
		{"an unsaved place asks which one", `{"question_th":"ไปเซ็นทรัลเวิลด์ตอนหกโมงดีไหม","origin":` + gpsChitLom + `,"places":[]}`, 200, func(t *testing.T, out map[string]any) {
			np := out["needs_place"].(map[string]any)
			cands := np["candidates"].([]any)
			if np["query_th"] != "เซ็นทรัลเวิลด์" || len(cands) == 0 || cands[0].(map[string]any)["name_th"] != "เซ็นทรัลเวิลด์" || cands[0].(map[string]any)["source"] != "local" {
				t.Fatal(out)
			}
			if _, ok := np["kind"]; ok {
				t.Errorf("no kind hint for a named place: %v", np)
			}
			if _, ok := out["verdict"]; ok || len(out) != 1 {
				t.Errorf("needs_place carries no verdict fields: %v", out)
			}
		}},
		{"home before it is set", `{"question_th":"กลับบ้านตอนหกโมง","places":[]}`, 200, func(t *testing.T, out map[string]any) {
			np := out["needs_place"].(map[string]any)
			if np["kind"] != "home" || np["query_th"] != "บ้าน" || len(np["candidates"].([]any)) != 0 {
				t.Fatal(out)
			}
		}},
		{"destination without origin", `{"destination":{"name_th":"สยาม","lat":13.7456,"lng":100.5341}}`, 400, nil},
		{"app trip id without coordinates", `{"trip_id":"app-0123456789"}`, 400, nil},
		{"place without coordinates", `{"places":[{"id":"h","kind":"home"}]}`, 400, nil},
		{"no origin and no home or work to start from", `{"question_th":"ไปยิม","places":[{"id":"g1","label_th":"ยิม","name_th":"ฟิตเนส","lat":13.7797,"lng":100.5448}]}`, 400, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			status, out := do(t, h, "POST", "/v1/decide", "16:10", bytes.NewBufferString(tt.body), "application/json")
			if status != tt.wantStatus {
				t.Fatalf("status = %d, want %d (%v)", status, tt.wantStatus, out)
			}
			if tt.check != nil {
				tt.check(t, out)
			}
		})
	}
}

func TestHomeStatusForAPoint(t *testing.T) {
	h := newServer(t)
	tests := []struct {
		name, query, clock string
		wantStatus         int
		check              func(t *testing.T, out map[string]any)
	}{
		{"the demo home by coordinates replays the scenario", "?lat=13.8161&lng=100.5901&name_th=บ้านของฉัน", "21:40", 200, func(t *testing.T, out map[string]any) {
			if out["level"] != "danger" || out["headline_th"] != "น้ำจะถึงหน้าบ้านใน 40 นาที" || out["place"].(map[string]any)["name_th"] != "บ้านของฉัน" || out["in_service_area"] != true {
				t.Fatal(out)
			}
		}},
		{"no params is the demo home", "", "21:40", 200, func(t *testing.T, out map[string]any) {
			if out["place"].(map[string]any)["name_th"] != "บ้านลาดพร้าว" || out["canal"].(map[string]any)["name_th"] != "คลองลาดพร้าว" {
				t.Fatal(out)
			}
		}},
		{"far from any canal station", "?lat=13.6681&lng=100.6046&name_th=คอนโดบางนา", "18:15", 200, func(t *testing.T, out map[string]any) {
			if out["canal"] != nil || out["minutes_to_doorstep"] != nil || out["in_service_area"] != true || !strings.Contains(out["summary_th"].(string), "ไม่มีสถานีวัดระดับคลองใกล้บ้าน") {
				t.Fatal(out)
			}
			if _, ok := out["flood_spots"].([]any); !ok {
				t.Fatalf("flood_spots should be a list: %v", out["flood_spots"])
			}
		}},
		{"outside Bangkok", "?lat=18.79&lng=98.98", "18:15", 200, func(t *testing.T, out map[string]any) {
			if out["in_service_area"] != false || out["canal"] != nil || !strings.Contains(out["summary_th"].(string), "นอกพื้นที่") {
				t.Fatal(out)
			}
		}},
		{"lat without lng", "?lat=13.7", "", 400, nil},
		{"bad lat", "?lat=north&lng=100.5", "", 400, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			status, out := do(t, h, "GET", "/v1/home-status"+tt.query, tt.clock, nil, "")
			if status != tt.wantStatus {
				t.Fatalf("status = %d, want %d (%v)", status, tt.wantStatus, out)
			}
			if tt.check != nil {
				tt.check(t, out)
			}
		})
	}
}

func TestPlacesSearchAndReverse(t *testing.T) {
	h := newServer(t)
	status, out := do(t, h, "GET", "/v1/places/search?q="+url.QueryEscape("พารากอน"), "", nil, "")
	if status != 200 {
		t.Fatalf("search status %d %v", status, out)
	}
	first := out["places"].([]any)[0].(map[string]any)
	if first["name_th"] != "สยามพารากอน" || first["source"] != "local" || first["address_th"] == "" || first["lat"] != 13.746 {
		t.Fatalf("search = %v", out)
	}
	if status, out := do(t, h, "GET", "/v1/places/search?q="+url.QueryEscape("zzqqxx"), "", nil, ""); status != 200 || len(out["places"].([]any)) != 0 {
		t.Fatalf("no results should be an empty list, got %d %v", status, out)
	}
	for _, q := range []string{"", "?q=", "?q=" + url.QueryEscape("ส"), "?q=%20%20a"} {
		if status, _ := do(t, h, "GET", "/v1/places/search"+q, "", nil, ""); status != 400 {
			t.Errorf("search %q: status %d, want 400", q, status)
		}
	}

	status, out = do(t, h, "GET", "/v1/places/reverse?lat=13.7441&lng=100.5431", "", nil, "")
	if status != 200 || out["name_th"] != "สถานี BTS ชิดลม" || out["in_service_area"] != true || out["source"] != "local" || out["lat"] != 13.7441 {
		t.Fatalf("reverse = %d %v", status, out)
	}
	if _, ok := out["distance_m"]; !ok {
		t.Errorf("local reverse should say how far the landmark is: %v", out)
	}
	for _, q := range []string{"", "?lat=13.7", "?lat=x&lng=100", "?lat=91&lng=100"} {
		if status, _ := do(t, h, "GET", "/v1/places/reverse"+q, "", nil, ""); status != 400 {
			t.Errorf("reverse %q: status %d, want 400", q, status)
		}
	}
}

func TestProactivePipelineEndToEnd(t *testing.T) {
	spots, _ := floodspot.Load(filepath.Join("..", "..", "..", "data", "bkk_flood_risk_points.json"))
	landmarks, _ := geocode.LoadLandmarks(filepath.Join("..", "..", "..", "data", "bkk_landmarks.json"))
	prov := planner.Providers{Weather: scenario.Weather{}, Routes: scenario.Routes{}, Canals: scenario.Canals{}, Reports: reports.NewMemoryStore(scenario.SeedReports()...)}
	userStore := users.NewMemoryUserStore()
	memNotifier := notify.NewMemoryNotifier()
	eval := &advise.Evaluator{
		Planner:  &planner.Planner{Spots: spots, Trips: scenario.Trips, Places: scenario.Places, Whereabouts: scenario.Whereabouts},
		Users:    userStore,
		Notifier: memNotifier,
	}
	scheduler := jobs.NewInlineScheduler(eval, prov)

	srv := &Server{
		DemoMode:  true,
		Planner:   eval.Planner,
		Scenario:  prov,
		Live:      prov,
		Geocoder:  geocode.Local{Landmarks: landmarks},
		UserStore: userStore,
		Evaluator: eval,
		Scheduler: scheduler,
	}
	h := srv.Handler()

	// 1. Ingest via Pub/Sub push message
	pubsubPayload := `{"uid":"mew-hero","source":"calendar","title":"ไปสยาม ตอนหกโมงเย็น","body":"นัดคุยงานที่สยาม"}`
	body := bytes.NewBufferString(pubsubPayload)
	status, out := do(t, h, "POST", "/internal/pubsub/raw", "16:10", body, "application/json")
	if status != 200 || out["status"] != "scheduled" {
		t.Fatalf("pubsub raw ingest status=%d resp=%v", status, out)
	}

	tripID := out["trip_id"].(string)

	// Verify task got scheduled
	if len(scheduler.Tasks) != 1 {
		t.Fatalf("expected 1 scheduled task, got %d", len(scheduler.Tasks))
	}

	// 2. Trigger task check endpoint for this trip at 16:10 (departure minus 45 min beat)
	checkBody := bytes.NewBufferString(`{"uid":"mew-hero","trip_id":"` + tripID + `","force_notify":true}`)
	status, checkOut := do(t, h, "POST", "/internal/tasks/check", "16:10", checkBody, "application/json")
	if status != 200 {
		t.Fatalf("task check failed: %d %v", status, checkOut)
	}

	if checkOut["notified"] != true || checkOut["verdict"] != "leave_now" {
		t.Fatalf("expected notified true and leave_now, got %v", checkOut)
	}

	if len(memNotifier.Messages) != 1 {
		t.Fatalf("expected 1 proactive notification message sent, got %d", len(memNotifier.Messages))
	}
	msg := memNotifier.Messages[0]
	if msg.UID != "mew-hero" || msg.HeadlineTH == "" {
		t.Fatalf("invalid notification message: %+v", msg)
	}
}

func TestTripsRealEmailNoStoreReturnsEmpty(t *testing.T) {
	h := newServerMode(t, false)
	code, out := do(t, h, "GET", "/v1/trips?email=real.person@example.com", "", nil, "")
	if code != 200 {
		t.Fatalf("status %d: %v", code, out)
	}
	trips, ok := out["trips"].([]any)
	if !ok || len(trips) != 0 {
		t.Fatalf("trips = %v, want []", out["trips"])
	}
	if out["connected"] != false {
		t.Fatalf("connected = %v, want false", out["connected"])
	}
}

func TestSyncRealEmailNoTokenReturnsEmptyNotConnected(t *testing.T) {
	h := newServerMode(t, false)
	code, out := do(t, h, "GET", "/v1/trips/sync?email=real.person@example.com", "", nil, "")
	if code != 200 {
		t.Fatalf("status %d: %v", code, out)
	}
	trips, ok := out["trips"].([]any)
	if !ok || len(trips) != 0 {
		t.Fatalf("trips = %v, want []", out["trips"])
	}
	if out["connected"] != false || out["email"] != "real.person@example.com" {
		t.Fatalf("connected/email = %v/%v", out["connected"], out["email"])
	}
}

func TestTripsConnectedWhenTokenExists(t *testing.T) {
	h := newServerMode(t, false)
	email := "linked.person@example.com"
	tokenStoreMu.Lock()
	tokenStore[email] = &userToken{}
	tokenStoreMu.Unlock()
	t.Cleanup(func() {
		tokenStoreMu.Lock()
		delete(tokenStore, email)
		tokenStoreMu.Unlock()
	})
	_, out := do(t, h, "GET", "/v1/trips?email="+email, "", nil, "")
	if out["connected"] != true || len(out["trips"].([]any)) != 0 {
		t.Fatalf("got %v, want connected with no trips", out)
	}
}

func TestTripsDemoHeaderStillReturnsScenario(t *testing.T) {
	h := newServerMode(t, false)
	for _, path := range []string{"/v1/trips?email=" + DemoEmail, "/v1/trips"} {
		_, out := do(t, h, "GET", path, "16:10", nil, "")
		trips := out["trips"].([]any)
		if len(trips) == 0 || trips[0].(map[string]any)["id"] != "cal-dinner" {
			t.Fatalf("%s: trips = %v, want scenario", path, out["trips"])
		}
	}
}

// A real account recording the demo replays the storm on its own calendar:
// an empty one stays empty instead of showing มิว's trips.
func TestTripsDemoHeaderNeverGivesRealAccountsScenario(t *testing.T) {
	h := newServerMode(t, false)
	for _, path := range []string{"/v1/trips?email=real.person@example.com", "/v1/trips/sync?email=real.person@example.com"} {
		_, out := do(t, h, "GET", path, "16:10", nil, "")
		if trips := out["trips"].([]any); len(trips) != 0 {
			t.Fatalf("%s: trips = %v, want none", path, trips)
		}
	}
}

func TestPubSubRaw_Base64Decoded(t *testing.T) {
	s := newTestServer(t, false)
	h := s.Handler()

	// Base64 encoded JSON IngestRequest: {"title":"นัดกินข้าวที่สยาม","body":"เวลา 19:00"}
	payloadJSON := `{"title":"นัดกินข้าวที่สยาม","body":"เวลา 19:00"}`
	encoded := base64.StdEncoding.EncodeToString([]byte(payloadJSON))

	pubSubMsg := fmt.Sprintf(`{"message":{"data":%q,"message_id":"msg-pubsub-1"}}`, encoded)
	status, out := do(t, h, "POST", "/internal/pubsub/raw", "", bytes.NewBufferString(pubSubMsg), "application/json")
	if status != http.StatusOK {
		t.Fatalf("expected status 200, got %d (out: %v)", status, out)
	}
	tripID, _ := out["trip_id"].(string)
	if tripID == "" {
		t.Fatalf("expected trip_id, got %v", out)
	}
	ut, err := s.UserStore.GetTrip(context.Background(), "demo-user", tripID)
	if err != nil {
		t.Fatalf("failed to get trip: %v", err)
	}
	if ut.Trip.TitleTH != "นัดกินข้าวที่สยาม" {
		t.Errorf("expected trip TitleTH 'นัดกินข้าวที่สยาม', got %v", ut.Trip.TitleTH)
	}
}

type fakeGenWithText struct {
	text string
}

func (f fakeGenWithText) GenerateContent(context.Context, string, []*genai.Content, *genai.GenerateContentConfig) (*genai.GenerateContentResponse, error) {
	return &genai.GenerateContentResponse{Candidates: []*genai.Candidate{{Content: &genai.Content{Parts: []*genai.Part{{Text: f.text}}}}}}, nil
}

func TestCreateReport_RejectedReturnsBadRequest(t *testing.T) {
	// Not a flood scene image should return 400 Bad Request
	notFloodJSON := `{"depth_cm_min":30,"depth_cm_max":40,"confidence":0.9,"is_flood_scene":false,"looks_like_screenshot":false,"description_th":"ภาพแมว","passable":{"car":"no","transit":"yes","moto":"no"}}`
	s := newTestServer(t, false)
	s.Gemini = &agent.Gemini{Gen: fakeGenWithText{text: notFloodJSON}}
	h := s.Handler()

	body, ct := multipartReport(t, "13.8130", "100.5760", true)
	status, out := do(t, h, "POST", "/v1/reports", "", body, ct)
	if status != http.StatusBadRequest {
		t.Fatalf("expected 400 Bad Request for non-flood photo, got %d (out: %v)", status, out)
	}
}

func TestHomeStatus_NilProviders(t *testing.T) {
	s := newTestServer(t, false)
	// All live providers nil
	s.Live = planner.Providers{}
	h := s.Handler()

	status, out := do(t, h, "GET", "/v1/home-status", "", nil, "")
	if status != http.StatusOK {
		t.Fatalf("expected 200 OK with nil providers, got %d (out: %v)", status, out)
	}
}

func TestHandleTaskCheck_InvalidPayload(t *testing.T) {
	h := newServer(t)

	// Missing UID or TripID -> 400
	status, _ := do(t, h, "POST", "/internal/tasks/check", "", bytes.NewBufferString(`{"uid":""}`), "application/json")
	if status != http.StatusBadRequest {
		t.Fatalf("expected 400 Bad Request for empty uid, got %d", status)
	}

	// Malformed JSON -> 400
	status, _ = do(t, h, "POST", "/internal/tasks/check", "", bytes.NewBufferString(`{not-json}`), "application/json")
	if status != http.StatusBadRequest {
		t.Fatalf("expected 400 Bad Request for malformed json, got %d", status)
	}
}

