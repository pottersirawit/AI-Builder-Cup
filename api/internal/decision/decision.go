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
)

// Vehicle Clearance Profiles (CONTEXT.md): water depth in cm & wind threshold in km/h.
const (
	carSlowDepthCM           = 5.0  // sedan slows, water sprays the floor
	carStallDepthCM          = 15.0 // sedan clearance
	motoStallDepthCM         = 10.0
	motoWindGustThresholdKMH = 45.0 // gusts > 45 km/h make two-wheelers dangerous
)

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
	RoadViaTH     []string // named roads on the car route, first one is where rain is reported

	Rain        []domain.RainSample
	Spots       []floodspot.Spot // flood spots on the road route
	Reports     []domain.Report  // community reports near the road route
	WindGustKMH float64          // peak wind gust on route (e.g. from WeatherNext 3)
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
	WindGustKMH float64
	DeepestTH   string // short name of the deepest flood spot or report
	Risk        Risk
	LateMinutes int
}

func (e Eval) Late() bool { return e.LateMinutes > 0 }
func (e Eval) OK() bool   { return e.Risk == RiskLow && !e.Late() }

type ModeOption struct {
	Mode    domain.Mode `json:"mode"`
	Verdict Verdict     `json:"verdict"`
	EtaMin  int         `json:"eta_min"`
	Risk    Risk        `json:"risk"`
	NoteTH  string      `json:"note_th"`
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
		res.ModeOptions = append(res.ModeOptions, ModeOption{
			Mode: m, Verdict: v, EtaMin: res.Evals[m].Minutes, Risk: res.Evals[m].Risk,
			NoteTH: modeNote(in, res.Evals[m]),
		})
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
	rain, depth, _ := hazards(in, mode, depart, depart.Add(minutes(base)))
	delay := 0
	switch mode {
	case domain.ModeCar:
		if rain >= rainModerate {
			delay += 10
		}
		if depth >= carSlowDepthCM {
			delay += 20
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
	e.MaxRainMM, e.MaxDepthCM, e.DeepestTH = hazards(in, mode, depart, e.Arrive)
	e.Risk = riskFor(mode, e.MaxRainMM, e.MaxDepthCM, in.WindGustKMH)
	if !in.ArriveBy.IsZero() && e.Arrive.After(in.ArriveBy) {
		e.LateMinutes = int(math.Ceil(e.Arrive.Sub(in.ArriveBy).Minutes()))
	}
	return e
}

func riskFor(mode domain.Mode, rain, depth, windGustKMH float64) Risk {
	switch mode {
	case domain.ModeCar:
		if depth >= carStallDepthCM {
			return RiskHigh
		}
		if depth >= carSlowDepthCM || rain >= rainModerate {
			return RiskMedium
		}
	case domain.ModeMoto:
		if depth >= motoStallDepthCM || rain >= rainModerate || windGustKMH >= motoWindGustThresholdKMH {
			return RiskHigh
		}
		if depth >= 1 || rain >= rainLight || windGustKMH >= 30.0 {
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

// hazards returns the worst rain and street water met between from and to.
// Transit ignores street water.
func hazards(in Input, mode domain.Mode, from, to time.Time) (rain, depth float64, deepest string) {
	for t := from; t.Before(to); t = t.Add(step) {
		rain = math.Max(rain, RainAt(in.Rain, t))
		if mode == domain.ModeTransit {
			continue
		}
		for _, s := range in.Spots {
			if d := SpotDepthCM(s, in.Rain, t); d > depth {
				depth, deepest = d, s.ShortNameTH()
			}
		}
		for _, r := range in.Reports {
			if d := reportDepthCM(r, in.Reports, t); d > depth {
				depth, deepest = d, nearestSpotName(in.Spots, r)
			}
		}
	}
	return rain, depth, deepest
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

func nearestSpotName(spots []floodspot.Spot, r domain.Report) string {
	best, name := math.Inf(1), unnamedReportSpot
	for _, s := range spots {
		d := math.Hypot(s.Lat-r.Lat, s.Lng-r.Lng)
		if d < best {
			best, name = d, s.ShortNameTH()
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
	if m != domain.ModeTransit {
		tr := evals[domain.ModeTransit]
		if tr.Risk.rank() < e.Risk.rank() && (e.Risk == RiskHigh || tr.OK()) {
			return SwitchMode, nil
		}
	}
	for t := in.DepartAt.Truncate(15 * time.Minute).Add(15 * time.Minute); !t.After(in.DepartAt.Add(3 * time.Hour)); t = t.Add(15 * time.Minute) {
		if EvaluateMode(in, m, t).Risk == RiskLow {
			return Wait, &t
		}
	}
	return DontGo, nil
}

// LeaveBy is the latest departure, from now, such that leaving at any moment
// until then is low risk and on time. Nil when leaving now is already not OK.
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
			break
		}
		best = t
	}
	return &best
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
			out = append(out, domain.RainSample{Time: s.Time, MMPerHr: math.Round(s.MMPerHr*10) / 10})
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
	for _, s := range in.Spots {
		d := 0.0
		for t := window.Depart; t.Before(window.Arrive); t = t.Add(step) {
			d = math.Max(d, SpotDepthCM(s, in.Rain, t))
		}
		out = append(out, FloodSpot{ID: s.ID, NameTH: s.NameTH, Lat: s.Lat, Lng: s.Lng, ExpectedDepthCM: int(math.Round(d)), Risk: depthRisk(d)})
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
			Lat: r.Lat, Lng: r.Lng, ExpectedDepthCM: int(d), Risk: depthRisk(d)})
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].ExpectedDepthCM > out[j].ExpectedDepthCM })
	return out
}

func reportLabel(in Input, r domain.Report) string {
	near := nearestSpotName(in.Spots, r)
	if in.Lang == domain.LangEN {
		if near == unnamedReportSpot {
			near = "a reported spot"
		}
		return "User report " + r.CreatedAt.Format("15:04") + " near " + near
	}
	return "รายงานผู้ใช้ " + r.CreatedAt.Format("15:04") + " ใกล้" + near
}

func depthRisk(d float64) Risk {
	switch {
	case d >= carStallDepthCM:
		return RiskHigh
	case d >= carSlowDepthCM:
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
		if !r.CreatedAt.After(in.Now) && in.Now.Sub(r.CreatedAt) < reportTTL {
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
