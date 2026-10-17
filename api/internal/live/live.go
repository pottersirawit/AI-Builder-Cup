// Package live holds the real-API providers (Google Weather, Google Routes,
// ThaiWater) and wrappers that fall back to the scenario when they fail.
package live

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"math"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

var defaultHTTP = &http.Client{Timeout: 6 * time.Second}

func getJSON(ctx context.Context, client *http.Client, req *http.Request, out any) error {
	if client == nil {
		client = defaultHTTP
	}
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s: %s: %.200s", req.URL.Host, resp.Status, body)
	}
	return json.Unmarshal(body, out)
}

// GoogleWeather calls the Google Maps Platform Weather API hourly forecast.
type GoogleWeather struct {
	APIKey  string
	BaseURL string // default https://weather.googleapis.com
	HTTP    *http.Client
}

func (GoogleWeather) Name() string { return "Google Weather API" }

func (w GoogleWeather) Rain(ctx context.Context, at domain.LatLng, from, to time.Time) ([]domain.RainSample, error) {
	if w.APIKey == "" {
		return nil, errors.New("GOOGLE_MAPS_API_KEY not set")
	}
	base := w.BaseURL
	if base == "" {
		base = "https://weather.googleapis.com"
	}
	hours := int(math.Ceil(time.Until(to).Hours())) + 1
	hours = max(1, min(hours, 240))
	q := url.Values{
		"key":                {w.APIKey},
		"location.latitude":  {strconv.FormatFloat(at.Lat, 'f', 5, 64)},
		"location.longitude": {strconv.FormatFloat(at.Lng, 'f', 5, 64)},
		"hours":              {strconv.Itoa(hours)},
		"pageSize":           {strconv.Itoa(hours)},
	}
	req, _ := http.NewRequest(http.MethodGet, base+"/v1/forecast/hours:lookup?"+q.Encode(), nil)
	var body struct {
		ForecastHours []struct {
			Interval struct {
				StartTime time.Time `json:"startTime"`
			} `json:"interval"`
			Precipitation struct {
				Probability struct {
					Percent int `json:"percent"`
				} `json:"probability"`
				Qpf struct {
					Quantity float64 `json:"quantity"`
				} `json:"qpf"`
			} `json:"precipitation"`
		} `json:"forecastHours"`
	}
	if err := getJSON(ctx, w.HTTP, req, &body); err != nil {
		return nil, err
	}
	var out []domain.RainSample
	for _, h := range body.ForecastHours {
		t := h.Interval.StartTime.In(domain.Bangkok)
		if t.Before(from.Add(-time.Hour)) || t.After(to) {
			continue
		}
		out = append(out, domain.RainSample{
			Time:    t,
			MMPerHr: h.Precipitation.Qpf.Quantity,
			ProbPct: h.Precipitation.Probability.Percent,
		})
	}
	if len(out) == 0 {
		return nil, errors.New("weather API returned no hours in range")
	}
	return out, nil
}

// GoogleRoutes calls Routes API computeRoutes (traffic aware for road modes).
type GoogleRoutes struct {
	APIKey  string
	BaseURL string // default https://routes.googleapis.com
	HTTP    *http.Client
}

func (GoogleRoutes) Name() string { return "Google Routes API" }

