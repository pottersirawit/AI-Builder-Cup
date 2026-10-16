// Package planner gathers everything one decision needs from the providers and
// exposes it as the tool box the Gemini agent calls (get_trip, get_route, ...).
// The fallback path calls the same tools, so `reasoning` always lists real calls.
package planner

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"errors"
	"fmt"
	"math"
	"strings"
	"time"
	"unicode"

	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
	"github.com/pottersirawit/fontokmai/api/internal/reports"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

// Providers are the data sources for one request (scenario or live).
type Providers struct {
	Weather     domain.WeatherProvider
	Routes      domain.RouteProvider
	Canals      domain.CanalProvider
	Reports     domain.ReportStore
	WeatherNext domain.WeatherNextProvider
	BMAFlood    domain.RoadFloodProvider
	BMATidal    domain.TidalProvider
	Hotlines    domain.HotlineProvider
	// Outlook feeds /v1/outlook; nil replays the scenario.
	Outlook domain.OutlookProvider
}

// Planner holds static data shared by all requests.
type Planner struct {
	Spots []floodspot.Spot
	Trips func(now time.Time) []domain.Trip
	// Places are the user's saved places; Whereabouts names the one they are
	// at now. Together they turn "ไปสยามตอนหกโมง" into a trip.
	Places      []domain.SavedPlace
	Whereabouts func(now time.Time) string
}

var (
	ErrUnknownTrip = errors.New("unknown trip")
	// ErrBadTrip is a trip request the server cannot act on, such as a
	// destination without an origin.
	ErrBadTrip = errors.New("bad trip request")
)

// AdHocPrefix marks trips typed as a question rather than found in Calendar or
// Gmail; the rest of the ID is the saved place ID, e.g. "adhoc-siam".
const AdHocPrefix = "adhoc-"

// AppPrefix marks trips the app sent as coordinates. The server stores
// nothing: the rest of the ID is a hash of the coordinates, so the app sends
// them again with every follow-up and gets the same ID back.
const AppPrefix = "app-"

// AppTrip is a trip between two points the app chose, by car, with no deadline.
func AppTrip(origin, dest domain.Place, titleTH string) domain.Trip {
	key := fmt.Sprintf("%.5f,%.5f>%.5f,%.5f", origin.Lat, origin.Lng, dest.Lat, dest.Lng)
	sum := sha1.Sum([]byte(key))
	return domain.Trip{ID: AppPrefix + hex.EncodeToString(sum[:])[:10], TitleTH: titleTH, Source: "app",
		Origin: origin, Destination: dest, Mode: domain.ModeCar}
}

// maxTitleRunes caps a trip title that may come from untrusted calendar or email text.
const maxTitleRunes = 80

// SanitizeTitle makes a title safe to show to the model and the user: control
// characters and angle brackets are dropped, whitespace is collapsed and the
// length is capped. Ordinary titles pass through unchanged.
func SanitizeTitle(s string) string {
	var b strings.Builder
	for _, r := range s {
		switch {
		case r == '<' || r == '>':
		case unicode.IsSpace(r):
			b.WriteRune(' ')
		case unicode.IsControl(r):
		default:
			b.WriteRune(r)
		}
	}
	out := strings.Join(strings.Fields(b.String()), " ")
	if rs := []rune(out); len(rs) > maxTitleRunes {
		out = string(rs[:maxTitleRunes])
	}
	return out
}

// tripWindow is how close an upcoming trip must be for a typed destination to
// mean that trip ("กลับบ้าน" at 16:10 is tonight's dinner).
const tripWindow = 12 * time.Hour

// sameSpotM is how close a trip's destination must be to a saved place.
const sameSpotM = 300

func (p *Planner) place(id string) (domain.SavedPlace, bool) {
	for _, pl := range p.Places {
		if pl.ID == id {
			return pl, true
		}
	}
	return domain.SavedPlace{}, false
}

