package decision

import (
	"fmt"
	"strings"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

// narrate writes the plain-Thai headline and summary used when Gemini is not
// available. Gemini rewrites these from the same numbers when it is.
func narrate(in Input, res Result) (headline, summary string, exp Explanation) {
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
		if res.LeaveBy != nil && !e.Late() && res.LeaveBy.Sub(in.Now) >= 10*time.Minute && res.RainOnset != nil && weatherEndsLeaveBy(in, *res.LeaveBy) {
			parts = append(parts, fmt.Sprintf("ถ้าออกหลัง %s จะเจอฝนกลางทาง", hhmm(*res.LeaveBy)))
		}
		if in.Mode == domain.ModeTransit && e.MaxRainMM >= rainLight {
			parts = append(parts, "พกร่มช่วงเดินออกจากสถานี")
		}
	case SwitchMode:
		tr := res.Evals[domain.ModeTransit]
		headline = "เปลี่ยนไปนั่งรถไฟฟ้าดีกว่า"
		parts = append(parts, fmt.Sprintf("%s%sด้วย%s จะเจอ%s", when, sep(when), in.Mode.NameTH(), hazardTH(e)))
		parts = append(parts, fmt.Sprintf("รถไฟฟ้าไม่โดนน้ำ ใช้เวลา %d นาที ถึง%sราว %s%s", tr.Minutes, in.DestinationTH, hhmm(tr.Arrive), deadlineTH(in, tr)))
	case Wait:
		headline = fmt.Sprintf("รอถึง %s ค่อยออก", hhmm(*res.WaitUntil))
		later := EvaluateMode(in, in.Mode, *res.WaitUntil)
		parts = append(parts, fmt.Sprintf("%s จะเจอ%s", when, hazardTH(e)))
		parts = append(parts, fmt.Sprintf("ออก %s ถึง%sราว %s%s", hhmm(later.Depart), in.DestinationTH, hhmm(later.Arrive), deadlineTH(in, later)))
		if tr, ok := trainNow(in, res); ok {
			parts = append(parts, fmt.Sprintf("หรือนั่งรถไฟฟ้าไปตอนนี้ ถึงราว %s%s", hhmm(tr.Arrive), deadlineTH(in, tr)))
		}
	case DontGo:
		headline = "อย่าเพิ่งออก"
		parts = append(parts, fmt.Sprintf("%s จะเจอ%s", when, hazardTH(e)))
		parts = append(parts, "ทุกทางเลือกยังเสี่ยงในอีก 3 ชั่วโมง อยู่ในที่ปลอดภัยแล้วรอติดตามอัปเดต")
	}
	exp = buildExplanation(in, res)
	return headline, strings.Join(nonEmpty(parts), " "), exp
}

func clearanceText(m domain.Mode) string {
	switch m {
	case domain.ModeCar:
		return "รถเก๋ง 15 ซม."
	case domain.ModeMoto:
		return "มอเตอร์ไซค์ 10 ซม."
	default:
		return "ระบบราง/ทางยกระดับ"
	}
}

