package resolve

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/extract"
	"github.com/pottersirawit/fontokmai/api/internal/geocode"
)

type fakeGeocoder struct {
	results map[string][]geocode.Place
}

func (f *fakeGeocoder) Search(_ context.Context, q string) ([]geocode.Place, error) {
	if res, ok := f.results[q]; ok {
		return res, nil
	}
	return nil, nil
}

func (f *fakeGeocoder) Reverse(_ context.Context, _ domain.LatLng) (geocode.Address, error) {
	return geocode.Address{}, nil
}

func testTime(h, m int) time.Time {
	return time.Date(2026, 10, 11, h, m, 0, 0, domain.Bangkok)
}

func TestResolve_SavedPlaceMatch(t *testing.T) {
	home := domain.SavedPlace{
		ID:      "p-home",
		Kind:    domain.KindHome,
		LabelTH: "บ้าน",
		Place:   domain.Place{NameTH: "บ้านลาดพร้าว", Lat: 13.8160, Lng: 100.5900},
	}
	work := domain.SavedPlace{
		ID:      "p-work",
		Kind:    domain.KindWork,
		LabelTH: "ที่ทำงาน",
		Place:   domain.Place{NameTH: "สีลม ซอย 3", Lat: 13.7263, Lng: 100.5340},
	}
	places := []domain.SavedPlace{home, work}

	arrive := testTime(18, 30)
	payload := extract.Payload{
		Source:          extract.SourceCalendar,
		SourceRef:       "cal-1",
		IsTrip:          true,
		TitleTH:         "กลับบ้าน",
		DestinationText: "บ้าน",
		ArriveBy:        &arrive,
	}

	currentOrigin := &work.Place
	trip, needsPlace, err := Trip(context.Background(), payload, currentOrigin, places, &fakeGeocoder{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if needsPlace != nil {
		t.Fatalf("unexpected needsPlace: %+v", needsPlace)
	}

	if trip.Destination.Lat != home.Lat || trip.Destination.Lng != home.Lng {
		t.Errorf("expected destination = home coords, got %+v", trip.Destination)
	}
	if trip.Origin.Lat != work.Lat || trip.Origin.Lng != work.Lng {
		t.Errorf("expected origin = work coords, got %+v", trip.Origin)
	}
	if trip.Source != extract.SourceCalendar {
		t.Errorf("expected trip source = calendar, got %s", trip.Source)
	}
}

func TestResolve_GeocodeMatch(t *testing.T) {
	geo := &fakeGeocoder{
		results: map[string][]geocode.Place{
			"อิมแพ็ค อารีน่า เมืองทองธานี": {
				{
					NameTH:    "อิมแพ็ค อารีน่า",
					AddressTH: "เมืองทองธานี นนทบุรี",
					Lat:       13.9119,
					Lng:       100.5480,
					Source:    "local",
				},
			},
		},
	}

	work := domain.Place{NameTH: "ออฟฟิศสีลม", Lat: 13.7263, Lng: 100.5340}
	arrive := testTime(19, 0)
	payload := extract.Payload{
		Source:          extract.SourceGmail,
		SourceRef:       "gmail-ticket-1",
		IsTrip:          true,
		TitleTH:         "คอนเสิร์ต",
		DestinationText: "อิมแพ็ค อารีน่า เมืองทองธานี",
		ArriveBy:        &arrive,
	}

	trip, needsPlace, err := Trip(context.Background(), payload, &work, nil, geo)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if needsPlace != nil {
		t.Fatalf("unexpected needsPlace: %+v", needsPlace)
	}

	if trip.Destination.NameTH != "อิมแพ็ค อารีน่า" {
		t.Errorf("expected destination name = 'อิมแพ็ค อารีน่า', got %s", trip.Destination.NameTH)
	}
	if trip.Destination.Lat != 13.9119 {
		t.Errorf("expected lat = 13.9119, got %f", trip.Destination.Lat)
	}
}

func TestResolve_NeedsPlace_WhenUnknown(t *testing.T) {
	geo := &fakeGeocoder{
		results: map[string][]geocode.Place{
			"ร้านลับบางรัก": {}, // Empty results
		},
	}

	work := domain.Place{NameTH: "ออฟฟิศ", Lat: 13.7263, Lng: 100.5340}
	payload := extract.Payload{
		Source:          extract.SourceCalendar,
		SourceRef:       "cal-unknown",
		IsTrip:          true,
		TitleTH:         "นัดกินข้าวร้านลับ",
		DestinationText: "ร้านลับบางรัก",
	}

	_, needsPlace, err := Trip(context.Background(), payload, &work, nil, geo)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if needsPlace == nil {
		t.Fatalf("expected needsPlace when destination cannot be located")
	}
	if needsPlace.QueryTH != "ร้านลับบางรัก" {
		t.Errorf("expected query = 'ร้านลับบางรัก', got %s", needsPlace.QueryTH)
	}
}

func TestResolve_NotATrip(t *testing.T) {
	payload := extract.Payload{
		Source:    extract.SourceCalendar,
		SourceRef: "cal-online",
		IsTrip:    false,
		TitleTH:   "ประชุม Google Meet",
	}

	_, _, err := Trip(context.Background(), payload, nil, nil, &fakeGeocoder{})
	if !errors.Is(err, ErrNotATrip) {
		t.Fatalf("expected ErrNotATrip, got %v", err)
	}
}