// TripTo is the trip to a saved place as of now: an upcoming Calendar or Gmail
// trip going there within tripWindow, otherwise an ad-hoc trip from where the
// user is now, by car, with no deadline.
func (p *Planner) TripTo(now time.Time, placeID string) (domain.Trip, error) {
	dest, ok := p.place(placeID)
	if !ok {
		return domain.Trip{}, fmt.Errorf("%w: no saved place %q", ErrUnknownTrip, placeID)
	}
	if t, ok := p.upcomingTo(now, dest.Point()); ok {
		return t, nil
	}
	return p.adHocTrip(now, dest, domain.LangTH), nil
}

// upcomingTo is a Calendar or Gmail trip to near there within tripWindow.
func (p *Planner) upcomingTo(now time.Time, dest domain.LatLng) (domain.Trip, bool) {
	for _, t := range p.Trips(now) {
		if t.Plannable() && geo.HaversineM(t.Destination.Point(), dest) <= sameSpotM && t.ArriveBy.Sub(now).Abs() <= tripWindow {
			return t, true
		}
	}
	return domain.Trip{}, false
}

func (p *Planner) adHocTrip(now time.Time, dest domain.SavedPlace, lang domain.Lang) domain.Trip {
	return domain.Trip{
		ID: AdHocPrefix + dest.ID, TitleTH: goTo(lang, dest.LabelFor(lang)), Source: "question",
		Origin: p.origin(now, dest.ID).Place, Destination: dest.Place, Mode: domain.ModeCar,
	}
}

// origin is where the user is now; asking to go where they already are means
// the other end of the commute (home <-> work).
func (p *Planner) origin(now time.Time, destID string) domain.SavedPlace {
	id := ""
	if p.Whereabouts != nil {
		id = p.Whereabouts(now)
	}
	if id == destID {
		id = map[bool]string{true: "work", false: "home"}[destID == "home"]
	}
	if pl, ok := p.place(id); ok {
		return pl
	}
	return p.Places[0]
}

// goTo is the title of a trip to a named place.
func goTo(lang domain.Lang, name string) string {
	return lang.Pick("ไป"+name, "Go to "+name)
}

// Call is one tool invocation, as shown in the "Gemini คิดแบบนี้" trace.
type Call struct {
	Tool      string         `json:"tool"`
	Args      map[string]any `json:"-"`
	SummaryTH string         `json:"summary_th"`
}

// Session is one decision: a trip, a clock reading, cached provider results
// and the log of tool calls.
type Session struct {
	// Lang is the language of the text the session writes; zero is Thai.
	Lang domain.Lang

	ctx  context.Context
	p    *Planner
	prov Providers
	Now  time.Time
	Trip domain.Trip

	// places are the user's saved places (nil: the demo user's) and origin is
	// where the app says the user is (nil: unknown).
	places []domain.SavedPlace
	origin *domain.Place

	routes  map[string]domain.Route
	rain    []domain.RainSample
	rainSet bool
	calls   []Call

	usedWeatherNext bool
	usedBMAFlood    bool
	usedTidal       bool
}

// TripRequest is what a decision request says about the trip.
type TripRequest struct {
	TripID string
	// Origin and Destination, both set, are a trip the app chose (AppTrip).
	// Origin alone is where the user is now, for a question that names a place.
	Origin, Destination *domain.Place
	// Places are the user's saved places; nil means the demo user's.
	Places []domain.SavedPlace
	// Lang is the language of the trip titles and decision text; zero is Thai.
	Lang domain.Lang
	// Trip, when set, is the exact trip passed by the client or resolved from user storage.
	Trip *domain.Trip
	// Email of the authenticated user.
	Email string
}

func (p *Planner) NewSession(ctx context.Context, prov Providers, now time.Time, tripID string) (*Session, error) {
	return p.Open(ctx, prov, now, TripRequest{TripID: tripID})
}

// Open starts a decision for the requested trip: the app's coordinates, a
// known trip ID, or the first upcoming trip.
// Online meetings, all-day events and trips with an unresolved end are not
// travel and are refused with ErrBadTrip rather than planned to (0,0).
func (p *Planner) Open(ctx context.Context, prov Providers, now time.Time, req TripRequest) (*Session, error) {
	s, err := p.open(ctx, prov, now, req)
	if err != nil {
		return s, err
	}
	if !s.Trip.Plannable() {
		return nil, fmt.Errorf("%w: %q is not travel we can plan (online, all-day or no known place)", ErrBadTrip, s.Trip.ID)
	}
	s.Trip = scenario.LocalizeTrip(s.Trip, s.Lang)
	return s, nil
}

