package decision

import (
	"fmt"
	"strings"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

// narrate writes the plain-Thai headline and summary used when Gemini is not
// available. Gemini rewrites these from the same numbers when it is.
func narrate(in Input, res Result) (headline, summary string) {
	e := res.Evals[in.Mode]
	leavingNow := e.Depart.Sub(in.Now) < 10*time.Minute
	when := "ถ้าออก " + hhmm(e.Depart)
	if leavingNow {
		when = "ถ้าออกตอนนี้"
	}
	var parts []string

	switch res.Verdict {
	case LeaveNow:
		switch {
		case e.Late():
			headline = fmt.Sprintf("ออก %s ได้ แต่เลยนัด %s", hhmm(e.Depart), hhmm(in.ArriveBy))
		case res.LeaveBy != nil && !e.Depart.After(*res.LeaveBy) && res.LeaveBy.Sub(in.Now) >= 10*time.Minute:
			headline = "ออกก่อน " + hhmm(*res.LeaveBy)
		case leavingNow:
			headline = "ออกได้เลย"
		default:
			headline = fmt.Sprintf("ออก %s ได้", hhmm(e.Depart))
		}
		if res.RainOnset != nil && res.RainOnset.After(e.Arrive) {
			parts = append(parts, rainOnsetTH(in, *res.RainOnset))
		}
		parts = append(parts, conditionsTH(e))
		parts = append(parts, fmt.Sprintf("%s ใช้เวลา %d นาที ถึง%sราว %s%s", when, e.Minutes, in.DestinationTH, hhmm(e.Arrive), deadlineTH(in, e)))
		if res.LeaveBy != nil && !e.Late() && res.LeaveBy.Sub(in.Now) >= 10*time.Minute && res.RainOnset != nil {
			parts = append(parts, fmt.Sprintf("ถ้าออกหลัง %s จะเจอฝนกลางทาง", hhmm(*res.LeaveBy)))
		}
		if in.Mode == domain.ModeTransit && e.MaxRainMM >= rainLight {
			parts = append(parts, "พกร่มช่วงเดินออกจากสถานี")
		}
	case SwitchMode:
		tr := res.Evals[domain.ModeTransit]
		headline = "เปลี่ยนไป BTS / MRT ดีกว่า"
		parts = append(parts, fmt.Sprintf("%s%sด้วย%s จะเจอ%s", when, sep(when), in.Mode.NameTH(), hazardTH(e)))
		parts = append(parts, fmt.Sprintf("รถไฟฟ้าไม่โดนน้ำ ใช้เวลา %d นาที ถึง%sราว %s%s", tr.Minutes, in.DestinationTH, hhmm(tr.Arrive), deadlineTH(in, tr)))
	case Wait:
		headline = fmt.Sprintf("รอถึง %s ค่อยออก", hhmm(*res.WaitUntil))
		later := EvaluateMode(in, in.Mode, *res.WaitUntil)
		parts = append(parts, fmt.Sprintf("%s จะเจอ%s", when, hazardTH(e)))
		parts = append(parts, fmt.Sprintf("ออก %s ถึง%sราว %s%s", hhmm(later.Depart), in.DestinationTH, hhmm(later.Arrive), deadlineTH(in, later)))
	case DontGo:
		headline = "อย่าเพิ่งออก"
		parts = append(parts, fmt.Sprintf("%s จะเจอ%s", when, hazardTH(e)))
		parts = append(parts, "ทุกทางเลือกยังเสี่ยงในอีก 3 ชั่วโมง อยู่ในที่ปลอดภัยแล้วรอติดตามอัปเดต")
	}
	return headline, strings.Join(nonEmpty(parts), " ")
}

func rainOnsetTH(in Input, t time.Time) string {
	if len(in.RoadViaTH) > 0 {
		return fmt.Sprintf("ฝนถึง%s ประมาณ %s", in.RoadViaTH[0], hhmm(t))
	}
	return "ฝนเริ่มบนเส้นทางประมาณ " + hhmm(t)
}

func conditionsTH(e Eval) string {
	var s string
	switch {
	case e.MaxRainMM >= rainModerate:
		s = "ระหว่างทาง" + rainWordTH(e.MaxRainMM)
	case e.MaxRainMM >= rainLight:
		s = "ระหว่างทางมีฝนเบา ๆ"
	}
	if e.Mode != domain.ModeTransit && e.MaxDepthCM >= 1 {
		w := fmt.Sprintf("%sยังมีน้ำรอระบายราว %.0f ซม.", e.DeepestTH, e.MaxDepthCM)
		if s == "" {
			return "ฝนซาแล้ว แต่" + w
		}
		return s + " " + w
	}
	return s
}

func hazardTH(e Eval) string {
	switch {
	case e.Mode != domain.ModeTransit && e.MaxDepthCM >= carSlowDepthCM:
		return fmt.Sprintf("น้ำท่วม%sราว %.0f ซม.", e.DeepestTH, e.MaxDepthCM)
	case e.MaxRainMM >= rainModerate:
		return fmt.Sprintf("%s %.0f มม./ชม. มองทางยาก ถนนลื่น", rainWordTH(e.MaxRainMM), e.MaxRainMM)
	case e.Mode != domain.ModeTransit && e.MaxDepthCM >= 1:
		return fmt.Sprintf("น้ำรอระบายที่%s", e.DeepestTH)
	case e.MaxRainMM >= rainLight:
		return "ฝนกลางทาง ถนนลื่น"
	}
	return "ความเสี่ยงระหว่างทาง"
}

func deadlineTH(in Input, e Eval) string {
	if in.ArriveBy.IsZero() {
		return ""
	}
	if e.Late() {
		return fmt.Sprintf(" เลยนัด %s ไป %d นาที บอกปลายทางก่อน", hhmm(in.ArriveBy), e.LateMinutes)
	}
	return fmt.Sprintf(" ทันนัด %s", hhmm(in.ArriveBy))
}

func modeNoteTH(in Input, e Eval) string {
	eta := fmt.Sprintf("%d นาที ถึง %s", e.Minutes, hhmm(e.Arrive))
	if e.Late() {
		eta += " (เลยนัด)"
	}
	switch e.Risk {
	case RiskHigh:
		return hazardTH(e) + " · " + eta
	case RiskMedium:
		if e.Mode == domain.ModeTransit {
			return "ขบวนไม่กระทบ พกร่มช่วงเดิน · " + eta
		}
		return hazardTH(e) + " · " + eta
	}
	if e.MaxRainMM < rainLight {
		return "ไม่เจอฝน · " + eta
	}
	return "ฝนเบา · " + eta
}

// rainWordTH follows the TMD bands: 10-35 mm/h moderate, 35+ heavy.
func rainWordTH(mm float64) string {
	if mm >= 35 {
		return "ฝนหนัก"
	}
	return "ฝนตกปานกลาง"
}

// sep puts a space after a trailing clock time so Thai words do not run into digits.
func sep(s string) string {
	if s != "" && s[len(s)-1] >= '0' && s[len(s)-1] <= '9' {
		return " "
	}
	return ""
}

func hhmm(t time.Time) string { return t.In(domain.Bangkok).Format("15:04") }

func nonEmpty(ss []string) []string {
	out := ss[:0]
	for _, s := range ss {
		if s != "" {
			out = append(out, s)
		}
	}
	return out
}
