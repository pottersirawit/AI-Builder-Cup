// Package homestatus is flood mode: the same question ("am I OK?") asked about
// home instead of a trip, answered from canal stage, rain, nearby BMA flood
// spots and neighbour reports.
package homestatus

import (
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
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

// CanalRadiusM and SpotRadiusM are how far a canal station or a BMA flood
// spot may be from home to say something about it.
const (
	CanalRadiusM = 3000
	SpotRadiusM  = 2000
	maxSpots     = 5
)

type Input struct {
	Now  time.Time
	Home Home
	// Canals are stage readings in any order; the nearest within CanalRadiusM is used.
	Canals []domain.CanalReading
	// Rain runs from midnight; samples after Now are the forecast.
	Rain []domain.RainSample
	// Spots is the whole BMA dataset; those within SpotRadiusM are used.
	Spots         []floodspot.Spot
	NearbyReports int // neighbour reports in the last hour
	CanalSource   string
	WeatherSource string
}

type Canal struct {
	NameTH   string  `json:"name_th"`
	LevelM   float64 `json:"level_m"`
	BankM    float64 `json:"bank_m"`
	RiseCM2h float64 `json:"rise_cm_2h"`
}

// Spot is a BMA flood spot near home and the water expected there at the
// heaviest rain of the next two hours.
type Spot struct {
	ID                   string  `json:"id"`
	NameTH               string  `json:"name_th"`
	Lat                  float64 `json:"lat"`
	Lng                  float64 `json:"lng"`
	DistanceM            int     `json:"distance_m"`
	ExpectedDepthCM      int     `json:"expected_depth_cm"`
	HistoricalMaxDepthCM int     `json:"historical_max_depth_cm"`
}

type Action struct {
	Order  int    `json:"order"`
	TextTH string `json:"text_th"`
}

type Status struct {
	Place             domain.Place `json:"place"`
	InServiceArea     bool         `json:"in_service_area"`
	Level             Level        `json:"level"`
	HeadlineTH        string       `json:"headline_th"`
	SummaryTH         string       `json:"summary_th"`
	Canal             *Canal       `json:"canal"` // nil when no station is within CanalRadiusM
	MinutesToDoorstep *int         `json:"minutes_to_doorstep"`
	RainTodayMM       float64      `json:"rain_today_mm"`
	ReportsNearby     int          `json:"reports_nearby"`
	FloodSpots        []Spot       `json:"flood_spots"`
	Actions           []Action     `json:"actions"`
	Sources           []string     `json:"sources"`
}

// Evaluate answers "is home OK?". With a canal station nearby it classifies the
// canal against its bank and how fast it rises, and (when the doorstep height
// is known) when water reaches the door. Without one it falls back to rain and
// the BMA flood spots around home, and says so.
func Evaluate(in Input) Status {
	home := in.Home.Place.Point()
	peak := peakRain(in.Rain, in.Now)
	st := Status{
		Place:         in.Home.Place,
		InServiceArea: geo.InServiceArea(home),
		RainTodayMM:   math.Round(rainTotalMM(in.Rain, in.Now)),
		ReportsNearby: in.NearbyReports,
		FloodSpots:    nearbySpots(in.Spots, home, peak),
	}
	canal := nearestCanal(in.Canals, home)
	if canal != nil {
		st.Sources = append(st.Sources, in.CanalSource)
		evaluateCanal(&st, in, *canal)
	} else {
		evaluateRain(&st, in, peak)
	}
	if in.WeatherSource != "" {
		st.Sources = append(st.Sources, in.WeatherSource)
	}
	if len(st.FloodSpots) > 0 {
		st.Sources = append(st.Sources, "BMA flood spots")
	}
	st.Sources = append(st.Sources, "รายงานผู้ใช้")
	if in.NearbyReports > 0 && st.Level != Normal {
		st.SummaryTH += fmt.Sprintf(" รายงานผู้ใช้ %d คนแถวบ้านในชั่วโมงที่ผ่านมา", in.NearbyReports)
	}
	return st
}

func evaluateCanal(st *Status, in Input, c domain.CanalReading) {
	margin := math.Round((c.BankM-c.LevelM)*100) / 100
	st.Canal = &Canal{NameTH: c.NameTH, LevelM: c.LevelM, BankM: c.BankM, RiseCM2h: c.RiseCM2h}
	switch {
	case margin <= 0.1 || (margin <= 0.2 && c.RiseCM2h >= 30):
		st.Level = Danger
	case margin <= 0.4 || c.RiseCM2h >= 20:
		st.Level = Watch
	default:
		st.Level = Normal
	}
	if c.RiseCM2h > 0 && in.Home.FloodLevelM > 0 && c.LevelM < in.Home.FloodLevelM {
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
			{1, fmt.Sprintf("ย้ายรถไปจอดที่%s ถนนยังแห้งอีก %d นาที", in.Home.parkingTH(), dry)},
			{2, "ยกปลั๊กไฟและของชั้นล่างขึ้นสูงกว่า 50 ซม."},
			{3, "เตรียมกระสอบทรายหน้าประตู จุดแจก: " + in.Home.sandbagTH()},
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
}

// evaluateRain is the honest fallback without a canal station: street water
// from rain at the nearby BMA flood spots, and what neighbours report.
func evaluateRain(st *Status, in Input, peak float64) {
	deepest := 0
	for _, s := range st.FloodSpots {
		deepest = max(deepest, s.ExpectedDepthCM)
	}
	switch {
	case deepest >= 20 || in.NearbyReports >= 3:
		st.Level = Danger
	case deepest > 0 || peak >= 20 || st.RainTodayMM >= 40 || in.NearbyReports >= 1:
		st.Level = Watch
	default:
		st.Level = Normal
	}

	var parts []string
	switch {
	case !st.InServiceArea:
		parts = append(parts, "อยู่นอกพื้นที่ที่แอปรองรับ ประเมินจากฝนอย่างเดียว ไม่มีข้อมูลคลองและจุดน้ำท่วม")
	case len(st.FloodSpots) > 0:
		parts = append(parts, fmt.Sprintf("ไม่มีสถานีวัดระดับคลองใกล้บ้าน ประเมินจากฝนและจุดน้ำท่วม กทม. %d จุดในรัศมี 2 กม.", len(st.FloodSpots)))
	default:
		parts = append(parts, "ไม่มีสถานีวัดระดับคลองใกล้บ้านและไม่มีจุดน้ำท่วมซ้ำซากในรัศมี 2 กม. ประเมินจากฝนอย่างเดียว")
	}
	parts = append(parts, fmt.Sprintf("ฝนสะสมวันนี้ %.0f มม.", st.RainTodayMM))
	if peak >= 1 {
		parts = append(parts, fmt.Sprintf("ฝนหนักสุด %.0f มม./ชม. ใน 2 ชั่วโมงนี้", peak))
	}
	worst := ""
	for _, s := range st.FloodSpots {
		if s.ExpectedDepthCM == deepest && deepest > 0 {
			worst = floodspot.Spot{NameTH: s.NameTH}.ShortNameTH()
			parts = append(parts, fmt.Sprintf("%s อาจมีน้ำขัง %d ซม.", worst, deepest))
			break
		}
	}
	st.SummaryTH = strings.Join(parts, " ")

	avoid := "ถนนที่น้ำขังบ่อยแถวบ้าน"
	if worst != "" {
		avoid = "ถนน" + worst
	}
	switch st.Level {
	case Danger:
		st.HeadlineTH = "ถนนแถวบ้านน้ำท่วม"
		if deepest > 0 {
			st.HeadlineTH = fmt.Sprintf("น้ำท่วมถนนแถวบ้านได้ถึง %d ซม.", deepest)
		}
		st.Actions = []Action{
			{1, "ย้ายรถไปจอดที่" + in.Home.parkingTH() + " ก่อนน้ำขึ้น"},
			{2, "เลี่ยง" + avoid + " ถ้าต้องออกไปข้างนอก"},
			{3, "ยกปลั๊กไฟและของชั้นล่างขึ้นสูงกว่า 50 ซม."},
		}
	case Watch:
		st.HeadlineTH = "เฝ้าระวังน้ำขังแถวบ้าน"
		st.Actions = []Action{
			{1, "ชาร์จโทรศัพท์และพาวเวอร์แบงก์ให้เต็ม"},
			{2, "ถ้าฝนตกต่อเกิน 1 ชั่วโมง ย้ายรถไปที่สูงและเลี่ยง" + avoid},
		}
	default:
		st.HeadlineTH = "แถวบ้านยังไม่มีน้ำท่วม"
		st.Actions = []Action{{1, "ยังไม่ต้องทำอะไร ฝนตกไหมจะเตือนเมื่อฝนหนักหรือมีน้ำขังแถวบ้าน"}}
	}
}

func (h Home) parkingTH() string {
	if h.SafeParkingTH != "" {
		return h.SafeParkingTH
	}
	return "อาคารจอดรถหรือที่สูงใกล้บ้าน"
}

func (h Home) sandbagTH() string {
	if h.SandbagPointTH != "" {
		return h.SandbagPointTH
	}
	return "สำนักงานเขตใกล้บ้าน"
}

func nearestCanal(canals []domain.CanalReading, home domain.LatLng) *domain.CanalReading {
	var best *domain.CanalReading
	bestD := math.Inf(1)
	for i, c := range canals {
		if d := geo.HaversineM(home, domain.LatLng{Lat: c.Lat, Lng: c.Lng}); d <= CanalRadiusM && d < bestD {
			best, bestD = &canals[i], d
		}
	}
	return best
}

func nearbySpots(spots []floodspot.Spot, home domain.LatLng, peakMMPerHr float64) []Spot {
	out := []Spot{}
	for _, s := range spots {
		d := geo.HaversineM(home, s.Point())
		if d > SpotRadiusM {
			continue
		}
		out = append(out, Spot{ID: s.ID, NameTH: s.NameTH, Lat: s.Lat, Lng: s.Lng, DistanceM: int(math.Round(d)),
			ExpectedDepthCM: int(math.Round(floodspot.InstantDepthCM(s, peakMMPerHr))), HistoricalMaxDepthCM: int(math.Round(s.MaxDepthCM))})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].DistanceM < out[j].DistanceM })
	if len(out) > maxSpots {
		out = out[:maxSpots]
	}
	return out
}

// peakRain is the heaviest rain from the current 15-minute slot to two hours ahead.
func peakRain(samples []domain.RainSample, now time.Time) float64 {
	peak := 0.0
	for _, s := range samples {
		if !s.Time.Before(now.Add(-15*time.Minute)) && !s.Time.After(now.Add(2*time.Hour)) {
			peak = math.Max(peak, s.MMPerHr)
		}
	}
	return peak
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