func (p *Planner) open(ctx context.Context, prov Providers, now time.Time, req TripRequest) (*Session, error) {
	s := &Session{Lang: req.Lang, ctx: ctx, p: p, prov: prov, Now: now, routes: map[string]domain.Route{}, places: req.Places, origin: req.Origin}

	if req.Trip != nil {
		s.Trip = *req.Trip
		if s.Trip.Origin.Lat == 0 && s.Trip.Origin.Lng == 0 && req.Origin != nil {
			s.Trip.Origin = *req.Origin
		}
		if s.Trip.Destination.Lat == 0 && s.Trip.Destination.Lng == 0 && req.Destination != nil {
			s.Trip.Destination = *req.Destination
		}
		return s, nil
	}

	switch {
	case req.Destination != nil && req.Origin == nil:
		return nil, fmt.Errorf("%w: destination needs an origin", ErrBadTrip)
	case req.Destination != nil:
		s.Trip = AppTrip(*req.Origin, *req.Destination, goTo(req.Lang, req.Destination.NameTH))
		return s, nil
	case strings.HasPrefix(req.TripID, AppPrefix):
		return nil, fmt.Errorf("%w: %q is not stored; send origin and destination with it", ErrBadTrip, req.TripID)
	}
	tripID := req.TripID
	trips := p.Trips(now)
	if len(trips) == 0 {
		return nil, ErrUnknownTrip
	}
	if tripID == "" {
		s.Trip = trips[0]
		for _, t := range trips {
			if t.Plannable() {
				s.Trip = t
				break
			}
		}
		return s, nil
	}
	for _, t := range trips {
		if t.ID == tripID {
			s.Trip = t
			return s, nil
		}
	}
	if placeID, ok := strings.CutPrefix(tripID, AdHocPrefix); ok {
		if dest, known := p.place(placeID); known {
			s.Trip = p.adHocTrip(now, dest, req.Lang)
			return s, nil
		}
	}
	return nil, fmt.Errorf("%w %q", ErrUnknownTrip, tripID)
}

// PlanTo switches the session to the trip to a saved place, dropping
// everything cached for the previous trip. For the demo user with no origin
// it is TripTo. Otherwise it is an upcoming Calendar or Gmail trip going
// there, or an app trip from the origin, or from the other end of the
// commute (home <-> work) when the app sent no origin.
func (s *Session) PlanTo(placeID string) error {
	var dest domain.SavedPlace
	found := false
	for _, pl := range s.Places() {
		if pl.ID == placeID {
			dest, found = pl, true
		}
	}
	if !found {
		return fmt.Errorf("%w: no saved place %q", ErrUnknownTrip, placeID)
	}
	var t domain.Trip
	if s.places == nil && s.origin == nil {
		if up, ok := s.p.upcomingTo(s.Now, dest.Point()); ok {
			t = up
		} else {
			t = s.p.adHocTrip(s.Now, dest, s.Lang)
		}
	} else if up, ok := s.p.upcomingTo(s.Now, dest.Point()); ok {
		t = up
	} else {
		origin, ok := s.commuteOrigin(dest)
		if !ok {
			return fmt.Errorf("%w: send origin (where the user is now) to plan a trip to %s", ErrBadTrip, dest.LabelTH)
		}
		title := goTo(s.Lang, dest.LabelFor(s.Lang))
		if dest.Kind == domain.KindHome {
			title = s.Lang.Pick("กลับบ้าน", "Going home")
		}
		t = AppTrip(origin, dest.Place, title)
	}
	s.Trip, s.routes, s.rain, s.rainSet = scenario.LocalizeTrip(t, s.Lang), map[string]domain.Route{}, nil, false
	return nil
}

