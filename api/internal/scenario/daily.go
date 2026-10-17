package scenario

import (
	"context"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

// Days is the demo's daily forecast: today is the storm day, then a rainy
// week turning drier, the same at every point.
type Days struct{}

func (Days) Name() string { return "Google Weather API (scenario)" }

var dayRuns = []struct {
	max, min, feelsMax, feelsMin float64
	prob, thunder, uv            int
	mm                           float64
	cond                         string
}{
	{34.6, 26.4, 41.0, 29.5, 100, 70, 10, 38, "THUNDERSTORM"},
	{33.0, 25.8, 39.0, 28.5, 70, 40, 9, 12, "RAIN_SHOWERS"},
	{33.5, 25.5, 39.5, 28.0, 60, 30, 10, 8, "SCATTERED_SHOWERS"},
	{34.0, 25.0, 40.0, 27.5, 40, 15, 11, 3, "PARTLY_CLOUDY"},
	{33.8, 24.6, 39.6, 27.0, 30, 10, 11, 1, "PARTLY_CLOUDY"},
	{33.2, 24.0, 38.8, 26.5, 20, 5, 10, 0, "MOSTLY_CLEAR"},
	{32.8, 23.5, 38.0, 26.0, 20, 5, 10, 0, "MOSTLY_CLEAR"},
	{32.5, 23.0, 37.5, 25.5, 30, 10, 9, 1, "PARTLY_CLOUDY"},
	{32.0, 22.8, 37.0, 25.0, 40, 15, 9, 2, "SCATTERED_SHOWERS"},
	{32.4, 23.2, 37.4, 25.4, 30, 10, 9, 1, "PARTLY_CLOUDY"},
}

func (d Days) Days(_ context.Context, _ domain.LatLng, now time.Time, l domain.Lang) ([]domain.DayForecast, error) {
	today := dayOf(now.In(domain.Bangkok))
	out := make([]domain.DayForecast, 0, len(dayRuns))
	for i, r := range dayRuns {
		out = append(out, domain.DayForecast{
			Day: today.AddDate(0, 0, i), MaxC: r.max, MinC: r.min, FeelsMaxC: r.feelsMax, FeelsMinC: r.feelsMin,
			RainProbPct: r.prob, RainMM: r.mm, ThunderProbPct: r.thunder, UVIndex: r.uv,
			Condition: r.cond, ConditionText: domain.ConditionText(r.cond, l),
		})
	}
	return out, nil
}
