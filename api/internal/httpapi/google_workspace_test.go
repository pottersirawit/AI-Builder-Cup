package httpapi

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/extract"
	"github.com/pottersirawit/fontokmai/api/internal/geocode"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
	"github.com/pottersirawit/fontokmai/api/internal/users"
	"google.golang.org/genai"
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
		if trip.Origin.NameTH == "สีลม ซอย 3" || trip.Origin.NameTH != "บ้านลาดพร้าว" {
			t.Errorf("trip Origin = %+v, want saved home place (บ้านลาดพร้าว), not hardcoded work (สีลม ซอย 3)", trip.Origin)
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

func TestAllDayCalendarEvent_WithLocationGeocodes(t *testing.T) {
	item := googleCalendarItem{ID: "evt_allday", Summary: "ประชุมประจำปี", Location: "ไบเทค บางนา"}
	item.Start.Date, item.End.Date = "2026-10-20", "2026-10-21"
	geo := &stubGeocoder{known: map[string]geocode.Place{"ไบเทค บางนา": {Lat: 13.6700, Lng: 100.6100}}}
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
	if !trip.Destination.Resolved() || trip.Destination.Lat != 13.6700 || trip.Destination.Lng != 100.6100 {
		t.Errorf("destination = %+v, want resolved at (13.67, 100.61)", trip.Destination)
	}
	if trip.LocationTextTH != "" {
		t.Errorf("location_text_th = %q, want empty for resolved event", trip.LocationTextTH)
	}
	if geo.searches != 1 {
		t.Errorf("geo.searches = %d, want 1", geo.searches)
	}
}

func TestAllDayCalendarEvent_WithUnresolvedLocation(t *testing.T) {
	item := googleCalendarItem{ID: "evt_unresolved", Summary: "สัมมนานอกสถานที่", Location: "เกาะร้าง"}
	item.Start.Date, item.End.Date = "2026-10-20", "2026-10-21"
	geo := &stubGeocoder{}
	trip := ConvertCalendarEventToTrip(context.Background(), item, geo, scenario.Places)
	if !trip.AllDay {
		t.Errorf("all_day = false, want true")
	}
	if trip.Destination.Resolved() {
		t.Errorf("destination should not be resolved: %+v", trip.Destination)
	}
	if trip.Destination.NameTH != "เกาะร้าง" {
		t.Errorf("destination name = %q, want เกาะร้าง", trip.Destination.NameTH)
	}
	if trip.LocationTextTH != "เกาะร้าง" {
		t.Errorf("location_text_th = %q, want เกาะร้าง", trip.LocationTextTH)
	}
}

func TestAllDayCalendarEvent_WithoutLocation(t *testing.T) {
	item := googleCalendarItem{ID: "evt_holiday", Summary: "วันหยุดสงกรานต์", Location: ""}
	item.Start.Date, item.End.Date = "2026-10-20", "2026-10-21"
	geo := &stubGeocoder{}
	trip := ConvertCalendarEventToTrip(context.Background(), item, geo, scenario.Places)
	if !trip.AllDay {
		t.Errorf("all_day = false, want true")
	}
	if trip.Destination.Resolved() {
		t.Errorf("destination should not be resolved: %+v", trip.Destination)
	}
	if trip.LocationTextTH != "" {
		t.Errorf("location_text_th = %q, want empty", trip.LocationTextTH)
	}
	if geo.searches != 0 {
		t.Errorf("geocoded an event without location: %d searches", geo.searches)
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

func gmailPayload(dest string, arriveBy *time.Time) extract.Payload {
	return extract.Payload{Source: extract.SourceGmail, IsTrip: true, TitleTH: "Concert", DestinationText: dest, ArriveBy: arriveBy}
}

func TestGmailWithoutAnExtractedTimeIsNoTrip(t *testing.T) {
	item := gmailMessageItem{ID: "msg_x", Subject: "Your booking is confirmed", Snippet: "Reservation #4411 for 2 guests", Date: "Thu, 15 Oct 2026 14:00:00 +0700"}
	at := time.Date(2026, 10, 18, 19, 0, 0, 0, domain.Bangkok)
	for name, p := range map[string]extract.Payload{
		"no time":     gmailPayload("Impact Arena", nil),
		"no place":    gmailPayload("", &at),
		"not a trip":  {IsTrip: false, DestinationText: "Impact Arena", ArriveBy: &at},
		"empty reply": {},
	} {
		if trip, ok := ConvertGmailMessageToTrip(context.Background(), item, p, &stubGeocoder{}, nil); ok {
			t.Errorf("%s: got trip %+v, want none", name, trip)
		}
	}
}

func TestGmailTripTakesTheExtractedTimeAndPlace(t *testing.T) {
	item := gmailMessageItem{ID: "msg_ticket", Subject: "E-ticket: concert", Date: "Thu, 15 Oct 2026 14:00:00 +0700"}
	at := time.Date(2026, 10, 18, 19, 0, 0, 0, domain.Bangkok)
	home := domain.Place{NameTH: "คอนโดอารีย์", Lat: 13.7797, Lng: 100.5446}
	geo := &stubGeocoder{known: map[string]geocode.Place{"Impact Arena": {Lat: 13.9118, Lng: 100.5478}}}
	trip, ok := ConvertGmailMessageToTrip(context.Background(), item, gmailPayload("Impact Arena", &at), geo, homePlaces(home))
	if !ok {
		t.Fatal("no trip from a payload with a time and a place")
	}
	if trip.ID != "gmail-msg_ticket" || trip.Source != "gmail" || trip.NoteTH != gmailNoteTH {
		t.Errorf("trip = %+v, want gmail-msg_ticket from gmail with the Gemini note", trip)
	}
	if !trip.ArriveBy.Equal(at) || trip.Origin != home || trip.Destination.Lat != 13.9118 {
		t.Errorf("trip = %+v, want arrive_by %v from home to Impact Arena", trip, at)
	}
}

func TestBaanPhuenIsNotTheUsersHome(t *testing.T) {
	item := calItem("evt_friend", "ปาร์ตี้", "บ้านเพื่อน", "2026-10-16T19:00:00+07:00", "")
	for name, places := range map[string][]domain.SavedPlace{
		"scenario": scenario.Places,
		"own home": homePlaces(domain.Place{NameTH: "บ้าน", Lat: 13.7797, Lng: 100.5446}),
	} {
		trip := ConvertCalendarEventToTrip(context.Background(), item, &stubGeocoder{}, places)
		if trip.Destination.Resolved() || trip.LocationTextTH != "บ้านเพื่อน" {
			t.Errorf("%s: destination = %+v, want บ้านเพื่อน unresolved", name, trip.Destination)
		}
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

	// 2b. Query /v1/trips with user's saved home address overrides hardcoded Silom origin
	rHome := httptest.NewRequest("GET", "/v1/trips?email="+testEmail+"&home_name=BTS+%E0%B8%AD%E0%B8%B2%E0%B8%A3%E0%B8%B5%E0%B8%A2%E0%B9%8C&home_lat=13.7797&home_lng=100.5446", nil)
	wHome := httptest.NewRecorder()
	h.ServeHTTP(wHome, rHome)
	if wHome.Code != http.StatusOK {
		t.Fatalf("GET /v1/trips with home params returned status %d, want 200", wHome.Code)
	}
	var resHome struct {
		Trips []domain.Trip `json:"trips"`
	}
	if err := json.NewDecoder(wHome.Body).Decode(&resHome); err != nil {
		t.Fatalf("decode trips with home failed: %v", err)
	}
	if len(resHome.Trips) != 1 || resHome.Trips[0].Origin.NameTH != "BTS อารีย์" {
		t.Errorf("got trip origin %+v, want BTS อารีย์", resHome.Trips)
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
	// events are Calendar items and mails Gmail messages (id, subject, body)
	// the fake serves; gmailQuery is the last search Gmail was asked.
	events     []googleCalendarItem
	mails      []fakeMail
	gmailQuery string
}

type fakeMail struct{ id, subject, body string }

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
		writeJSON(w, http.StatusOK, map[string]any{"items": append([]googleCalendarItem{}, f.events...)})
	})
	mux.HandleFunc("GET /gmail", func(w http.ResponseWriter, r *http.Request) {
		f.gmailQuery = r.URL.Query().Get("q")
		msgs := []map[string]string{}
		for _, m := range f.mails {
			msgs = append(msgs, map[string]string{"id": m.id})
		}
		writeJSON(w, http.StatusOK, map[string]any{"messages": msgs})
	})
	mux.HandleFunc("GET /gmail/{id}", func(w http.ResponseWriter, r *http.Request) {
		for _, m := range f.mails {
			if m.id != r.PathValue("id") {
				continue
			}
			writeJSON(w, http.StatusOK, map[string]any{"id": m.id, "snippet": m.subject, "payload": map[string]any{
				"mimeType": "multipart/alternative",
				"headers":  []map[string]string{{"name": "Subject", "value": m.subject}, {"name": "Date", "value": "Thu, 15 Oct 2026 14:00:00 +0700"}},
				"parts": []map[string]any{
					{"mimeType": "text/html", "body": map[string]string{"data": base64.URLEncoding.EncodeToString([]byte("<p>html</p>"))}},
					{"mimeType": "text/plain", "body": map[string]string{"data": base64.URLEncoding.EncodeToString([]byte(m.body))}},
				},
			}})
			return
		}
		http.NotFound(w, r)
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

// replyGenerator answers every Gemini call with reply and keeps the prompts.
type replyGenerator struct {
	reply   string
	prompts []string
}

func (g *replyGenerator) GenerateContent(_ context.Context, _ string, contents []*genai.Content, _ *genai.GenerateContentConfig) (*genai.GenerateContentResponse, error) {
	g.prompts = append(g.prompts, contents[0].Parts[0].Text)
	return &genai.GenerateContentResponse{Candidates: []*genai.Candidate{{Content: genai.NewContentFromText(g.reply, genai.RoleModel)}}}, nil
}

func syncedTrips(t *testing.T, h http.Handler, target string) map[string]domain.Trip {
	t.Helper()
	var res struct {
		Trips []domain.Trip `json:"trips"`
	}
	if err := json.NewDecoder(get(h, target).Body).Decode(&res); err != nil {
		t.Fatal(err)
	}
	byID := map[string]domain.Trip{}
	for _, tr := range res.Trips {
		byID[tr.ID] = tr
	}
	return byID
}

func TestSyncPlansFromTheSentHome(t *testing.T) {
	s := newTestServer(t, false)
	g := &fakeGoogle{email: "home.owner@example.com", events: []googleCalendarItem{
		calItem("friend", "ปาร์ตี้", "บ้านเพื่อน", "2026-10-18T19:00:00+07:00", "2026-10-18T22:00:00+07:00"),
	}}
	g.start(t, s)
	storeToken(t, g.email, userToken{AccessToken: "at-1"})
	h := s.Handler()

	trips := syncedTrips(t, h, "/v1/trips/sync?email="+url.QueryEscape(g.email)+"&home_lat=13.7797&home_lng=100.5446&home_name="+url.QueryEscape("คอนโดอารีย์"))
	trip, ok := trips["cal-friend"]
	if !ok {
		t.Fatalf("synced trips = %v, want cal-friend", trips)
	}
	if want := (domain.Place{NameTH: "คอนโดอารีย์", Lat: 13.7797, Lng: 100.5446}); trip.Origin != want {
		t.Errorf("origin = %+v, want the sent home %+v", trip.Origin, want)
	}
	if trip.Destination.Resolved() || trip.LocationTextTH != "บ้านเพื่อน" {
		t.Errorf("destination = %+v, want บ้านเพื่อน left for the user to place", trip.Destination)
	}

	trips = syncedTrips(t, h, "/v1/trips/sync?email="+url.QueryEscape(g.email))
	if got := trips["cal-friend"].Origin; got != defaultOrigin || got == scenario.Home {
		t.Errorf("origin with no home = %+v, want %+v", got, defaultOrigin)
	}
	if !strings.Contains(defaultOrigin.NameTH, "ยังไม่ได้ตั้งบ้าน") {
		t.Errorf("default origin %q does not say no home is set", defaultOrigin.NameTH)
	}
}

func TestSyncReadsGmailWithGeminiOnly(t *testing.T) {
	mail := fakeMail{id: "m1", subject: "Your e-ticket", body: "Doors open 18 Oct 2026 at 19:00, Impact Arena"}

	t.Run("without Gemini", func(t *testing.T) {
		s := newTestServer(t, false)
		g := &fakeGoogle{email: "no.gemini@example.com", mails: []fakeMail{mail}}
		g.start(t, s)
		storeToken(t, g.email, userToken{AccessToken: "at-1"})
		trips := syncedTrips(t, s.Handler(), "/v1/trips/sync?email="+url.QueryEscape(g.email))
		if len(trips) != 0 {
			t.Errorf("trips = %v, want none without Gemini", trips)
		}
		for _, want := range []string{"-category:promotions", "-category:social"} {
			if !strings.Contains(g.gmailQuery, want) {
				t.Errorf("gmail query %q lacks %q", g.gmailQuery, want)
			}
		}
	})

	t.Run("with Gemini", func(t *testing.T) {
		s := newTestServer(t, false)
		gen := &replyGenerator{reply: `{"is_trip":true,"title_th":"Concert","destination_text":"Impact Arena","arrive_by":"2026-10-18T19:00:00+07:00","confidence":0.9,"evidence_th":"Doors open 19:00"}`}
		s.Gemini = &agent.Gemini{Gen: gen, Model: "test"}
		g := &fakeGoogle{email: "with.gemini@example.com", mails: []fakeMail{mail}}
		g.start(t, s)
		storeToken(t, g.email, userToken{AccessToken: "at-1"})
		trips := syncedTrips(t, s.Handler(), "/v1/trips/sync?email="+url.QueryEscape(g.email))
		trip, ok := trips["gmail-m1"]
		if len(trips) != 1 || !ok {
			t.Fatalf("trips = %v, want gmail-m1 only", trips)
		}
		if want := time.Date(2026, 10, 18, 19, 0, 0, 0, domain.Bangkok); !trip.ArriveBy.Equal(want) || trip.Source != "gmail" || trip.NoteTH != gmailNoteTH {
			t.Errorf("trip = %+v, want a gmail trip arriving %v with the Gemini note", trip, want)
		}
		if len(gen.prompts) != 1 || !strings.Contains(gen.prompts[0], "Doors open 18 Oct 2026") {
			t.Errorf("Gemini was asked %q, want the email body", gen.prompts)
		}
	})
}

func TestSyncReconcilesAndSortsCalendarEvents(t *testing.T) {
	s := newTestServer(t, false)
	g := &fakeGoogle{
		email: "reconcile.owner@example.com",
		events: []googleCalendarItem{
			calItem("evt1", "Event 1 Late", "สยาม", "2026-10-18T20:00:00+07:00", "2026-10-18T21:00:00+07:00"),
			calItem("evt2", "Event 2 Early", "อโศก", "2026-10-18T10:00:00+07:00", "2026-10-18T11:00:00+07:00"),
		},
	}
	g.start(t, s)
	storeToken(t, g.email, userToken{AccessToken: "at-1"})
	h := s.Handler()

	// Initial sync
	w1 := get(h, "/v1/trips/sync?email="+url.QueryEscape(g.email))
	var res1 struct {
		Trips []domain.Trip `json:"trips"`
	}
	if err := json.NewDecoder(w1.Body).Decode(&res1); err != nil {
		t.Fatal(err)
	}
	if len(res1.Trips) != 2 {
		t.Fatalf("first sync trips count = %d, want 2", len(res1.Trips))
	}
	// Verify sorted chronologically
	if res1.Trips[0].ID != "cal-evt2" || res1.Trips[1].ID != "cal-evt1" {
		t.Errorf("trips not sorted by arrive_by: got [%s, %s], want [cal-evt2, cal-evt1]",
			res1.Trips[0].ID, res1.Trips[1].ID)
	}

	// Update events in Google Calendar: evt1 deleted, evt3 added
	g.events = []googleCalendarItem{
		calItem("evt2", "Event 2 Early", "อโศก", "2026-10-18T10:00:00+07:00", "2026-10-18T11:00:00+07:00"),
		calItem("evt3", "Event 3 Mid", "อารีย์", "2026-10-18T15:00:00+07:00", "2026-10-18T16:00:00+07:00"),
	}

	// Second sync on refresh
	w2 := get(h, "/v1/trips/sync?email="+url.QueryEscape(g.email))
	var res2 struct {
		Trips []domain.Trip `json:"trips"`
	}
	if err := json.NewDecoder(w2.Body).Decode(&res2); err != nil {
		t.Fatal(err)
	}
	if len(res2.Trips) != 2 {
		t.Fatalf("second sync trips count = %d, want 2 (got %v)", len(res2.Trips), res2.Trips)
	}
	// Verify evt1 is removed, and evt2 & evt3 are sorted
	if res2.Trips[0].ID != "cal-evt2" || res2.Trips[1].ID != "cal-evt3" {
		t.Errorf("reconciled trips order mismatch: got [%s, %s], want [cal-evt2, cal-evt3]",
			res2.Trips[0].ID, res2.Trips[1].ID)
	}
}

func TestSyncChainsBackToBackEventsPreservingPreviousDestination(t *testing.T) {
	s := newTestServer(t, false)
	g := &fakeGoogle{
		email: "chain.owner@example.com",
		events: []googleCalendarItem{
			calItem("dentist", "ทำฟันที่สยาม", "สยาม", "2026-10-18T10:00:00+07:00", "2026-10-18T11:30:00+07:00"),
			calItem("dinner", "กินข้าวเย็นที่อโศก", "อโศก", "2026-10-18T13:00:00+07:00", "2026-10-18T14:30:00+07:00"),
		},
	}
	g.start(t, s)
	storeToken(t, g.email, userToken{AccessToken: "at-1"})
	h := s.Handler()

	syncURL := fmt.Sprintf("/v1/trips/sync?email=%s&home_name=%s&home_lat=13.7797&home_lng=100.5446",
		url.QueryEscape(g.email), url.QueryEscape("บ้านลาดพร้าว"))
	w := get(h, syncURL)
	var res struct {
		Trips []domain.Trip `json:"trips"`
	}
	if err := json.NewDecoder(w.Body).Decode(&res); err != nil {
		t.Fatal(err)
	}
	if len(res.Trips) != 2 {
		t.Fatalf("expected 2 trips, got %d", len(res.Trips))
	}
	if res.Trips[0].Origin.NameTH != "บ้านลาดพร้าว" {
		t.Errorf("trip 0 origin = %q, want บ้านลาดพร้าว", res.Trips[0].Origin.NameTH)
	}
	if res.Trips[1].Origin.NameTH != "สยาม" {
		t.Errorf("trip 1 origin = %q, want สยาม (chained from previous destination)", res.Trips[1].Origin.NameTH)
	}
}
