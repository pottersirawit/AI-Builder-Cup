package agent

import (
	"regexp"
	"slices"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
)

// GuardrailTool names the reasoning step that records Gemini text replaced
// by the engine's because it quoted a time the data does not support.
const GuardrailTool = "guardrail_times"

var (
	// clockTime matches HH:MM, the format the system prompt asks for.
	clockTime = regexp.MustCompile(`(?:^|[^0-9])([01]?[0-9]|2[0-3]):([0-5][0-9])`)
	// leaveBefore matches "ออกก่อน HH:MM", which can only mean the leave-by.
	leaveBefore = regexp.MustCompile(`ออก(?:เดินทาง)?ก่อน\s*(?:เวลา\s*)?([01]?[0-9]|2[0-3]):([0-5][0-9])`)
	// leaveBeforeEN is the English "leave by HH:MM" and "leave before HH:MM".
	leaveBeforeEN = regexp.MustCompile(`(?i)\bleave\s+(?:by|before)\s+(?:about\s+|around\s+)?([01]?[0-9]|2[0-3]):([0-5][0-9])`)
)

// Grounding is what an answer's text may say about time: the HH:MM readings
// the engine and tools returned, and the engine's leave-by.
type Grounding struct {
	known   map[string]bool
	leaveBy string
}

// NewGrounding collects the clock, the departure, the appointment, the
// engine's leave-by, wait-until and rain onset, each mode's departure and
// arrival, the rain timeline and extra (see ToolTimes).
func NewGrounding(resp Response, core decision.Result, extra ...time.Time) Grounding {
	g := Grounding{known: map[string]bool{}}
	add := func(t time.Time) {
		if !t.IsZero() {
			g.known[hhmm(t)] = true
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
	if core.LeaveBy != nil {
		g.leaveBy = hhmm(*core.LeaveBy)
	}
	return g
}

// ToolTimes are times the tools returned beyond core's own: community
// report times and the arrival when leaving at the engine's wait-until.
func ToolTimes(s *planner.Session, depart time.Time, mode domain.Mode, core decision.Result) []time.Time {
	var out []time.Time
	if in, err := s.Input(depart, mode); err == nil {
		for _, r := range in.Reports {
			out = append(out, r.CreatedAt)
		}
	}
	if core.WaitUntil != nil {
		if later, err := s.Baseline(*core.WaitUntil, mode); err == nil {
			out = append(out, later.Evals[mode].Arrive)
		}
	}
	return out
}

// Ungrounded lists, once each, the HH:MM times in texts that no tool
// returned, and any "ออกก่อน HH:MM" or "leave by HH:MM" that is not the engine's leave-by.
func (g Grounding) Ungrounded(texts ...string) []string {
	var out []string
	add := func(t string) {
		if !slices.Contains(out, t) {
			out = append(out, t)
		}
	}
	for _, text := range texts {
		for _, m := range clockTime.FindAllStringSubmatch(text, -1) {
			if t := matchHHMM(m); !g.known[t] {
				add(t)
			}
		}
		if g.leaveBy == "" {
			continue
		}
		for _, re := range []*regexp.Regexp{leaveBefore, leaveBeforeEN} {
			for _, m := range re.FindAllStringSubmatch(text, -1) {
				if t := matchHHMM(m); t != g.leaveBy {
					add(t)
				}
			}
		}
	}
	return out
}

func matchHHMM(m []string) string {
	if len(m[1]) == 1 {
		return "0" + m[1] + ":" + m[2]
	}
	return m[1] + ":" + m[2]
}

func hhmm(t time.Time) string { return t.In(domain.Bangkok).Format("15:04") }
