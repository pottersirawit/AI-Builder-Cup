// Package httpapi serves API contract v0 (docs/plan/merged-flow.md).
package httpapi

import (
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/clock"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/homestatus"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
	"github.com/pottersirawit/fontokmai/api/internal/reports"
	"github.com/pottersirawit/fontokmai/api/internal/vision"
)

type Server struct {
	// DemoMode replays the scenario when no X-Demo-Clock header is sent.
	DemoMode bool
	Planner  *planner.Planner
	// Scenario is used whenever the request is on the demo clock; Live otherwise.
	Scenario planner.Providers
	Live     planner.Providers
	Gemini   *agent.Gemini
	Users    []domain.MockUser
	Home     homestatus.Home
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
	})
	mux.HandleFunc("GET /v1/trips", s.withClock(s.trips))
	mux.HandleFunc("GET /v1/places", s.withClock(s.places))
	mux.HandleFunc("POST /v1/decide", s.withClock(s.decide))
	mux.HandleFunc("POST /v1/reports", s.withClock(s.createReport))
	mux.HandleFunc("GET /v1/reports", s.withClock(s.listReports))
	mux.HandleFunc("GET /v1/home-status", s.withClock(s.homeStatus))
	return cors(logRequests(mux))
}

// reqCtx is what every handler needs about the request's moment in time.
type reqCtx struct {
	now  time.Time
	prov planner.Providers
}

func (s *Server) withClock(h func(http.ResponseWriter, *http.Request, reqCtx)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		c, demo, err := clock.FromRequest(r, s.DemoMode)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		prov := s.Live
		if demo {
			prov = s.Scenario
		}
		h(w, r, reqCtx{now: c.Now(), prov: prov})
	}
}

func (s *Server) trips(w http.ResponseWriter, r *http.Request, rc reqCtx) {
	writeJSON(w, http.StatusOK, map[string]any{"trips": s.Planner.Trips(rc.now)})
}

// places lists the saved places a question can name, and which one the user
// is at now (the origin of an ad-hoc trip).
func (s *Server) places(w http.ResponseWriter, r *http.Request, rc reqCtx) {
	current := ""
	if s.Planner.Whereabouts != nil {
		current = s.Planner.Whereabouts(rc.now)
	}
	places := s.Planner.Places
	if places == nil {
		places = []domain.SavedPlace{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"places": places, "current_place_id": current})
}

func (s *Server) decide(w http.ResponseWriter, r *http.Request, rc reqCtx) {
	var req agent.Request
	if err := json.NewDecoder(io.LimitReader(r.Body, 64<<10)).Decode(&req); err != nil && !errors.Is(err, io.EOF) {
		writeError(w, http.StatusBadRequest, "invalid JSON body: "+err.Error())
		return
	}
	sess, err := s.Planner.NewSession(r.Context(), rc.prov, rc.now, req.TripID)
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	sources := []string{rc.prov.Weather.Name(), rc.prov.Routes.Name(), rc.prov.Canals.Name(), "BMA flood spots"}
	resp, err := agent.Decide(r.Context(), s.Gemini, sess, req, sources)
	switch {
	case errors.Is(err, agent.ErrBadRequest):
		writeError(w, http.StatusBadRequest, err.Error())
	case err != nil:
		slog.Error("decide failed", "err", err)
		writeError(w, http.StatusBadGateway, err.Error())
	default:
		writeJSON(w, http.StatusOK, resp)
	}
}

type reportResponse struct {
	domain.Report
	NotifiedUsers        int `json:"notified_users"`
	CorroboratingReports int `json:"corroborating_reports"`
}

