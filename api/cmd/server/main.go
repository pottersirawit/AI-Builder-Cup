// Command server runs the ฝนตกไหม API.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
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
	"github.com/pottersirawit/fontokmai/api/internal/geocode"
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
	landmarksPath := flag.String("landmarks", env("LANDMARKS_PATH", ""), "path to bkk_landmarks.json")
	flag.Parse()

	path := *floodPoints
	if path == "" {
		path = findData("bkk_flood_risk_points.json")
	}
	spots, err := floodspot.Load(path)
	if err != nil {
		slog.Error("cannot load flood spots; set FLOOD_POINTS_PATH", "err", err)
		os.Exit(1)
	}
	if *landmarksPath == "" {
		*landmarksPath = findData("bkk_landmarks.json")
	}
	landmarks, err := geocode.LoadLandmarks(*landmarksPath)
	if err != nil {
		slog.Error("cannot load landmarks; set LANDMARKS_PATH", "err", err)
		os.Exit(1)
	}
	var geocoder geocode.Geocoder = geocode.Local{Landmarks: landmarks}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	store, closeStore, err := newReportStore(ctx)
	if err != nil {
		slog.Error("cannot open report store", "err", err)
		os.Exit(1)
	}
	defer closeStore()
	scen := planner.Providers{Weather: scenario.Weather{}, Routes: scenario.Routes{}, Canals: scenario.Canals{}, Reports: store}
	liveProv := scen
	if key := os.Getenv("GOOGLE_MAPS_API_KEY"); key != "" {
		liveProv.Weather = live.WeatherFallback{Primary: live.GoogleWeather{APIKey: key}, Fallback: scenario.Weather{}}
		liveProv.Routes = live.RouteFallback{Primary: live.GoogleRoutes{APIKey: key}, Fallback: scenario.Routes{}}
		geocoder = geocode.Fallback{Primary: geocode.Google{APIKey: key}, Fallback: geocoder}
	}
	liveProv.Canals = live.CanalFallback{Primary: live.ThaiWater{URL: os.Getenv("THAIWATER_URL")}, Fallback: scenario.Canals{}}

	gemini := agent.NewGeminiFromEnv(ctx)
	demo := !isFalse(os.Getenv("DEMO_MODE"))
	srv := &httpapi.Server{
		DemoMode: demo,
		Planner:  &planner.Planner{Spots: spots, Trips: scenario.Trips, Places: scenario.Places, Whereabouts: scenario.Whereabouts},
		Scenario: scen,
		Live:     liveProv,
		Gemini:   gemini,
		Users:    scenario.MockUsers(),
		Home:     homestatus.Home(scenario.HomeProfile),
		Geocoder: geocoder,
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
		"google_maps_key", os.Getenv("GOOGLE_MAPS_API_KEY") != "", "report_store", env("REPORT_STORE", "memory"), "flood_spots", len(spots), "flood_points", path, "landmarks", len(landmarks),
		"now_bangkok", time.Now().In(domain.Bangkok).Format(time.RFC3339))
	if err := httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}

// newReportStore picks REPORT_STORE: "memory" (default) or "firestore"
// (collection FIRESTORE_COLLECTION in GOOGLE_CLOUD_PROJECT or the detected
// project). Both start with the scenario's seeded reports; Firestore seeds by
// fixed ID, so restarts do not duplicate them.
func newReportStore(ctx context.Context) (domain.ReportStore, func(), error) {
	switch kind := strings.ToLower(env("REPORT_STORE", "memory")); kind {
	case "memory":
		return reports.NewMemoryStore(scenario.SeedReports()...), func() {}, nil
	case "firestore":
		fs, err := reports.NewFirestoreStore(ctx, os.Getenv("GOOGLE_CLOUD_PROJECT"), env("FIRESTORE_COLLECTION", "reports"))
		if err != nil {
			return nil, nil, err
		}
		seedCtx, cancel := context.WithTimeout(ctx, 20*time.Second)
		defer cancel()
		for _, r := range scenario.SeedReports() {
			if _, err := fs.Add(seedCtx, r); err != nil {
				fs.Close()
				return nil, nil, fmt.Errorf("seed reports: %w", err)
			}
		}
		return fs, func() { _ = fs.Close() }, nil
	default:
		return nil, nil, fmt.Errorf("REPORT_STORE=%q: want memory or firestore", kind)
	}
}

// findData looks for a data file next to the binary's working directory first
// (Docker image), then in the repo layout (go run from api/ or from the repo root).
func findData(name string) string {
	for _, dir := range []string{"data", "../data", "/app/data"} {
		if p := dir + "/" + name; fileExists(p) {
			return p
		}
	}
	return "data/" + name
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
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
