package domain

import (
	"context"
	"time"
)

// DayForecast is one day's weather at a place: what a day out (climbing,
// camping, the beach) needs to pack for, days ahead of the hourly outlook.
type DayForecast struct {
	// Day is midnight Bangkok time of the forecast day.
	Day         time.Time `json:"day"`
	MaxC        float64   `json:"max_c"`
	MinC        float64   `json:"min_c"`
	FeelsMaxC   float64   `json:"feels_max_c"`
	FeelsMinC   float64   `json:"feels_min_c"`
	RainProbPct int       `json:"rain_prob_pct"`
	RainMM      float64   `json:"rain_mm"`
	// ThunderProbPct is the daytime chance of a thunderstorm.
	ThunderProbPct int    `json:"thunder_prob_pct"`
	UVIndex        int    `json:"uv_index"`
	Condition      string `json:"condition"`
	ConditionText  string `json:"condition_th"`
}

// DailyHorizon is how many days ahead a daily forecast reaches.
const DailyHorizon = 10

// DailyProvider forecasts the next DailyHorizon days at a point, from today.
type DailyProvider interface {
	Days(ctx context.Context, at LatLng, now time.Time, l Lang) ([]DayForecast, error)
	Name() string
}

// ForecastFor is the forecast of the Bangkok day containing day, if any.
func ForecastFor(days []DayForecast, day time.Time) *DayForecast {
	y, m, d := day.In(Bangkok).Date()
	for i := range days {
		dy, dm, dd := days[i].Day.In(Bangkok).Date()
		if dy == y && dm == m && dd == d {
			return &days[i]
		}
	}
	return nil
}