func (g GoogleRoutes) Route(ctx context.Context, from, to domain.LatLng, mode domain.Mode, departAt time.Time) (domain.Route, error) {
	if g.APIKey == "" {
		return domain.Route{}, errors.New("GOOGLE_MAPS_API_KEY not set")
	}
	base := g.BaseURL
	if base == "" {
		base = "https://routes.googleapis.com"
	}
	travelMode := map[domain.Mode]string{domain.ModeCar: "DRIVE", domain.ModeMoto: "TWO_WHEELER", domain.ModeTransit: "TRANSIT"}[mode]
	waypoint := func(p domain.LatLng) map[string]any {
		return map[string]any{"location": map[string]any{"latLng": map[string]float64{"latitude": p.Lat, "longitude": p.Lng}}}
	}
	reqBody := map[string]any{"origin": waypoint(from), "destination": waypoint(to), "travelMode": travelMode}
	if departAt.After(time.Now()) {
		reqBody["departureTime"] = departAt.UTC().Format(time.RFC3339)
	}
	if mode != domain.ModeTransit {
		reqBody["routingPreference"] = "TRAFFIC_AWARE"
	}
	b, _ := json.Marshal(reqBody)
	req, _ := http.NewRequest(http.MethodPost, base+"/directions/v2:computeRoutes", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Goog-Api-Key", g.APIKey)
	req.Header.Set("X-Goog-FieldMask", "routes.duration,routes.polyline.encodedPolyline,routes.description,routes.legs.steps.transitDetails")
	var body struct {
		Routes []struct {
			Duration    string `json:"duration"`
			Description string `json:"description"`
			Polyline    struct {
				EncodedPolyline string `json:"encodedPolyline"`
			} `json:"polyline"`
			Legs []struct {
				Steps []struct {
					TransitDetails *struct {
						StopCount   int `json:"stopCount"`
						StopDetails struct {
							DepartureStop struct {
								Name string `json:"name"`
							} `json:"departureStop"`
							ArrivalStop struct {
								Name string `json:"name"`
							} `json:"arrivalStop"`
						} `json:"stopDetails"`
						TransitLine struct {
							Name      string `json:"name"`
							NameShort string `json:"nameShort"`
						} `json:"transitLine"`
					} `json:"transitDetails"`
				} `json:"steps"`
			} `json:"legs"`
		} `json:"routes"`
	}
	if err := getJSON(ctx, g.HTTP, req, &body); err != nil {
		return domain.Route{}, err
	}
	if len(body.Routes) == 0 {
		return domain.Route{}, errors.New("routes API returned no route")
	}
	r := body.Routes[0]
	secs, err := strconv.ParseFloat(strings.TrimSuffix(r.Duration, "s"), 64)
	if err != nil {
		return domain.Route{}, fmt.Errorf("bad duration %q", r.Duration)
	}
	route := domain.Route{Mode: mode, Polyline: geo.DecodePolyline(r.Polyline.EncodedPolyline), DurationMin: int(math.Round(secs / 60)), Source: "Google Routes API"}
	if r.Description != "" {
		route.ViaTH = []string{r.Description}
	}
	for _, leg := range r.Legs {
		for _, step := range leg.Steps {
			td := step.TransitDetails
			if td == nil {
				continue
			}
			line := strings.TrimSpace(td.TransitLine.Name)
			if line == "" {
				line = strings.TrimSpace(td.TransitLine.NameShort)
			}
			dep := strings.TrimSpace(td.StopDetails.DepartureStop.Name)
			arr := strings.TrimSpace(td.StopDetails.ArrivalStop.Name)
			if dep != "" && arr != "" {
				route.TransitLegs = append(route.TransitLegs, domain.TransitLeg{
					LineTH:        line,
					FromStationTH: dep,
					ToStationTH:   arr,
					StopCount:     td.StopCount,
				})
				if len(route.ViaTH) == 0 || route.ViaTH[len(route.ViaTH)-1] != dep {
					route.ViaTH = append(route.ViaTH, dep)
				}
				if route.ViaTH[len(route.ViaTH)-1] != arr {
					route.ViaTH = append(route.ViaTH, arr)
				}
			}
		}
	}
	fallbackVia, fallbackLegs := scenario.DescribeRoute(from, to, mode)
	if len(route.ViaTH) == 0 {
		route.ViaTH = fallbackVia
	}
	if mode == domain.ModeTransit && len(route.TransitLegs) == 0 {
		route.TransitLegs = fallbackLegs
	}
	return route, nil
}

// ThaiWater reads the public ThaiWater (HII) water level feed and returns the
// stations nearest to a point. Rise over 2 h is not in the feed, so it is 0.
type ThaiWater struct {
	URL  string // default https://api-v3.thaiwater.net/api/v1/thaiwater30/public/waterlevel_load
	HTTP *http.Client
}

func (ThaiWater) Name() string { return "ThaiWater (HII)" }

func (tw ThaiWater) Canals(ctx context.Context, near domain.LatLng, _ time.Time) ([]domain.CanalReading, error) {
	u := tw.URL
	if u == "" {
		u = "https://api-v3.thaiwater.net/api/v1/thaiwater30/public/waterlevel_load"
	}
	req, _ := http.NewRequest(http.MethodGet, u, nil)
	var body struct {
		WaterlevelData struct {
			Data []struct {
				WaterlevelMSL json.Number `json:"waterlevel_msl"`
				Station       struct {
					ID      json.Number       `json:"id"`
					Name    map[string]string `json:"tele_station_name"`
					Lat     json.Number       `json:"tele_station_lat"`
					Lng     json.Number       `json:"tele_station_long"`
					MinBank json.Number       `json:"min_bank"`
				} `json:"station"`
			} `json:"data"`
		} `json:"waterlevel_data"`
	}
	if err := getJSON(ctx, tw.HTTP, req, &body); err != nil {
		return nil, err
	}
	var out []domain.CanalReading
	for _, d := range body.WaterlevelData.Data {
		lat, _ := d.Station.Lat.Float64()
		lng, _ := d.Station.Lng.Float64()
		level, err1 := d.WaterlevelMSL.Float64()
		bank, err2 := d.Station.MinBank.Float64()
		if err1 != nil || err2 != nil || lat == 0 {
			continue
		}
		p := domain.LatLng{Lat: lat, Lng: lng}
		if geo.HaversineM(near, p) > 15000 {
			continue
		}
		out = append(out, domain.CanalReading{StationID: d.Station.ID.String(), NameTH: d.Station.Name["th"], NameEN: d.Station.Name["en"], Lat: lat, Lng: lng,
			LevelM: level, BankM: bank, Source: "ThaiWater (HII)"})
	}
	if len(out) == 0 {
		return nil, errors.New("thaiwater returned no stations near the point")
	}
	for i := 1; i < len(out); i++ {
		for j := i; j > 0 && geo.HaversineM(near, domain.LatLng{Lat: out[j].Lat, Lng: out[j].Lng}) < geo.HaversineM(near, domain.LatLng{Lat: out[j-1].Lat, Lng: out[j-1].Lng}); j-- {
			out[j], out[j-1] = out[j-1], out[j]
		}
	}
	return out, nil
}

// Fallback wrappers: try the live provider, log and replay the scenario on error.

type WeatherFallback struct{ Primary, Fallback domain.WeatherProvider }

func (w WeatherFallback) Name() string { return w.Primary.Name() }
func (w WeatherFallback) Rain(ctx context.Context, at domain.LatLng, from, to time.Time) ([]domain.RainSample, error) {
	out, err := w.Primary.Rain(ctx, at, from, to)
	if err == nil {
		return out, nil
	}
	slog.Warn("live weather failed, using scenario", "err", err)
	return w.Fallback.Rain(ctx, at, from, to)
}

type RouteFallback struct{ Primary, Fallback domain.RouteProvider }

func (r RouteFallback) Name() string { return r.Primary.Name() }
func (r RouteFallback) Route(ctx context.Context, from, to domain.LatLng, mode domain.Mode, departAt time.Time) (domain.Route, error) {
	out, err := r.Primary.Route(ctx, from, to, mode, departAt)
	if err == nil {
		return out, nil
	}
	slog.Warn("live routes failed, using scenario", "mode", mode, "err", err)
	return r.Fallback.Route(ctx, from, to, mode, departAt)
}

type CanalFallback struct{ Primary, Fallback domain.CanalProvider }

func (c CanalFallback) Name() string { return c.Primary.Name() }
func (c CanalFallback) Canals(ctx context.Context, near domain.LatLng, at time.Time) ([]domain.CanalReading, error) {
	out, err := c.Primary.Canals(ctx, near, at)
	if err == nil {
		return out, nil
	}
	slog.Warn("live canals failed, using scenario", "err", err)
	return c.Fallback.Canals(ctx, near, at)
}

type WeatherNextFallback struct {
	Primary  domain.WeatherNextProvider
	Fallback domain.WeatherNextProvider
}

func (w WeatherNextFallback) Name() string { return w.Primary.Name() }
func (w WeatherNextFallback) PeakConditionsAlongRoute(polyline []domain.LatLng) (float64, float64, error) {
	g, t, err := w.Primary.PeakConditionsAlongRoute(polyline)
	if err == nil {
		return g, t, nil
	}
	slog.Warn("live weathernext failed, using scenario", "err", err)
	return w.Fallback.PeakConditionsAlongRoute(polyline)
}
