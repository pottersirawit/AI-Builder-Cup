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
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/advise"
	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/geocode"
	"github.com/pottersirawit/fontokmai/api/internal/homestatus"
	"github.com/pottersirawit/fontokmai/api/internal/httpapi"
	"github.com/pottersirawit/fontokmai/api/internal/jobs"
	"github.com/pottersirawit/fontokmai/api/internal/live"
	"github.com/pottersirawit/fontokmai/api/internal/notify"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
	"github.com/pottersirawit/fontokmai/api/internal/reports"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
	"github.com/pottersirawit/fontokmai/api/internal/users"
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
	bmaFloodScen := scenario.BMAFlood{}
	bmaTidalScen := scenario.BMATidal{}
	wnScen := scenario.WeatherNext{}
	scen := planner.Providers{
		Weather:     scenario.Weather{},
		Routes:      scenario.Routes{},
		Canals:      scenario.Canals{},
		Reports:     store,
		WeatherNext: wnScen,
		BMAFlood:    bmaFloodScen,
		BMATidal:    bmaTidalScen,
		Hotlines:    scenario.DirectoryHotlines{},
		Outlook:     scenario.Outlook{},
	}
	liveProv := scen
	if key := os.Getenv("GOOGLE_MAPS_API_KEY"); key != "" {
		liveProv.Weather = live.WeatherFallback{Primary: live.GoogleWeather{APIKey: key}, Fallback: scenario.Weather{}}
		liveProv.Outlook = live.OutlookFallback{Primary: live.GoogleWeather{APIKey: key}, Fallback: scenario.Outlook{}}
		liveProv.Routes = live.RouteFallback{Primary: live.GoogleRoutes{APIKey: key}, Fallback: scenario.Routes{}}
		geocoder = geocode.Fallback{Primary: geocode.Google{APIKey: key}, Fallback: geocoder}
	}
	liveProv.Canals = live.CanalFallback{Primary: live.ThaiWater{URL: os.Getenv("THAIWATER_URL")}, Fallback: scenario.Canals{}}
	liveProv.BMAFlood = live.RoadFloodFallback{
		Primary:  live.NewBMARoadFloodFetcher(os.Getenv("BMA_FLOOD_URL"), nil, 3*time.Minute),
		Fallback: bmaFloodScen,
	}
	liveProv.BMATidal = live.TidalFallback{
		Primary:  live.NewBMATidalFetcher(os.Getenv("BMA_TIDE_URL"), nil, 15*time.Minute),
		Fallback: bmaTidalScen,
	}

	// BigQuery WeatherNext 3 Fetcher with 6-hour in-memory cache
	bqFetcher, bqErr := live.NewBigQueryWeatherNextFetcher(ctx, os.Getenv("GOOGLE_CLOUD_PROJECT"))
	if bqErr != nil {
		slog.Warn("cannot init BigQuery WeatherNext fetcher, using scenario fallback", "err", bqErr)
		liveProv.WeatherNext = wnScen
	} else {
		wnCache := live.NewWeatherNextCache(bqFetcher, 6*time.Hour)
		go func() {
			warmCtx, warmCancel := context.WithTimeout(context.Background(), 25*time.Second)
			defer warmCancel()
			if err := wnCache.Refresh(warmCtx, false); err != nil {
				slog.Warn("initial WeatherNext cache warm failed", "err", err)
			} else {
				slog.Info("WeatherNext 3 6-hour cache warmed successfully from BigQuery")
			}
		}()
		liveProv.WeatherNext = live.WeatherNextFallback{Primary: wnCache, Fallback: wnScen}
	}

	gemini := agent.NewGeminiFromEnv(ctx)
	demo := !isFalse(os.Getenv("DEMO_MODE"))

	userStore := users.NewMemoryUserStore()
	logNotifier := &notify.LogNotifier{}
	plannerInst := &planner.Planner{Spots: spots, Trips: scenario.Trips, Places: scenario.Places, Whereabouts: scenario.Whereabouts}
	evaluator := &advise.Evaluator{
		Planner:  plannerInst,
		Users:    userStore,
		Notifier: logNotifier,
		Gemini:   gemini,
	}
	scheduler := jobs.NewInlineScheduler(evaluator, scen)

	srv := &httpapi.Server{
		DemoMode:   demo,
		Planner:    plannerInst,
		Scenario:   scen,
		Live:       liveProv,
		Gemini:     gemini,
		Users:      scenario.MockUsers(),
		Home:       homestatus.Home(scenario.HomeProfile),
		Geocoder:   geocoder,
		UserStore:  userStore,
		Evaluator:  evaluator,
		Scheduler:  scheduler,
		Internal:   internalAuthFromEnv(),
		IngestOpen: os.Getenv("INGEST_OPEN") == "1",
		Limits: httpapi.Limits{
			DecideRPM:        envInt("RATE_DECIDE_PER_MIN", 0),
			PlacesRPM:        envInt("RATE_PLACES_PER_MIN", 0),
			MaxBodyBytes:     int64(envInt("MAX_BODY_BYTES", 0)),
			MaxQuestionRunes: envInt("MAX_QUESTION_RUNES", 0),
		},
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

// internalAuthFromEnv guards /internal/* and /v1/ingest: INTERNAL_TOKEN (shared
// secret header X-Internal-Token) and/or TASKS_INVOKER_SA plus the optional
// comma-separated INTERNAL_ALLOWED_SA (OIDC token emails from Cloud Tasks and
// Pub/Sub push). INTERNAL_AUDIENCE pins the OIDC audience.
func internalAuthFromEnv() httpapi.InternalAuth {
	auth := httpapi.InternalAuth{Token: os.Getenv("INTERNAL_TOKEN"), Audience: os.Getenv("INTERNAL_AUDIENCE")}
	for _, v := range append([]string{os.Getenv("TASKS_INVOKER_SA")}, strings.Split(os.Getenv("INTERNAL_ALLOWED_SA"), ",")...) {
		if v = strings.TrimSpace(v); v != "" {
			auth.AllowedSAs = append(auth.AllowedSAs, v)
		}
	}
	return auth
}

// envInt reads a positive integer; anything else gives def (0 means "use the default").
func envInt(key string, def int) int {
	if n, err := strconv.Atoi(strings.TrimSpace(os.Getenv(key))); err == nil && n > 0 {
		return n
	}
	return def
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
