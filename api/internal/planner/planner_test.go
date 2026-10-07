package planner

import (
	"context"
	"errors"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/reports"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func at(hh, mm int) time.Time { return time.Date(2026, 9, 29, hh, mm, 0, 0, domain.Bangkok) }

func newPlanner(t *testing.T) *Planner {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	spots, err := floodspot.Load(filepath.Join(filepath.Dir(file), "..", "..", "..", "data", "bkk_flood_risk_points.json"))
	if err != nil {
		t.Fatal(err)
	}
	return &Planner{Spots: spots, Trips: scenario.Trips, Places: scenario.Places, Whereabouts: scenario.Whereabouts}
}

func scenarioProviders() Providers {
	return Providers{Weather: scenario.Weather{}, Routes: scenario.Routes{}, Canals: scenario.Canals{}, Reports: reports.NewMemoryStore(scenario.SeedReports()...)}
}

func TestNewSessionTrips(t *testing.T) {
	p := newPlanner(t)
	tests := []struct {
		id      string
		want    string
		wantErr bool
	}{
		{"", "cal-dinner", false},
		{"gmail-concert", "gmail-concert", false},
		{"adhoc-siam", "adhoc-siam", false}, // the app re-asks with the slider using the returned trip id
		{"nope", "", true},
		{"adhoc-mars", "", true},
	}
	for _, tt := range tests {
		s, err := p.NewSession(context.Background(), scenarioProviders(), at(16, 10), tt.id)
		if tt.wantErr {
			if !errors.Is(err, ErrUnknownTrip) {
				t.Fatalf("%q: want ErrUnknownTrip, got %v", tt.id, err)
			}
			continue
		}
		if err != nil || s.Trip.ID != tt.want {
			t.Fatalf("%q: got %v %v", tt.id, s, err)
		}
	}
}

func TestToolsAtTheHeroMoments(t *testing.T) {
	tests := []struct {
		now     time.Time
		tool    string
		args    map[string]any
		summary string
	}{
		{at(16, 10), "get_trip", nil, "ต้องถึงบ้านลาดพร้าวก่อน 18:30 (จาก Google Calendar)"},
		{at(16, 10), "get_route", map[string]any{"mode": "car"}, "ใช้เวลา 50 นาที ผ่าน พระราม 4 → อโศก → รัชดาภิเษก"},
		{at(16, 10), "get_rain_along_route", nil, "ฝนถึงพระราม 4 ราว 17:30 หนักสุด 52 มม./ชม. ตอน 18:15"},
		{at(16, 10), "get_flood_spots_on_route", map[string]any{"depart_at": "16:10"}, "ยังไม่มีน้ำขัง"},
		{at(16, 10), "get_flood_spots_on_route", map[string]any{"depart_at": "18:00"}, "ลึกสุดคาด"},
		{at(16, 10), "get_canal_levels", nil, "คลองลาดพร้าว 1.4 ม. ตลิ่ง 1.8 ม."},
		{at(16, 10), "get_community_reports", nil, "ยังไม่มีรายงาน"},
		{at(18, 50), "get_community_reports", nil, "รายงานจากผู้ใช้ 2 รายการบนเส้นทาง ล่าสุด 18:47"},
		{at(16, 10), "evaluate_departure", map[string]any{"mode": "car", "depart_at": "2026-09-29T20:00:00+07:00"}, "เลยนัด 150 นาที"},
	}
	p := newPlanner(t)
	for _, tt := range tests {
		t.Run(tt.tool+"@"+tt.now.Format("15:04"), func(t *testing.T) {
			s, _ := p.NewSession(context.Background(), scenarioProviders(), tt.now, "cal-dinner")
			if _, err := s.Call(tt.tool, tt.args); err != nil {
				t.Fatal(err)
			}
			calls := s.Calls()
			if len(calls) != 1 || calls[0].Tool != tt.tool || !strings.Contains(calls[0].SummaryTH, tt.summary) {
				t.Fatalf("summary %q should contain %q", calls[0].SummaryTH, tt.summary)
			}
		})
	}
}

func TestUnknownToolIsRecordedAsAnError(t *testing.T) {
	s, _ := newPlanner(t).NewSession(context.Background(), scenarioProviders(), at(16, 10), "")
	if _, err := s.Call("launch_rocket", nil); err == nil {
		t.Fatal("want error")
	}
	if c := s.Calls(); len(c) != 1 || !strings.Contains(c[0].SummaryTH, "ไม่สำเร็จ") {
		t.Fatalf("got %+v", c)
	}
}

func TestBaselineMatchesTheHero(t *testing.T) {
	s, _ := newPlanner(t).NewSession(context.Background(), scenarioProviders(), at(16, 10), "cal-dinner")
	res, err := s.Baseline(at(16, 10), domain.ModeCar)
	if err != nil {
		t.Fatal(err)
	}
	if res.HeadlineTH != "ออกก่อน 16:45" {
		t.Fatalf("headline = %q", res.HeadlineTH)
	}
}

func TestParseTime(t *testing.T) {
	now := at(16, 10)
	tests := map[string]time.Time{
		"20:00":                     at(20, 0),
		"17.30":                     at(17, 30),
		"2026-09-29T11:00:00Z":      at(18, 0),
		"2026-09-29T18:52:00+07:00": at(18, 52),
	}
	for in, want := range tests {
		if got, err := ParseTime(in, now); err != nil || !got.Equal(want) {
			t.Errorf("%q: got %v %v, want %v", in, got, err, want)
		}
	}
	if _, err := ParseTime("soon", now); err == nil {
		t.Error("want error for garbage")
	}
}

func TestTripTo(t *testing.T) {
	saturday := time.Date(2026, 10, 3, 16, 10, 0, 0, domain.Bangkok)
	tests := []struct {
		name       string
		now        time.Time
		place      string
		wantID     string
		wantOrigin domain.Place
	}{
		{"typed destination from the office", at(16, 10), "siam", "adhoc-siam", scenario.Silom},
		{"home is tonight's Calendar dinner", at(16, 10), "home", "cal-dinner", scenario.Silom},
		{"going to the office while there starts from home", at(16, 10), "work", "adhoc-work", scenario.Home},
		{"concert days away stays ad hoc", at(16, 10), "impact", "adhoc-impact", scenario.Silom},
		{"concert tonight is the Gmail trip", saturday, "impact", "gmail-concert", scenario.Silom},
		{"weekend evening starts from home", saturday, "thonglor", "adhoc-thonglor", scenario.Home},
	}
	p := newPlanner(t)
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			trip, err := p.TripTo(tt.now, tt.place)
			if err != nil {
				t.Fatal(err)
			}
			if trip.ID != tt.wantID || trip.Origin != tt.wantOrigin {
				t.Fatalf("got %s from %v", trip.ID, trip.Origin)
			}
			if strings.HasPrefix(trip.ID, AdHocPrefix) && (!trip.ArriveBy.IsZero() || trip.Source != "question" || trip.Mode != domain.ModeCar) {
				t.Fatalf("ad-hoc trip = %+v", trip)
			}
		})
	}
	if _, err := p.TripTo(at(16, 10), "mars"); !errors.Is(err, ErrUnknownTrip) {
		t.Fatalf("want ErrUnknownTrip, got %v", err)
	}
}

