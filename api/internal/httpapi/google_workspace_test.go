package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geocode"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
	"github.com/pottersirawit/fontokmai/api/internal/users"
)

func TestParseClientSecret(t *testing.T) {
	rawJSON := `{"web":{"client_id":"cid","client_secret":"secret123"}}`
	if got := parseClientSecret(rawJSON); got != "secret123" {
		t.Errorf("parseClientSecret(webJSON) = %q, want secret123", got)
	}

	installedJSON := `{"installed":{"client_secret":"secretInstalled"}}`
	if got := parseClientSecret(installedJSON); got != "secretInstalled" {
		t.Errorf("parseClientSecret(installedJSON) = %q, want secretInstalled", got)
	}

	plain := "GOCSPX-plain"
	if got := parseClientSecret(plain); got != "GOCSPX-plain" {
		t.Errorf("parseClientSecret(plain) = %q, want GOCSPX-plain", got)
	}
}

func TestConvertCalendarEventToTrip(t *testing.T) {
	ctx := context.Background()
	savedPlaces := scenario.Places

	t.Run("timed event with location", func(t *testing.T) {
		item := googleCalendarItem{
			ID:       "evt_lunch",
			Summary:  "กินข้าวกับเพื่อน",
			Location: "สยามพารากอน",
		}
		item.Start.DateTime = "2026-10-16T12:30:00+07:00"

		trip := ConvertCalendarEventToTrip(ctx, item, nil, savedPlaces)
		if trip.ID != "cal-evt_lunch" {
			t.Errorf("trip ID = %q, want cal-evt_lunch", trip.ID)
		}
		if trip.Source != "calendar" {
			t.Errorf("trip Source = %q, want calendar", trip.Source)
		}
		if trip.TitleTH != "กินข้าวกับเพื่อน" {
			t.Errorf("trip TitleTH = %q", trip.TitleTH)
		}
		if trip.ArriveBy.Hour() != 12 || trip.ArriveBy.Minute() != 30 {
			t.Errorf("trip ArriveBy = %v", trip.ArriveBy)
		}
		if trip.Destination.Lat == 0 || trip.Destination.Lng == 0 {
			t.Errorf("destination not geocoded")
		}
	})

	t.Run("all day event", func(t *testing.T) {
		item := googleCalendarItem{
			ID:      "evt_allday",
			Summary: "ประชุมประจำปี",
		}
		item.Start.Date = "2026-10-20"

		trip := ConvertCalendarEventToTrip(ctx, item, nil, savedPlaces)
		if trip.ArriveBy.IsZero() {
			t.Errorf("all day event arriveBy should not be zero")
		}
	})
}

// stubGeocoder finds the places it knows and counts every search.
type stubGeocoder struct {
	known    map[string]geocode.Place
	searches int
}

func (g *stubGeocoder) Search(_ context.Context, q string) ([]geocode.Place, error) {
	g.searches++
	if p, ok := g.known[q]; ok {
		return []geocode.Place{p}, nil
	}
	return nil, nil
}

func (g *stubGeocoder) Reverse(context.Context, domain.LatLng) (geocode.Address, error) {
	return geocode.Address{}, nil
}

func calItem(id, summary, location, start, end string) googleCalendarItem {
	item := googleCalendarItem{ID: id, Summary: summary, Location: location}
	item.Start.DateTime, item.End.DateTime = start, end
	return item
}

