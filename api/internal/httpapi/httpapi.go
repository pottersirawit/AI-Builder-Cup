// Package httpapi serves the API contract (v0 plus the additive v1) in docs/plan/merged-flow.md.
package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/clock"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/extract"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
	"github.com/pottersirawit/fontokmai/api/internal/geocode"
	"github.com/pottersirawit/fontokmai/api/internal/homestatus"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
	"github.com/pottersirawit/fontokmai/api/internal/reports"
	"github.com/pottersirawit/fontokmai/api/internal/resolve"
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
	// Home is the demo user's home: /v1/home-status without a point, and the
	// profile (doorstep height, parking) used for points near it.
	Home homestatus.Home
	// Geocoder answers place search and reverse geocoding, and the candidates
	// of a needs_place answer.
	Geocoder geocode.Geocoder
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
	mux.HandleFunc("GET /v1/places/search", s.searchPlaces)
	mux.HandleFunc("GET /v1/places/reverse", s.reversePlace)
	mux.HandleFunc("POST /v1/ingest", s.withClock(s.ingest))
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
	tripReq, err := req.TripRequest()
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	sess, err := s.Planner.Open(r.Context(), rc.prov, rc.now, tripReq)
	if errors.Is(err, planner.ErrBadTrip) {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	sources := []string{rc.prov.Weather.Name(), rc.prov.Routes.Name(), rc.prov.Canals.Name(), "BMA flood spots"}
	resp, err := agent.Decide(r.Context(), s.Gemini, sess, req, sources)
	var needs *agent.NeedsPlace
	switch {
	case errors.As(err, &needs):
		writeJSON(w, http.StatusOK, map[string]any{"needs_place": s.needsPlace(r.Context(), needs)})
	case errors.Is(err, agent.ErrBadRequest), errors.Is(err, planner.ErrBadTrip):
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

type needsPlaceResponse struct {
	QueryTH    string          `json:"query_th"`
	Kind       string          `json:"kind,omitempty"`
	Candidates []geocode.Place `json:"candidates"`
}

// needsPlace offers search results for a named place; a missing home or work
// has no useful search ("บ้าน"), so the app offers GPS and search instead.
func (s *Server) needsPlace(ctx context.Context, n *agent.NeedsPlace) needsPlaceResponse {
	out := needsPlaceResponse{QueryTH: n.QueryTH, Kind: n.Kind, Candidates: []geocode.Place{}}
	if n.Kind == "" && s.Geocoder != nil {
		if found, err := s.Geocoder.Search(ctx, n.QueryTH); err == nil && found != nil {
			out.Candidates = found
		}
	}
	return out
}

// point reads lat and lng from the query. ok is false when neither is given.
func point(q url.Values) (p domain.LatLng, ok bool, err error) {
	if q.Get("lat") == "" && q.Get("lng") == "" {
		return p, false, nil
	}
	lat, err1 := strconv.ParseFloat(q.Get("lat"), 64)
	lng, err2 := strconv.ParseFloat(q.Get("lng"), 64)
	if err1 != nil || err2 != nil || lat < -90 || lat > 90 || lng < -180 || lng > 180 {
		return p, true, errors.New("lat and lng must both be numbers")
	}
	return domain.LatLng{Lat: lat, Lng: lng}, true, nil
}

// demoHomeM is how close a point must be to the demo home to replay its
// scenario profile (doorstep height, parking, sandbag point).
const demoHomeM = 300

func (s *Server) homeStatus(w http.ResponseWriter, r *http.Request, rc reqCtx) {
	home := s.Home
	at, given, err := point(r.URL.Query())
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if given {
		place := domain.Place{NameTH: r.URL.Query().Get("name_th"), Lat: at.Lat, Lng: at.Lng}
		if place.NameTH == "" {
			place.NameTH = "บ้าน"
		}
		if geo.HaversineM(at, s.Home.Place.Point()) > demoHomeM {
			home = homestatus.Home{}
		}
		home.Place = place
	}
	ctx, p := r.Context(), home.Place.Point()
	canals, err := rc.prov.Canals.Canals(ctx, p, rc.now)
	if err != nil {
		slog.Warn("no canal data for home status", "err", err)
		canals = nil
	}
	midnight := time.Date(rc.now.Year(), rc.now.Month(), rc.now.Day(), 0, 0, 0, 0, domain.Bangkok)
	rain, err := rc.prov.Weather.Rain(ctx, p, midnight, rc.now.Add(2*time.Hour))
	if err != nil {
		rain = nil
	}
	nearby, err := rc.prov.Reports.Near(ctx, p, 500, rc.now.Add(-time.Hour), rc.now)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, homestatus.Evaluate(homestatus.Input{
		Now: rc.now, Home: home, Canals: canals, Rain: rain, Spots: s.Planner.Spots, NearbyReports: len(nearby),
		CanalSource: rc.prov.Canals.Name(), WeatherSource: rc.prov.Weather.Name(),
	}))
}

func (s *Server) searchPlaces(w http.ResponseWriter, r *http.Request) {
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if utf8.RuneCountInString(q) < 2 {
		writeError(w, http.StatusBadRequest, "q needs at least 2 characters")
		return
	}
	found, err := s.Geocoder.Search(r.Context(), q)
	if err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	if found == nil {
		found = []geocode.Place{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"places": found})
}

func (s *Server) reversePlace(w http.ResponseWriter, r *http.Request) {
	at, given, err := point(r.URL.Query())
	if err == nil && !given {
		err = errors.New("lat and lng are required")
	}
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	addr, err := s.Geocoder.Reverse(r.Context(), at)
	if err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, addr)
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
type IngestRequest struct {
	Source    string              `json:"source"`     // calendar | gmail
	SourceRef string              `json:"source_ref"` // unique id
	Title     string              `json:"title"`
	Body      string              `json:"body"`
	Origin    *domain.Place       `json:"origin"`
	Places    []domain.SavedPlace `json:"places"`
}

type IngestResponse struct {
	Payload    extract.Payload     `json:"payload"`
	Trip       *domain.Trip        `json:"trip,omitempty"`
	NeedsPlace *resolve.NeedsPlace `json:"needs_place,omitempty"`
}

func (s *Server) ingest(w http.ResponseWriter, r *http.Request, ctx reqCtx) {
	var req IngestRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json body: "+err.Error())
		return
	}
	if req.Source == "" {
		req.Source = extract.SourceCalendar
	}

	raw := extract.RawMessage{
		Source:    req.Source,
		SourceRef: req.SourceRef,
		Title:     req.Title,
		Body:      req.Body,
	}

	payload, err := extract.Extract(r.Context(), s.Gemini, raw, ctx.now)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to extract payload: "+err.Error())
		return
	}

	if !payload.IsTrip {
		writeJSON(w, http.StatusOK, IngestResponse{Payload: payload})
		return
	}

	places := req.Places
	if places == nil {
		places = s.Planner.Places
	}

	trip, needsPlace, err := resolve.Trip(r.Context(), payload, req.Origin, places, s.Geocoder)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	resp := IngestResponse{
		Payload:    payload,
		NeedsPlace: needsPlace,
	}
	if needsPlace == nil {
		resp.Trip = &trip
	}

	writeJSON(w, http.StatusOK, resp)
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
