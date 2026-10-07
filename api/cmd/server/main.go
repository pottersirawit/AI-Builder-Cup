// Command server runs the ฝนตกไหม API.
package main

import (
	"context"
	"errors"
	"flag"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/homestatus"
	"github.com/pottersirawit/fontokmai/api/internal/httpapi"
	"github.com/pottersirawit/fontokmai/api/internal/live"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
	"github.com/pottersirawit/fontokmai/api/internal/reports"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	floodPoints := flag.String("flood-points", env("FLOOD_POINTS_PATH", ""), "path to bkk_flood_risk_points.json")
	flag.Parse()

	path := *floodPoints
	if path == "" {
		path = findFloodPoints()
	}
	spots, err := floodspot.Load(path)
	if err != nil {
		slog.Error("cannot load flood spots; set FLOOD_POINTS_PATH", "err", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	store := reports.NewMemoryStore(scenario.SeedReports()...)
	scen := planner.Providers{Weather: scenario.Weather{}, Routes: scenario.Routes{}, Canals: scenario.Canals{}, Reports: store}
	liveProv := scen
	if key := os.Getenv("GOOGLE_MAPS_API_KEY"); key != "" {
		liveProv.Weather = live.WeatherFallback{Primary: live.GoogleWeather{APIKey: key}, Fallback: scenario.Weather{}}
		liveProv.Routes = live.RouteFallback{Primary: live.GoogleRoutes{APIKey: key}, Fallback: scenario.Routes{}}
	}
	liveProv.Canals = live.CanalFallback{Primary: live.ThaiWater{URL: os.Getenv("THAIWATER_URL")}, Fallback: scenario.Canals{}}

	gemini := agent.NewGeminiFromEnv(ctx)
	demo := !isFalse(os.Getenv("DEMO_MODE"))
	srv := &httpapi.Server{
		DemoMode: demo,
		Planner:  &planner.Planner{Spots: spots, Trips: scenario.Trips},
		Scenario: scen,
		Live:     liveProv,
		Gemini:   gemini,
		Users:    scenario.MockUsers(),
		Home:     homestatus.Home(scenario.HomeProfile),
	}

	addr := ":" + env("PORT", "8080")
	httpServer := &http.Server{Addr: addr, Handler: srv.Handler(), ReadHeaderTimeout: 10 * time.Second}
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = httpServer.Shutdown(shutdown)
	}()
	slog.Info("ฝนตกไหม API listening", "addr", addr, "demo_mode", demo, "gemini", gemini.Available(),
		"google_maps_key", os.Getenv("GOOGLE_MAPS_API_KEY") != "", "flood_spots", len(spots), "flood_points", path,
		"now_bangkok", time.Now().In(domain.Bangkok).Format(time.RFC3339))
	if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}

// findFloodPoints looks next to the binary's working directory first (Docker
// image), then in the repo layout (go run from api/ or from the repo root).
func findFloodPoints() string {
	for _, p := range []string{"data/bkk_flood_risk_points.json", "../data/bkk_flood_risk_points.json", "/app/data/bkk_flood_risk_points.json"} {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return "data/bkk_flood_risk_points.json"
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func isFalse(v string) bool {
	switch strings.ToLower(strings.TrimSpace(v)) {
	case "0", "false", "no", "off":
		return true
	}
	return false
}