func TestPlanToReplacesTheTripAndItsCaches(t *testing.T) {
	s, _ := newPlanner(t).NewSession(context.Background(), scenarioProviders(), at(16, 10), "cal-dinner")
	if _, err := s.Call("get_route", map[string]any{"mode": "car"}); err != nil {
		t.Fatal(err)
	}
	if err := s.PlanTo("siam"); err != nil {
		t.Fatal(err)
	}
	if s.Trip.ID != "adhoc-siam" || s.Trip.Destination != scenario.Siam {
		t.Fatalf("trip = %+v", s.Trip)
	}
	s.Call("get_trip", nil)
	s.Call("get_route", map[string]any{"mode": "car"})
	calls := s.Calls()
	if !strings.Contains(calls[1].SummaryTH, "ไปสยาม") || !strings.Contains(calls[1].SummaryTH, "ไม่มีเวลานัด") {
		t.Errorf("get_trip summary = %q", calls[1].SummaryTH)
	}
	if strings.Contains(calls[2].SummaryTH, "รัชดาภิเษก") || strings.HasSuffix(calls[2].SummaryTH, "ผ่าน ") {
		t.Errorf("route to Siam reused the Lat Phrao corridor: %q", calls[2].SummaryTH)
	}
	if err := s.PlanTo("mars"); !errors.Is(err, ErrUnknownTrip) {
		t.Fatalf("want ErrUnknownTrip, got %v", err)
	}
}

func TestResetCalls(t *testing.T) {
	s, _ := newPlanner(t).NewSession(context.Background(), scenarioProviders(), at(16, 10), "")
	s.Call("get_trip", nil)
	s.ResetCalls()
	if c := s.Calls(); len(c) != 0 {
		t.Fatalf("calls after reset = %+v", c)
	}
}
