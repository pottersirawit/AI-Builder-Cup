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

func TestGoogleWeatherParsesHourlyForecast(t *testing.T) {
	start := time.Now().Truncate(time.Hour).UTC()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/forecast/hours:lookup" || r.URL.Query().Get("key") != "k" {
			http.Error(w, "bad request "+r.URL.String(), 400)
			return
		}
		json.NewEncoder(w).Encode(map[string]any{"forecastHours": []any{
			map[string]any{"interval": map[string]any{"startTime": start.Format(time.RFC3339)}, "precipitation": map[string]any{"qpf": map[string]any{"quantity": 0.4, "unit": "MILLIMETERS"}}},
			map[string]any{"interval": map[string]any{"startTime": start.Add(time.Hour).Format(time.RFC3339)}, "precipitation": map[string]any{"qpf": map[string]any{"quantity": 12.5}}},
		}})
	}))
	defer srv.Close()
	got, err := GoogleWeather{APIKey: "k", BaseURL: srv.URL}.Rain(context.Background(), scenario.Silom.Point(), start, start.Add(3*time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || got[1].MMPerHr != 12.5 || !got[1].Time.Equal(start.Add(time.Hour)) {
		t.Fatalf("got %+v", got)
	}
}

func TestGoogleRoutesParsesComputeRoutes(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body map[string]any
		json.NewDecoder(r.Body).Decode(&body)
		if r.Header.Get("X-Goog-Api-Key") != "k" || body["travelMode"] != "TWO_WHEELER" {
			http.Error(w, "bad request", 400)
			return
		}
		w.Write([]byte(`{"routes":[{"duration":"2730s","description":"รัชดาภิเษก","polyline":{"encodedPolyline":"_p~iF~ps|U_ulLnnqC"}}]}`))
	}))
	defer srv.Close()
	got, err := GoogleRoutes{APIKey: "k", BaseURL: srv.URL}.Route(context.Background(), scenario.Silom.Point(), scenario.Home.Point(), domain.ModeMoto, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	if got.DurationMin != 46 || len(got.Polyline) != 2 || got.ViaTH[0] != "รัชดาภิเษก" {
		t.Fatalf("got %+v", got)
	}
}

func TestThaiWaterPicksNearestStation(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"waterlevel_data":{"data":[
			{"waterlevel_msl":"0.9","station":{"id":1,"tele_station_name":{"th":"คลองแสนแสบ"},"tele_station_lat":13.747,"tele_station_long":100.564,"min_bank":1.1}},
			{"waterlevel_msl":1.62,"station":{"id":2,"tele_station_name":{"th":"คลองลาดพร้าว"},"tele_station_lat":"13.818","tele_station_long":"100.593","min_bank":"1.8"}},
			{"waterlevel_msl":null,"station":{"id":3,"tele_station_lat":13.8,"tele_station_long":100.6}},
			{"waterlevel_msl":2.0,"station":{"id":4,"tele_station_name":{"th":"เชียงใหม่"},"tele_station_lat":18.8,"tele_station_long":98.9,"min_bank":3}}
		]}}`))
	}))
	defer srv.Close()
	got, err := ThaiWater{URL: srv.URL}.Canals(context.Background(), scenario.Home.Point(), time.Now())
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || got[0].NameTH != "คลองลาดพร้าว" || got[0].LevelM != 1.62 || got[0].BankM != 1.8 {
		t.Fatalf("got %+v", got)
	}
}

type failingWeather struct{}

func (failingWeather) Name() string { return "broken" }
func (failingWeather) Rain(context.Context, domain.LatLng, time.Time, time.Time) ([]domain.RainSample, error) {
	return nil, errors.New("boom")
}

func TestFallbacksReplayTheScenario(t *testing.T) {
	ctx := context.Background()
	from := time.Date(2026, 9, 29, 18, 0, 0, 0, domain.Bangkok)
	rain, err := WeatherFallback{Primary: failingWeather{}, Fallback: scenario.Weather{}}.Rain(ctx, scenario.Silom.Point(), from, from.Add(time.Hour))
	if err != nil || len(rain) == 0 || rain[0].MMPerHr != 38 {
		t.Fatalf("weather fallback: %v %+v", err, rain)
	}
	route, err := RouteFallback{Primary: GoogleRoutes{}, Fallback: scenario.Routes{}}.Route(ctx, scenario.Silom.Point(), scenario.Home.Point(), domain.ModeCar, from)
	if err != nil || route.Source != scenario.Source {
		t.Fatalf("route fallback: %v %+v", err, route)
	}
	canals, err := CanalFallback{Primary: ThaiWater{URL: "http://127.0.0.1:1"}, Fallback: scenario.Canals{}}.Canals(ctx, scenario.Home.Point(), from)
	if err != nil || canals[0].Source != scenario.Source {
		t.Fatalf("canal fallback: %v %+v", err, canals)
	}
}

func TestGoogleRoutesParsesTransitLegs(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"routes":[{"duration":"1800s","polyline":{"encodedPolyline":"_p~iF~ps|U_ulLnnqC"},"legs":[{"steps":[
			{"transitDetails":{"stopCount":9,"stopDetails":{"departureStop":{"name":"MRT สีลม"},"arrivalStop":{"name":"MRT ลาดพร้าว"}},"transitLine":{"name":"MRT สายสีน้ำเงิน","nameShort":"BL"}}}
		]}]}]}`))
	}))
	defer srv.Close()
	got, err := GoogleRoutes{APIKey: "k", BaseURL: srv.URL}.Route(context.Background(), scenario.Silom.Point(), scenario.Home.Point(), domain.ModeTransit, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	if len(got.TransitLegs) != 1 {
		t.Fatalf("expected 1 transit leg, got %+v", got.TransitLegs)
	}
	leg := got.TransitLegs[0]
	if leg.LineTH != "MRT สายสีน้ำเงิน" || leg.FromStationTH != "MRT สีลม" || leg.ToStationTH != "MRT ลาดพร้าว" || leg.StopCount != 9 {
		t.Fatalf("got leg %+v", leg)
	}
}

func TestGoogleRoutesParsesFractionalDuration(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"routes":[{"duration":"354.5s","description":"ทางด่วน","polyline":{"encodedPolyline":"_p~iF~ps|U_ulLnnqC"}}]}`))
	}))
	defer srv.Close()
	got, err := GoogleRoutes{APIKey: "k", BaseURL: srv.URL}.Route(context.Background(), scenario.Silom.Point(), scenario.Home.Point(), domain.ModeCar, time.Now())
	if err != nil {
		t.Fatalf("unexpected error parsing fractional duration: %v", err)
	}
	// 354.5s / 60 = 5.908 min -> rounds to 6 min
	if got.DurationMin != 6 {
		t.Fatalf("got DurationMin = %d, want 6", got.DurationMin)
	}
}


