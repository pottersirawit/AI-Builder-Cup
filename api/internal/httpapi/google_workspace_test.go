package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
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

	testEmail := "the32069@gmail.com"
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

	// 2. Query /v1/trips?email=the32069@gmail.com
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

	// 3. Query /v1/trips/sync?email=the32069@gmail.com
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
