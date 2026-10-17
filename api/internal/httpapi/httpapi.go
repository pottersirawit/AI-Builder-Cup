// Package httpapi serves the API contract (v0 plus the additive v1) in docs/plan/merged-flow.md.
package httpapi

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/pottersirawit/fontokmai/api/internal/advise"
	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/clock"
	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/extract"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
	"github.com/pottersirawit/fontokmai/api/internal/geocode"
	"github.com/pottersirawit/fontokmai/api/internal/homestatus"
	"github.com/pottersirawit/fontokmai/api/internal/jobs"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
	"github.com/pottersirawit/fontokmai/api/internal/reports"
	"github.com/pottersirawit/fontokmai/api/internal/resolve"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
	"github.com/pottersirawit/fontokmai/api/internal/users"
	"github.com/pottersirawit/fontokmai/api/internal/vision"
)

type Server struct {
	// ReportLimits bounds photo uploads; zero fields take the defaults.
	ReportLimits ReportLimits
	reportRL     uploadLimiter
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
	// Proactive pipeline components
	UserStore users.UserStore
	Evaluator *advise.Evaluator
	Scheduler jobs.Scheduler
	// Internal guards /internal/* and /v1/ingest; Limits caps the cost of the
	// public Gemini-backed endpoints. IngestOpen leaves /v1/ingest unauthenticated.
	Internal   InternalAuth
	IngestOpen bool
	Limits     Limits
	// Google is the OAuth flow's configuration; the zero value is production.
	Google GoogleOAuth
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	healthHandler := func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
	}
	mux.HandleFunc("GET /healthz", healthHandler)
	mux.HandleFunc("GET /v1/healthz", healthHandler)
	mux.HandleFunc("GET /health", healthHandler)
	mux.HandleFunc("GET /v1/health", healthHandler)
	mux.HandleFunc("GET /{$}", s.homePage)
	mux.HandleFunc("GET /privacy", s.privacyPolicy)
	mux.HandleFunc("GET /oauth2callback", s.oauth2Callback)
	mux.HandleFunc("GET /v1/oauth/start", s.oauthStart)
	mux.HandleFunc("GET /v1/oauth/status", s.oauthStatus)
	mux.HandleFunc("GET /v1/trips", s.withClock(s.trips))
	mux.HandleFunc("GET /v1/trips/sync", s.withClock(s.syncTrips))
	mux.HandleFunc("POST /v1/trips/sync", s.withClock(s.syncTrips))
	mux.HandleFunc("GET /v1/places", s.withClock(s.places))
	mux.Handle("POST /v1/decide", s.Limits.rateLimit("decide", s.Limits.decideRPM(), s.Limits.limitBody(s.withClock(s.decide))))
	mux.HandleFunc("POST /v1/reports", s.withClock(s.createReport))
	mux.HandleFunc("GET /v1/reports", s.withClock(s.listReports))
	mux.HandleFunc("GET /v1/home-status", s.withClock(s.homeStatus))
	mux.Handle("GET /v1/outlook", s.Limits.rateLimit("outlook", s.Limits.placesRPM(), s.withClock(s.outlook)))
	mux.Handle("GET /v1/places/search", s.Limits.rateLimit("places", s.Limits.placesRPM(), http.HandlerFunc(s.searchPlaces)))
	mux.Handle("GET /v1/places/reverse", s.Limits.rateLimit("places", s.Limits.placesRPM(), http.HandlerFunc(s.reversePlace)))
	ingest := s.Limits.limitBody(s.withClock(s.ingest))
	if !s.IngestOpen {
		ingest = s.Internal.require(ingest)
	}
	mux.Handle("POST /v1/ingest", ingest)
	mux.Handle("POST /internal/pubsub/raw", s.Internal.require(s.Limits.limitBody(s.withClock(s.handlePubSubRaw))))
	mux.Handle("POST /internal/tasks/check", s.Internal.require(s.Limits.limitBody(s.withClock(s.handleTaskCheck))))
	return cors(logRequests(mux))
}

// reqCtx is what every handler needs about the request's moment in time.
type reqCtx struct {
	now  time.Time
	prov planner.Providers
	lang domain.Lang
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
		h(w, r, reqCtx{now: c.Now(), prov: prov, lang: domain.LangFromRequest(r)})
	}
}

// DemoEmail is มิว's address: the only account that sees the scripted trips.
const DemoEmail = "miw.demo@gmail.com"