func TestCalendarEventWithoutAPlaceIsUnresolved(t *testing.T) {
	ctx := context.Background()
	geo := &stubGeocoder{}
	for _, tt := range []struct{ location, wantText string }{
		{"", ""},
		{"ร้านลับ ซอยไม่มีชื่อ", "ร้านลับ ซอยไม่มีชื่อ"},
	} {
		item := calItem("evt_x", "คุยเรื่องงบประมาณ", tt.location, "2026-10-16T15:00:00+07:00", "2026-10-16T16:00:00+07:00")
		trip := ConvertCalendarEventToTrip(ctx, item, geo, scenario.Places)
		if trip.Destination.Resolved() || trip.LocationTextTH != tt.wantText || trip.Virtual {
			t.Errorf("location %q: got %+v, want unresolved with location_text_th %q", tt.location, trip, tt.wantText)
		}
		b, _ := json.Marshal(trip)
		var raw struct {
			Destination map[string]any `json:"destination"`
		}
		_ = json.Unmarshal(b, &raw)
		if _, has := raw.Destination["lat"]; has {
			t.Errorf("unresolved destination has coordinates: %s", b)
		}
	}
}

func TestOnlineCalendarEventsAreVirtual(t *testing.T) {
	ctx := context.Background()
	meet := calItem("evt_meet", "Sprint planning", "", "2026-10-16T10:00:00+07:00", "2026-10-16T11:00:00+07:00")
	meet.HangoutLink = "https://meet.google.com/abc-defg-hij"
	conf := calItem("evt_conf", "1:1", "", "2026-10-16T10:00:00+07:00", "")
	conf.ConferenceData = json.RawMessage(`{"conferenceId":"x"}`)
	tests := []googleCalendarItem{
		meet,
		conf,
		calItem("evt_zoom", "Client call", "https://zoom.us/j/123", "2026-10-16T10:00:00+07:00", ""),
		calItem("evt_teams", "Vendor sync", "Microsoft Teams Meeting", "2026-10-16T10:00:00+07:00", ""),
		calItem("evt_gmeet", "Retro", "google meet", "2026-10-16T10:00:00+07:00", ""),
	}
	for _, item := range tests {
		geo := &stubGeocoder{known: map[string]geocode.Place{item.Summary: {Lat: 13.7, Lng: 100.5}}}
		trip := ConvertCalendarEventToTrip(ctx, item, geo, scenario.Places)
		if !trip.Virtual || trip.Destination.NameTH != "ออนไลน์" || trip.Destination.Resolved() {
			t.Errorf("%s: got %+v, want a virtual trip to ออนไลน์", item.ID, trip)
		}
		if geo.searches != 0 {
			t.Errorf("%s: geocoded an online meeting %d times", item.ID, geo.searches)
		}
	}
}

func TestAllDayCalendarEvent(t *testing.T) {
	item := googleCalendarItem{ID: "evt_allday", Summary: "ประชุมประจำปี", Location: "ไบเทค บางนา"}
	item.Start.Date, item.End.Date = "2026-10-20", "2026-10-21"
	geo := &stubGeocoder{}
	trip := ConvertCalendarEventToTrip(context.Background(), item, geo, scenario.Places)
	if !trip.AllDay {
		t.Errorf("all_day = false, want true")
	}
	if want := time.Date(2026, 10, 20, 0, 0, 0, 0, domain.Bangkok); !trip.ArriveBy.Equal(want) {
		t.Errorf("arrive_by = %v, want %v", trip.ArriveBy, want)
	}
	if want := time.Date(2026, 10, 21, 0, 0, 0, 0, domain.Bangkok); !trip.EndsAt.Equal(want) {
		t.Errorf("ends_at = %v, want %v", trip.EndsAt, want)
	}
	if geo.searches != 0 {
		t.Errorf("geocoded an all-day event")
	}
}

func TestCalendarEventEndsAt(t *testing.T) {
	item := calItem("evt_end", "กินข้าวกับเพื่อน", "สยามพารากอน", "2026-10-16T12:30:00+07:00", "2026-10-16T13:45:00+07:00")
	trip := ConvertCalendarEventToTrip(context.Background(), item, nil, scenario.Places)
	if want := time.Date(2026, 10, 16, 13, 45, 0, 0, domain.Bangkok); !trip.EndsAt.Equal(want) {
		t.Errorf("ends_at = %v, want %v", trip.EndsAt, want)
	}
	if trip.Origin != scenario.Home {
		t.Errorf("origin = %+v, want the saved home", trip.Origin)
	}
}

