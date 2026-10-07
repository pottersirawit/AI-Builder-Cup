// Package floodspot loads the BMA flood spot dataset and matches spots to routes.
// The depth model is ported from engine/geospatial/flood_matcher.py.
package floodspot

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
)

// Spot is one BMA Flood Spot from data/bkk_flood_risk_points.json.
type Spot struct {
	ID               string   `json:"id"`
	NameTH           string   `json:"name_th"`
	NameEN           string   `json:"name_en"`
	District         string   `json:"district"`
	Lat              float64  `json:"latitude"`
	Lng              float64  `json:"longitude"`
	RiskRadiusM      float64  `json:"risk_radius_meters"`
	ThresholdMMPerHr float64  `json:"critical_rain_threshold_mm_hr"`
	DrainageCanal    string   `json:"drainage_canal"`
	MaxDepthCM       float64  `json:"historical_max_depth_cm"`
	HighRiskVehicles []string `json:"high_risk_vehicles"`
	NotesTH          string   `json:"notes"`
}

func (s Spot) Point() domain.LatLng { return domain.LatLng{Lat: s.Lat, Lng: s.Lng} }

// Load reads the dataset, filling defaults the Python matcher also assumed.
func Load(path string) ([]Spot, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read flood spots: %w", err)
	}
	var spots []Spot
	if err := json.Unmarshal(b, &spots); err != nil {
		return nil, fmt.Errorf("parse flood spots %s: %w", path, err)
	}
	for i := range spots {
		if spots[i].RiskRadiusM == 0 {
			spots[i].RiskRadiusM = 2000
		}
		if spots[i].ThresholdMMPerHr == 0 {
			spots[i].ThresholdMMPerHr = 35
		}
		if spots[i].MaxDepthCM == 0 {
			spots[i].MaxDepthCM = 20
		}
	}
	return spots, nil
}

// OnRoute returns the spots whose risk radius the route passes through.
func OnRoute(spots []Spot, route []domain.LatLng) []Spot {
	var out []Spot
	for _, s := range spots {
		if geo.DistanceToPolylineM(s.Point(), route) <= s.RiskRadiusM {
			out = append(out, s)
		}
	}
	return out
}

// InstantDepthCM estimates street water depth while rain falls at mmPerHr.
// Above the spot's threshold depth scales with the excess; heavy-but-below
// threshold rain leaves a shallow film; light rain drains.
func InstantDepthCM(s Spot, mmPerHr float64) float64 {
	if mmPerHr >= s.ThresholdMMPerHr {
		excess := min((mmPerHr-s.ThresholdMMPerHr)/s.ThresholdMMPerHr, 1.5)
		return s.MaxDepthCM * (0.5 + 0.5*excess)
	}
	if mmPerHr > 15 {
		return s.MaxDepthCM * 0.2
	}
	return 0
}

// ShortNameTH turns "ถนนรัชดาภิเษก หน้าศาลอาญา ..." into "รัชดาภิเษก" for headlines.
func (s Spot) ShortNameTH() string {
	name := strings.TrimPrefix(s.NameTH, "ถนน")
	cut := len(name)
	for _, sep := range []string{" ช่วง", " หน้า", " แยก", " ซอย", " ("} {
		if i := strings.Index(name, sep); i >= 0 && i < cut {
			cut = i
		}
	}
	return strings.TrimSpace(name[:cut])
}
