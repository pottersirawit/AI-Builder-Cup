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
	SafeParkingEN  string
	SandbagPointEN string
}

// CanalRadiusM and SpotRadiusM are how far a canal station or a BMA flood
// spot may be from home to say something about it.
const (
	CanalRadiusM = 3000
	SpotRadiusM  = 2000
	maxSpots     = 5
)

type Input struct {
	Lang domain.Lang // language of the user-facing text; the zero value is Thai
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
	NameEN               string  `json:"-"`
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
		FloodSpots:    nearbySpots(in.Spots, home, peak, in.Lang),
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
	st.Sources = append(st.Sources, in.Lang.Pick("รายงานผู้ใช้", "Community reports"))
	if in.NearbyReports > 0 && st.Level != Normal {
		st.SummaryTH += in.Lang.Pick(fmt.Sprintf(" รายงานผู้ใช้ %d คนแถวบ้านในชั่วโมงที่ผ่านมา", in.NearbyReports),
			fmt.Sprintf(" %d %s near home in the last hour.", in.NearbyReports, plural(in.NearbyReports, "report", "reports")))
	}
	return st
}

func plural(n int, one, many string) string {
	if n == 1 {
		return one
	}
	return many
}

func evaluateCanal(st *Status, in Input, c domain.CanalReading) {
	margin := math.Round((c.BankM-c.LevelM)*100) / 100
	l := in.Lang
	name := c.NameTH
	if l == domain.LangEN && c.NameEN != "" {
		name = c.NameEN
	}
	st.Canal = &Canal{NameTH: name, LevelM: c.LevelM, BankM: c.BankM, RiseCM2h: c.RiseCM2h}
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
		rise = l.Pick(fmt.Sprintf(" ขึ้น %.0f ซม. ใน 2 ชั่วโมง", c.RiseCM2h), fmt.Sprintf(" Up %.0f cm in 2 hours.", c.RiseCM2h))
	}
	switch st.Level {
	case Danger:
		st.HeadlineTH = l.Pick(fmt.Sprintf("%sล้นตลิ่งแล้ว", name), fmt.Sprintf("%s has overflowed", name))
		if st.MinutesToDoorstep != nil {
			st.HeadlineTH = l.Pick(fmt.Sprintf("น้ำจะถึงหน้าบ้านใน %d นาที", *st.MinutesToDoorstep), fmt.Sprintf("Water will reach your door in %d minutes", *st.MinutesToDoorstep))
		}
		st.SummaryTH = l.Pick(fmt.Sprintf("%sขึ้นถึงตลิ่งแล้ว (%.1f / %.1f ม.)%s ฝนสะสมวันนี้ %.0f มม.", name, c.LevelM, c.BankM, rise, st.RainTodayMM),
			fmt.Sprintf("%s has reached its bank (%.1f / %.1f m).%s Rain today: %.0f mm.", name, c.LevelM, c.BankM, rise, st.RainTodayMM))
		dry := 20
		if st.MinutesToDoorstep != nil {
			dry = max(5, *st.MinutesToDoorstep-15)
		}
		st.Actions = []Action{
			{1, l.Pick(fmt.Sprintf("ย้ายรถไปจอดที่%s ถนนยังแห้งอีก %d นาที", in.Home.parkingTH(), dry),
				fmt.Sprintf("Move your car to %s. The road stays dry for another %d minutes.", in.Home.parking(l), dry))},
			{2, l.Pick("ยกปลั๊กไฟและของชั้นล่างขึ้นสูงกว่า 50 ซม.", "Lift power strips and ground-floor items above 50 cm.")},
			{3, l.Pick("เตรียมกระสอบทรายหน้าประตู จุดแจก: "+in.Home.sandbagTH(), "Set sandbags at the door. Pick-up point: "+in.Home.sandbag(l))},
		}
	case Watch:
		st.HeadlineTH = l.Pick("คืนนี้เสี่ยงน้ำท่วม: ปานกลาง", "Moderate flood risk tonight")
		st.SummaryTH = l.Pick(fmt.Sprintf("%s %.1f ม. ต่ำกว่าตลิ่ง %.1f ม.%s ฝนสะสมวันนี้ %.0f มม.", name, c.LevelM, margin, rise, st.RainTodayMM),
			fmt.Sprintf("%s is at %.1f m, %.1f m below its bank.%s Rain today: %.0f mm.", name, c.LevelM, margin, rise, st.RainTodayMM))
		st.Actions = []Action{
			{1, l.Pick("ชาร์จโทรศัพท์และพาวเวอร์แบงก์ให้เต็ม", "Charge your phone and power bank.")},
			{2, l.Pick("ถ้าฝนตกต่อเกิน 1 ชั่วโมง ย้ายรถไปที่สูงก่อน", "If the rain lasts over an hour, move your car to higher ground.")},
			{3, l.Pick("ยกของที่เสียหายง่ายขึ้นจากพื้นชั้นล่าง", "Lift fragile items off the ground floor.")},
		}
	default:
		st.HeadlineTH = l.Pick("บ้านปลอดภัย ระดับคลองปกติ", "Home is safe, canal level is normal")
		st.SummaryTH = l.Pick(fmt.Sprintf("%s %.1f ม. ต่ำกว่าตลิ่ง %.1f ม.", name, c.LevelM, margin),
			fmt.Sprintf("%s is at %.1f m, %.1f m below its bank.", name, c.LevelM, margin))
		st.Actions = []Action{{1, l.Pick("ยังไม่ต้องทำอะไร ฝนตกไหมจะเตือนเมื่อคลองขึ้นเร็ว", "Nothing to do yet. Fon Tok Mai will alert you if the canal rises fast.")}}
	}
}

