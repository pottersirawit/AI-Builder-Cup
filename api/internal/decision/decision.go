// Package decision is the deterministic core of ฝนตกไหม: rain along the route x
// BMA flood spot thresholds x vehicle clearance gives a verdict per mode, the
// latest safe departure and a confidence. It does no I/O; the planner feeds it.
package decision

import (
	"math"
	"sort"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
)

type Verdict string

const (
	LeaveNow   Verdict = "leave_now"
	Wait       Verdict = "wait"
	SwitchMode Verdict = "switch_mode"
	DontGo     Verdict = "dont_go"
)

func (v Verdict) Valid() bool { return v == LeaveNow || v == Wait || v == SwitchMode || v == DontGo }

type Risk string

const (
	RiskLow    Risk = "low"
	RiskMedium Risk = "medium"
	RiskHigh   Risk = "high"
)

func (r Risk) rank() int { return map[Risk]int{RiskLow: 0, RiskMedium: 1, RiskHigh: 2}[r] }

// Rain intensity bands in mm/h.
const (
	rainLight    = 1.0
	rainModerate = 10.0
	rainHeavy    = 35.0
)

// Vehicle Clearance Profiles (CONTEXT.md): water depth in cm & wind threshold in km/h.
const (
	carSlowDepthCM           = 5.0  // sedan slows, water sprays the floor
	carStallDepthCM          = 15.0 // sedan clearance
	motoStallDepthCM         = 10.0
	pickupSlowDepthCM        = 20.0
	pickupStallDepthCM       = 35.0
	motoWindGustCautionKMH   = 30.0 // gusts make riding harder
	motoWindGustThresholdKMH = 45.0 // gusts > 45 km/h make two-wheelers dangerous
	motoRainProbThresholdPct = 60   // PoP >= 60% prompts rain gear advisory
)

// stallDepthCM is the water a mode cannot pass; slowDepthCM the water that
// slows it.
func stallDepthCM(m domain.Mode) float64 {
	switch m {
	case domain.ModeMoto:
		return motoStallDepthCM
	case domain.ModePickup:
		return pickupStallDepthCM
	default:
		return carStallDepthCM
	}
}

func slowDepthCM(m domain.Mode) float64 {
	switch m {
	case domain.ModeMoto:
		return 1
	case domain.ModePickup:
		return pickupSlowDepthCM
	default:
		return carSlowDepthCM
	}
}

// Thresholds are the engine's cut-offs by unit ("cm", "mmh", "kmh"), which
// advice may quote as facts.
func Thresholds() map[string][]float64 {
	return map[string][]float64{
		"cm":  {carSlowDepthCM, carStallDepthCM, motoStallDepthCM, pickupSlowDepthCM, pickupStallDepthCM, soloReportCapCM},
		"mmh": {rainLight, rainModerate, rainHeavy},
		"kmh": {motoWindGustCautionKMH, motoWindGustThresholdKMH},
	}
}

// Water drains from a flood spot linearly over drainWindow after the rain that
// caused it; a community report is trusted for reportTTL.
const (
	drainWindow = 120 * time.Minute
	reportTTL   = 60 * time.Minute
	step        = 5 * time.Minute
)

const unnamedReportSpot = "จุดที่มีรายงาน"

// TravelFunc returns base door-to-door minutes for a mode departing at t,
// before weather delays.
type TravelFunc func(mode domain.Mode, departAt time.Time) int

type Input struct {
	Lang     domain.Lang // language of the narrative text; zero is Thai
	Now      time.Time
	DepartAt time.Time
	ArriveBy time.Time // zero when the trip has no deadline
	Mode     domain.Mode

	DestinationTH string
	RoadViaTH     []string                     // named roads on the car route, first one is where rain is reported
	Routes        map[domain.Mode]domain.Route // calculated route details per mode

	Rain        []domain.RainSample
	Spots       []floodspot.Spot         // flood spots on the road route
	Reports     []domain.Report          // community reports near the road route
	RoadSensors []domain.RoadFloodSensor // live BMA road flood sensors near the route
	Tidal       *domain.TidalReading     // BMA KlongMap tidal backwater status
	WindGustKMH float64                  // peak wind gust on route (from WeatherNext 3)
	TempC       float64                  // peak temperature on route (from WeatherNext 3)
	Travel      TravelFunc
}