func TestBackToBackCalendarEventsConnect(t *testing.T) {
	items := []googleCalendarItem{
		// Out of order on purpose: the connection follows start times.
		calItem("evt_b", "รีวิวงาน", "ทองหล่อ", "2026-10-16T12:00:00+07:00", "2026-10-16T13:00:00+07:00"),
		calItem("evt_a", "กินข้าวกับเพื่อน", "สยามพารากอน", "2026-10-16T10:00:00+07:00", "2026-10-16T11:00:00+07:00"),
		calItem("evt_c", "ประชุมออนไลน์", "https://zoom.us/j/1", "2026-10-16T14:00:00+07:00", "2026-10-16T15:00:00+07:00"),
		calItem("evt_d", "ทานข้าวเย็น", "สยาม", "2026-10-16T15:30:00+07:00", "2026-10-16T17:00:00+07:00"),
		calItem("evt_e", "ยิมตอนดึก", "ทองหล่อ", "2026-10-16T21:00:00+07:00", ""),
	}
	trips := ConvertCalendarEventsToTrips(context.Background(), items, nil, scenario.Places)
	byID := map[string]domain.Trip{}
	for _, tr := range trips {
		byID[tr.ID] = tr
	}
	if got := byID["cal-evt_a"].Origin; got != scenario.Home {
		t.Errorf("first event origin = %+v, want home", got)
	}
	if got := byID["cal-evt_b"].Origin; got != scenario.Siam {
		t.Errorf("second event origin = %+v, want the first event's place (Siam)", got)
	}
	// An online meeting is no place to come from; the last place was Thonglor at 13:00.
	if got := byID["cal-evt_d"].Origin; got != scenario.Thonglor {
		t.Errorf("after an online meeting origin = %+v, want Thonglor", got)
	}
	// Siam ended at 17:00, more than 3 hours before 21:00.
	if got := byID["cal-evt_e"].Origin; got != scenario.Home {
		t.Errorf("late event origin = %+v, want home", got)
	}
}

func TestGmailTripWithoutAPlaceIsUnresolved(t *testing.T) {
	item := gmailMessageItem{ID: "msg_x", Subject: "Your booking is confirmed", Snippet: "Reservation #4411 for 2 guests", Date: "Thu, 15 Oct 2026 14:00:00 +0700"}
	trip := ConvertGmailMessageToTrip(context.Background(), item, &stubGeocoder{}, scenario.Places)
	if trip.Destination.Resolved() || !trip.EndsAt.IsZero() {
		t.Errorf("got %+v, want an unresolved trip with no ends_at", trip)
	}
}

