package live

import (
	"context"
	"errors"
	"log/slog"
	"net/url"
	"strconv"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

// Days reads the daily forecast: the high and low, the daytime chance of rain
// and thunder, and the UV peak, for each day from today.
func (w GoogleWeather) Days(ctx context.Context, at domain.LatLng, _ time.Time, l domain.Lang) ([]domain.DayForecast, error) {
	if w.APIKey == "" {
		return nil, errors.New("GOOGLE_MAPS_API_KEY not set")
	}
	n := strconv.Itoa(domain.DailyHorizon)
	type part struct {
		WeatherCondition struct {
			Type        string `json:"type"`
			Description struct {
				Text string `json:"text"`
			} `json:"description"`
		} `json:"weatherCondition"`
		Precipitation struct {
			Probability struct{ Percent int }      `json:"probability"`
			Qpf         struct{ Quantity float64 } `json:"qpf"`
		} `json:"precipitation"`
		ThunderstormProbability int `json:"thunderstormProbability"`
		UVIndex                 int `json:"uvIndex"`
	}
	var body struct {
		ForecastDays []struct {
			DisplayDate             struct{ Year, Month, Day int } `json:"displayDate"`
			Daytime                 part                           `json:"daytimeForecast"`
			Nighttime               part                           `json:"nighttimeForecast"`
			MaxTemperature          struct{ Degrees float64 }      `json:"maxTemperature"`
			MinTemperature          struct{ Degrees float64 }      `json:"minTemperature"`
			FeelsLikeMaxTemperature struct{ Degrees float64 }      `json:"feelsLikeMaxTemperature"`
			FeelsLikeMinTemperature struct{ Degrees float64 }      `json:"feelsLikeMinTemperature"`
		} `json:"forecastDays"`
	}
	if err := getJSON(ctx, w.HTTP, w.lookup("days", at, l, url.Values{"days": {n}, "pageSize": {n}}), &body); err != nil {
		return nil, err
	}
	var out []domain.DayForecast
	for _, d := range body.ForecastDays {
		day, night := d.Daytime, d.Nighttime
		text := day.WeatherCondition.Description.Text
		if text == "" {
			text = domain.ConditionText(day.WeatherCondition.Type, l)
		}
		out = append(out, domain.DayForecast{
			Day:            time.Date(d.DisplayDate.Year, time.Month(d.DisplayDate.Month), d.DisplayDate.Day, 0, 0, 0, 0, domain.Bangkok),
			MaxC:           d.MaxTemperature.Degrees,
			MinC:           d.MinTemperature.Degrees,
			FeelsMaxC:      d.FeelsLikeMaxTemperature.Degrees,
			FeelsMinC:      d.FeelsLikeMinTemperature.Degrees,
			RainProbPct:    max(day.Precipitation.Probability.Percent, night.Precipitation.Probability.Percent),
			RainMM:         day.Precipitation.Qpf.Quantity + night.Precipitation.Qpf.Quantity,
			ThunderProbPct: max(day.ThunderstormProbability, night.ThunderstormProbability),
			UVIndex:        day.UVIndex,
			Condition:      day.WeatherCondition.Type,
			ConditionText:  text,
		})
	}
	if len(out) == 0 {
		return nil, errors.New("weather API returned no days")
	}
	return out, nil
}

type DailyFallback struct{ Primary, Fallback domain.DailyProvider }

func (d DailyFallback) Name() string { return d.Primary.Name() }

func (d DailyFallback) Days(ctx context.Context, at domain.LatLng, now time.Time, l domain.Lang) ([]domain.DayForecast, error) {
	out, err := d.Primary.Days(ctx, at, now, l)
	if err == nil {
		return out, nil
	}
	slog.Warn("daily forecast failed, using scenario", "err", err)
	return d.Fallback.Days(ctx, at, now, l)
}
