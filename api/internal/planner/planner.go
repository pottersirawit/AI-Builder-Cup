// Package planner gathers everything one decision needs from the providers and
// exposes it as the tool box the Gemini agent calls (get_trip, get_route, ...).
// The fallback path calls the same tools, so `reasoning` always lists real calls.
package planner

import (
	"context"
	"errors"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
	"github.com/pottersirawit/fontokmai/api/internal/reports"
)

// Providers are the data sources for one request (scenario or live).
type Providers struct {
	Weather domain.WeatherProvider
	Routes  domain.RouteProvider
	Canals  domain.CanalProvider
	Reports domain.ReportStore
}

// Planner holds static data shared by all requests.
type Planner struct {
	Spots []floodspot.Spot
	Trips func(now time.Time) []domain.Trip
}

var ErrUnknownTrip = errors.New("unknown trip")

// Call is one tool invocation, as shown in the "Gemini คิดแบบนี้" trace.
type Call struct {
	Tool      string         `json:"tool"`
	Args      map[string]any `json:"-"`
	SummaryTH string         `json:"summary_th"`
}

// Session is one decision: a trip, a clock reading, cached provider results
// and the log of tool calls.
type Session struct {
	ctx  context.Context
	p    *Planner
	prov Providers
	Now  time.Time
	Trip domain.Trip

	routes  map[string]domain.Route
	rain    []domain.RainSample
	rainSet bool
	calls   []Call
}

func (p *Planner) NewSession(ctx context.Context, prov Providers, now time.Time, tripID string) (*Session, error) {
	trips := p.Trips(now)
	if len(trips) == 0 {
		return nil, ErrUnknownTrip
	}
	s := &Session{ctx: ctx, p: p, prov: prov, Now: now, routes: map[string]domain.Route{}}
	if tripID == "" {
		s.Trip = trips[0]
		return s, nil
	}
	for _, t := range trips {
		if t.ID == tripID {
			s.Trip = t
			return s, nil
		}
	}
	return nil, fmt.Errorf("%w %q", ErrUnknownTrip, tripID)
}

func (s *Session) Calls() []Call { return append([]Call(nil), s.calls...) }

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
	in := decision.Input{
		Now: s.Now, DepartAt: depart, ArriveBy: s.Trip.ArriveBy, Mode: mode,
		DestinationTH: s.Trip.Destination.NameTH, RoadViaTH: road.ViaTH,
		Rain: rain, Spots: floodspot.OnRoute(s.p.Spots, road.Polyline), Reports: reps,
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
		out, summary = map[string]any{"error": err.Error()}, "เรียกข้อมูลไม่สำเร็จ: "+err.Error()
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
		return map[string]any{"trip": t, "now": s.Now.Format(time.RFC3339)},
			fmt.Sprintf("นัด%s ต้องถึง%sก่อน %s (%s)", t.TitleTH, t.Destination.NameTH, hhmm(t.ArriveBy), sourceTH(t.Source)), nil

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
		via := strings.Join(r.ViaTH, " → ")
		return map[string]any{"mode": mode, "depart_at": depart.Format(time.RFC3339), "duration_min": mins, "via_th": r.ViaTH, "source": r.Source},
			fmt.Sprintf("%s ออก %s ใช้เวลา %d นาที ผ่าน %s", mode.NameTH(), hhmm(depart), mins, via), nil

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
		summary := "ไม่มีฝนบนเส้นทางใน 5 ชั่วโมงข้างหน้า"
		if onset != nil {
			where := "เส้นทาง"
			if len(road.ViaTH) > 0 {
				where = road.ViaTH[0]
			}
			summary = fmt.Sprintf("ฝนถึง%s ราว %s หนักสุด %.0f มม./ชม. ตอน %s", where, hhmm(onset.Time), peak.MMPerHr, hhmm(peak.Time))
		}
		return map[string]any{"samples": samples, "source": s.prov.Weather.Name()}, summary, nil

	case "get_flood_spots_on_route":
		res, err := s.Baseline(depart, mode)
		if err != nil {
			return nil, "", err
		}
		summary := fmt.Sprintf("เส้นทางผ่านจุดเสี่ยงน้ำท่วม %d จุด", len(res.FloodSpots))
		if len(res.FloodSpots) > 0 {
			d := res.FloodSpots[0]
			if d.ExpectedDepthCM > 0 {
				summary += fmt.Sprintf(" ลึกสุดคาด %d ซม. ที่ %s ถ้าออก %s", d.ExpectedDepthCM, d.NameTH, hhmm(depart))
			} else {
				summary += fmt.Sprintf(" ออก %s ยังไม่มีน้ำขัง", hhmm(depart))
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
		summary := "ไม่มีข้อมูลคลองใกล้ปลายทาง"
		if len(canals) > 0 {
			c := canals[0]
			summary = fmt.Sprintf("%s %.1f ม. ตลิ่ง %.1f ม. (ต่ำกว่าตลิ่ง %.0f ซม.)", c.NameTH, c.LevelM, c.BankM, math.Max(0, (c.BankM-c.LevelM)*100))
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
		summary := "ยังไม่มีรายงานน้ำท่วมจากผู้ใช้บนเส้นทางในชั่วโมงที่ผ่านมา"
		if len(reps) > 0 {
			last := reps[len(reps)-1]
			summary = fmt.Sprintf("รายงานจากผู้ใช้ %d รายการบนเส้นทาง ล่าสุด %s น้ำ %d-%d ซม.", len(reps), hhmm(last.CreatedAt), last.DepthCMMin, last.DepthCMMax)
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
	}
	return "พิมพ์ถามเอง"
}

func riskTH(r decision.Risk) string {
	return map[decision.Risk]string{decision.RiskLow: "ต่ำ", decision.RiskMedium: "ปานกลาง", decision.RiskHigh: "สูง"}[r]
}