func buildExplanation(in Input, res Result) Explanation {
	e := res.Evals[in.Mode]
	tr := res.Evals[domain.ModeTransit]
	var exp Explanation

	// 1. Reason why
	switch res.Verdict {
	case LeaveNow:
		switch {
		case res.LeaveBy != nil && res.LeaveBy.Sub(in.Now) >= 10*time.Minute && weatherEndsLeaveBy(in, *res.LeaveBy):
			exp.ReasonWhyTH = fmt.Sprintf("แนะนำให้ออกก่อน %s ด้วย%s เพื่อให้ถึงปลายทางก่อนกลุ่มฝนตกหนักสะสมจนเกิดน้ำท่วมขังบนเส้นทาง", hhmm(*res.LeaveBy), in.Mode.NameTH())
		case res.LeaveBy != nil && res.LeaveBy.Sub(in.Now) >= 10*time.Minute && !in.ArriveBy.IsZero():
			exp.ReasonWhyTH = fmt.Sprintf("แนะนำให้ออกก่อน %s ด้วย%s เพื่อให้ถึงปลายทางทันนัด %s", hhmm(*res.LeaveBy), in.Mode.NameTH(), hhmm(in.ArriveBy))
		case res.LeaveBy != nil && res.LeaveBy.Sub(in.Now) >= 10*time.Minute:
			exp.ReasonWhyTH = fmt.Sprintf("แนะนำให้ออกก่อน %s ด้วย%s", hhmm(*res.LeaveBy), in.Mode.NameTH())
		case e.Late():
			exp.ReasonWhyTH = fmt.Sprintf("เส้นทางพอไปได้ด้วย%s แต่จะถึงปลายทางเลยเวลานัดหมาย %s ไป %d นาที", in.Mode.NameTH(), hhmm(in.ArriveBy), e.LateMinutes)
		case in.Mode == domain.ModeTransit && e.MaxRainMM >= rainLight:
			exp.ReasonWhyTH = "รถไฟฟ้าวิ่งได้ตามปกติแม้ฝนตก ไม่โดนน้ำท่วมบนถนน พกร่มไว้ช่วงเดินไปและกลับจากสถานี"
		default:
			exp.ReasonWhyTH = fmt.Sprintf("สภาพเส้นทางปัจจุบันปลอดภัย ฝนไม่หนักและไม่มีน้ำท่วมขังขวางทาง สามารถออกเดินทางด้วย%s ได้ทันที", in.Mode.NameTH())
		}
	case SwitchMode:
		switch {
		case e.MaxDepthCM >= stallDepthCM(in.Mode):
			exp.ReasonWhyTH = fmt.Sprintf("แนะนำเปลี่ยนไปใช้รถไฟฟ้าแทนการใช้%s เนื่องจากเส้นทางมีน้ำท่วมขังที่%s สูงราว %.0f ซม. ซึ่งเกินระยะปลอดภัย (%s) ขณะที่รถไฟฟ้าวิ่งบนทางยกระดับ/ใต้ดิน ไม่ได้รับผลกระทบจากน้ำท่วมผิวถนน",
				in.Mode.NameTH(), e.DeepestTH, e.MaxDepthCM, clearanceText(in.Mode))
		case e.MaxRainMM >= rainModerate:
			exp.ReasonWhyTH = fmt.Sprintf("แนะนำเปลี่ยนไปใช้รถไฟฟ้าแทนการใช้%s เนื่องจากมีฝนกลางทางราว %.0f มม./ชม. ถนนลื่น รถไฟฟ้าใช้เวลาราว %d นาที", in.Mode.NameTH(), e.MaxRainMM, tr.Minutes)
		case e.MaxDepthCM >= slowDepthCM(in.Mode):
			exp.ReasonWhyTH = fmt.Sprintf("แนะนำเปลี่ยนไปใช้รถไฟฟ้าแทนการใช้%s เนื่องจากเส้นทางมีน้ำท่วมขังที่%s สูงราว %.0f ซม. ทำให้ต้องชะลอ (ระยะพ้นน้ำปลอดภัย: %s) ขณะที่รถไฟฟ้าวิ่งบนทางยกระดับ/ใต้ดิน ไม่ได้รับผลกระทบจากน้ำท่วมผิวถนน",
				in.Mode.NameTH(), e.DeepestTH, e.MaxDepthCM, clearanceText(in.Mode))
		case e.WindGustKMH >= motoWindGustThresholdKMH && in.Mode == domain.ModeMoto:
			exp.ReasonWhyTH = fmt.Sprintf("แนะนำเปลี่ยนไปใช้รถไฟฟ้าแทนรถจักรยานยนต์ เนื่องจากตรวจพบลมกระโชกแรง %.0f กม./ชม. บนเส้นทาง เสี่ยงต่อการเสียหลัก", e.WindGustKMH)
		case e.Risk == RiskHigh:
			exp.ReasonWhyTH = fmt.Sprintf("แนะนำเปลี่ยนไปใช้รถไฟฟ้าเนื่องจากเส้นทางทางบกมีความเสี่ยงสูงจากสภาพอากาศ รถไฟฟ้าใช้เวลาราว %d นาทีและปลอดภัยกว่า", tr.Minutes)
		case e.MaxRainMM < rainLight && e.WindGustKMH >= motoWindGustCautionKMH:
			exp.ReasonWhyTH = fmt.Sprintf("แนะนำเปลี่ยนไปใช้รถไฟฟ้าแทนการใช้%s เนื่องจากมีลมกระโชก %.0f กม./ชม. บนเส้นทาง ขับขี่ลำบาก รถไฟฟ้าใช้เวลาราว %d นาที", in.Mode.NameTH(), e.WindGustKMH, tr.Minutes)
		default:
			exp.ReasonWhyTH = fmt.Sprintf("แนะนำเปลี่ยนไปใช้รถไฟฟ้าแทนการใช้%s เนื่องจากมีฝนกลางทางราว %.0f มม./ชม. ถนนลื่น รถไฟฟ้าใช้เวลาราว %d นาที", in.Mode.NameTH(), e.MaxRainMM, tr.Minutes)
		}
	case Wait:
		if res.WaitUntil != nil && e.MaxDepthCM < 1 {
			exp.ReasonWhyTH = fmt.Sprintf("แนะนำให้รอจนถึง %s เพื่อให้ฝนซาลงก่อนออกเดินทางด้วย%s", hhmm(*res.WaitUntil), in.Mode.NameTH())
		} else if res.WaitUntil != nil {
			exp.ReasonWhyTH = fmt.Sprintf("แนะนำให้รอจนถึง %s เพื่อให้น้ำท่วมขังที่%s ระบายลงคลองและฝนซาลงก่อนออกเดินทางด้วย%s", hhmm(*res.WaitUntil), e.DeepestTH, in.Mode.NameTH())
		} else {
			exp.ReasonWhyTH = fmt.Sprintf("แนะนำให้ชะลอการเดินทางด้วย%s ไว้ก่อน เพื่อรอให้ระดับน้ำท่วมขังบนเส้นทางระบาย", in.Mode.NameTH())
		}
	case DontGo:
		exp.ReasonWhyTH = "ยังไม่ควรออกเดินทางในขณะนี้ เนื่องจากสภาพอากาศและน้ำท่วมมีความเสี่ยงสูงในทุกเส้นทางและทุกวิธีเดินทาง ควรรอในอาคารที่ปลอดภัย"
	}

	// 2. Factors considered
	// Rain factor
	if res.RainOnset != nil && !res.RainOnset.After(in.Now) {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("กลุ่มฝน: กำลังตกบนเส้นทางตอนนี้ (ความแรงสูงสุด %.0f มม./ชม.)", e.MaxRainMM))
	} else if res.RainOnset != nil && e.MaxRainMM < rainLight {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("กลุ่มฝน: เริ่มตกบนเส้นทางราว %s หลังถึงปลายทาง", hhmm(*res.RainOnset)))
	} else if res.RainOnset != nil {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("กลุ่มฝน: เริ่มตกบนเส้นทางราว %s (ความแรงสูงสุด %.0f มม./ชม.)", hhmm(*res.RainOnset), e.MaxRainMM))
	} else if e.MaxRainMM >= rainLight {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("ปริมาณฝน: มีฝนตกระหว่างทางสูงสุด %.0f มม./ชม.", e.MaxRainMM))
	} else {
		exp.FactorsTH = append(exp.FactorsTH, "ปริมาณฝน: ยังไม่มีกลุ่มฝนตกสะสมบนเส้นทาง")
	}

	// Water depth & vehicle clearance factor
	if e.MaxDepthCM >= 1 {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("ระดับน้ำท่วมขัง: สูงสุดราว %.0f ซม. ที่%s (ระยะพ้นน้ำปลอดภัย: %s)", e.MaxDepthCM, e.DeepestTH, clearanceText(in.Mode)))
	} else {
		exp.FactorsTH = append(exp.FactorsTH, "ระดับน้ำท่วมขัง: ไม่พบจุดน้ำท่วมขังสะสมบนเส้นทาง")
	}

	// Wind factor (if relevant)
	if e.WindGustKMH >= motoWindGustCautionKMH {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("แรงลม: ลมกระโชกสูงสุด %.0f กม./ชม. (เกณฑ์เฝ้าระวังมอเตอร์ไซค์ %.0f กม./ชม.)", e.WindGustKMH, motoWindGustThresholdKMH))
	}

	// Deadline / Travel time factor
	if !in.ArriveBy.IsZero() {
		if e.Late() {
			exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("เวลานัดหมาย: %s (คาดว่าจะถึง %s ล่าช้า %d นาที)", hhmm(in.ArriveBy), hhmm(e.Arrive), e.LateMinutes))
		} else {
			exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("เวลานัดหมาย: %s (คาดว่าจะถึง %s ทันเวลานัด)", hhmm(in.ArriveBy), hhmm(e.Arrive)))
		}
	} else {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("เวลาเดินทาง: ประมาณ %d นาที ถึงปลายทางราว %s", e.Minutes, hhmm(e.Arrive)))
	}

	// Community reports factor
	if n := usableReports(in.Reports); n > 0 {
		exp.FactorsTH = append(exp.FactorsTH, fmt.Sprintf("รายงานชุมชน: มีการแจ้งเตือนน้ำท่วมจริงในพื้นที่ %d จุด", n))
	}

	// 3. Avoid spots
	for _, s := range res.FloodSpots {
		if s.ExpectedDepthCM > 0 || s.Risk == RiskHigh || s.Risk == RiskMedium {
			exp.AvoidSpotsTH = append(exp.AvoidSpotsTH, s.NameTH)
		}
	}
	if len(exp.AvoidSpotsTH) == 0 && e.MaxDepthCM >= 1 && e.DeepestTH != "" {
		exp.AvoidSpotsTH = append(exp.AvoidSpotsTH, e.DeepestTH)
	}

	// 4. Route optimization advice
	if len(exp.AvoidSpotsTH) > 0 {
		spotsStr := strings.Join(exp.AvoidSpotsTH, ", ")
		if res.Verdict == SwitchMode {
			exp.RouteAdviceTH = fmt.Sprintf("แนะนำหลีกเลี่ยงเส้นทางผ่าน %s โดยเปลี่ยนไปใช้รถไฟฟ้า (BTS/MRT) หรือหากจำเป็นต้องขับรถ ควรขึ้นทางด่วนยกระดับเพื่อเลี่ยงจุดน้ำท่วมขัง", spotsStr)
		} else {
			exp.RouteAdviceTH = fmt.Sprintf("เฝ้าระวังจุดเสี่ยงน้ำท่วมบริเวณ %s หากมีฝนตกหนักแนะนำปรับเส้นทางเลี่ยงไปใช้ทางด่วนยกระดับหรือถนนสายหลักข้างเคียง", spotsStr)
		}
	} else {
		if in.Mode == domain.ModeTransit {
			exp.RouteAdviceTH = "เส้นทางรถไฟฟ้าไม่ได้รับผลกระทบจากจุดเสี่ยงน้ำท่วมบนถนน สามารถเดินทางตามปกติ"
			if e.MaxRainMM >= rainLight {
				exp.RouteAdviceTH += " (พกร่มช่วงเดินเข้า-ออกสถานี)"
			}
		} else {
			exp.RouteAdviceTH = "เส้นทางปัจจุบันไม่ผ่านจุดเสี่ยงน้ำท่วมวิกฤตของ กทม. สามารถใช้เส้นทางหลักได้ตามปกติ"
		}
	}

	return exp
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
	case e.Mode == domain.ModeMoto && e.MaxProbPct >= motoRainProbThresholdPct:
		return fmt.Sprintf("โอกาสฝนตก %d%% ควรเตรียมเสื้อกันฝน", e.MaxProbPct)
	}
	if e.Mode == domain.ModeMoto && e.WindGustKMH >= motoWindGustCautionKMH {
		return fmt.Sprintf("ลมกระโชก %.0f กม./ชม.", e.WindGustKMH)
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

// modeNote is the one-line note under a mode option, in the input's language.
func modeNote(in Input, e Eval) string {
	if in.Lang == domain.LangEN {
		return modeNoteEN(e)
	}
	return modeNoteTH(in, e)
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
	if mm >= rainHeavy {
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

// trainNow is the train's trip when the asked mode must wait but the train
// can go now: the app then puts the train first, so the summary offers it.
func trainNow(in Input, res Result) (Eval, bool) {
	if in.Mode == domain.ModeTransit {
		return Eval{}, false
	}
	for _, o := range res.ModeOptions {
		if o.Mode == domain.ModeTransit && o.Verdict == LeaveNow {
			return res.Evals[domain.ModeTransit], true
		}
	}
	return Eval{}, false
}
