package live

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func TestGoogleWeatherDaysMapsForecastFields(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/forecast/days:lookup" || r.URL.Query().Get("days") != "10" {
			http.NotFound(w, r)
			return
		}
		w.Write([]byte(`{"forecastDays":[{
			"displayDate":{"year":2026,"month":10,"day":3},
			"daytimeForecast":{"weatherCondition":{"type":"SCATTERED_SHOWERS","description":{"text":"ฝนตกกระจาย"}},
				"precipitation":{"probability":{"percent":60},"qpf":{"quantity":4.5}},"thunderstormProbability":30,"uvIndex":9},
			"nighttimeForecast":{"weatherCondition":{"type":"CLOUDY"},
				"precipitation":{"probability":{"percent":70},"qpf":{"quantity":2}},"thunderstormProbability":10},
			"maxTemperature":{"degrees":33.2},"minTemperature":{"degrees":22.1},
			"feelsLikeMaxTemperature":{"degrees":38.9},"feelsLikeMinTemperature":{"degrees":21.4}}]}`))
	}))
	defer srv.Close()

	now := time.Date(2026, 9, 29, 16, 10, 0, 0, domain.Bangkok)
	days, err := GoogleWeather{APIKey: "k", BaseURL: srv.URL}.Days(context.Background(), scenario.Home.Point(), now, domain.LangTH)
	if err != nil {
		t.Fatal(err)
	}
	f := domain.ForecastFor(days, time.Date(2026, 10, 3, 15, 0, 0, 0, domain.Bangkok))
	if f == nil {
		t.Fatalf("no forecast for 3 Oct in %+v", days)
	}
	if f.MaxC != 33.2 || f.MinC != 22.1 || f.FeelsMaxC != 38.9 || f.FeelsMinC != 21.4 {
		t.Errorf("temperatures %+v", f)
	}
	if f.RainProbPct != 70 || f.RainMM != 6.5 || f.ThunderProbPct != 30 || f.UVIndex != 9 {
		t.Errorf("the day's wettest half and its total rain, got %+v", f)
	}
	if f.Condition != "SCATTERED_SHOWERS" || f.ConditionText != "ฝนตกกระจาย" {
		t.Errorf("condition %+v", f)
	}
}

func TestDailyFallbackUsesTheScenario(t *testing.T) {
	now := time.Date(2026, 9, 29, 16, 10, 0, 0, domain.Bangkok)
	days, err := DailyFallback{Primary: GoogleWeather{}, Fallback: scenario.Days{}}.Days(context.Background(), scenario.Home.Point(), now, domain.LangTH)
	if err != nil || len(days) != domain.DailyHorizon || domain.ForecastFor(days, now) == nil {
		t.Fatalf("got %d days, err %v", len(days), err)
	}
}
