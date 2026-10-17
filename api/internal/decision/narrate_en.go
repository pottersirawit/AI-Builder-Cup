package decision

import (
	"fmt"
	"strings"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

// narrateEN is narrate in English: the same facts and the same shape rules
// (headline of at most 30 characters), in short friendly sentences. Place and
// road names come from Thai datasets, so they appear only when written in
// Latin letters; otherwise the text says "on your route".
func narrateEN(in Input, res Result) (headline, summary string, exp Explanation) {
	e := res.Evals[in.Mode]
	leavingNow := e.Depart.Sub(in.Now) < 10*time.Minute
	when := "If you leave at " + hhmm(e.Depart)
	if leavingNow {
		when = "If you leave now"
	}
	var parts []string

	switch res.Verdict {
	case LeaveNow:
		switch {
		case e.Late():
			headline = fmt.Sprintf("Leave %s, late for %s", hhmm(e.Depart), hhmm(in.ArriveBy))
		case res.LeaveBy != nil && !e.Depart.After(*res.LeaveBy) && res.LeaveBy.Sub(in.Now) >= 10*time.Minute:
			headline = "Leave by " + hhmm(*res.LeaveBy)
		case leavingNow:
			headline = "Good to go now"
		default:
			headline = fmt.Sprintf("OK to leave at %s", hhmm(e.Depart))
		}
		if res.RainOnset != nil && res.RainOnset.After(e.Arrive) {
			parts = append(parts, "Rain starts on your route around "+hhmm(*res.RainOnset)+".")
		}
		parts = append(parts, conditionsEN(e))
		parts = append(parts, fmt.Sprintf("%s, the trip takes %d min and you arrive%s around %s%s.", when, e.Minutes, atEN(in.DestinationTH), hhmm(e.Arrive), deadlineEN(in, e)))
		if res.LeaveBy != nil && !e.Late() && res.LeaveBy.Sub(in.Now) >= 10*time.Minute && res.RainOnset != nil && weatherEndsLeaveBy(in, *res.LeaveBy) {
			parts = append(parts, fmt.Sprintf("If you leave after %s you will hit rain on the way.", hhmm(*res.LeaveBy)))
		}
		if in.Mode == domain.ModeTransit && e.MaxRainMM >= rainLight {
			parts = append(parts, "Bring an umbrella for the walk from the station.")
		}
	case SwitchMode:
		tr := res.Evals[domain.ModeTransit]
		headline = "Take BTS / MRT instead"
		parts = append(parts, fmt.Sprintf("%s by %s, you would hit %s.", when, in.Mode.NameFor(domain.LangEN), hazardEN(e)))
		parts = append(parts, fmt.Sprintf("BTS / MRT stays clear of the water. It takes %d min and you arrive%s around %s%s.", tr.Minutes, atEN(in.DestinationTH), hhmm(tr.Arrive), deadlineEN(in, tr)))
	case Wait:
		headline = fmt.Sprintf("Wait until %s", hhmm(*res.WaitUntil))
		later := EvaluateMode(in, in.Mode, *res.WaitUntil)
		parts = append(parts, fmt.Sprintf("%s, you would hit %s.", when, hazardEN(e)))
		parts = append(parts, fmt.Sprintf("Leaving at %s, you arrive%s around %s%s.", hhmm(later.Depart), atEN(in.DestinationTH), hhmm(later.Arrive), deadlineEN(in, later)))
	case DontGo:
		headline = "Don't leave yet"
		parts = append(parts, fmt.Sprintf("%s, you would hit %s.", when, hazardEN(e)))
		parts = append(parts, "Every option is still risky for the next 3 hours. Stay somewhere safe and wait for updates.")
	}
	exp = buildExplanationEN(in, res)
	return headline, strings.Join(nonEmpty(parts), " "), exp
}

func clearanceEN(m domain.Mode) string {
	switch m {
	case domain.ModeCar:
		return "a sedan's 15 cm"
	case domain.ModeMoto:
		return "a motorbike's 10 cm"
	default:
		return "rail and elevated track"
	}
}

func buildExplanationEN(in Input, res Result) Explanation {
	e := res.Evals[in.Mode]
	tr := res.Evals[domain.ModeTransit]
	mode := in.Mode.NameFor(domain.LangEN)
	var exp Explanation

	switch res.Verdict {
	case LeaveNow:
		switch {
		case res.LeaveBy != nil && res.LeaveBy.Sub(in.Now) >= 10*time.Minute && weatherEndsLeaveBy(in, *res.LeaveBy):
			exp.ReasonWhyTH = fmt.Sprintf("We suggest leaving by %s (%s) so you get there before heavy rain builds up and floods the route.", hhmm(*res.LeaveBy), mode)
		case res.LeaveBy != nil && res.LeaveBy.Sub(in.Now) >= 10*time.Minute && !in.ArriveBy.IsZero():
			exp.ReasonWhyTH = fmt.Sprintf("We suggest leaving by %s (%s) to make your %s appointment.", hhmm(*res.LeaveBy), mode, hhmm(in.ArriveBy))
		case res.LeaveBy != nil && res.LeaveBy.Sub(in.Now) >= 10*time.Minute:
			exp.ReasonWhyTH = fmt.Sprintf("We suggest leaving by %s (%s).", hhmm(*res.LeaveBy), mode)
		case e.Late():
			exp.ReasonWhyTH = fmt.Sprintf("The route is passable by %s, but you would arrive %d min past your %s appointment.", mode, e.LateMinutes, hhmm(in.ArriveBy))
		default:
			exp.ReasonWhyTH = fmt.Sprintf("Conditions on your route are safe right now: no heavy rain and no standing water in the way. You can head out by %s.", mode)
		}
	case SwitchMode:
		switch {
		case e.MaxDepthCM >= 1 && e.Risk == RiskHigh:
			exp.ReasonWhyTH = fmt.Sprintf("We suggest taking BTS / MRT instead of the %s because there is about %.0f cm of standing water%s, beyond the safe clearance (%s). Trains run above or below the street, so flooding does not affect them.",
				mode, e.MaxDepthCM, whereEN(e.DeepestTH), clearanceEN(in.Mode))
		case e.MaxDepthCM >= 1:
			exp.ReasonWhyTH = fmt.Sprintf("We suggest taking BTS / MRT instead of the %s because about %.0f cm of standing water%s will slow you down (safe clearance: %s). Trains run above or below the street, so flooding does not affect them.",
				mode, e.MaxDepthCM, whereEN(e.DeepestTH), clearanceEN(in.Mode))
		case e.WindGustKMH >= motoWindGustThresholdKMH && in.Mode == domain.ModeMoto:
			exp.ReasonWhyTH = fmt.Sprintf("We suggest taking BTS / MRT instead of the motorbike because wind gusts of %.0f km/h on the route make it easy to lose control.", e.WindGustKMH)
		case e.Risk == RiskHigh:
			exp.ReasonWhyTH = fmt.Sprintf("We suggest taking BTS / MRT because the road route is high risk in this weather. The train takes about %d min and is safer.", tr.Minutes)
		case e.MaxRainMM < rainLight && e.WindGustKMH >= motoWindGustCautionKMH:
			exp.ReasonWhyTH = fmt.Sprintf("We suggest taking BTS / MRT instead of the %s because wind gusts of %.0f km/h on the route make riding harder. The train takes about %d min.", mode, e.WindGustKMH, tr.Minutes)
		default:
			exp.ReasonWhyTH = fmt.Sprintf("We suggest taking BTS / MRT instead of the %s because of rain on the way (about %.0f mm/h) and slick roads. The train takes about %d min.", mode, e.MaxRainMM, tr.Minutes)
		}
	case Wait:
		if res.WaitUntil != nil {
			exp.ReasonWhyTH = fmt.Sprintf("We suggest waiting until %s so the standing water%s can drain and the rain can ease before you travel by %s.", hhmm(*res.WaitUntil), whereEN(e.DeepestTH), mode)
		} else {
			exp.ReasonWhyTH = fmt.Sprintf("We suggest holding off on travelling by %s until the standing water on the route has drained.", mode)
		}
	case DontGo:
		exp.ReasonWhyTH = "It is not a good time to set out. Weather and flooding are high risk on every route and for every way of travelling, so stay indoors somewhere safe."
	}

	if res.RainOnset != nil {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("Rain: starts on your route around %s (peak %.0f mm/h)", hhmm(*res.RainOnset), e.MaxRainMM))
	} else if e.MaxRainMM >= rainLight {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("Rain: up to %.0f mm/h on the way", e.MaxRainMM))
	} else {
		exp.FactorsTH = append(exp.FactorsTH, "Rain: no rain band building on your route yet")
	}

	if e.MaxDepthCM >= 1 {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("Water depth: up to about %.0f cm%s (safe clearance: %s)", e.MaxDepthCM, whereEN(e.DeepestTH), clearanceEN(in.Mode)))
	} else {
		exp.FactorsTH = append(exp.FactorsTH, "Water depth: no standing water found on the route")
	}

	if e.WindGustKMH >= motoWindGustCautionKMH {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("Wind: gusts up to %.0f km/h (motorbike caution threshold is %.0f km/h)", e.WindGustKMH, motoWindGustThresholdKMH))
	}

	if !in.ArriveBy.IsZero() {
		if e.Late() {
			exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("Appointment: %s (expected arrival %s, %d min late)", hhmm(in.ArriveBy), hhmm(e.Arrive), e.LateMinutes))
		} else {
			exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("Appointment: %s (expected arrival %s, on time)", hhmm(in.ArriveBy), hhmm(e.Arrive)))
		}
	} else {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("Travel time: about %d min, arriving around %s", e.Minutes, hhmm(e.Arrive)))
	}

	if len(in.Reports) > 0 {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("Community reports: %d real flood reports near your route", len(in.Reports)))
	}

	for _, s := range res.FloodSpots {
		if s.ExpectedDepthCM > 0 || s.Risk == RiskHigh || s.Risk == RiskMedium {
			exp.AvoidSpotsTH = append(exp.AvoidSpotsTH, s.NameTH)
		}
	}
	if len(exp.AvoidSpotsTH) == 0 && e.MaxDepthCM >= 1 && e.DeepestTH != "" {
		exp.AvoidSpotsTH = append(exp.AvoidSpotsTH, e.DeepestTH)
	}

	if len(exp.AvoidSpotsTH) > 0 {
		spots := "the flood-prone spots listed below"
		if latin := latinOnly(exp.AvoidSpotsTH); len(latin) > 0 {
			spots = strings.Join(latin, ", ")
		}
		if res.Verdict == SwitchMode {
			exp.RouteAdviceTH = fmt.Sprintf("Skip the road route past %s and take BTS / MRT. If you have to drive, use the elevated expressway to get around the flooded spots.", spots)
		} else {
			exp.RouteAdviceTH = fmt.Sprintf("Watch for flooding at %s. If heavy rain hits, switch to the elevated expressway or a nearby main road.", spots)
		}
	} else if in.Mode == domain.ModeTransit {
		exp.RouteAdviceTH = "Your train route is not affected by flooded roads, so travel as normal."
		if e.MaxRainMM >= rainLight {
			exp.RouteAdviceTH = "Your train route is not affected by flooded roads, so travel as normal (bring an umbrella for the walk to and from the station)."
		}
	} else {
		exp.RouteAdviceTH = "Your route does not pass any critical flood spot in Bangkok, so you can take the main route as usual."
	}
	return exp
}