// Eval is one mode departing at one time.
type Eval struct {
	Mode        domain.Mode
	Depart      time.Time
	Arrive      time.Time
	Minutes     int
	MaxRainMM   float64
	MaxDepthCM  float64
	MaxProbPct  int
	WindGustKMH float64
	DeepestTH   string // short name of the deepest flood spot or report
	Risk        Risk
	LateMinutes int
}

func (e Eval) Late() bool { return e.LateMinutes > 0 }
func (e Eval) OK() bool   { return e.Risk == RiskLow && !e.Late() }

type ModeOption struct {
	Mode        domain.Mode         `json:"mode"`
	Verdict     Verdict             `json:"verdict"`
	EtaMin      int                 `json:"eta_min"`
	Risk        Risk                `json:"risk"`
	RainProbPct int                 `json:"rain_prob_pct"`
	NoteTH      string              `json:"note_th"`
	ViaTH       []string            `json:"via_th,omitempty"`
	TransitLegs []domain.TransitLeg `json:"transit_legs,omitempty"`
}

type FloodSpot struct {
	ID              string  `json:"id"`
	NameTH          string  `json:"name_th"`
	Lat             float64 `json:"lat"`
	Lng             float64 `json:"lng"`
	ExpectedDepthCM int     `json:"expected_depth_cm"`
	Risk            Risk    `json:"risk"`
}

// Explanation details why a mode and departure time were chosen, lists concrete
// factors evaluated, and provides flood-avoidance route optimization advice.
type Explanation struct {
	ReasonWhyTH   string   `json:"reason_why_th"`
	FactorsTH     []string `json:"factors_th"`
	RouteAdviceTH string   `json:"route_advice_th"`
	AvoidSpotsTH  []string `json:"avoid_spots_th"`
}

// Result is the deterministic answer. Narrative fields may later be rewritten
// by the Gemini agent; numbers stay.
type Result struct {
	Verdict      Verdict
	HeadlineTH   string
	SummaryTH    string
	LeaveBy      *time.Time
	WaitUntil    *time.Time
	Confidence   float64
	RainTimeline []domain.RainSample
	ModeOptions  []ModeOption
	FloodSpots   []FloodSpot
	Evals        map[domain.Mode]Eval
	RainOnset    *time.Time
	Explanation  Explanation
}

// Decide answers "should I leave at DepartAt with Mode?".
func Decide(in Input) Result {
	res := Result{Evals: map[domain.Mode]Eval{}}
	for _, m := range domain.AllModes {
		res.Evals[m] = EvaluateMode(in, m, in.DepartAt)
	}
	for _, m := range domain.AllModes {
		v, _ := verdictFor(in, m, res.Evals)
		opt := ModeOption{
			Mode: m, Verdict: v, EtaMin: res.Evals[m].Minutes, Risk: res.Evals[m].Risk,
			RainProbPct: res.Evals[m].MaxProbPct,
			NoteTH:      modeNote(in, res.Evals[m]),
		}
		if rt, ok := in.Routes[m]; ok {
			opt.ViaTH = rt.ViaTH
			opt.TransitLegs = rt.TransitLegs
		} else if m != domain.ModeTransit && len(in.RoadViaTH) > 0 {
			opt.ViaTH = in.RoadViaTH
		}
		res.ModeOptions = append(res.ModeOptions, opt)
	}
	res.Verdict, res.WaitUntil = verdictFor(in, in.Mode, res.Evals)
	res.LeaveBy = LeaveBy(in, in.Mode)
	res.RainOnset = rainOnset(in)
	res.RainTimeline = timeline(in)
	res.FloodSpots = floodSpots(in, res.Evals)
	res.Confidence = confidence(in, res.Evals[in.Mode])
	if in.Lang == domain.LangEN {
		res.HeadlineTH, res.SummaryTH, res.Explanation = narrateEN(in, res)
	} else {
		res.HeadlineTH, res.SummaryTH, res.Explanation = narrate(in, res)
	}
	return res
}

