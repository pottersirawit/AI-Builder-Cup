package floodspot

import (
	"math"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

func datasetPath() string {
	_, file, _, _ := runtime.Caller(0)
	return filepath.Join(filepath.Dir(file), "..", "..", "..", "data", "bkk_flood_risk_points.json")
}

func TestLoadDataset(t *testing.T) {
	spots, err := Load(datasetPath())
	if err != nil {
		t.Fatal(err)
	}
	if len(spots) < 8 {
		t.Fatalf("got %d spots, want at least 8", len(spots))
	}
	for _, s := range spots {
		if s.ID == "" || s.NameTH == "" || s.Lat == 0 || s.ThresholdMMPerHr == 0 {
			t.Fatalf("incomplete spot %+v", s)
		}
	}
}

func TestInstantDepthCM(t *testing.T) {
	ratchada := Spot{ThresholdMMPerHr: 35, MaxDepthCM: 25}
	tests := []struct {
		name string
		mm   float64
		want float64
	}{
		{"dry", 0, 0},
		{"light rain drains", 10, 0},
		{"heavy but below threshold leaves a film", 30, 5},
		{"exactly at threshold is half the historical max", 35, 12.5},
		{"peak storm 52 mm/h", 52, 25 * (0.5 + 0.5*17.0/35)},
		{"excess is capped at 1.5x", 500, 25 * 1.25},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := InstantDepthCM(ratchada, tt.mm); math.Abs(got-tt.want) > 1e-9 {
				t.Fatalf("got %.2f, want %.2f", got, tt.want)
			}
		})
	}
}

func TestOnRoute(t *testing.T) {
	spots := []Spot{
		{ID: "near", Lat: 13.80, Lng: 100.55, RiskRadiusM: 1000},
		{ID: "far", Lat: 13.90, Lng: 100.55, RiskRadiusM: 1000},
		{ID: "edge", Lat: 13.808, Lng: 100.55, RiskRadiusM: 1000},
	}
	route := []domain.LatLng{{Lat: 13.80, Lng: 100.50}, {Lat: 13.80, Lng: 100.60}}
	got := OnRoute(spots, route)
	if len(got) != 2 || got[0].ID != "near" || got[1].ID != "edge" {
		t.Fatalf("got %+v", got)
	}
}

func TestShortNameTH(t *testing.T) {
	tests := map[string]string{
		"ถนนรัชดาภิเษก หน้าศาลอาญา และซอยเสือใหญ่อุทิศ":       "รัชดาภิเษก",
		"ถนนพระราม 4 ช่วงใต้ทางด่วน และแยกเกษมราษฎร์":         "พระราม 4",
		"ถนนสุขุมวิท ช่วงอโศก - พร้อมพงษ์ (สุขุมวิท 21 - 39)": "สุขุมวิท",
		"ซอยไม่มีถนน": "ซอยไม่มีถนน",
	}
	for in, want := range tests {
		if got := (Spot{NameTH: in}).ShortNameTH(); got != want {
			t.Errorf("%q: got %q, want %q", in, got, want)
		}
	}
}