func conditionsEN(e Eval) string {
	var s string
	switch {
	case e.MaxRainMM >= rainModerate:
		s = rainWordEN(e.MaxRainMM) + " on the way."
	case e.MaxRainMM >= rainLight:
		s = "Light rain on the way."
	}
	if e.Mode != domain.ModeTransit && e.MaxDepthCM >= 1 {
		w := fmt.Sprintf("About %.0f cm of water is still draining%s.", e.MaxDepthCM, whereEN(e.DeepestTH))
		if s == "" {
			return "The rain has eased, but " + strings.ToLower(w[:1]) + w[1:]
		}
		return s + " " + w
	}
	return s
}

// hazardEN is a noun phrase for the worst thing met on the way.
func hazardEN(e Eval) string {
	switch {
	case e.Mode != domain.ModeTransit && e.MaxDepthCM >= carSlowDepthCM:
		return fmt.Sprintf("flooding of about %.0f cm%s", e.MaxDepthCM, whereEN(e.DeepestTH))
	case e.MaxRainMM >= rainModerate:
		return fmt.Sprintf("%s at %.0f mm/h, poor visibility and slick roads", strings.ToLower(rainWordEN(e.MaxRainMM)), e.MaxRainMM)
	case e.Mode != domain.ModeTransit && e.MaxDepthCM >= 1:
		return "water still draining" + whereEN(e.DeepestTH)
	case e.MaxRainMM >= rainLight:
		return "rain on the way and slick roads"
	}
	if e.Mode == domain.ModeMoto && e.WindGustKMH >= motoWindGustCautionKMH {
		return fmt.Sprintf("wind gusts of %.0f km/h", e.WindGustKMH)
	}
	return "some risk on the way"
}