// evaluateRain is the honest fallback without a canal station: street water
// from rain at the nearby BMA flood spots, and what neighbours report.
func evaluateRain(st *Status, in Input, peak float64) {
	l := in.Lang
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
		parts = append(parts, l.Pick("อยู่นอกพื้นที่ที่แอปรองรับ ประเมินจากฝนอย่างเดียว ไม่มีข้อมูลคลองและจุดน้ำท่วม",
			"This is outside the area the app covers. The estimate uses rain only, with no canal or flood spot data."))
	case len(st.FloodSpots) > 0:
		parts = append(parts, l.Pick(fmt.Sprintf("ไม่มีสถานีวัดระดับคลองใกล้บ้าน ประเมินจากฝนและจุดน้ำท่วม กทม. %d จุดในรัศมี 2 กม.", len(st.FloodSpots)),
			fmt.Sprintf("No canal gauge near home. The estimate uses rain and %d BMA flood %s within 2 km.", len(st.FloodSpots), plural(len(st.FloodSpots), "spot", "spots"))))
	default:
		parts = append(parts, l.Pick("ไม่มีสถานีวัดระดับคลองใกล้บ้านและไม่มีจุดน้ำท่วมซ้ำซากในรัศมี 2 กม. ประเมินจากฝนอย่างเดียว",
			"No canal gauge or recurring flood spot within 2 km of home. The estimate uses rain only."))
	}
	parts = append(parts, l.Pick(fmt.Sprintf("ฝนสะสมวันนี้ %.0f มม.", st.RainTodayMM), fmt.Sprintf("Rain today: %.0f mm.", st.RainTodayMM)))
	if peak >= 1 {
		parts = append(parts, l.Pick(fmt.Sprintf("ฝนหนักสุด %.0f มม./ชม. ใน 2 ชั่วโมงนี้", peak), fmt.Sprintf("Heaviest rain %.0f mm/h in the next 2 hours.", peak)))
	}
	worst := ""
	for _, s := range st.FloodSpots {
		if s.ExpectedDepthCM == deepest && deepest > 0 {
			if l == domain.LangEN && s.NameEN != "" {
				worst = floodspot.Spot{NameEN: s.NameEN}.ShortNameEN()
				parts = append(parts, fmt.Sprintf("Water may pool on %s, up to %d cm.", worst, deepest))
			} else {
				worst = floodspot.Spot{NameTH: s.NameTH}.ShortNameTH()
				parts = append(parts, l.Pick(fmt.Sprintf("%s อาจมีน้ำขัง %d ซม.", worst, deepest), fmt.Sprintf("Water may pool on %s, up to %d cm.", worst, deepest)))
			}
			break
		}
	}
	st.SummaryTH = strings.Join(parts, " ")

	avoid := l.Pick("ถนนที่น้ำขังบ่อยแถวบ้าน", "streets near home that often flood")
	if worst != "" {
		avoid = l.Pick("ถนน"+worst, worst)
	}
	switch st.Level {
	case Danger:
		st.HeadlineTH = l.Pick("ถนนแถวบ้านน้ำท่วม", "Streets near home are flooded")
		if deepest > 0 {
			st.HeadlineTH = l.Pick(fmt.Sprintf("น้ำท่วมถนนแถวบ้านได้ถึง %d ซม.", deepest), fmt.Sprintf("Streets near home may flood up to %d cm", deepest))
		}
		st.Actions = []Action{
			{1, l.Pick("ย้ายรถไปจอดที่"+in.Home.parkingTH()+" ก่อนน้ำขึ้น", "Move your car to "+in.Home.parking(l)+" before the water rises.")},
			{2, l.Pick("เลี่ยง"+avoid+" ถ้าต้องออกไปข้างนอก", "Avoid "+avoid+" if you have to go out.")},
			{3, l.Pick("ยกปลั๊กไฟและของชั้นล่างขึ้นสูงกว่า 50 ซม.", "Lift power strips and ground-floor items above 50 cm.")},
		}
	case Watch:
		st.HeadlineTH = l.Pick("เฝ้าระวังน้ำขังแถวบ้าน", "Watch for pooling water near home")
		st.Actions = []Action{
			{1, l.Pick("ชาร์จโทรศัพท์และพาวเวอร์แบงก์ให้เต็ม", "Charge your phone and power bank.")},
			{2, l.Pick("ถ้าฝนตกต่อเกิน 1 ชั่วโมง ย้ายรถไปที่สูงและเลี่ยง"+avoid, "If the rain lasts over an hour, move your car to higher ground and avoid "+avoid+".")},
		}
	default:
		st.HeadlineTH = l.Pick("แถวบ้านยังไม่มีน้ำท่วม", "No flooding near home")
		st.Actions = []Action{{1, l.Pick("ยังไม่ต้องทำอะไร ฝนตกไหมจะเตือนเมื่อฝนหนักหรือมีน้ำขังแถวบ้าน", "Nothing to do yet. Fon Tok Mai will alert you to heavy rain or pooling water near home.")}}
	}
}

func (h Home) parking(l domain.Lang) string {
	if l == domain.LangEN {
		if h.SafeParkingEN != "" {
			return h.SafeParkingEN
		}
		return "a car park or high ground near home"
	}
	return h.parkingTH()
}

func (h Home) sandbag(l domain.Lang) string {
	if l == domain.LangEN {
		if h.SandbagPointEN != "" {
			return h.SandbagPointEN
		}
		return "your district office"
	}
	return h.sandbagTH()
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

func nearbySpots(spots []floodspot.Spot, home domain.LatLng, peakMMPerHr float64, l domain.Lang) []Spot {
	out := []Spot{}
	for _, s := range spots {
		d := geo.HaversineM(home, s.Point())
		if d > SpotRadiusM {
			continue
		}
		name := s.NameTH
		if l == domain.LangEN && s.NameEN != "" {
			name = s.NameEN
		}
		out = append(out, Spot{ID: s.ID, NameTH: name, NameEN: s.NameEN, Lat: s.Lat, Lng: s.Lng, DistanceM: int(math.Round(d)),
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
