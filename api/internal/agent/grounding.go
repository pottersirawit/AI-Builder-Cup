package agent

import (
	"math"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
)

// GuardrailTool names the reasoning step that records Gemini text replaced
// by the engine's because it quoted a time the data does not support.
const GuardrailTool = "guardrail_times"

// Trace steps for the other guards: a verdict Gemini proposed that the engine
// does not hold, and a number with a unit that no tool returned.
const (
	GuardrailVerdictTool = "guardrail_verdict"
	GuardrailNumbersTool = "guardrail_numbers"
)

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
	// nums are the numbers with units the engine and tools returned, by unit.
	nums map[string][]float64
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
	g.collectNumbers(resp, core)
	return g
}

// collectNumbers gathers the evidence values numbers in text may quote: flood
// depths, rain rates, ETAs, lateness, wind, the clearance thresholds and the
// minutes between the departure (or appointment) and each known time.
func (g *Grounding) collectNumbers(resp Response, core decision.Result) {
	for unit, vs := range decision.Thresholds() {
		g.addNum(unit, vs...)
	}
	for _, f := range slices.Concat(core.FloodSpots, resp.FloodSpots) {
		g.addNum("cm", float64(f.ExpectedDepthCM))
	}
	for _, e := range core.Evals {
		g.addNum("cm", e.MaxDepthCM)
		g.addNum("mmh", e.MaxRainMM)
		g.addNum("kmh", e.WindGustKMH)
		g.addNum("min", float64(e.Minutes), float64(e.LateMinutes))
	}
	for _, o := range core.ModeOptions {
		g.addNum("min", float64(o.EtaMin))
	}
	for _, r := range core.RainTimeline {
		g.addNum("mmh", r.MMPerHr)
	}
	for _, ref := range []time.Time{resp.DepartAt, resp.Trip.ArriveBy} {
		if ref.IsZero() {
			continue
		}
		var ts []time.Time
		for _, t := range []*time.Time{resp.LeaveBy, core.LeaveBy, core.WaitUntil, core.RainOnset} {
			if t != nil {
				ts = append(ts, *t)
			}
		}
		for _, e := range core.Evals {
			ts = append(ts, e.Depart, e.Arrive)
		}
		for _, r := range core.RainTimeline {
			ts = append(ts, r.Time)
		}
		for _, t := range ts {
			g.addNum("min", math.Abs(t.Sub(ref).Minutes()))
		}
	}
}

func (g *Grounding) addNum(unit string, vs ...float64) {
	if g.nums == nil {
		g.nums = map[string][]float64{}
	}
	g.nums[unit] = append(g.nums[unit], vs...)
}

// AddFacts counts the numbers with units in texts (the tools' own summaries
// and the engine's text) as returned by the tools.
func (g *Grounding) AddFacts(texts ...string) {
	for _, text := range texts {
		for _, q := range unitNumbers(text) {
			g.addNum(q.unit, q.value)
		}
	}
}

// AddToolCalls grounds HH:MM times and travel durations that were explicitly
// returned by tool calls during the session.
func (g *Grounding) AddToolCalls(s *planner.Session) {
	if g.known == nil {
		g.known = map[string]bool{}
	}
	for _, c := range s.Calls() {
		for _, m := range clockTime.FindAllStringSubmatch(c.SummaryTH, -1) {
			g.known[matchHHMM(m)] = true
		}
		if c.Tool == "evaluate_departure" || c.Tool == "get_route" {
			mode := s.Trip.Mode
			if m, ok := c.Args["mode"].(string); ok && domain.Mode(m).Valid() {
				mode = domain.Mode(m)
			}
			depart := s.Now
			if v, ok := c.Args["depart_at"].(string); ok && v != "" {
				if t, err := planner.ParseTime(v, s.Now); err == nil {
					depart = t
				}
			}
			if in, err := s.Input(depart, mode); err == nil {
				ev := decision.EvaluateMode(in, mode, depart)
				g.known[hhmm(ev.Depart)] = true
				g.known[hhmm(ev.Arrive)] = true
				g.addNum("min", float64(ev.Minutes), float64(ev.LateMinutes))
				if lb := decision.LeaveBy(in, mode); lb != nil {
					g.known[hhmm(*lb)] = true
				}
			}
		}
	}
}