func deadlineEN(in Input, e Eval) string {
	if in.ArriveBy.IsZero() {
		return ""
	}
	if e.Late() {
		return fmt.Sprintf(", %d min past %s (let them know ahead)", e.LateMinutes, hhmm(in.ArriveBy))
	}
	return ", in time for " + hhmm(in.ArriveBy)
}

func modeNoteEN(e Eval) string {
	eta := fmt.Sprintf("%d min, arrive %s", e.Minutes, hhmm(e.Arrive))
	if e.Late() {
		eta += " (late)"
	}
	cap := func(s string) string { return strings.ToUpper(s[:1]) + s[1:] }
	switch e.Risk {
	case RiskHigh:
		return cap(hazardEN(e)) + " · " + eta
	case RiskMedium:
		if e.Mode == domain.ModeTransit {
			return "Trains unaffected, bring an umbrella for the walk · " + eta
		}
		return cap(hazardEN(e)) + " · " + eta
	}
	if e.MaxRainMM < rainLight {
		return "No rain · " + eta
	}
	return "Light rain · " + eta
}

func rainWordEN(mm float64) string {
	if mm >= 35 {
		return "Heavy rain"
	}
	return "Moderate rain"
}

// atEN is " at <place>" when the place is written in Latin letters.
func atEN(name string) string {
	if name == "" || domain.HasThai(name) {
		return ""
	}
	return " at " + name
}

// whereEN is " at <spot>" for a Latin spot name and " on your route" otherwise.
func whereEN(name string) string {
	if name == "" || domain.HasThai(name) {
		return " on your route"
	}
	return " at " + name
}

func latinOnly(names []string) []string {
	var out []string
	for _, n := range names {
		if !domain.HasThai(n) {
			out = append(out, n)
		}
	}
	return out
}