func requestEmail(r *http.Request) string {
	if email := r.URL.Query().Get("email"); email != "" {
		return email
	}
	return r.URL.Query().Get("uid")
}

// requestHome is the app's saved home from ?home_lat=&home_lng=&home_name=,
// unresolved when it sent none.
func requestHome(r *http.Request) domain.Place {
	q := r.URL.Query()
	lat, errLat := strconv.ParseFloat(q.Get("home_lat"), 64)
	lng, errLng := strconv.ParseFloat(q.Get("home_lng"), 64)
	if errLat != nil || errLng != nil || lat < -90 || lat > 90 || lng < -180 || lng > 180 {
		return domain.Place{}
	}
	name := strings.TrimSpace(q.Get("home_name"))
	if name == "" {
		name = "บ้าน"
	}
	return domain.Place{NameTH: name, Lat: lat, Lng: lng}
}

// isDefaultOrPlaceholderOrigin reports whether p is an unconfigured or default placeholder origin.
func isDefaultOrPlaceholderOrigin(p domain.Place) bool {
	if p.Lat == 0 && p.Lng == 0 {
		return true
	}
	if strings.Contains(p.NameTH, "ยังไม่ได้ตั้งบ้าน") {
		return true
	}
	if p.NameTH == defaultOrigin.NameTH || (p.Lat == defaultOrigin.Lat && p.Lng == defaultOrigin.Lng) {
		return true
	}
	if p.NameTH == "สีลม" && p.Lat == 13.7279 && p.Lng == 100.5281 {
		return true
	}
	return false
}

// applyHomeOrigin overrides a trip's origin with the user's saved home place
// when the trip starts from a placeholder/unconfigured origin, unless the
// trip's destination is already that home place.
func applyHomeOrigin(t domain.Trip, home domain.Place) domain.Trip {
	if home.Lat == 0 && home.Lng == 0 {
		return t
	}
	dLat := t.Destination.Lat - home.Lat
	dLng := t.Destination.Lng - home.Lng
	if dLat*dLat+dLng*dLng < 0.00001 {
		return t
	}
	if !isDefaultOrPlaceholderOrigin(t.Origin) {
		return t
	}
	t.Origin = home
	return t
}

func hasToken(email string) bool {
	tokenStoreMu.RLock()
	defer tokenStoreMu.RUnlock()
	_, ok := tokenStore[email]
	return ok
}

// userTrips returns a real account's stored trips, never มิว's scenario: that
// is only for an empty email or DemoEmail. The X-Demo-Clock header replays the
// storm's weather, not มิว's calendar.
func (s *Server) userTrips(r *http.Request, rc reqCtx, email string) []domain.Trip {
	trips := []domain.Trip{}
	homePlace := requestHome(r)
	hasHome := homePlace.Lat != 0 || homePlace.Lng != 0
	if s.UserStore != nil && email != "" {
		if uTrips, err := s.UserStore.ListTrips(r.Context(), email); err == nil {
			for _, ut := range uTrips {
				t := ut.Trip
				if hasHome {
					t = applyHomeOrigin(t, homePlace)
					if t.Origin != ut.Trip.Origin {
						ut.Trip = t
						_ = s.UserStore.UpsertTrip(r.Context(), ut)
					}
				}
				trips = append(trips, t)
			}
			trips = DeduplicateTrips(trips)
			sort.SliceStable(trips, func(i, j int) bool {
				if trips[i].ArriveBy.IsZero() {
					return false
				}
				if trips[j].ArriveBy.IsZero() {
					return true
				}
				return trips[i].ArriveBy.Before(trips[j].ArriveBy)
			})
		}
	}
	if len(trips) == 0 && (email == "" || email == DemoEmail) && s.Planner != nil && s.Planner.Trips != nil {
		trips = s.Planner.Trips(rc.now)
	}
	if rc.lang == domain.LangEN {
		for i, t := range trips {
			trips[i] = scenario.LocalizeTrip(t, rc.lang)
		}
	}
	return trips
}

func (s *Server) trips(w http.ResponseWriter, r *http.Request, rc reqCtx) {
	email := requestEmail(r)
	writeJSON(w, http.StatusOK, map[string]any{
		"trips":     s.userTrips(r, rc, email),
		"connected": hasToken(email),
	})
}