func TestTripsHandlerShowsEndsAndOnlineMeetings(t *testing.T) {
	h := newTestServer(t, true).Handler()
	r := httptest.NewRequest("GET", "/v1/trips", nil)
	r.Header.Set("X-Demo-Clock", "2026-09-29T16:10:00+07:00")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	var res struct {
		Trips []json.RawMessage `json:"trips"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &res); err != nil {
		t.Fatal(err)
	}
	found := map[string]string{}
	for _, raw := range res.Trips {
		var tr struct {
			ID string `json:"id"`
		}
		_ = json.Unmarshal(raw, &tr)
		found[tr.ID] = string(raw)
		if tr.ID != "gmail-flight" && !strings.Contains(string(raw), `"ends_at"`) {
			t.Errorf("%s has no ends_at: %s", tr.ID, raw)
		}
	}
	t.Logf("cal-sync: %s", found["cal-sync"])
	t.Logf("cal-review: %s", found["cal-review"])
	if !strings.Contains(found["cal-sync"], `"virtual":true`) || strings.Contains(found["cal-sync"], `"lat"`+":0") {
		t.Errorf("cal-sync = %s, want a virtual trip", found["cal-sync"])
	}
	if !strings.Contains(found["cal-review"], `"ends_at":"2026-09-30T14:00:00+07:00"`) {
		t.Errorf("cal-review = %s", found["cal-review"])
	}
}

func TestDecideRefusesTripsWithNoTravel(t *testing.T) {
	h := newTestServer(t, true).Handler()
	unresolved, _ := json.Marshal(map[string]any{"trip": domain.Trip{
		ID: "cal-somewhere", TitleTH: "ไม่รู้ที่", Source: "calendar", Origin: scenario.Home,
		Destination: domain.Place{NameTH: "ร้านลับ"}, LocationTextTH: "ร้านลับ",
		ArriveBy: time.Date(2026, 9, 29, 18, 0, 0, 0, domain.Bangkok), Mode: domain.ModeCar,
	}})
	for name, body := range map[string]string{
		"virtual trip id": `{"trip_id":"cal-sync"}`,
		"unresolved trip": string(unresolved),
	} {
		r := httptest.NewRequest("POST", "/v1/decide", strings.NewReader(body))
		r.Header.Set("X-Demo-Clock", "2026-09-29T16:10:00+07:00")
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		if w.Code != http.StatusBadRequest {
			t.Errorf("%s: status %d, want 400: %s", name, w.Code, w.Body.String())
		}
	}
}

func TestConvertGmailMessageToTrip(t *testing.T) {
	ctx := context.Background()
	savedPlaces := scenario.Places

	item := gmailMessageItem{
		ID:      "msg_ticket",
		Subject: "ยืนยันการจอง: บัตรคอนเสิร์ต อิมแพ็ค อารีน่า",
		Snippet: "ตั๋วคอนเสิร์ต Impact Arena เมืองทองธานี วันที่ 18 ต.ค. เวลา 19:00",
		Date:    "Thu, 15 Oct 2026 14:00:00 +0700",
	}

	trip := ConvertGmailMessageToTrip(ctx, item, nil, savedPlaces)
	if trip.ID != "gmail-msg_ticket" {
		t.Errorf("trip ID = %q, want gmail-msg_ticket", trip.ID)
	}
	if trip.Source != "gmail" {
		t.Errorf("trip Source = %q, want gmail", trip.Source)
	}
	if trip.Destination.Lat == 0 {
		t.Errorf("destination not resolved for gmail item")
	}
}

func TestServer_TripsUserStoreAndSync(t *testing.T) {
	s := newTestServer(t, true)
	h := s.Handler()

	testEmail := "real.person@example.com"
	customTrip := domain.Trip{
		ID:          "cal-custom-1",
		TitleTH:     "นัดหมายพิเศษจาก Calendar",
		Source:      "calendar",
		Origin:      domain.Place{NameTH: "สีลม", Lat: 13.7279, Lng: 100.5281},
		Destination: domain.Place{NameTH: "ทองหล่อ", Lat: 13.7314, Lng: 100.5815},
		ArriveBy:    time.Now().Add(2 * time.Hour),
		Mode:        domain.ModeCar,
	}

	// 1. Upsert into UserStore
	err := s.UserStore.UpsertTrip(context.Background(), users.UserTrip{
		UID:       testEmail,
		Trip:      customTrip,
		UpdatedAt: time.Now(),
	})
	if err != nil {
		t.Fatalf("upsert trip failed: %v", err)
	}

	// 2. Query /v1/trips?email=real.person@example.com
	r := httptest.NewRequest("GET", "/v1/trips?email="+testEmail, nil)
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)

	if w.Code != http.StatusOK {
		t.Fatalf("GET /v1/trips returned status %d, want 200", w.Code)
	}

	var res struct {
		Trips []domain.Trip `json:"trips"`
	}
	if err := json.NewDecoder(w.Body).Decode(&res); err != nil {
		t.Fatalf("decode trips failed: %v", err)
	}

	if len(res.Trips) != 1 || res.Trips[0].ID != "cal-custom-1" {
		t.Errorf("got trips %+v, want custom trip cal-custom-1", res.Trips)
	}

	// 3. Query /v1/trips/sync?email=real.person@example.com
	rSync := httptest.NewRequest("GET", "/v1/trips/sync?email="+testEmail, nil)
	wSync := httptest.NewRecorder()
	h.ServeHTTP(wSync, rSync)

	if wSync.Code != http.StatusOK {
		t.Fatalf("GET /v1/trips/sync returned status %d, want 200", wSync.Code)
	}

	// 4. Decide on this custom trip via trip_id and email
	decReqBody, _ := json.Marshal(map[string]any{
		"trip_id": "cal-custom-1",
		"email":   testEmail,
	})
	rDec := httptest.NewRequest("POST", "/v1/decide", bytes.NewReader(decReqBody))
	wDec := httptest.NewRecorder()
	h.ServeHTTP(wDec, rDec)
	if wDec.Code != http.StatusOK {
		t.Fatalf("POST /v1/decide returned status %d, want 200: %s", wDec.Code, wDec.Body.String())
	}

	var decRes struct {
		Verdict   string      `json:"verdict"`
		Trip      domain.Trip `json:"trip"`
		Reasoning []struct {
			Tool      string `json:"tool"`
			SummaryTH string `json:"summary_th"`
		} `json:"reasoning"`
	}
	if err := json.NewDecoder(wDec.Body).Decode(&decRes); err != nil {
		t.Fatalf("decode decide response failed: %v", err)
	}
	if decRes.Trip.ID != "cal-custom-1" || decRes.Trip.TitleTH != "นัดหมายพิเศษจาก Calendar" {
		t.Errorf("decide returned trip %+v, want cal-custom-1 with custom title", decRes.Trip)
	}
	if len(decRes.Reasoning) == 0 || !strings.Contains(decRes.Reasoning[0].SummaryTH, "นัดหมายพิเศษจาก Calendar") {
		t.Errorf("expected reasoning trace to mention custom trip title, got: %+v", decRes.Reasoning)
	}

	// 5. Decide with trip passed directly in request body
	directReqBody, _ := json.Marshal(map[string]any{
		"trip": customTrip,
	})
	rDirect := httptest.NewRequest("POST", "/v1/decide", bytes.NewReader(directReqBody))
	wDirect := httptest.NewRecorder()
	h.ServeHTTP(wDirect, rDirect)
	if wDirect.Code != http.StatusOK {
		t.Fatalf("POST /v1/decide direct returned status %d, want 200: %s", wDirect.Code, wDirect.Body.String())
	}
}

// fakeGoogle stands in for Google's token, userinfo, Calendar and Gmail
// endpoints, counting the refresh_token grants it answers.
type fakeGoogle struct {
	email       string
	failCode    bool
	failRefresh bool
	refreshes   int
}

func (f *fakeGoogle) start(t *testing.T, s *Server) {
	t.Helper()
	mux := http.NewServeMux()
	mux.HandleFunc("POST /token", func(w http.ResponseWriter, r *http.Request) {
		_ = r.ParseForm()
		switch r.Form.Get("grant_type") {
		case "authorization_code":
			if f.failCode {
				http.Error(w, `{"error":"invalid_grant"}`, http.StatusBadRequest)
				return
			}
			writeJSON(w, http.StatusOK, map[string]any{"access_token": "at-1", "refresh_token": "rt-1", "expires_in": 3599,
				"scope": "openid https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/gmail.readonly"})
		case "refresh_token":
			f.refreshes++
			if f.failRefresh || r.Form.Get("refresh_token") != "rt-1" {
				http.Error(w, `{"error":"invalid_grant"}`, http.StatusBadRequest)
				return
			}
			writeJSON(w, http.StatusOK, map[string]any{"access_token": "at-2", "expires_in": 3599})
		default:
			http.Error(w, "bad grant", http.StatusBadRequest)
		}
	})
	mux.HandleFunc("GET /userinfo", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"email": f.email, "email_verified": true})
	})
	mux.HandleFunc("GET /calendar", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"items": []any{}})
	})
	mux.HandleFunc("GET /gmail", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"messages": []any{}})
	})
	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	s.Google = GoogleOAuth{
		TokenURL:    srv.URL + "/token",
		UserinfoURL: srv.URL + "/userinfo",
		CalendarURL: srv.URL + "/calendar",
		GmailURL:    srv.URL + "/gmail",
		AppURLs:     []string{"https://fontokmai.example"},
	}
	t.Cleanup(func() {
		tokenStoreMu.Lock()
		delete(tokenStore, f.email)
		tokenStoreMu.Unlock()
	})
}

func get(h http.Handler, target string) *httptest.ResponseRecorder {
	w := httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest("GET", target, nil))
	return w
}

// startState runs /v1/oauth/start for returnTo and gives back the state Google
// would echo to the callback.
func startState(t *testing.T, h http.Handler, returnTo string) string {
	t.Helper()
	w := get(h, "/v1/oauth/start?return="+url.QueryEscape(returnTo))
	if w.Code != http.StatusFound {
		t.Fatalf("start = %d, want 302: %s", w.Code, w.Body.String())
	}
	loc, err := url.Parse(w.Header().Get("Location"))
	if err != nil {
		t.Fatal(err)
	}
	return loc.Query().Get("state")
}

func TestOAuthStartAsksForBothScopesWithConsent(t *testing.T) {
	s := newTestServer(t, false)
	w := get(s.Handler(), "/v1/oauth/start?return="+url.QueryEscape("http://localhost:5173/#/"))
	if w.Code != http.StatusFound {
		t.Fatalf("status = %d, want 302: %s", w.Code, w.Body.String())
	}
	loc, err := url.Parse(w.Header().Get("Location"))
	if err != nil {
		t.Fatal(err)
	}
	if loc.Host != "accounts.google.com" {
		t.Errorf("redirect host = %q, want accounts.google.com", loc.Host)
	}
	q := loc.Query()
	scopes := strings.Fields(q.Get("scope"))
	for _, want := range []string{"openid", "email", "https://www.googleapis.com/auth/calendar.readonly", "https://www.googleapis.com/auth/gmail.readonly"} {
		if !slices.Contains(scopes, want) {
			t.Errorf("scope %q missing from %q", want, q.Get("scope"))
		}
	}
	for k, want := range map[string]string{
		"prompt": "consent", "access_type": "offline", "include_granted_scopes": "true", "response_type": "code",
		"redirect_uri": "https://fontokmai-api-lmr33aj5zq-as.a.run.app/oauth2callback",
	} {
		if got := q.Get(k); got != want {
			t.Errorf("%s = %q, want %q", k, got, want)
		}
	}
	if q.Get("state") == "" || q.Get("client_id") == "" {
		t.Errorf("state or client_id missing: %v", q)
	}
}

func TestOAuthStartRejectsOtherOrigins(t *testing.T) {
	s := newTestServer(t, false)
	s.Google.AppURLs = []string{"https://fontokmai.example"}
	h := s.Handler()
	for _, ret := range []string{"https://evil.example/", "https://ai-cup-511208.web.app.evil.example/", "javascript:alert(1)", ""} {
		if w := get(h, "/v1/oauth/start?return="+url.QueryEscape(ret)); w.Code != http.StatusBadRequest {
			t.Errorf("return %q: status = %d, want 400", ret, w.Code)
		}
	}
	for _, ret := range []string{"https://fontokmai.example/app", "https://ai-cup-511208.web.app/", "https://ai-cup-511208.firebaseapp.com/",
		"http://localhost:8080/", "http://127.0.0.1:5000/"} {
		if w := get(h, "/v1/oauth/start?return="+url.QueryEscape(ret)); w.Code != http.StatusFound {
			t.Errorf("return %q: status = %d, want 302", ret, w.Code)
		}
	}
}

func TestOAuthCallbackStoresTokenUnderVerifiedEmail(t *testing.T) {
	s := newTestServer(t, false)
	g := &fakeGoogle{email: "owner.real@example.com"}
	g.start(t, s)
	h := s.Handler()

	state := startState(t, h, "https://fontokmai.example/#/")
	w := get(h, "/oauth2callback?code=c-1&state="+url.QueryEscape(state))
	if w.Code != http.StatusFound {
		t.Fatalf("callback = %d, want 302: %s", w.Code, w.Body.String())
	}
	if got, want := w.Header().Get("Location"), "https://fontokmai.example/?connected=owner.real%40example.com#/"; got != want {
		t.Errorf("Location = %q, want %q", got, want)
	}
	tokenStoreMu.RLock()
	tok := tokenStore[g.email]
	tokenStoreMu.RUnlock()
	if tok == nil || tok.AccessToken != "at-1" || tok.RefreshToken != "rt-1" || tok.LastSync.IsZero() {
		t.Fatalf("stored token = %+v, want at-1/rt-1 synced", tok)
	}

	var st struct {
		Connected bool      `json:"connected"`
		Scopes    []string  `json:"scopes"`
		LastSync  time.Time `json:"last_sync"`
	}
	sw := get(h, "/v1/oauth/status?email="+url.QueryEscape(g.email))
	if err := json.NewDecoder(sw.Body).Decode(&st); err != nil {
		t.Fatal(err)
	}
	if !st.Connected || !slices.Contains(st.Scopes, "https://www.googleapis.com/auth/calendar.readonly") || st.LastSync.IsZero() {
		t.Errorf("status = %+v, want connected with calendar scope and a last sync", st)
	}
	if sw := get(h, "/v1/oauth/status?email=nobody@example.com"); !strings.Contains(sw.Body.String(), `"connected":false`) {
		t.Errorf("unknown account status = %s, want connected:false", sw.Body.String())
	}
}

func TestOAuthStatusFindsTheAccountByNonce(t *testing.T) {
	s := newTestServer(t, false)
	g := &fakeGoogle{email: "nonce.owner@example.com"}
	g.start(t, s)
	h := s.Handler()

	nonce := "n0nce-AbC_123"
	if sw := get(h, "/v1/oauth/status?nonce="+nonce); !strings.Contains(sw.Body.String(), `"connected":false`) {
		t.Fatalf("status before sign-in = %s, want connected:false", sw.Body.String())
	}
	w := get(h, "/v1/oauth/start?nonce="+nonce+"&return="+url.QueryEscape("https://fontokmai.example/"))
	loc, _ := url.Parse(w.Header().Get("Location"))
	if cb := get(h, "/oauth2callback?code=c-1&state="+url.QueryEscape(loc.Query().Get("state"))); cb.Code != http.StatusFound {
		t.Fatalf("callback = %d: %s", cb.Code, cb.Body.String())
	}
	var st struct {
		Email     string `json:"email"`
		Connected bool   `json:"connected"`
	}
	if err := json.NewDecoder(get(h, "/v1/oauth/status?nonce="+nonce).Body).Decode(&st); err != nil {
		t.Fatal(err)
	}
	if !st.Connected || st.Email != g.email {
		t.Errorf("status by nonce = %+v, want connected as %s", st, g.email)
	}
	if sw := get(h, "/v1/oauth/status?nonce=other-nonce"); !strings.Contains(sw.Body.String(), `"connected":false`) {
		t.Errorf("another nonce = %s, want connected:false", sw.Body.String())
	}
	if w := get(h, "/v1/oauth/start?nonce="+url.QueryEscape("bad nonce!")+"&return="+url.QueryEscape("https://fontokmai.example/")); w.Code != http.StatusBadRequest {
		t.Errorf("malformed nonce: status = %d, want 400", w.Code)
	}
}

func TestOAuthCallbackFailureStoresNothing(t *testing.T) {
	s := newTestServer(t, false)
	g := &fakeGoogle{email: "failed.exchange@example.com", failCode: true}
	g.start(t, s)
	h := s.Handler()

	state := startState(t, h, "https://fontokmai.example/")
	w := get(h, "/oauth2callback?code=bad&state="+url.QueryEscape(state))
	if w.Code == http.StatusFound {
		t.Fatalf("callback redirected to %q after a failed exchange", w.Header().Get("Location"))
	}
	body := w.Body.String()
	if !strings.Contains(body, "Back to ฝนตกไหม") || !strings.Contains(body, `href="https://fontokmai.example/"`) || !strings.Contains(body, "invalid_grant") {
		t.Errorf("error page lacks the reason or the way back: %s", body)
	}
	if hasToken(g.email) {
		t.Error("a token was stored after a failed exchange")
	}
}

func TestOAuthCallbackRejectsForgedState(t *testing.T) {
	s := newTestServer(t, false)
	g := &fakeGoogle{email: "forged.state@example.com"}
	g.start(t, s)
	h := s.Handler()
	for _, state := range []string{"", "someone@example.com", startState(t, h, "https://fontokmai.example/") + "x"} {
		w := get(h, "/oauth2callback?code=c-1&state="+url.QueryEscape(state))
		if w.Code == http.StatusFound || hasToken(g.email) {
			t.Errorf("state %q: status %d, token stored %v; want error page and no token", state, w.Code, hasToken(g.email))
		}
	}
}

func storeToken(t *testing.T, email string, tok userToken) {
	t.Helper()
	tokenStoreMu.Lock()
	tokenStore[email] = &tok
	tokenStoreMu.Unlock()
}

func TestSyncRefreshesAnExpiringToken(t *testing.T) {
	s := newTestServer(t, false)
	g := &fakeGoogle{email: "expiring@example.com"}
	g.start(t, s)
	storeToken(t, g.email, userToken{AccessToken: "at-old", RefreshToken: "rt-1", Expiry: time.Now().Add(time.Minute)})

	w := get(s.Handler(), "/v1/trips/sync?email="+url.QueryEscape(g.email))
	if !strings.Contains(w.Body.String(), `"connected":true`) {
		t.Errorf("sync = %s, want connected:true", w.Body.String())
	}
	if g.refreshes != 1 {
		t.Errorf("refresh calls = %d, want 1", g.refreshes)
	}
	tokenStoreMu.RLock()
	tok := *tokenStore[g.email]
	tokenStoreMu.RUnlock()
	if tok.AccessToken != "at-2" || tok.RefreshToken != "rt-1" || time.Until(tok.Expiry) < 30*time.Minute {
		t.Errorf("token after refresh = %+v, want at-2 keeping rt-1 with a new expiry", tok)
	}

	get(s.Handler(), "/v1/trips/sync?email="+url.QueryEscape(g.email))
	if g.refreshes != 1 {
		t.Errorf("refresh calls after a fresh token = %d, want still 1", g.refreshes)
	}
}

func TestSyncWithAFailedRefreshIsDisconnected(t *testing.T) {
	s := newTestServer(t, false)
	g := &fakeGoogle{email: "revoked@example.com", failRefresh: true}
	g.start(t, s)
	storeToken(t, g.email, userToken{AccessToken: "at-old", RefreshToken: "rt-1", Expiry: time.Now().Add(-time.Hour)})

	w := get(s.Handler(), "/v1/trips/sync?email="+url.QueryEscape(g.email))
	if !strings.Contains(w.Body.String(), `"connected":false`) {
		t.Errorf("sync = %s, want connected:false", w.Body.String())
	}
}