var (
	thaiToArabic = strings.NewReplacer("๐", "0", "๑", "1", "๒", "2", "๓", "3", "๔", "4", "๕", "5", "๖", "6", "๗", "7", "๘", "8", "๙", "9")
	spaces       = regexp.MustCompile(`\s+`)
	// num is one number or a range ("10-15"); the unit follows it, so the
	// rain rate (mm/h) is listed before anything shorter that it contains.
	quantityRe = `(\d+(?:\.\d+)?)(?:\s?[-–~]\s?(\d+(?:\.\d+)?))?\s?`
	unitRes    = []struct {
		unit string
		re   *regexp.Regexp
	}{
		{"mmh", regexp.MustCompile(quantityRe + `(?:มม\.?\s?/\s?(?:ชม\.?|ชั่วโมง)|มม\.?\s?ต่อ\s?ชั่วโมง|mm\s?/\s?h(?:r|our)?\b|mm\s?per\s?hour)`)},
		{"kmh", regexp.MustCompile(quantityRe + `(?:กม\.?\s?/\s?(?:ชม\.?|ชั่วโมง)|กิโลเมตรต่อชั่วโมง|km\s?/\s?h(?:r|our)?\b|kph\b|km\s?per\s?hour)`)},
		{"cm", regexp.MustCompile(quantityRe + `(?:ซม\.?|เซนติเมตร|cm\b|centimet(?:re|er)s?\b)`)},
		{"min", regexp.MustCompile(quantityRe + `(?:นาที|min(?:ute)?s?\b)`)},
	}
	// contradicts are phrases that mean "go now", which no wait, switch_mode
	// or dont_go answer may say. Thai has no spaces, so a negation such as
	// "ยังออกไม่ได้เลย" cannot be told from the phrase by pattern; the check
	// accepts that and only catches the plain affirmative forms.
	contradicts = regexp.MustCompile(`(?i)ออกได้เลย|ไปได้เลย|ออกเลย|\bleave now\b|\bgo now\b|\bsafe to leave\b`)
	// negatedEN and negatedTH end the text right before a contradicts match
	// that is negated ("don't leave now", "อย่าไปได้เลย").
	negatedEN = regexp.MustCompile(`(?i)\b(?:don'?t|don’t|do not|never)\s+(?:\w+\s+)?$`)
	negatedTH = regexp.MustCompile(`(?:ไม่|อย่า)(?:เพิ่ง|ควร)?\s*$`)
	// transitNamed is the train a switch_mode answer tells the reader to take
	// now, which is not a contradiction.
	transitNamed = regexp.MustCompile(`(?i)\bBTS\b|\bMRT\b|รถไฟฟ้า|\btrains?\b|\bskytrain\b|\bsubway\b|\bmetro\b`)
	sentenceEnd  = regexp.MustCompile(`[.!?\n]`)
	// Thai marks a clause with a space, not punctuation.
	clauseEndTH = regexp.MustCompile(`[.!?\s]`)
	thaiScript  = regexp.MustCompile(`\p{Thai}`)
)

type quantity struct {
	unit  string
	value float64
	text  string
}

// unitNumbers lists every number with a unit (cm, mm/h, minutes, km/h) in text,
// after normalising Thai digits and whitespace; both ends of a range count.
func unitNumbers(text string) []quantity {
	text = strings.ToLower(spaces.ReplaceAllString(thaiToArabic.Replace(text), " "))
	var out []quantity
	for _, u := range unitRes {
		for _, m := range u.re.FindAllStringSubmatch(text, -1) {
			for _, n := range m[1:3] {
				if n == "" {
					continue
				}
				v, err := strconv.ParseFloat(n, 64)
				if err == nil {
					out = append(out, quantity{u.unit, v, strings.TrimSpace(m[0])})
				}
			}
		}
	}
	return out
}

// UngroundedNumbers lists, once each, the numbers with units in texts that no
// tool or engine value matches within one unit of rounding.
func (g Grounding) UngroundedNumbers(texts ...string) []string {
	var out []string
	for _, text := range texts {
		for _, q := range unitNumbers(text) {
			ok := slices.ContainsFunc(g.nums[q.unit], func(f float64) bool { return math.Abs(math.Round(f)-math.Round(q.value)) <= 1 })
			if !ok && !slices.Contains(out, q.text) {
				out = append(out, q.text)
			}
		}
	}
	return out
}

// Contradicts reports text that tells the reader to leave now when verdict
// says otherwise. For switch_mode, leaving now in a sentence that names the
// train is the advice itself.
func Contradicts(text string, verdict decision.Verdict) bool {
	if verdict == decision.LeaveNow {
		return false
	}
	for _, loc := range contradicts.FindAllStringIndex(text, -1) {
		before := text[:loc[0]]
		if negatedEN.MatchString(before) || negatedTH.MatchString(before) {
			continue
		}
		end := sentenceEnd
		if thaiScript.MatchString(text[loc[0]:loc[1]]) {
			end = clauseEndTH
		}
		if verdict == decision.SwitchMode && transitNamed.MatchString(sentenceAround(text, loc, end)) {
			continue
		}
		return true
	}
	return false
}

func sentenceAround(text string, loc []int, sentenceEnd *regexp.Regexp) string {
	start := 0
	if ends := sentenceEnd.FindAllStringIndex(text[:loc[0]], -1); len(ends) > 0 {
		start = ends[len(ends)-1][1]
	}
	end := len(text)
	if next := sentenceEnd.FindStringIndex(text[loc[1]:]); next != nil {
		end = loc[1] + next[0]
	}
	return text[start:end]
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