// EvaluateMode simulates one departure: base travel time, weather delays, then
// the worst rain and water met on the way, judged by the mode's clearance.
func EvaluateMode(in Input, mode domain.Mode, depart time.Time) Eval {
	base := in.Travel(mode, depart)
	rain, depth, _, _ := hazards(in, mode, depart, depart.Add(minutes(base)))
	delay := 0
	switch mode {
	case domain.ModeCar:
		if rain >= rainModerate {
			delay += 10
		}
		if depth >= carSlowDepthCM {
			delay += 20
		}
	case domain.ModePickup:
		if rain >= rainModerate {
			delay += 10
		}
		if depth >= pickupSlowDepthCM {
			delay += 15
		}
	case domain.ModeMoto:
		if rain >= rainModerate {
			delay += 10
		}
		if depth >= 1 {
			delay += 15
		}
	case domain.ModeTransit:
		if rain >= rainModerate {
			delay += 5
		}
	}
	total := base + delay
	e := Eval{Mode: mode, Depart: depart, Minutes: total, Arrive: depart.Add(minutes(total)), WindGustKMH: in.WindGustKMH}
	e.MaxRainMM, e.MaxDepthCM, e.MaxProbPct, e.DeepestTH = hazards(in, mode, depart, e.Arrive)
	e.Risk = riskFor(mode, e.MaxRainMM, e.MaxDepthCM, in.WindGustKMH, e.MaxProbPct)
	if !in.ArriveBy.IsZero() && e.Arrive.After(in.ArriveBy) {
		e.LateMinutes = int(math.Ceil(e.Arrive.Sub(in.ArriveBy).Minutes()))
	}
	return e
}

func riskFor(mode domain.Mode, rain, depth, windGustKMH float64, probPct int) Risk {
	switch mode {
	case domain.ModeCar:
		if depth >= carStallDepthCM {
			return RiskHigh
		}
		if depth >= carSlowDepthCM || rain >= rainModerate {
			return RiskMedium
		}
	case domain.ModePickup:
		if depth >= pickupStallDepthCM {
			return RiskHigh
		}
		if depth >= pickupSlowDepthCM || rain >= rainModerate {
			return RiskMedium
		}
	case domain.ModeMoto:
		if depth >= motoStallDepthCM || rain >= rainModerate || windGustKMH >= motoWindGustThresholdKMH {
			return RiskHigh
		}
		if depth >= 1 || rain >= rainLight || windGustKMH >= 30.0 || probPct >= motoRainProbThresholdPct {
			return RiskMedium
		}
	case domain.ModeTransit:
		// Trains run above or below the water; only the walk to the station gets wet.
		if rain >= rainModerate {
			return RiskMedium
		}
	}
	return RiskLow
}

// hazards returns the worst rain, rain probability, and street water met between from and to.
// Transit ignores street water.
func hazards(in Input, mode domain.Mode, from, to time.Time) (rain, depth float64, prob int, deepest string) {
	for t := from; t.Before(to); t = t.Add(step) {
		rain = math.Max(rain, RainAt(in.Rain, t))
		prob = max(prob, RainProbAt(in.Rain, t))
		if mode == domain.ModeTransit {
			continue
		}
		for _, s := range in.Spots {
			if d := SpotDepthCMWithTide(s, in.Rain, t, in.Tidal); d > depth {
				depth, deepest = d, s.ShortName(in.Lang)
			}
		}
		for _, rs := range in.RoadSensors {
			if d := sensorDepthCM(rs, t); d > depth {
				depth, deepest = d, sensorName(rs, in.Lang)
			}
		}
		for _, r := range in.Reports {
			if d := reportDepthCM(r, in.Reports, t); d > depth {
				depth, deepest = d, nearestSpotName(in.Spots, r, in.Lang)
			}
		}
	}
	return rain, depth, prob, deepest
}

// RainProbAt is the rain probability (percent) of the latest sample at or before t.
func RainProbAt(samples []domain.RainSample, t time.Time) int {
	v, found := 0, false
	var last time.Time
	for _, s := range samples {
		if s.Time.After(t) {
			break
		}
		v, last, found = s.ProbPct, s.Time, true
	}
	if !found || (len(samples) > 0 && last.Equal(samples[len(samples)-1].Time) && t.Sub(last) >= time.Hour) {
		return 0
	}
	return v
}