// commuteOrigin is where a trip to dest starts: the app's origin, else work
// for home and home for anywhere else.
func (s *Session) commuteOrigin(dest domain.SavedPlace) (domain.Place, bool) {
	if s.origin != nil {
		return *s.origin, true
	}
	want := []string{domain.KindHome, domain.KindWork}
	if dest.Kind == domain.KindHome {
		want = []string{domain.KindWork}
	}
	for _, kind := range want {
		for _, pl := range s.Places() {
			if pl.Kind == kind && pl.ID != dest.ID {
				return pl.Place, true
			}
		}
	}
	return domain.Place{}, false
}

// Places are the places a question can name: the user's, or the demo user's.
func (s *Session) Places() []domain.SavedPlace {
	if s.places != nil {
		return s.places
	}
	return s.p.Places
}

// localVia gives road names in the session's language.
func (s *Session) localVia(via []string) []string {
	if s.Lang != domain.LangEN {
		return via
	}
	out := make([]string, len(via))
	for i, v := range via {
		out[i] = scenario.Text(v, s.Lang)
	}
	return out
}

func (s *Session) Calls() []Call { return append([]Call(nil), s.calls...) }

// ResetCalls forgets the logged tool calls, so a fallback after a failed agent
// run does not list the agent's calls twice.
func (s *Session) ResetCalls() { s.calls = nil }

func (s *Session) route(mode domain.Mode, depart time.Time) (domain.Route, error) {
	key := string(mode) + depart.Format(time.RFC3339)
	if r, ok := s.routes[key]; ok {
		return r, nil
	}
	r, err := s.prov.Routes.Route(s.ctx, s.Trip.Origin.Point(), s.Trip.Destination.Point(), mode, depart)
	if err != nil {
		return domain.Route{}, err
	}
	s.routes[key] = r
	return r, nil
}

// rainSeries covers two hours of history (for drainage) to eight hours ahead,
// sampled at the middle of the road route.
func (s *Session) rainSeries(road domain.Route) ([]domain.RainSample, error) {
	if s.rainSet {
		return s.rain, nil
	}
	mid := s.Trip.Origin.Point()
	if n := len(road.Polyline); n > 0 {
		mid = road.Polyline[n/2]
	}
	r, err := s.prov.Weather.Rain(s.ctx, mid, s.Now.Add(-2*time.Hour), s.Now.Add(8*time.Hour))
	if err != nil {
		return nil, err
	}
	s.rain, s.rainSet = r, true
	return r, nil
}

func (s *Session) reportsNear(road domain.Route) ([]domain.Report, error) {
	if len(road.Polyline) == 0 {
		return nil, nil
	}
	center, radius := road.Polyline[len(road.Polyline)/2], 0.0
	for _, p := range road.Polyline {
		radius = math.Max(radius, geo.HaversineM(center, p))
	}
	all, err := s.prov.Reports.Near(s.ctx, center, radius+reports.NotifyRadiusM, s.Now.Add(-time.Hour), s.Now)
	if err != nil {
		return nil, err
	}
	var out []domain.Report
	for _, r := range all {
		if geo.DistanceToPolylineM(r.Point(), road.Polyline) <= reports.NotifyRadiusM {
			out = append(out, r)
		}
	}
	return out, nil
}

