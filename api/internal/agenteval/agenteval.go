// Package agenteval scores the /v1/decide agent against the scripted
// 29 September storm: every demo time x mode plus the demo questions. Each
// answer is checked against the deterministic engine (safety, agreement,
// grounded clock times, required tools, headline length, explanation), and
// optionally rated by a Gemini judge for natural Thai. Without Gemini it
// scores the fallback path, so the suite also guards the demo offline.
package agenteval

import (
	"context"
	"fmt"
	"regexp"
	"slices"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
	"github.com/pottersirawit/fontokmai/api/internal/reports"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

// Check names, in report order.
const (
	CheckValidVerdict   = "valid_verdict"
	CheckSafeForMode    = "safe_for_mode"
	CheckDemoScript     = "matches_demo_script"
	CheckAgreesWithCore = "agrees_with_core"
	CheckRequiredTools  = "required_tools"
	CheckGroundedTimes  = "grounded_times"
	CheckHeadlineLength = "headline_length"
	CheckExplanation    = "explanation_complete"
)

var checkOrder = []string{CheckValidVerdict, CheckSafeForMode, CheckDemoScript, CheckAgreesWithCore,
	CheckRequiredTools, CheckGroundedTimes, CheckHeadlineLength, CheckExplanation}

// RequiredTools are the tools the system prompt says the agent must call.
var RequiredTools = []string{"get_trip", "get_rain_along_route", "get_flood_spots_on_route", "evaluate_departure"}

// MaxHeadlineRunes is the headline limit the system prompt sets.
const MaxHeadlineRunes = 30

// Case is one decision request at one demo-clock time.
type Case struct {
	Name string
	Now  time.Time
	Req  agent.Request
	// WantVerdict is the verdict the demo script relies on; empty means the
	// case is only compared with the deterministic engine.
	WantVerdict decision.Verdict
}

// Check is one pass/fail judgement on an answer.
type Check struct {
	Name   string `json:"name"`
	Pass   bool   `json:"pass"`
	Detail string `json:"detail,omitempty"`
}

// Result is one scored case.
type Result struct {
	Case        string           `json:"case"`
	GeneratedBy string           `json:"generated_by"`
	Verdict     decision.Verdict `json:"verdict"`
	CoreVerdict decision.Verdict `json:"core_verdict"`
	Mode        domain.Mode      `json:"mode"`
	HeadlineTH  string           `json:"headline_th"`
	SummaryTH   string           `json:"summary_th"`
	Tools       []string         `json:"tools"`
	LatencyMS   int64            `json:"latency_ms"`
	Checks      []Check          `json:"checks"`
	Judge       *JudgeScore      `json:"judge,omitempty"`
	JudgeErr    string           `json:"judge_error,omitempty"`
	Err         string           `json:"error,omitempty"`
}

// Passed is true when the case ran and every check passed. The judge's score
// is reported alongside, never a pass/fail gate.
func (r Result) Passed() bool {
	if r.Err != "" {
		return false
	}
	for _, c := range r.Checks {
		if !c.Pass {
			return false
		}
	}
	return true
}

// Report is a full run.
type Report struct {
	Model   string    `json:"model"`
	RanAt   time.Time `json:"ran_at"`
	Results []Result  `json:"results"`
}

// Options tune a run.
type Options struct {
	// Judge asks Gemini to rate each answer's Thai (needs Gemini).
	Judge bool
}

// Providers are the scenario providers with a fresh report store, so every
// case sees only the seeded reports its clock has reached.
func Providers() planner.Providers {
	return planner.Providers{Weather: scenario.Weather{}, Routes: scenario.Routes{}, Canals: scenario.Canals{},
		Reports: reports.NewMemoryStore(scenario.SeedReports()...)}
}

func demoAt(hh, mm int) time.Time { return time.Date(2026, 9, 29, hh, mm, 0, 0, domain.Bangkok) }

// DemoCases are the demo beats (docs/ai/HANDOFF.md) for every mode on มิว's
// dinner trip, plus the questions the video asks in plain Thai. 19:30 has no
// scripted verdict: with the seeded Ratchada reports (18:41, 18:47) still
// trusted, the engine says switch to BTS, not the "wait until 20:00" of the
// report-free beat.
func DemoCases() []Case {
	scripted := map[string]decision.Verdict{
		"16:10/car":  decision.LeaveNow,
		"17:15/moto": decision.SwitchMode,
		"18:55/car":  decision.SwitchMode,
	}
	var cases []Case
	for _, clock := range []struct{ hh, mm int }{{16, 10}, {17, 15}, {18, 0}, {18, 55}, {19, 30}} {
		for _, m := range domain.AllModes {
			key := fmt.Sprintf("%02d:%02d/%s", clock.hh, clock.mm, m)
			cases = append(cases, Case{
				Name: key, Now: demoAt(clock.hh, clock.mm), WantVerdict: scripted[key],
				Req: agent.Request{TripID: "cal-dinner", Mode: string(m)},
			})
		}
	}
	for _, q := range []string{"ถ้ารอถึงสองทุ่มค่อยกลับล่ะ", "ไป BTS แทนดีไหม", "ไปสยามตอนหกโมงดีไหม", "นั่งมอไซค์ไปตอนห้าโมงครึ่งได้ไหม"} {
		cases = append(cases, Case{Name: "16:10 \"" + q + "\"", Now: demoAt(16, 10), Req: agent.Request{QuestionTH: q}})
	}
	return cases
}

// Run decides every case (with Gemini when g is available, else the
// fallback) and scores it. A case that cannot be decided is reported with Err.
func Run(ctx context.Context, g *agent.Gemini, p *planner.Planner, cases []Case, opts Options) Report {
	rep := Report{Model: "fallback", RanAt: time.Now().In(domain.Bangkok)}
	if g.Available() {
		rep.Model = g.Model
	}
	for _, c := range cases {
		rep.Results = append(rep.Results, runCase(ctx, g, p, c, opts))
	}
	return rep
}

func runCase(ctx context.Context, g *agent.Gemini, p *planner.Planner, c Case, opts Options) Result {
	res := Result{Case: c.Name}
	tr, err := c.Req.TripRequest()
	if err != nil {
		res.Err = err.Error()
		return res
	}
	prov := Providers()
	s, err := p.Open(ctx, prov, c.Now, tr)
	if err != nil {
		res.Err = err.Error()
		return res
	}
	sources := []string{prov.Weather.Name(), prov.Routes.Name(), prov.Canals.Name(), "BMA flood spots"}
	start := time.Now()
	resp, err := agent.Decide(ctx, g, s, c.Req, sources)
	res.LatencyMS = time.Since(start).Milliseconds()
	if err != nil {
		res.Err = err.Error()
		return res
	}
	core, err := s.Baseline(resp.DepartAt, resp.Mode)
	if err != nil {
		res.Err = err.Error()
		return res
	}
	// Times the tools returned beyond core's own: report times and the
	// arrival when leaving at the engine's wait-until.
	var toolTimes []time.Time
	if in, err := s.Input(resp.DepartAt, resp.Mode); err == nil {
		for _, r := range in.Reports {
			toolTimes = append(toolTimes, r.CreatedAt)
		}
	}
	if core.WaitUntil != nil {
		if later, err := s.Baseline(*core.WaitUntil, resp.Mode); err == nil {
			toolTimes = append(toolTimes, later.Evals[resp.Mode].Arrive)
		}
	}
	res.GeneratedBy, res.Verdict, res.CoreVerdict, res.Mode = resp.GeneratedBy, resp.Verdict, core.Verdict, resp.Mode
	res.HeadlineTH, res.SummaryTH, res.Tools = resp.HeadlineTH, resp.SummaryTH, tools(resp)
	res.Checks = Score(c, resp, core, toolTimes...)
	if opts.Judge && g.Available() {
		j, err := Judge(ctx, g, resp, core)
		if err != nil {
			res.JudgeErr = err.Error()
		} else {
			res.Judge = &j
		}
	}
	return res
}

func tools(resp agent.Response) []string {
	var out []string
	for _, c := range resp.Reasoning {
		out = append(out, c.Tool)
	}
	return out
}

// clockTime matches HH:MM, the format the system prompt asks for.
var clockTime = regexp.MustCompile(`(?:^|[^0-9])([01]?[0-9]|2[0-3]):([0-5][0-9])`)

// Score checks one answer against the deterministic engine's result for the
// same departure and mode. extra are further times the tools returned (such
// as community report times) that the text may quote.
func Score(c Case, resp agent.Response, core decision.Result, extra ...time.Time) []Check {
	var out []Check
	add := func(name string, pass bool, detail string) {
		out = append(out, Check{Name: name, Pass: pass, Detail: detail})
	}

	add(CheckValidVerdict, resp.Verdict.Valid(), string(resp.Verdict))

	risk := core.Evals[resp.Mode].Risk
	add(CheckSafeForMode, !(resp.Verdict == decision.LeaveNow && risk == decision.RiskHigh),
		fmt.Sprintf("%s by %s, engine risk %s", resp.Verdict, resp.Mode, risk))

	if c.WantVerdict != "" {
		add(CheckDemoScript, resp.Verdict == c.WantVerdict, fmt.Sprintf("got %s, script wants %s", resp.Verdict, c.WantVerdict))
	}
	add(CheckAgreesWithCore, resp.Verdict == core.Verdict, fmt.Sprintf("got %s, engine says %s", resp.Verdict, core.Verdict))

	called := tools(resp)
	var missing []string
	for _, t := range RequiredTools {
		if !slices.Contains(called, t) {
			missing = append(missing, t)
		}
	}
	add(CheckRequiredTools, len(missing) == 0, "missing "+strings.Join(missing, ", "))

	known := groundedTimes(resp, core, extra)
	var invented []string
	for _, text := range []string{resp.HeadlineTH, resp.SummaryTH, resp.Explanation.ReasonWhyTH, resp.Explanation.RouteAdviceTH} {
		for _, m := range clockTime.FindAllStringSubmatch(text, -1) {
			hh := m[1]
			if len(hh) == 1 {
				hh = "0" + hh
			}
			hhmm := hh + ":" + m[2]
			if !known[hhmm] && !slices.Contains(invented, hhmm) {
				invented = append(invented, hhmm)
			}
		}
	}
	add(CheckGroundedTimes, len(invented) == 0, "times not in tool data: "+strings.Join(invented, ", "))

	n := utf8.RuneCountInString(resp.HeadlineTH)
	add(CheckHeadlineLength, n > 0 && n <= MaxHeadlineRunes, fmt.Sprintf("%d characters", n))

	add(CheckExplanation, resp.Explanation.ReasonWhyTH != "" && len(resp.Explanation.FactorsTH) > 0,
		"reason_why_th and factors_th are required")

	for i := range out {
		if out[i].Pass && out[i].Name != CheckHeadlineLength {
			out[i].Detail = ""
		}
	}
	return out
}

// groundedTimes are the HH:MM readings an answer may quote: the clock, the
// departure, the appointment, the engine's leave-by, wait-until and rain
// onset, each mode's arrival, the rain timeline and report times.
func groundedTimes(resp agent.Response, core decision.Result, extra []time.Time) map[string]bool {
	known := map[string]bool{}
	add := func(t time.Time) {
		if !t.IsZero() {
			known[t.In(domain.Bangkok).Format("15:04")] = true
		}
	}
	add(resp.DepartAt)
	add(resp.Trip.ArriveBy)
	for _, t := range []*time.Time{resp.LeaveBy, core.LeaveBy, core.WaitUntil, core.RainOnset} {
		if t != nil {
			add(*t)
		}
	}
	for _, e := range core.Evals {
		add(e.Depart)
		add(e.Arrive)
	}
	for _, r := range core.RainTimeline {
		add(r.Time)
	}
	for _, t := range extra {
		add(t)
	}
	return known
}