// RainAt is the intensity of the latest sample at or before t. Samples hold
// until the next one; the last sample holds for an hour.
func RainAt(samples []domain.RainSample, t time.Time) float64 {
	v, found := 0.0, false
	var last time.Time
	for _, s := range samples {
		if s.Time.After(t) {
			break
		}
		v, last, found = s.MMPerHr, s.Time, true
	}
	if !found || (len(samples) > 0 && last.Equal(samples[len(samples)-1].Time) && t.Sub(last) >= time.Hour) {
		return 0
	}
	return v
}

// SpotDepthCM is the street water at a flood spot at t: each recent rain sample
// floods the spot (ported depth model) and the water drains over drainWindow.
func SpotDepthCM(s floodspot.Spot, samples []domain.RainSample, t time.Time) float64 {
	depth := 0.0
	for _, r := range samples {
		age := t.Sub(r.Time)
		if age < 0 || age >= drainWindow {
			continue
		}
		left := 1 - float64(age)/float64(drainWindow)
		depth = math.Max(depth, floodspot.InstantDepthCM(s, r.MMPerHr)*left)
	}
	return depth
}

// SpotDepthCMWithTide accounts for Chao Phraya tidal backwater slowing canal
// gravity drainage when active street flooding (>= carSlowDepthCM) is present.
func SpotDepthCMWithTide(s floodspot.Spot, samples []domain.RainSample, t time.Time, tidal *domain.TidalReading) float64 {
	depth := SpotDepthCM(s, samples, t)
	if depth >= carSlowDepthCM && tidal != nil {
		switch tidal.SurgeRisk {
		case "high":
			depth = math.Min(float64(s.MaxDepthCM), depth*1.10)
		case "medium":
			depth = math.Min(float64(s.MaxDepthCM), depth*1.05)
		}
	}
	return depth
}

// sensorDepthCM returns the street water depth reported by a live BMA road
// sensor at t, draining linearly over drainWindow from its reading timestamp.
func sensorDepthCM(s domain.RoadFloodSensor, t time.Time) float64 {
	if s.DepthCM <= 0 {
		return 0
	}
	if s.UpdatedAt.IsZero() {
		return s.DepthCM
	}
	age := t.Sub(s.UpdatedAt)
	if age < 0 || age >= drainWindow {
		return 0
	}
	left := 1 - float64(age)/float64(drainWindow)
	return s.DepthCM * left
}

func sensorName(s domain.RoadFloodSensor, l domain.Lang) string {
	if l == domain.LangEN && s.NameEN != "" {
		return s.NameEN
	}
	if s.NameTH != "" {
		return s.NameTH
	}
	return s.Code
}

// Report weighting: a lone photo is cheap to fake, so a report only counts at
// its full depth once another usable report nearby backs it up.
const (
	minReportConfidence   = 0.5
	soloReportCapCM       = 15.0
	corroborationRadiusM  = 300.0
	corroborationWindow   = 30 * time.Minute
	corroboratingReportsN = 2 // usable reports in the cluster, the report itself included
)

// UsableReport is false for the fallback hero assessment and for low-confidence
// photos; those never reach the engine.
func UsableReport(r domain.Report) bool {
	return r.GeneratedBy != "fallback" && r.Confidence >= minReportConfidence
}

func usableReports(rs []domain.Report) int {
	n := 0
	for _, r := range rs {
		if UsableReport(r) {
			n++
		}
	}
	return n
}

// reportCorroborated reports whether enough usable reports already existing at t
// sit within corroborationRadiusM and corroborationWindow of r.
func reportCorroborated(r domain.Report, all []domain.Report, t time.Time) bool {
	n := 0
	for _, o := range all {
		if !UsableReport(o) || o.CreatedAt.After(t) {
			continue
		}
		if o.CreatedAt.Sub(r.CreatedAt).Abs() <= corroborationWindow && geo.HaversineM(r.Point(), o.Point()) <= corroborationRadiusM {
			n++
		}
	}
	return n >= corroboratingReportsN
}

// reportDepthCM is the street water a report contributes at t: the full
// DepthCMMax when corroborated, otherwise confidence-weighted and capped.
func reportDepthCM(r domain.Report, all []domain.Report, t time.Time) float64 {
	if t.Before(r.CreatedAt) || t.Sub(r.CreatedAt) >= reportTTL || !UsableReport(r) {
		return 0
	}
	if reportCorroborated(r, all, t) {
		return float64(r.DepthCMMax)
	}
	return math.Min(float64(r.DepthCMMax)*r.Confidence, soloReportCapCM)
}