// Input assembles the deterministic engine input for one departure.
func (s *Session) Input(depart time.Time, mode domain.Mode) (decision.Input, error) {
	road, err := s.route(domain.ModeCar, depart)
	if err != nil {
		return decision.Input{}, err
	}
	rain, err := s.rainSeries(road)
	if err != nil {
		return decision.Input{}, err
	}
	reps, err := s.reportsNear(road)
	if err != nil {
		return decision.Input{}, err
	}
	var windGustKMH float64
	if s.prov.WeatherNext != nil && len(road.Polyline) > 0 {
		if g, _, err := s.prov.WeatherNext.PeakConditionsAlongRoute(road.Polyline); err == nil {
			windGustKMH = g
			s.usedWeatherNext = true
		}
	}
	if s.prov.BMAFlood != nil && len(road.Polyline) > 0 {
		if sensors, err := s.prov.BMAFlood.SensorsNearRoute(road.Polyline, 250); err == nil && len(sensors) > 0 {
			s.usedBMAFlood = true
		}
	}
	if s.prov.BMATidal != nil {
		if _, err := s.prov.BMATidal.TidalStatus(s.ctx, depart); err == nil {
			s.usedTidal = true
		}
	}
	in := decision.Input{
		Lang: s.Lang, Now: s.Now, DepartAt: depart, ArriveBy: s.Trip.ArriveBy, Mode: mode,
		DestinationTH: s.Trip.Destination.NameTH, RoadViaTH: s.localVia(road.ViaTH),
		Rain: rain, Spots: floodspot.OnRoute(s.p.Spots, road.Polyline), Reports: reps,
		WindGustKMH: windGustKMH,
	}
	from, to := s.Trip.Origin.Point(), s.Trip.Destination.Point()
	if tt, ok := s.prov.Routes.(domain.TravelTimer); ok {
		in.Travel = func(m domain.Mode, t time.Time) int { return tt.TravelMinutes(from, to, m, t) }
	} else {
		fixed := map[domain.Mode]int{}
		for _, m := range domain.AllModes {
			r, err := s.route(m, depart)
			if err != nil {
				return decision.Input{}, err
			}
			fixed[m] = r.DurationMin
		}
		in.Travel = func(m domain.Mode, _ time.Time) int { return fixed[m] }
	}
	return in, nil
}

// Baseline runs the deterministic engine without logging tool calls.
func (s *Session) Baseline(depart time.Time, mode domain.Mode) (decision.Result, error) {
	in, err := s.Input(depart, mode)
	if err != nil {
		return decision.Result{}, err
	}
	return decision.Decide(in), nil
}

// SourcesUsed returns the human-readable names of data sources configured in Providers
// and actively queried during the route evaluation.
func (s *Session) SourcesUsed() []string {
	var out []string
	if s.origin != nil {
		out = append(out, s.Lang.Pick("GPS ตำแหน่งปัจจุบัน", "GPS current location"))
	}
	if s.prov.Weather != nil {
		out = append(out, s.prov.Weather.Name())
	}
	if s.prov.Routes != nil {
		out = append(out, s.prov.Routes.Name())
	}
	if s.prov.Canals != nil {
		out = append(out, s.prov.Canals.Name())
	}
	out = append(out, "BMA flood spots")
	if s.prov.WeatherNext != nil {
		out = append(out, s.prov.WeatherNext.Name())
	}
	if s.prov.BMAFlood != nil {
		out = append(out, s.prov.BMAFlood.Name())
	}
	if s.prov.BMATidal != nil {
		out = append(out, s.prov.BMATidal.Name())
	}
	if s.prov.Hotlines != nil {
		out = append(out, s.prov.Hotlines.Name())
	}
	return out
}

// EmergencyContacts returns official emergency helplines from the hotline provider.
func (s *Session) EmergencyContacts() []domain.EmergencyContact {
	if s.prov.Hotlines != nil {
		return s.prov.Hotlines.EmergencyContacts()
	}
	return nil
}

// ---- tools ----

// Param describes one tool argument.
type Param struct {
	Type        string // "string" or "number"
	Description string
	Enum        []string
}

// Tool describes one function the agent may call.
type Tool struct {
	Name        string
	Description string
	Params      map[string]Param
	Required    []string
}

var (
	pDepart = Param{Type: "string", Description: "เวลาออกเดินทาง RFC 3339 หรือ HH:MM (เวลาไทย) ไม่ระบุ = ตอนนี้"}
	pMode   = Param{Type: "string", Description: "วิธีเดินทาง", Enum: []string{"car", "transit", "moto"}}
)

