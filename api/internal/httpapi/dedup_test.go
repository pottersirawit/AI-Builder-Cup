package httpapi

import (
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

func TestDeduplicateTrips(t *testing.T) {
	bkk := domain.Bangkok
	baseTime := time.Date(2026, 10, 18, 14, 0, 0, 0, bkk)

	t.Run("drops duplicate gmail trip when calendar trip matches time and venue", func(t *testing.T) {
		calTrip := domain.Trip{
			ID:          "cal-flight1",
			TitleTH:     "เที่ยวบิน FD3024",
			Source:      "calendar",
			Destination: domain.Place{NameTH: "สนามบินดอนเมือง", Lat: 13.9126, Lng: 100.6067},
			ArriveBy:    baseTime,
		}
		gmailTrip := domain.Trip{
			ID:          "gmail-msg1",
			TitleTH:     "AirAsia Booking Confirmation FD3024",
			Source:      "gmail",
			Destination: domain.Place{NameTH: "สนามบินดอนเมือง", Lat: 13.9130, Lng: 100.6070},
			ArriveBy:    baseTime.Add(10 * time.Minute), // within 90 mins
		}

		trips := []domain.Trip{calTrip, gmailTrip}
		deduped := DeduplicateTrips(trips)

		if len(deduped) != 1 {
			t.Fatalf("expected 1 trip, got %d", len(deduped))
		}
		if deduped[0].ID != "cal-flight1" {
			t.Errorf("expected calendar trip cal-flight1 to be preserved, got %s", deduped[0].ID)
		}
	})

	t.Run("adopts resolved venue from gmail when calendar venue is unresolved", func(t *testing.T) {
		calTrip := domain.Trip{
			ID:             "cal-concert1",
			TitleTH:        "คอนเสิร์ต Maroon 5",
			Source:         "calendar",
			Destination:    domain.Place{NameTH: "อิมแพ็ค"}, // unresolved (0,0)
			LocationTextTH: "อิมแพ็ค เมืองทองธานี",
			ArriveBy:       baseTime,
		}
		gmailTrip := domain.Trip{
			ID:             "gmail-ticket1",
			TitleTH:        "Ticket - Maroon 5 World Tour",
			Source:         "gmail",
			Destination:    domain.Place{NameTH: "อิมแพ็ค อารีน่า", Lat: 13.9113, Lng: 100.5489},
			LocationTextTH: "อิมแพ็ค อารีน่า เมืองทองธานี",
			ArriveBy:       baseTime,
		}

		trips := []domain.Trip{calTrip, gmailTrip}
		deduped := DeduplicateTrips(trips)

		if len(deduped) != 1 {
			t.Fatalf("expected 1 trip, got %d", len(deduped))
		}
		if deduped[0].ID != "cal-concert1" {
			t.Errorf("expected calendar trip cal-concert1, got %s", deduped[0].ID)
		}
		if !deduped[0].Destination.Resolved() {
			t.Errorf("expected calendar trip to adopt resolved destination from gmail, got lat=%f", deduped[0].Destination.Lat)
		}
		if deduped[0].Destination.Lat != 13.9113 {
			t.Errorf("expected adopted lat 13.9113, got %f", deduped[0].Destination.Lat)
		}
	})

	t.Run("deduplicates all-day events on the same day with matching title", func(t *testing.T) {
		allDayTime := time.Date(2026, 10, 19, 0, 0, 0, 0, bkk)
		calTrip := domain.Trip{
			ID:       "cal-conf",
			TitleTH:  "Tech Conference 2026",
			Source:   "calendar",
			AllDay:   true,
			ArriveBy: allDayTime,
		}
		gmailTrip := domain.Trip{
			ID:       "gmail-conf-ticket",
			TitleTH:  "Ticketmelon: Tech Conference 2026",
			Source:   "gmail",
			AllDay:   true,
			ArriveBy: allDayTime,
		}

		trips := []domain.Trip{calTrip, gmailTrip}
		deduped := DeduplicateTrips(trips)

		if len(deduped) != 1 {
			t.Fatalf("expected 1 trip, got %d", len(deduped))
		}
		if deduped[0].ID != "cal-conf" {
			t.Errorf("expected cal-conf, got %s", deduped[0].ID)
		}
	})

	t.Run("deduplicates date-only gmail trip when timed calendar trip exists on same day", func(t *testing.T) {
		calTrip := domain.Trip{
			ID:          "cal-saladaeng",
			TitleTH:     "นัดเจอเพื่อน",
			Source:      "calendar",
			Destination: domain.Place{NameTH: "BTS ศาลาแดง", Lat: 13.7285, Lng: 100.5341},
			ArriveBy:    time.Date(2026, 10, 18, 18, 0, 0, 0, bkk),
		}
		gmailTrip := domain.Trip{
			ID:          "gmail-saladaeng",
			TitleTH:     "นัดเจอกันที่ BTS ศาลาแดง",
			Source:      "gmail",
			AllDay:      true,
			Destination: domain.Place{NameTH: "BTS ศาลาแดง", Lat: 13.7285, Lng: 100.5341},
			ArriveBy:    time.Date(2026, 10, 18, 0, 0, 0, 0, bkk),
			EndsAt:      time.Date(2026, 10, 19, 0, 0, 0, 0, bkk),
		}

		deduped := DeduplicateTrips([]domain.Trip{gmailTrip, calTrip})
		if len(deduped) != 1 || deduped[0].ID != "cal-saladaeng" {
			t.Errorf("expected single cal-saladaeng trip, got %+v", deduped)
		}
	})

	t.Run("preserves distinct events on the same day", func(t *testing.T) {
		tripMorning := domain.Trip{
			ID:          "cal-work",
			TitleTH:     "ประชุมเช้า",
			Source:      "calendar",
			Destination: domain.Place{NameTH: "ออฟฟิศ", Lat: 13.72, Lng: 100.52},
			ArriveBy:    time.Date(2026, 10, 18, 9, 0, 0, 0, bkk),
		}
		tripEvening := domain.Trip{
			ID:          "gmail-dinner",
			TitleTH:     "จองโต๊ะอาหารค่ำ",
			Source:      "gmail",
			Destination: domain.Place{NameTH: "ร้านอาหารริมน้ำ", Lat: 13.74, Lng: 100.51},
			ArriveBy:    time.Date(2026, 10, 18, 19, 0, 0, 0, bkk),
		}

		trips := []domain.Trip{tripMorning, tripEvening}
		deduped := DeduplicateTrips(trips)

		if len(deduped) != 2 {
			t.Fatalf("expected 2 distinct trips preserved, got %d", len(deduped))
		}
	})

	t.Run("deduplicates via token overlap when titles are not substrings", func(t *testing.T) {
		calTrip := domain.Trip{
			ID:       "cal-keynote",
			TitleTH:  "Conference Keynote at Hall",
			Source:   "calendar",
			ArriveBy: baseTime,
		}
		gmailTrip := domain.Trip{
			ID:       "gmail-keynote",
			TitleTH:  "Reminder: Keynote session details",
			Source:   "gmail",
			ArriveBy: baseTime.Add(15 * time.Minute),
		}

		trips := []domain.Trip{calTrip, gmailTrip}
		deduped := DeduplicateTrips(trips)

		if len(deduped) != 1 {
			t.Fatalf("expected 1 trip via token overlap, got %d", len(deduped))
		}
		if deduped[0].ID != "cal-keynote" {
			t.Errorf("expected cal-keynote, got %s", deduped[0].ID)
		}
	})
}

