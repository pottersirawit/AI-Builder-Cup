package reports

import (
	"context"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func at(hh, mm int) time.Time { return time.Date(2026, 9, 29, hh, mm, 0, 0, domain.Bangkok) }

func TestMemoryStoreNear(t *testing.T) {
	ctx := context.Background()
	s := NewMemoryStore(scenario.SeedReports()...)
	added, _ := s.Add(ctx, domain.Report{Lat: scenario.HeroReportPoint.Lat, Lng: scenario.HeroReportPoint.Lng, CreatedAt: at(18, 52)})
	if added.ID != "r1" {
		t.Fatalf("first id = %q, want r1", added.ID)
	}
	tests := []struct {
		name         string
		since, until time.Time
		radius       float64
		want         int
	}{
		{"corroborating window at 18:52 includes พลอย", at(18, 22), at(18, 52), 300, 3},
		{"before the storm nothing is visible", at(0, 0), at(16, 10), 5000, 0},
		{"replay hides reports from the future", at(18, 0), at(18, 45), 300, 1},
		{"tight radius", at(18, 0), at(19, 0), 10, 1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, _ := s.Near(ctx, scenario.HeroReportPoint, tt.radius, tt.since, tt.until)
			if len(got) != tt.want {
				t.Fatalf("got %d reports, want %d", len(got), tt.want)
			}
		})
	}
}

func TestNotifiedUsers(t *testing.T) {
	users := scenario.MockUsers()
	tests := []struct {
		name string
		p    domain.LatLng
		want int
	}{
		{"hero point on Ratchada", scenario.HeroReportPoint, 27},
		{"empty rice field far away", domain.LatLng{Lat: 14.5, Lng: 101.5}, 0},
	}
	for _, tt := range tests {
		if got := NotifiedUsers(users, tt.p); got != tt.want {
			t.Fatalf("%s: got %d, want %d", tt.name, got, tt.want)
		}
	}
}