func nearestSpotName(spots []floodspot.Spot, r domain.Report, l domain.Lang) string {
	best, name := math.Inf(1), unnamedReportSpot
	for _, s := range spots {
		d := math.Hypot(s.Lat-r.Lat, s.Lng-r.Lng)
		if d < best {
			best, name = d, s.ShortName(l)
		}
	}
	return name
}

// verdictFor applies the decision rules for one mode at in.DepartAt.
func verdictFor(in Input, m domain.Mode, evals map[domain.Mode]Eval) (Verdict, *time.Time) {
	e := evals[m]
	if e.Risk == RiskLow || (m == domain.ModeTransit && e.Risk == RiskMedium) {
		return LeaveNow, nil
	}
	tr := evals[domain.ModeTransit]
	if m != domain.ModeTransit && tr.Risk.rank() < e.Risk.rank() && (e.Risk == RiskHigh || (m != domain.ModeMoto && tr.OK())) {
		return SwitchMode, nil
	}
	// A wait that makes an on-time trip late, or a late one later still, is
	// no answer; the train is, when it is no riskier and gets there on time or
	// sooner. Failing that, the first clearing wait still beats staying put.
	var firstClear *time.Time
	start := in.DepartAt
	if in.Now.After(start) {
		start = in.Now
	}
	for t := start.Truncate(15 * time.Minute).Add(15 * time.Minute); !t.After(start.Add(3 * time.Hour)); t = t.Add(15 * time.Minute) {
		if t.Before(in.Now) {
			continue
		}
		later := EvaluateMode(in, m, t)
		if later.Risk != RiskLow {
			continue
		}
		if (e.Late() && later.Arrive.After(e.Arrive)) || (later.Late() && !e.Late()) {
			if firstClear == nil {
				firstClear = &t
			}
			continue
		}
		return Wait, &t
	}
	if firstClear != nil && m != domain.ModeTransit && tr.Risk.rank() <= e.Risk.rank() && (!tr.Late() || tr.Arrive.Before(e.Arrive)) {
		return SwitchMode, nil
	}
	if firstClear != nil {
		return Wait, firstClear
	}
	// A rider waits out a shower; only weather that does not clear calls for the train.
	if m == domain.ModeMoto && tr.OK() {
		return SwitchMode, nil
	}
	return DontGo, nil
}

// LeaveBy is the latest departure, from now, such that leaving at any moment
// until then is low risk and on time. Nil when leaving now is already not OK,
// and when nothing ends the window within the search horizon.
func LeaveBy(in Input, m domain.Mode) *time.Time {
	if !EvaluateMode(in, m, in.Now).OK() {
		return nil
	}
	best := in.Now
	limit := in.Now.Add(6 * time.Hour)
	if !in.ArriveBy.IsZero() && in.ArriveBy.Before(limit) {
		limit = in.ArriveBy
	}
	for t := ceil(in.Now, step); !t.After(limit); t = t.Add(step) {
		if !EvaluateMode(in, m, t).OK() {
			return &best
		}
		best = t
	}
	return nil
}

// weatherEndsLeaveBy reports whether rain or water, rather than the
// appointment, makes departing right after leaveBy not OK.
func weatherEndsLeaveBy(in Input, leaveBy time.Time) bool {
	return EvaluateMode(in, in.Mode, leaveBy.Add(step)).Risk != RiskLow
}

func rainOnset(in Input) *time.Time {
	for _, s := range in.Rain {
		if s.Time.Before(in.Now.Truncate(15*time.Minute)) || s.MMPerHr < rainLight {
			continue
		}
		t := s.Time
		if t.Before(in.Now) {
			t = in.Now
		}
		return &t
	}
	return nil
}

func timeline(in Input) []domain.RainSample {
	from := in.Now.Truncate(time.Hour)
	to := from.Add(5 * time.Hour)
	out := []domain.RainSample{}
	for _, s := range in.Rain {
		if !s.Time.Before(from) && !s.Time.After(to) {
			out = append(out, domain.RainSample{Time: s.Time, MMPerHr: math.Round(s.MMPerHr*10) / 10, ProbPct: s.ProbPct})
		}
	}
	return out
}

