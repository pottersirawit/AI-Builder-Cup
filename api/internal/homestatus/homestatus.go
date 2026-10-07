// Package homestatus is flood mode: the same question ("am I OK?") asked about
// home instead of a trip, answered from canal stage, rain and neighbour reports.
package homestatus

import (
	"fmt"
	"math"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

type Level string

const (
	Normal Level = "normal"
	Watch  Level = "watch"
	Danger Level = "danger"
)

type Home struct {
	Place          domain.Place
	FloodLevelM    float64 // canal stage at which water reaches the door
	SafeParkingTH  string
	SandbagPointTH string
}

type Input struct {
	Now           time.Time
	Home          Home
	Canal         domain.CanalReading // nearest station
	Rain          []domain.RainSample // since midnight
	NearbyReports int                 // neighbour reports in the last hour
	Sources       []string
}

type Canal struct {
	NameTH   string  `json:"name_th"`
	LevelM   float64 `json:"level_m"`
	BankM    float64 `json:"bank_m"`
	RiseCM2h float64 `json:"rise_cm_2h"`
}

type Action struct {
	Order  int    `json:"order"`
	TextTH string `json:"text_th"`
}

type Status struct {
	Level             Level    `json:"level"`
	HeadlineTH        string   `json:"headline_th"`
	SummaryTH         string   `json:"summary_th"`
	Canal             Canal    `json:"canal"`
	MinutesToDoorstep *int     `json:"minutes_to_doorstep"`
	RainTodayMM       float64  `json:"rain_today_mm"`
	ReportsNearby     int      `json:"reports_nearby"`
	Actions           []Action `json:"actions"`
	Sources           []string `json:"sources"`
}

// Evaluate classifies the canal against its bank and how fast it is rising,
// estimates when water reaches the door and orders what to do first.
func Evaluate(in Input) Status {
	c := in.Canal
	margin := math.Round((c.BankM-c.LevelM)*100) / 100
	st := Status{
		Canal:         Canal{NameTH: c.NameTH, LevelM: c.LevelM, BankM: c.BankM, RiseCM2h: c.RiseCM2h},
		RainTodayMM:   math.Round(rainTotalMM(in.Rain, in.Now)),
		ReportsNearby: in.NearbyReports,
		Sources:       in.Sources,
	}
	switch {
	case margin <= 0.1 || (margin <= 0.2 && c.RiseCM2h >= 30):
		st.Level = Danger
	case margin <= 0.4 || c.RiseCM2h >= 20:
		st.Level = Watch
	default:
		st.Level = Normal
	}
	if c.RiseCM2h > 0 && c.LevelM < in.Home.FloodLevelM {
		ratePerMin := c.RiseCM2h / 120
		m := int(math.Ceil((in.Home.FloodLevelM-c.LevelM)*100/ratePerMin/5) * 5)
		st.MinutesToDoorstep = &m
	}

	rise := ""
	if c.RiseCM2h >= 10 {
		rise = fmt.Sprintf(" ขึ้น %.0f ซม. ใน 2 ชั่วโมง", c.RiseCM2h)
	}
	switch st.Level {
	case Danger:
		st.HeadlineTH = fmt.Sprintf("%sล้นตลิ่งแล้ว", c.NameTH)
		if st.MinutesToDoorstep != nil {
			st.HeadlineTH = fmt.Sprintf("น้ำจะถึงหน้าบ้านใน %d นาที", *st.MinutesToDoorstep)
		}
		st.SummaryTH = fmt.Sprintf("%sขึ้นถึงตลิ่งแล้ว (%.1f / %.1f ม.)%s ฝนสะสมวันนี้ %.0f มม.", c.NameTH, c.LevelM, c.BankM, rise, st.RainTodayMM)
		dry := 20
		if st.MinutesToDoorstep != nil {
			dry = max(5, *st.MinutesToDoorstep-15)
		}
		st.Actions = []Action{
			{1, fmt.Sprintf("ย้ายรถไปจอดที่%s ถนนยังแห้งอีก %d นาที", in.Home.SafeParkingTH, dry)},
			{2, "ยกปลั๊กไฟและของชั้นล่างขึ้นสูงกว่า 50 ซม."},
			{3, "เตรียมกระสอบทรายหน้าประตู จุดแจก: " + in.Home.SandbagPointTH},
		}
	case Watch:
		st.HeadlineTH = "คืนนี้เสี่ยงน้ำท่วม: ปานกลาง"
		st.SummaryTH = fmt.Sprintf("%s %.1f ม. ต่ำกว่าตลิ่ง %.1f ม.%s ฝนสะสมวันนี้ %.0f มม.", c.NameTH, c.LevelM, margin, rise, st.RainTodayMM)
		st.Actions = []Action{
			{1, "ชาร์จโทรศัพท์และพาวเวอร์แบงก์ให้เต็ม"},
			{2, "ถ้าฝนตกต่อเกิน 1 ชั่วโมง ย้ายรถไปที่สูงก่อน"},
			{3, "ยกของที่เสียหายง่ายขึ้นจากพื้นชั้นล่าง"},
		}
	default:
		st.HeadlineTH = "บ้านปลอดภัย ระดับคลองปกติ"
		st.SummaryTH = fmt.Sprintf("%s %.1f ม. ต่ำกว่าตลิ่ง %.1f ม.", c.NameTH, c.LevelM, margin)
		st.Actions = []Action{{1, "ยังไม่ต้องทำอะไร ฝนตกไหมจะเตือนเมื่อคลองขึ้นเร็ว"}}
	}
	if in.NearbyReports > 0 && st.Level != Normal {
		st.SummaryTH += fmt.Sprintf(" รายงานผู้ใช้ %d คนแถวบ้านในชั่วโมงที่ผ่านมา", in.NearbyReports)
	}
	return st
}

// rainTotalMM integrates mm/h samples up to now.
func rainTotalMM(samples []domain.RainSample, now time.Time) float64 {
	total := 0.0
	for i, s := range samples {
		if !s.Time.Before(now) {
			break
		}
		end := s.Time.Add(time.Hour)
		if i+1 < len(samples) {
			end = samples[i+1].Time
		}
		if end.After(now) {
			end = now
		}
		total += s.MMPerHr * end.Sub(s.Time).Hours()
	}
	return total
}