// Tools is the agent's tool box, in the order the fallback path calls them.
var Tools = []Tool{
	{Name: "get_trip", Description: "ดูทริปที่กำลังตัดสินใจ: ต้นทาง ปลายทาง เวลาที่ต้องถึง วิธีเดินทางประจำ และที่มา (Calendar/Gmail)"},
	{Name: "get_route", Description: "ขอเส้นทางจาก Google Routes API (traffic aware) สำหรับวิธีเดินทางและเวลาออก คืนเวลาเดินทางและถนนที่ผ่าน",
		Params: map[string]Param{"mode": pMode, "depart_at": pDepart}, Required: []string{"mode"}},
	{Name: "get_rain_along_route", Description: "พยากรณ์ฝนรายช่วงบนเส้นทาง (Google Weather API) ตั้งแต่ตอนนี้ถึง 5 ชั่วโมงข้างหน้า มม./ชม."},
	{Name: "get_flood_spots_on_route", Description: "จุดน้ำท่วมซ้ำซาก กทม. ที่เส้นทางผ่าน พร้อมความลึกที่คาดว่าจะเจอเมื่อออกตามเวลาที่ระบุ",
		Params: map[string]Param{"mode": pMode, "depart_at": pDepart}},
	{Name: "get_canal_levels", Description: "ระดับน้ำในคลองใกล้ปลายทางจาก ThaiWater (HII) เทียบกับตลิ่ง"},
	{Name: "get_community_reports", Description: "รายงานน้ำท่วมจากผู้ใช้ (ภาพ + Gemini vision) ใกล้เส้นทางในชั่วโมงที่ผ่านมา"},
	{Name: "evaluate_departure", Description: "ให้เครื่องคำนวณความเสี่ยงแบบกำหนดแน่นอน (ฝน x จุดน้ำท่วม x ความสูงใต้ท้องรถ) ของการออกเวลาหนึ่งด้วยวิธีหนึ่ง คืนเวลาถึง ความเสี่ยง และสายเกินนัดกี่นาที",
		Params: map[string]Param{"mode": pMode, "depart_at": pDepart}, Required: []string{"mode"}},
}

// Call runs one tool, records it and returns its JSON-able result.
func (s *Session) Call(name string, args map[string]any) (map[string]any, error) {
	out, summary, err := s.dispatch(name, args)
	if err != nil {
		out, summary = map[string]any{"error": err.Error()}, s.Lang.Pick("เรียกข้อมูลไม่สำเร็จ: ", "Could not fetch the data: ")+err.Error()
	}
	s.calls = append(s.calls, Call{Tool: name, Args: args, SummaryTH: summary})
	return out, err
}

