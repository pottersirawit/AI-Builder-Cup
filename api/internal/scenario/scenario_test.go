package scenario

import (
	"context"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
)

func demo(hh, mm int) time.Time { return time.Date(2026, 9, 29, hh, mm, 0, 0, domain.Bangkok) }

func TestRainScript(t *testing.T) {
	tests := []struct {
		at      time.Time
		atLeast float64
		below   float64
	}{
		{demo(16, 10), 0, 0.01},
		{demo(17, 20), 0, 1},   // still dry enough before the cell
		{demo(17, 30), 1, 10},  // rain reaches Rama 4
		{demo(18, 20), 30, 99}, // peak
		{demo(19, 20), 1, 10},  // eased
		{demo(20, 10), 0, 0.01},
	}
	for _, tt := range tests {
		t.Run(tt.at.Format("15:04"), func(t *testing.T) {
			if got := RainAt(tt.at); got < tt.atLeast || got >= tt.below {
				t.Fatalf("RainAt = %v, want in [%v, %v)", got, tt.atLeast, tt.below)
			}
		})
	}
	samples, _ := Weather{}.Rain(context.Background(), Silom.Point(), demo(16, 10), demo(21, 0))
	if len(samples) != 21 || !samples[0].Time.Equal(demo(16, 0)) {
		t.Fatalf("got %d samples starting %v", len(samples), samples[0].Time)
	}
}

func TestCanalScript(t *testing.T) {
	tests := []struct {
		at     time.Time
		level  float64
		rise2h float64
	}{
		{demo(16, 10), 1.4, 0},
		{demo(21, 40), 1.8, 40},
	}
	for _, tt := range tests {
		got, _ := Canals{}.Canals(context.Background(), Home.Point(), tt.at)
		lp := got[0]
		if lp.NameTH != "คลองลาดพร้าว" || lp.LevelM != tt.level || lp.BankM != 1.8 || lp.RiseCM2h != tt.rise2h {
			t.Fatalf("%s: got %+v", tt.at.Format("15:04"), lp)
		}
	}
}

func TestHeroRouteDurations(t *testing.T) {
	r := Routes{}
	tests := []struct {
		mode   domain.Mode
		depart time.Time
		want   int
	}{
		{domain.ModeCar, demo(16, 10), 50}, // "ถ้าออกตอนนี้ถึงบ้านราว 17:00"
		{domain.ModeCar, demo(16, 45), 60}, // traffic builds
		{domain.ModeTransit, demo(16, 10), 40},
		{domain.ModeMoto, demo(16, 10), 30},
	}
	for _, tt := range tests {
		route, err := r.Route(context.Background(), Silom.Point(), Home.Point(), tt.mode, tt.depart)
		if err != nil || route.DurationMin != tt.want {
			t.Fatalf("%s at %s: got %d (%v), want %d", tt.mode, tt.depart.Format("15:04"), route.DurationMin, err, tt.want)
		}
	}
	car, _ := r.Route(context.Background(), Silom.Point(), Home.Point(), domain.ModeCar, demo(16, 10))
	if d := geo.DistanceToPolylineM(HeroReportPoint, car.Polyline); d > 50 {
		t.Fatalf("car corridor should pass the hero report point, is %.0f m away", d)
	}
}

func TestMockUsersCrossingHeroPoint(t *testing.T) {
	crossing := 0
	for _, u := range MockUsers() {
		if geo.DistanceToPolylineM(HeroReportPoint, u.Route) <= 300 {
			crossing++
		}
	}
	if crossing != 27 {
		t.Fatalf("crossing = %d, want 27", crossing)
	}
}

func TestTripsAreAnchoredToTheClockDay(t *testing.T) {
	trips := Trips(demo(16, 10))
	if trips[0].ID != "cal-dinner" || !trips[0].ArriveBy.Equal(demo(18, 30)) {
		t.Fatalf("got %+v", trips[0])
	}
	if trips[1].ArriveBy.Weekday() != time.Saturday {
		t.Fatalf("concert should be on Saturday, got %v", trips[1].ArriveBy)
	}
}