func (s *Server) syncTrips(w http.ResponseWriter, r *http.Request, rc reqCtx) {
	email := requestEmail(r)

	accessToken, connected := s.accessToken(r.Context(), email)
	if connected {
		s.syncAndRecord(r.Context(), email, accessToken, requestHome(r), rc.now)
	}

	trips := s.userTrips(r, rc, email)
	writeJSON(w, http.StatusOK, map[string]any{
		"synced":    true,
		"email":     email,
		"connected": connected,
		"count":     len(trips),
		"trips":     trips,
	})
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
	if rc.lang == domain.LangEN {
		places = append([]domain.SavedPlace(nil), places...)
		for i := range places {
			places[i].LabelTH = places[i].LabelFor(rc.lang)
			places[i].Place = scenario.LocalizePlace(places[i].Place, rc.lang)
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"places": places, "current_place_id": current})
}

func (s *Server) decide(w http.ResponseWriter, r *http.Request, rc reqCtx) {
	var req agent.Request
	if err := json.NewDecoder(io.LimitReader(r.Body, 64<<10)).Decode(&req); err != nil && !errors.Is(err, io.EOF) {
		writeError(w, http.StatusBadRequest, "invalid JSON body: "+err.Error())
		return
	}
	if utf8.RuneCountInString(req.QuestionTH) > s.Limits.maxQuestion() {
		writeError(w, http.StatusBadRequest, "question_th is too long")
		return
	}
	tripReq, err := req.TripRequestFor(rc.lang)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if tripReq.Trip != nil {
		if tripReq.Origin != nil && (tripReq.Origin.Lat != 0 || tripReq.Origin.Lng != 0) {
			tripReq.Trip.Origin = *tripReq.Origin
		}
		if s.UserStore != nil {
			email := req.Email
			if email == "" {
				email = r.URL.Query().Get("email")
			}
			if email != "" {
				_ = s.UserStore.UpsertTrip(r.Context(), users.UserTrip{
					UID:       email,
					Trip:      *tripReq.Trip,
					UpdatedAt: time.Now(),
				})
			}
		}
	} else if tripReq.Trip == nil && tripReq.TripID != "" && s.UserStore != nil {
		if ut, err := s.UserStore.FindTripByID(r.Context(), tripReq.TripID); err == nil {
			t := ut.Trip
			if tripReq.Origin != nil && (tripReq.Origin.Lat != 0 || tripReq.Origin.Lng != 0) {
				t.Origin = *tripReq.Origin
			}
			tripReq.Trip = &t
		}
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
	resp, err := agent.Decide(r.Context(), s.Gemini, sess, req, nil)
	var needs *agent.NeedsPlace
	var activity *agent.NeedsActivity
	switch {
	case errors.As(err, &needs):
		writeJSON(w, http.StatusOK, map[string]any{"needs_place": s.needsPlace(r.Context(), needs)})
	case errors.As(err, &activity):
		writeJSON(w, http.StatusOK, map[string]any{"activity": activity.Plan})
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
	lim := s.ReportLimits.withDefaults()
	if !s.reportRL.allow(clientIP(r), time.Now(), lim.Uploads, lim.Window) {
		writeError(w, http.StatusTooManyRequests, "too many photo uploads, try again later")
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, lim.MaxUploadBytes+(1<<20))
	if err := r.ParseMultipartForm(8 << 20); err != nil {
		var tooBig *http.MaxBytesError
		if errors.As(err, &tooBig) {
			writeError(w, http.StatusRequestEntityTooLarge, "photo too large")
			return
		}
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
	photo, err := io.ReadAll(io.LimitReader(file, lim.MaxUploadBytes+1))
	if err != nil {
		writeError(w, http.StatusBadRequest, "cannot read photo")
		return
	}
	if int64(len(photo)) > lim.MaxUploadBytes {
		writeError(w, http.StatusRequestEntityTooLarge, "photo too large")
		return
	}
	if err := checkDimensions(photo, lim.MaxDimension); err != nil {
		writeError(w, http.StatusRequestEntityTooLarge, "photo dimensions too large")
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
	assessment, by := vision.Assess(r.Context(), s.Gemini, photo, mime, rc.lang)
	if by == vision.GeneratedByRejected {
		writeError(w, http.StatusBadRequest, assessment.DescriptionTH)
		return
	}
	assessment.Lat, assessment.Lng, assessment.CreatedAt, assessment.GeneratedBy = lat, lng, rc.now, by
	// Only a real Gemini reading of a flood photo is evidence; the fallback
	// and rejected assessments go back to the caller but are never stored.
	saved := assessment
	if vision.IsEvidence(by) {
		saved, err = rc.prov.Reports.Add(r.Context(), assessment)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
	}
	corroborating := 0
	for _, e := range earlier {
		if decision.UsableReport(e) {
			corroborating++
		}
	}
	writeJSON(w, http.StatusCreated, reportResponse{
		Report:               saved,
		NotifiedUsers:        reports.NotifiedUsers(s.Users, point),
		CorroboratingReports: corroborating,
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
	usable := []domain.Report{}
	for _, rep := range reps {
		if decision.UsableReport(rep) {
			usable = append(usable, rep)
		}
	}
	reps = usable
	for i := range reps {
		reps[i] = scenario.LocalizeReport(reps[i], rc.lang)
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
			place.NameTH = rc.lang.Pick("บ้าน", "Home")
		}
		if geo.HaversineM(at, s.Home.Place.Point()) > demoHomeM {
			home = homestatus.Home{}
		}
		home.Place = place
	}
	ctx, p := r.Context(), home.Place.Point()
	var canals []domain.CanalReading
	var canalSource string
	if rc.prov.Canals != nil {
		canalSource = rc.prov.Canals.Name()
		var err error
		canals, err = rc.prov.Canals.Canals(ctx, p, rc.now)
		if err != nil {
			slog.Warn("no canal data for home status", "err", err)
			canals = nil
		}
	}
	midnight := time.Date(rc.now.Year(), rc.now.Month(), rc.now.Day(), 0, 0, 0, 0, domain.Bangkok)
	var rain []domain.RainSample
	var weatherSource string
	if rc.prov.Weather != nil {
		weatherSource = rc.prov.Weather.Name()
		var err error
		rain, err = rc.prov.Weather.Rain(ctx, p, midnight, rc.now.Add(2*time.Hour))
		if err != nil {
			rain = nil
		}
	}
	nearbyCount := 0
	if rc.prov.Reports != nil {
		nearby, err := rc.prov.Reports.Near(ctx, p, 500, rc.now.Add(-time.Hour), rc.now)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		nearbyCount = len(nearby)
	}
	var spots []floodspot.Spot
	if s.Planner != nil {
		spots = s.Planner.Spots
	}
	status := homestatus.Evaluate(homestatus.Input{
		Lang: rc.lang, Now: rc.now, Home: home, Canals: canals, Rain: rain, Spots: spots, NearbyReports: nearbyCount,
		CanalSource: canalSource, WeatherSource: weatherSource,
	})
	status.Place = scenario.LocalizePlace(status.Place, rc.lang)
	writeJSON(w, http.StatusOK, status)
}

// outlook is the next hours of weather at a point (the demo home by default),
// for the app's what-to-carry line.
func (s *Server) outlook(w http.ResponseWriter, r *http.Request, rc reqCtx) {
	at, given, err := point(r.URL.Query())
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if !given {
		at = s.Home.Place.Point()
	}
	var prov domain.OutlookProvider = scenario.Outlook{}
	if rc.prov.Outlook != nil {
		prov = rc.prov.Outlook
	}
	out, err := prov.Outlook(r.Context(), at, rc.now, rc.lang)
	if err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) searchPlaces(w http.ResponseWriter, r *http.Request) {
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if utf8.RuneCountInString(q) < 2 {
		writeError(w, http.StatusBadRequest, "q needs at least 2 characters")
		return
	}
	found, err := s.Geocoder.Search(geocode.WithLang(r.Context(), domain.LangFromRequest(r)), q)
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
	addr, err := s.Geocoder.Reverse(geocode.WithLang(r.Context(), domain.LangFromRequest(r)), at)
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
	UID       string              `json:"uid"`        // user ID for server-side state
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
		// Upsert into user store if user store is configured and UID is present
		if s.UserStore != nil && req.UID != "" {
			_ = s.UserStore.UpsertTrip(r.Context(), users.UserTrip{
				UID:    req.UID,
				Trip:   trip,
				Places: places,
			})
			// Schedule proactive check at T-45 before departure/arrival if scheduler available
			if s.Scheduler != nil {
				target := trip.ArriveBy
				if target.IsZero() {
					target = ctx.now.Add(2 * time.Hour)
				}
				runAt := target.Add(-45 * time.Minute)
				if runAt.Before(ctx.now) {
					runAt = ctx.now
				}
				_ = s.Scheduler.ScheduleCheck(r.Context(), req.UID, trip.ID, runAt)
			}
		}
	}

	writeJSON(w, http.StatusOK, resp)
}

// PubSubMessage wraps Google Cloud Pub/Sub push notification payload.
type PubSubMessage struct {
	Message struct {
		Data        string            `json:"data"`
		Attributes  map[string]string `json:"attributes"`
		MessageID   string            `json:"messageId"`
		PublishTime string            `json:"publishTime"`
	} `json:"message"`
	Subscription string `json:"subscription"`
}

func (s *Server) handlePubSubRaw(w http.ResponseWriter, r *http.Request, ctx reqCtx) {
	var body IngestRequest
	// Support direct JSON payload or wrapped Pub/Sub push
	var psMsg PubSubMessage
	rawBytes, err := io.ReadAll(r.Body)
	if err != nil {
		writeError(w, http.StatusBadRequest, "cannot read request body")
		return
	}
	if json.Unmarshal(rawBytes, &psMsg) == nil && psMsg.Message.Data != "" {
		// Pub/Sub push message detected
		dataBytes, err := base64.StdEncoding.DecodeString(psMsg.Message.Data)
		if err != nil {
			dataBytes = []byte(psMsg.Message.Data)
		}
		_ = json.Unmarshal(dataBytes, &body)
		if body.SourceRef == "" {
			body.SourceRef = psMsg.Message.MessageID
		}
	} else {
		_ = json.Unmarshal(rawBytes, &body)
	}

	if body.Source == "" {
		body.Source = extract.SourceCalendar
	}

	payload, err := extract.Extract(r.Context(), s.Gemini, extract.RawMessage{
		Source:    body.Source,
		SourceRef: body.SourceRef,
		Title:     body.Title,
		Body:      body.Body,
	}, ctx.now)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "extract failed: "+err.Error())
		return
	}

	if !payload.IsTrip {
		writeJSON(w, http.StatusOK, map[string]any{"status": "ignored", "reason": "not_a_trip"})
		return
	}

	places := body.Places
	if places == nil {
		places = s.Planner.Places
	}

	trip, needsPlace, err := resolve.Trip(r.Context(), payload, body.Origin, places, s.Geocoder)
	if err != nil || needsPlace != nil {
		writeJSON(w, http.StatusOK, map[string]any{"status": "needs_place", "needs": needsPlace})
		return
	}

	uid := body.UID
	if uid == "" {
		uid = "demo-user"
	}

	if s.UserStore != nil {
		_ = s.UserStore.UpsertTrip(r.Context(), users.UserTrip{
			UID:    uid,
			Trip:   trip,
			Places: places,
		})
	}

	if s.Scheduler != nil {
		target := trip.ArriveBy
		if target.IsZero() {
			target = ctx.now.Add(2 * time.Hour)
		}
		runAt := target.Add(-45 * time.Minute)
		if runAt.Before(ctx.now) {
			runAt = ctx.now
		}
		_ = s.Scheduler.ScheduleCheck(r.Context(), uid, trip.ID, runAt)
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"status":  "scheduled",
		"trip_id": trip.ID,
		"uid":     uid,
	})
}

type taskCheckRequest struct {
	UID         string `json:"uid"`
	TripID      string `json:"trip_id"`
	ForceNotify bool   `json:"force_notify"`
}

func (s *Server) handleTaskCheck(w http.ResponseWriter, r *http.Request, ctx reqCtx) {
	var req taskCheckRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json: "+err.Error())
		return
	}
	if strings.TrimSpace(req.UID) == "" || strings.TrimSpace(req.TripID) == "" {
		writeError(w, http.StatusBadRequest, "missing uid or trip_id")
		return
	}

	if s.Evaluator == nil {
		writeError(w, http.StatusInternalServerError, "evaluator not configured")
		return
	}

	res, err := s.Evaluator.EvaluateTrip(r.Context(), ctx.prov, ctx.now, req.UID, req.TripID, req.ForceNotify)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			writeError(w, http.StatusBadRequest, "trip not found: "+err.Error())
			return
		}
		writeError(w, http.StatusInternalServerError, "evaluation failed: "+err.Error())
		return
	}

	writeJSON(w, http.StatusOK, res)
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