func (s *Session) dispatch(name string, args map[string]any) (map[string]any, string, error) {
	mode := s.Trip.Mode
	if m, ok := args["mode"].(string); ok && domain.Mode(m).Valid() {
		mode = domain.Mode(m)
	}
	depart := s.Now
	if v, ok := args["depart_at"].(string); ok && v != "" {
		t, err := ParseTime(v, s.Now)
		if err != nil {
			return nil, "", err
		}
		depart = t
	}

	switch name {
	case "get_trip":
		t := s.Trip
		t.TitleTH = SanitizeTitle(t.TitleTH)
		summary := fmt.Sprintf("นัด%s ต้องถึง%sก่อน %s (%s)", t.TitleTH, t.Destination.NameTH, hhmm(t.ArriveBy), sourceTH(t.Source))
		if t.ArriveBy.IsZero() {
			summary = fmt.Sprintf("%s จาก%s ไม่มีเวลานัด (%s)", t.TitleTH, t.Origin.NameTH, sourceTH(t.Source))
		}
		if s.Lang == domain.LangEN {
			summary = fmt.Sprintf("%s: be at %s by %s (%s)", t.TitleTH, t.Destination.NameTH, hhmm(t.ArriveBy), sourceEN(t.Source))
			if t.ArriveBy.IsZero() {
				summary = fmt.Sprintf("%s from %s, no appointment time (%s)", t.TitleTH, t.Origin.NameTH, sourceEN(t.Source))
			}
		}
		return map[string]any{"trip": t, "now": s.Now.Format(time.RFC3339)}, summary, nil

	case "get_route":
		r, err := s.route(mode, depart)
		if err != nil {
			return nil, "", err
		}
		in, err := s.Input(depart, mode)
		if err != nil {
			return nil, "", err
		}
		mins := in.Travel(mode, depart)
		summary := fmt.Sprintf("%s ออก %s ใช้เวลา %d นาที", mode.NameTH(), hhmm(depart), mins)
		via := " ผ่าน "
		if s.Lang == domain.LangEN {
			summary = fmt.Sprintf("By %s, leaving %s takes %d min", mode.NameFor(s.Lang), hhmm(depart), mins)
			via = " via "
		}
		if len(r.ViaTH) > 0 {
			summary += via + strings.Join(s.localVia(r.ViaTH), " → ")
		}
		return map[string]any{"mode": mode, "depart_at": depart.Format(time.RFC3339), "duration_min": mins, "via_th": r.ViaTH, "source": r.Source},
			summary, nil

	case "get_rain_along_route":
		road, err := s.route(domain.ModeCar, s.Now)
		if err != nil {
			return nil, "", err
		}
		rain, err := s.rainSeries(road)
		if err != nil {
			return nil, "", err
		}
		var samples []map[string]any
		var onset, peak *domain.RainSample
		for i, r := range rain {
			if r.Time.Before(s.Now.Truncate(15*time.Minute)) || r.Time.After(s.Now.Add(5*time.Hour)) {
				continue
			}
			samples = append(samples, map[string]any{"time": hhmm(r.Time), "mm_per_hr": r.MMPerHr})
			if onset == nil && r.MMPerHr >= 1 {
				onset = &rain[i]
			}
			if peak == nil || r.MMPerHr > peak.MMPerHr {
				peak = &rain[i]
			}
		}
		summary := s.Lang.Pick("ไม่มีฝนบนเส้นทางใน 5 ชั่วโมงข้างหน้า", "No rain on the route in the next 5 hours")
		if onset != nil {
			where := "เส้นทาง"
			if s.Lang == domain.LangEN {
				where = "your route"
			}
			if len(road.ViaTH) > 0 {
				where = s.localVia(road.ViaTH)[0]
			}
			summary = fmt.Sprintf(s.Lang.Pick("ฝนถึง%s ราว %s หนักสุด %.0f มม./ชม. ตอน %s", "Rain reaches %s around %s, peaking at %.0f mm/h at %s"), where, hhmm(onset.Time), peak.MMPerHr, hhmm(peak.Time))
		}
		return map[string]any{"samples": samples, "source": s.prov.Weather.Name()}, summary, nil

	case "get_flood_spots_on_route":
		res, err := s.Baseline(depart, mode)
		if err != nil {
			return nil, "", err
		}
		summary := fmt.Sprintf(s.Lang.Pick("เส้นทางผ่านจุดเสี่ยงน้ำท่วม %d จุด", "The route passes %d flood-prone spots"), len(res.FloodSpots))
		if len(res.FloodSpots) > 0 {
			d := res.FloodSpots[0]
			if d.ExpectedDepthCM > 0 {
				summary += fmt.Sprintf(s.Lang.Pick(" ลึกสุดคาด %d ซม. ที่ %s ถ้าออก %s", ", deepest expected %d cm at %[2]s if you leave at %[3]s"), d.ExpectedDepthCM, d.NameTH, hhmm(depart))
			} else {
				summary += fmt.Sprintf(s.Lang.Pick(" ออก %s ยังไม่มีน้ำขัง", ", no standing water if you leave at %s"), hhmm(depart))
			}
		}
		return map[string]any{"depart_at": depart.Format(time.RFC3339), "flood_spots": res.FloodSpots, "source": "BMA flood spots"}, summary, nil

	case "get_canal_levels":
		canals, err := s.prov.Canals.Canals(s.ctx, s.Trip.Destination.Point(), s.Now)
		if err != nil {
			return nil, "", err
		}
		if len(canals) > 3 {
			canals = canals[:3]
		}
		summary := s.Lang.Pick("ไม่มีข้อมูลคลองใกล้ปลายทาง", "No canal data near the destination")
		if len(canals) > 0 {
			c := canals[0]
			summary = fmt.Sprintf(s.Lang.Pick("%s %.1f ม. ตลิ่ง %.1f ม. (ต่ำกว่าตลิ่ง %.0f ซม.)", "%s at %.1f m, bank at %.1f m (%.0f cm below the bank)"), c.NameTH, c.LevelM, c.BankM, math.Max(0, (c.BankM-c.LevelM)*100))
		}
		return map[string]any{"canals": canals}, summary, nil

	case "get_community_reports":
		road, err := s.route(domain.ModeCar, s.Now)
		if err != nil {
			return nil, "", err
		}
		reps, err := s.reportsNear(road)
		if err != nil {
			return nil, "", err
		}
		summary := s.Lang.Pick("ยังไม่มีรายงานน้ำท่วมจากผู้ใช้บนเส้นทางในชั่วโมงที่ผ่านมา", "No flood reports from users on the route in the past hour")
		if len(reps) > 0 {
			last := reps[len(reps)-1]
			summary = fmt.Sprintf(s.Lang.Pick("รายงานจากผู้ใช้ %d รายการบนเส้นทาง ล่าสุด %s น้ำ %d-%d ซม.", "%d user reports on the route, latest at %s with water %d-%d cm"), len(reps), hhmm(last.CreatedAt), last.DepthCMMin, last.DepthCMMax)
		}
		return map[string]any{"reports": reps}, summary, nil

	case "evaluate_departure":
		in, err := s.Input(depart, mode)
		if err != nil {
			return nil, "", err
		}
		e := decision.EvaluateMode(in, mode, depart)
		out := map[string]any{"mode": mode, "depart_at": hhmm(depart), "arrive_at": hhmm(e.Arrive), "minutes": e.Minutes,
			"max_rain_mm_per_hr": e.MaxRainMM, "max_water_depth_cm": math.Round(e.MaxDepthCM), "risk": e.Risk, "late_minutes": e.LateMinutes}
		if lb := decision.LeaveBy(in, mode); lb != nil {
			out["latest_safe_departure"] = hhmm(*lb)
		}
		if s.Lang == domain.LangEN {
			late := ""
			if e.Late() {
				late = fmt.Sprintf(", %d min past the appointment", e.LateMinutes)
			}
			return out, fmt.Sprintf("Leaving at %s by %s, arrive %s, %s risk%s", hhmm(depart), mode.NameFor(s.Lang), hhmm(e.Arrive), riskEN(e.Risk), late), nil
		}
		late := ""
		if e.Late() {
			late = fmt.Sprintf(" เลยนัด %d นาที", e.LateMinutes)
		}
		return out, fmt.Sprintf("ออก %s ด้วย%s ถึง %s ความเสี่ยง%s%s", hhmm(depart), mode.NameTH(), hhmm(e.Arrive), riskTH(e.Risk), late), nil
	}
	return nil, "", fmt.Errorf("unknown tool %q", name)
}