func (s *Server) createReport(w http.ResponseWriter, r *http.Request, rc reqCtx) {
	if err := r.ParseMultipartForm(12 << 20); err != nil {
		writeError(w, http.StatusBadRequest, "want multipart/form-data with photo, lat, lng: "+err.Error())
		return
	}
	lat, err1 := strconv.ParseFloat(r.FormValue("lat"), 64)
	lng, err2 := strconv.ParseFloat(r.FormValue("lng"), 64)
	if err1 != nil || err2 != nil || lat < -90 || lat > 90 || lng < -180 || lng > 180 {
		writeError(w, http.StatusBadRequest, "lat and lng are required numbers")
		return
	}
	file, header, err := r.FormFile("photo")
	if err != nil {
		writeError(w, http.StatusBadRequest, "photo is required")
		return
	}
	defer file.Close()
	photo, err := io.ReadAll(io.LimitReader(file, 10<<20))
	if err != nil {
		writeError(w, http.StatusBadRequest, "cannot read photo")
		return
	}
	mime := header.Header.Get("Content-Type")
	if mime == "" || mime == "application/octet-stream" {
		mime = http.DetectContentType(photo)
	}

	point := domain.LatLng{Lat: lat, Lng: lng}
	earlier, err := rc.prov.Reports.Near(r.Context(), point, reports.NotifyRadiusM, rc.now.Add(-30*time.Minute), rc.now)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	assessment, by := vision.Assess(r.Context(), s.Gemini, photo, mime)
	assessment.Lat, assessment.Lng, assessment.CreatedAt, assessment.GeneratedBy = lat, lng, rc.now, by
	saved, err := rc.prov.Reports.Add(r.Context(), assessment)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, reportResponse{
		Report:               saved,
		NotifiedUsers:        reports.NotifiedUsers(s.Users, point),
		CorroboratingReports: len(earlier),
	})
}

func (s *Server) listReports(w http.ResponseWriter, r *http.Request, rc reqCtx) {
	q := r.URL.Query()
	center, radius := domain.LatLng{Lat: 13.7563, Lng: 100.5018}, 60000.0
	if q.Get("lat") != "" || q.Get("lng") != "" {
		lat, err1 := strconv.ParseFloat(q.Get("lat"), 64)
		lng, err2 := strconv.ParseFloat(q.Get("lng"), 64)
		if err1 != nil || err2 != nil {
			writeError(w, http.StatusBadRequest, "lat and lng must be numbers")
			return
		}
		center, radius = domain.LatLng{Lat: lat, Lng: lng}, 1000
	}
	if v := q.Get("radius_m"); v != "" {
		rm, err := strconv.ParseFloat(v, 64)
		if err != nil || rm <= 0 {
			writeError(w, http.StatusBadRequest, "radius_m must be a positive number")
			return
		}
		radius = rm
	}
	reps, err := rc.prov.Reports.Near(r.Context(), center, radius, rc.now.Add(-24*time.Hour), rc.now)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if reps == nil {
		reps = []domain.Report{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"reports": reps})
}

func (s *Server) homeStatus(w http.ResponseWriter, r *http.Request, rc reqCtx) {
	ctx, home := r.Context(), s.Home.Place.Point()
	canals, err := rc.prov.Canals.Canals(ctx, home, rc.now)
	if err != nil || len(canals) == 0 {
		writeError(w, http.StatusBadGateway, "no canal data")
		return
	}
	midnight := time.Date(rc.now.Year(), rc.now.Month(), rc.now.Day(), 0, 0, 0, 0, domain.Bangkok)
	rain, err := rc.prov.Weather.Rain(ctx, home, midnight, rc.now)
	if err != nil {
		rain = nil
	}
	nearby, err := rc.prov.Reports.Near(ctx, home, 500, rc.now.Add(-time.Hour), rc.now)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, homestatus.Evaluate(homestatus.Input{
		Now: rc.now, Home: s.Home, Canal: canals[0], Rain: rain, NearbyReports: len(nearby),
		Sources: []string{rc.prov.Canals.Name(), rc.prov.Weather.Name(), "รายงานผู้ใช้"},
	}))
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("Access-Control-Allow-Origin", "*")
		h.Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		h.Set("Access-Control-Allow-Headers", "Content-Type, Authorization, "+clock.Header)
		h.Set("Access-Control-Max-Age", "3600")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		slog.Info("request", "method", r.Method, "path", r.URL.Path, "status", rec.status,
			"ms", time.Since(start).Milliseconds(), "demo_clock", r.Header.Get(clock.Header))
	})
}