func floodSpots(in Input, evals map[domain.Mode]Eval) []FloodSpot {
	window := evals[in.Mode]
	if in.Mode == domain.ModeTransit {
		window = evals[domain.ModeCar]
	}
	var out []FloodSpot
	matchedSensor := map[int]bool{}
	for _, s := range in.Spots {
		d := 0.0
		for t := window.Depart; t.Before(window.Arrive); t = t.Add(step) {
			d = math.Max(d, SpotDepthCMWithTide(s, in.Rain, t, in.Tidal))
		}
		for idx, rs := range in.RoadSensors {
			if geo.HaversineM(domain.LatLng{Lat: s.Lat, Lng: s.Lng}, rs.Point()) <= 300 {
				matchedSensor[idx] = true
				for t := window.Depart; t.Before(window.Arrive); t = t.Add(step) {
					d = math.Max(d, sensorDepthCM(rs, t))
				}
			}
		}
		out = append(out, FloodSpot{ID: s.ID, NameTH: s.Name(in.Lang), Lat: s.Lat, Lng: s.Lng, ExpectedDepthCM: int(math.Round(d)), Risk: depthRisk(d, in.Mode)})
	}
	for idx, rs := range in.RoadSensors {
		if matchedSensor[idx] {
			continue
		}
		d := 0.0
		for t := window.Depart; t.Before(window.Arrive); t = t.Add(step) {
			d = math.Max(d, sensorDepthCM(rs, t))
		}
		if d < 1 {
			continue
		}
		out = append(out, FloodSpot{
			ID:              "sensor-" + rs.Code,
			NameTH:          sensorName(rs, in.Lang),
			Lat:             rs.Lat,
			Lng:             rs.Lng,
			ExpectedDepthCM: int(math.Round(d)),
			Risk:            depthRisk(d, in.Mode),
		})
	}
	for _, r := range in.Reports {
		d := 0.0
		for t := window.Depart; t.Before(window.Arrive); t = t.Add(step) {
			d = math.Max(d, reportDepthCM(r, in.Reports, t))
		}
		if d == 0 {
			continue
		}
		out = append(out, FloodSpot{ID: "report-" + r.ID, NameTH: reportLabel(in, r),
			Lat: r.Lat, Lng: r.Lng, ExpectedDepthCM: int(d), Risk: depthRisk(d, in.Mode)})
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].ExpectedDepthCM > out[j].ExpectedDepthCM })
	return out
}

func reportLabel(in Input, r domain.Report) string {
	near := nearestSpotName(in.Spots, r, in.Lang)
	if in.Lang == domain.LangEN {
		if near == unnamedReportSpot {
			near = "a reported spot"
		}
		return "User report " + r.CreatedAt.Format("15:04") + " near " + near
	}
	return "รายงานผู้ใช้ " + r.CreatedAt.Format("15:04") + " ใกล้" + near
}

func depthRisk(d float64, mode domain.Mode) Risk {
	switch {
	case d >= stallDepthCM(mode):
		return RiskHigh
	case d >= slowDepthCM(mode):
		return RiskMedium
	}
	return RiskLow
}

// confidence decays with forecast horizon, drops when the answer sits on a
// threshold, and rises when people on the ground confirm the water.
func confidence(in Input, e Eval) float64 {
	c := 0.9 - 0.04*e.Arrive.Sub(in.Now).Hours()
	near := func(v, threshold, band float64) bool { return math.Abs(v-threshold) < band }
	if near(e.MaxDepthCM, carSlowDepthCM, 2) || near(e.MaxDepthCM, carStallDepthCM, 3) || near(e.MaxRainMM, rainModerate, 2) {
		c -= 0.08
	}
	for _, r := range in.Reports {
		if UsableReport(r) && !r.CreatedAt.After(in.Now) && in.Now.Sub(r.CreatedAt) < reportTTL {
			c += 0.03
			break
		}
	}
	return math.Round(math.Max(0.4, math.Min(0.95, c))*100) / 100
}

func minutes(n int) time.Duration { return time.Duration(n) * time.Minute }

func ceil(t time.Time, d time.Duration) time.Time {
	if r := t.Truncate(d); r.Equal(t) {
		return t
	} else {
		return r.Add(d)
	}
}