// ParseTime accepts RFC 3339 or HH:MM on the day of now (Bangkok time).
func ParseTime(v string, now time.Time) (time.Time, error) {
	if t, err := time.Parse(time.RFC3339, v); err == nil {
		return t.In(domain.Bangkok), nil
	}
	for _, layout := range []string{"15:04", "15.04"} {
		if t, err := time.ParseInLocation(layout, v, domain.Bangkok); err == nil {
			n := now.In(domain.Bangkok)
			return time.Date(n.Year(), n.Month(), n.Day(), t.Hour(), t.Minute(), 0, 0, domain.Bangkok), nil
		}
	}
	return time.Time{}, fmt.Errorf("bad time %q: want RFC 3339 or HH:MM", v)
}

func hhmm(t time.Time) string { return t.In(domain.Bangkok).Format("15:04") }

func sourceTH(src string) string {
	switch src {
	case "calendar":
		return "จาก Google Calendar"
	case "gmail":
		return "จากอีเมลยืนยันใน Gmail"
	case "app":
		return "เลือกในแอป"
	}
	return "พิมพ์ถามเอง"
}

func riskTH(r decision.Risk) string {
	return map[decision.Risk]string{decision.RiskLow: "ต่ำ", decision.RiskMedium: "ปานกลาง", decision.RiskHigh: "สูง"}[r]
}

func sourceEN(src string) string {
	switch src {
	case "calendar":
		return "from Google Calendar"
	case "gmail":
		return "from a Gmail confirmation"
	case "app":
		return "picked in the app"
	}
	return "typed in as a question"
}

func riskEN(r decision.Risk) string {
	return map[decision.Risk]string{decision.RiskLow: "low", decision.RiskMedium: "medium", decision.RiskHigh: "high"}[r]
}
