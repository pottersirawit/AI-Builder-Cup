package live

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func TestGoogleWeatherOutlookMapsForecastFields(t *testing.T) {
	start := time.Date(2026, 9, 29, 9, 0, 0, 0, time.UTC) // 16:00 Bangkok
	hour := func(at time.Time, temp float64, cond, text string) map[string]any {
		return map[string]any{
			"interval":             map[string]any{"startTime": at.Format(time.RFC3339)},
			"weatherCondition":     map[string]any{"type": cond, "description": map[string]any{"text": text, "languageCode": "th"}},
			"temperature":          map[string]any{"degrees": temp, "unit": "CELSIUS"},
			"feelsLikeTemperature": map[string]any{"degrees": 39.1, "unit": "CELSIUS"},
			"uvIndex":              7,
			"relativeHumidity":     68,
			"wind":                 map[string]any{"speed": map[string]any{"value": 11, "unit": "KILOMETERS_PER_HOUR"}},
			"precipitation": map[string]any{
				"probability": map[string]any{"percent": 20, "type": "RAIN"},
				"qpf":         map[string]any{"quantity": 0.4, "unit": "MILLIMETERS"},
			},
		}
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		if q.Get("key") != "k" || q.Get("languageCode") != "th" {
			http.Error(w, "bad request "+r.URL.String(), 400)
			return
		}
		switch r.URL.Path {
		case "/v1/forecast/hours:lookup":
			json.NewEncoder(w).Encode(map[string]any{"forecastHours": []any{
				hour(start.Add(-time.Hour), 34, "CLEAR", "ท้องฟ้าแจ่มใส"),
				hour(start, 33.4, "PARTLY_CLOUDY", "มีเมฆบางส่วน"),
				hour(start.Add(time.Hour), 31, "THUNDERSTORM", "พายุฝนฟ้าคะนอง"),
			}})
		case "/v1/forecast/days:lookup":
			w.Write([]byte(`{"forecastDays":[{"sunEvents":{"sunriseTime":"2026-09-28T23:05:00Z","sunsetTime":"2026-09-29T11:12:00Z"}}]}`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()

	from := time.Date(2026, 9, 29, 16, 10, 0, 0, domain.Bangkok)
	got, err := GoogleWeather{APIKey: "k", BaseURL: srv.URL}.Outlook(context.Background(), scenario.Home.Point(), from, domain.LangTH)
	if err != nil {
		t.Fatal(err)
	}
	if len(got.Hours) != 2 {
		t.Fatalf("got %d hours, want the 15:00 hour dropped: %+v", len(got.Hours), got.Hours)
	}
	h := got.Hours[0]
	want := domain.OutlookHour{Time: start.In(domain.Bangkok), TempC: 33.4, FeelsLikeC: 39.1, UVIndex: 7, RainProbPct: 20, RainMMPerHr: 0.4,
		HumidityPct: 68, WindKPH: 11, Condition: "PARTLY_CLOUDY", ConditionText: "มีเมฆบางส่วน"}
	if !h.Time.Equal(want.Time) || h.Time.Location() != domain.Bangkok {
		t.Errorf("time = %v", h.Time)
	}
	h.Time = want.Time
	if h != want {
		t.Errorf("hour = %+v\nwant  %+v", h, want)
	}
	if got.Now != got.Hours[0] {
		t.Errorf("now = %+v, want the first forecast hour", got.Now)
	}
	if !got.Sunset.Equal(time.Date(2026, 9, 29, 18, 12, 0, 0, domain.Bangkok)) {
		t.Errorf("sunset = %v", got.Sunset)
	}
}

type failingOutlook struct{}

func (failingOutlook) Name() string { return "broken" }
func (failingOutlook) Outlook(context.Context, domain.LatLng, time.Time, domain.Lang) (domain.Outlook, error) {
	return domain.Outlook{}, errors.New("down")
}

func TestOutlookFallbackUsesScenario(t *testing.T) {
	from := time.Date(2026, 9, 29, 13, 30, 0, 0, domain.Bangkok)
	got, err := OutlookFallback{Primary: failingOutlook{}, Fallback: scenario.Outlook{}}.Outlook(context.Background(), scenario.Home.Point(), from, domain.LangTH)
	if err != nil || len(got.Hours) != 12 {
		t.Fatalf("got %d hours, err %v", len(got.Hours), err)
	}
	if len(got.Sources) != 1 || got.Sources[0] != (scenario.Outlook{}).Name() {
		t.Errorf("sources = %v", got.Sources)
	}
}
