package live

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"net/url"
	"strconv"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

// Outlook reads the hourly forecast from the hour containing from. Now is the
// first forecast hour rather than a separate currentConditions call, so one
// request feeds the whole outlook. Sunset comes from the daily forecast and is
// left out when that call fails.
func (w GoogleWeather) Outlook(ctx context.Context, at domain.LatLng, from time.Time, l domain.Lang) (domain.Outlook, error) {
	if w.APIKey == "" {
		return domain.Outlook{}, errors.New("GOOGLE_MAPS_API_KEY not set")
	}
	n := strconv.Itoa(domain.OutlookHours + 1)
	req := w.lookup("hours", at, l, url.Values{"hours": {n}, "pageSize": {n}})
	var body struct {
		ForecastHours []struct {
			Interval struct {
				StartTime time.Time `json:"startTime"`
			} `json:"interval"`
			WeatherCondition struct {
				Type        string `json:"type"`
				Description struct {
					Text string `json:"text"`
				} `json:"description"`
			} `json:"weatherCondition"`
			Temperature          struct{ Degrees float64 } `json:"temperature"`
			FeelsLikeTemperature struct{ Degrees float64 } `json:"feelsLikeTemperature"`
			UVIndex              int                       `json:"uvIndex"`
			RelativeHumidity     int                       `json:"relativeHumidity"`
			Wind                 struct {
				Speed struct{ Value float64 } `json:"speed"`
			} `json:"wind"`
			Precipitation struct {
				Probability struct{ Percent int }      `json:"probability"`
				Qpf         struct{ Quantity float64 } `json:"qpf"`
			} `json:"precipitation"`
		} `json:"forecastHours"`
	}
	if err := getJSON(ctx, w.HTTP, req, &body); err != nil {
		return domain.Outlook{}, err
	}
	start := from.Truncate(time.Hour)
	out := domain.Outlook{Sources: []string{w.Name()}}
	for _, h := range body.ForecastHours {
		t := h.Interval.StartTime.In(domain.Bangkok)
		if t.Before(start) || len(out.Hours) == domain.OutlookHours {
			continue
		}
		text := h.WeatherCondition.Description.Text
		if text == "" {
			text = domain.ConditionText(h.WeatherCondition.Type, l)
		}
		out.Hours = append(out.Hours, domain.OutlookHour{
			Time: t, TempC: h.Temperature.Degrees, FeelsLikeC: h.FeelsLikeTemperature.Degrees, UVIndex: h.UVIndex,
			RainProbPct: h.Precipitation.Probability.Percent, RainMMPerHr: h.Precipitation.Qpf.Quantity,
			HumidityPct: h.RelativeHumidity, WindKPH: h.Wind.Speed.Value,
			Condition: h.WeatherCondition.Type, ConditionText: text,
		})
	}
	if len(out.Hours) == 0 {
		return domain.Outlook{}, errors.New("weather API returned no hours from now")
	}
	out.Now = out.Hours[0]
	out.Sunset = w.sunset(ctx, at, l)
	return out, nil
}

func (w GoogleWeather) sunset(ctx context.Context, at domain.LatLng, l domain.Lang) time.Time {
	var body struct {
		ForecastDays []struct {
			SunEvents struct {
				SunsetTime time.Time `json:"sunsetTime"`
			} `json:"sunEvents"`
		} `json:"forecastDays"`
	}
	if err := getJSON(ctx, w.HTTP, w.lookup("days", at, l, url.Values{"days": {"1"}, "pageSize": {"1"}}), &body); err != nil || len(body.ForecastDays) == 0 {
		slog.Warn("no sunset from weather API", "err", err)
		return time.Time{}
	}
	if t := body.ForecastDays[0].SunEvents.SunsetTime; !t.IsZero() {
		return t.In(domain.Bangkok)
	}
	return time.Time{}
}

// lookup builds a GET for /v1/forecast/{kind}:lookup at a point in l.
func (w GoogleWeather) lookup(kind string, at domain.LatLng, l domain.Lang, q url.Values) *http.Request {
	base := w.BaseURL
	if base == "" {
		base = "https://weather.googleapis.com"
	}
	q.Set("key", w.APIKey)
	q.Set("location.latitude", strconv.FormatFloat(at.Lat, 'f', 5, 64))
	q.Set("location.longitude", strconv.FormatFloat(at.Lng, 'f', 5, 64))
	q.Set("languageCode", string(l))
	req, _ := http.NewRequest(http.MethodGet, base+"/v1/forecast/"+kind+":lookup?"+q.Encode(), nil)
	return req
}

type OutlookFallback struct{ Primary, Fallback domain.OutlookProvider }

func (o OutlookFallback) Name() string { return o.Primary.Name() }
func (o OutlookFallback) Outlook(ctx context.Context, at domain.LatLng, from time.Time, l domain.Lang) (domain.Outlook, error) {
	out, err := o.Primary.Outlook(ctx, at, from, l)
	if err == nil {
		return out, nil
	}
	slog.Warn("live outlook failed, using scenario", "err", err)
	return o.Fallback.Outlook(ctx, at, from, l)
}
