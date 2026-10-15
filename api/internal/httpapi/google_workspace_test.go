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
