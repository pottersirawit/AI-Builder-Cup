// Package scenario replays the มิว demo script (fontokmai.html) so every demo
// beat is reproducible on camera regardless of real weather. Weather, traffic and
// canal profiles are keyed by time of day, so any date replays the same evening;
// seeded community reports live on the scenario date, 2026-09-29.
package scenario

import (
	"context"
	"fmt"
	"math"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
)

const Source = "scenario"

var (
	Silom  = domain.Place{NameTH: "สีลม ซอย 3", Lat: 13.7263, Lng: 100.5340}
	Home   = domain.Place{NameTH: "บ้านลาดพร้าว", Lat: 13.8160, Lng: 100.5900}
	Impact = domain.Place{NameTH: "อิมแพ็ค เมืองทองธานี", Lat: 13.9119, Lng: 100.5480}
	// Siam is BTS Siam / Siam Paragon; Thonglor is BTS Thong Lo on Sukhumvit.
	Siam     = domain.Place{NameTH: "สยาม", Lat: 13.7456, Lng: 100.5341}
	Thonglor = domain.Place{NameTH: "ทองหล่อ", Lat: 13.7243, Lng: 100.5853}
	// HeroReportPoint is ถ.รัชดาภิเษก หน้าซอยลาดพร้าว 32, where มิว takes the 18:52 photo.
	HeroReportPoint = domain.LatLng{Lat: 13.8130, Lng: 100.5760}
)

// HomeFloodLevelM is the canal stage at which water reaches มิว's doorstep:
// their house sits below the road, 13 cm of overtopping is enough.
const HomeFloodLevelM = 1.93

func at(day time.Time, hh, mm int) time.Time {
	return time.Date(day.Year(), day.Month(), day.Day(), hh, mm, 0, 0, domain.Bangkok)
}

func dayOf(t time.Time) time.Time {
	t = t.In(domain.Bangkok)
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, domain.Bangkok)
}

func minuteOfDay(t time.Time) int {
	t = t.In(domain.Bangkok)
	return t.Hour()*60 + t.Minute()
}

// rainBySlot is rain on the Silom to Lat Phrao corridor in mm/h per 15-minute slot.
// The cell reaches Rama 4 around 17:30, peaks 18:00 to 18:45 and eases by 19:15.
// A second band from 21:00 tops canals up for flood mode at 21:40 (68 mm by then).
var rainBySlot = map[string]float64{
	"17:15": 0.4, "17:30": 2.1, "17:45": 12, "18:00": 38, "18:15": 52, "18:30": 45, "18:45": 30,
	"19:00": 12, "19:15": 4, "19:30": 1.5, "19:45": 0.5,
	"21:00": 20, "21:15": 30, "21:30": 36, "21:45": 20, "22:00": 10, "22:15": 4,
}

// traffic (1 free flow .. 3 jammed) and platform crowding per 15-minute slot from 16:00.
var (
	traffic = []int{1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 1, 1, 1}
	crowd   = []int{1, 1, 2, 2, 2, 3, 3, 3, 3, 3, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1}
)

// RainAt is the scenario rain intensity at t.
func RainAt(t time.Time) float64 {
	m := minuteOfDay(t) / 15 * 15
	return rainBySlot[fmt.Sprintf("%02d:%02d", m/60, m%60)]
}

func level(profile []int, t time.Time) int {
	i := (minuteOfDay(t) - 16*60) / 15
	if i < 0 || i >= len(profile) {
		return 1
	}
	return profile[i]
}

// Weather replays the scenario rain. It is the same along the whole corridor.
type Weather struct{}

func (Weather) Name() string { return "Google Weather API (scenario)" }

func (Weather) Rain(_ context.Context, _ domain.LatLng, from, to time.Time) ([]domain.RainSample, error) {
	start := from.In(domain.Bangkok).Truncate(15 * time.Minute)
	var out []domain.RainSample
	for t := start; !t.After(to); t = t.Add(15 * time.Minute) {
		out = append(out, domain.RainSample{Time: t, MMPerHr: RainAt(t)})
	}
	return out, nil
}

// Routes replays traffic-aware routes. The Silom to Lat Phrao corridor is drawn
// by hand; any other pair is a straight line at a city-average speed.
type Routes struct{}

func (Routes) Name() string { return "Google Routes API (scenario)" }

var (
	carCorridor = []domain.LatLng{
		{Lat: 13.7263, Lng: 100.5340}, {Lat: 13.7290, Lng: 100.5370}, {Lat: 13.7255, Lng: 100.5450}, {Lat: 13.7230, Lng: 100.5560},
		{Lat: 13.7210, Lng: 100.5640}, {Lat: 13.7372, Lng: 100.5610}, {Lat: 13.7480, Lng: 100.5630}, {Lat: 13.7570, Lng: 100.5660},
		{Lat: 13.7700, Lng: 100.5720}, {Lat: 13.7900, Lng: 100.5745}, {Lat: 13.8062, Lng: 100.5737}, {Lat: 13.8130, Lng: 100.5760},
		{Lat: 13.8150, Lng: 100.5830}, {Lat: 13.8160, Lng: 100.5900},
	}
	mrtCorridor = []domain.LatLng{
		{Lat: 13.7263, Lng: 100.5340}, {Lat: 13.7292, Lng: 100.5365}, {Lat: 13.7256, Lng: 100.5456}, {Lat: 13.7230, Lng: 100.5530},
		{Lat: 13.7378, Lng: 100.5604}, {Lat: 13.7489, Lng: 100.5634}, {Lat: 13.7578, Lng: 100.5655}, {Lat: 13.7660, Lng: 100.5700},
		{Lat: 13.7786, Lng: 100.5735}, {Lat: 13.7895, Lng: 100.5742}, {Lat: 13.7997, Lng: 100.5739}, {Lat: 13.8062, Lng: 100.5737},
		{Lat: 13.8160, Lng: 100.5900},
	}
)

func isHeroTrip(from, to domain.LatLng) bool {
	return geo.HaversineM(from, Silom.Point()) < 1500 && geo.HaversineM(to, Home.Point()) < 1500
}

func (r Routes) Route(_ context.Context, from, to domain.LatLng, mode domain.Mode, departAt time.Time) (domain.Route, error) {
	if !mode.Valid() {
		return domain.Route{}, fmt.Errorf("unknown mode %q", mode)
	}
	route := domain.Route{Mode: mode, Source: Source}
	if isHeroTrip(from, to) {
		route.Polyline = carCorridor
		route.ViaTH = []string{"พระราม 4", "อโศก", "รัชดาภิเษก"}
		if mode == domain.ModeTransit {
			route.Polyline = mrtCorridor
			route.ViaTH = []string{"MRT สีลม", "MRT สุขุมวิท", "MRT ลาดพร้าว"}
		}
	} else {
		route.Polyline = []domain.LatLng{from, to}
	}
	route.DurationMin = r.minutes(from, to, mode, departAt)
	return route, nil
}

func (r Routes) minutes(from, to domain.LatLng, mode domain.Mode, departAt time.Time) int {
	base := map[domain.Mode]int{domain.ModeCar: 50, domain.ModeMoto: 30, domain.ModeTransit: 40}[mode]
	if !isHeroTrip(from, to) {
		km := geo.HaversineM(from, to) / 1000 * 1.3
		speed := map[domain.Mode]float64{domain.ModeCar: 22, domain.ModeMoto: 30, domain.ModeTransit: 28}[mode]
		base = int(math.Round(km/speed*60)) + 10
	}
	switch mode {
	case domain.ModeCar:
		return base + (level(traffic, departAt)-1)*10
	case domain.ModeMoto:
		return base + (level(traffic, departAt)-1)*5
	default:
		return base + (level(crowd, departAt)-1)*10
	}
}

// TravelMinutes lets the decision engine search departures without more calls.
func (r Routes) TravelMinutes(from, to domain.LatLng, mode domain.Mode, departAt time.Time) int {
	return r.minutes(from, to, mode, departAt)
}

// Canals replays ThaiWater stage readings. คลองลาดพร้าว rises 40 cm between
// 19:40 and 21:40 and reaches its bank (1.8 m) at 21:40.
type Canals struct{}

func (Canals) Name() string { return "ThaiWater (HII) (scenario)" }

func latPhraoLevel(t time.Time) float64 {
	m := float64(minuteOfDay(t))
	switch {
	case m < 19*60+40:
		return 1.4
	case m <= 21*60+40:
		return 1.4 + 0.4*(m-(19*60+40))/120
	default:
		return math.Min(2.1, 1.8+0.1*(m-(21*60+40))/60)
	}
}

func (Canals) Canals(_ context.Context, near domain.LatLng, t time.Time) ([]domain.CanalReading, error) {
	lp := latPhraoLevel(t)
	readings := []domain.CanalReading{
		{StationID: "BMA-CANAL-02", NameTH: "คลองลาดพร้าว", NameEN: "Lat Phrao Canal", Lat: 13.8185, Lng: 100.5935, LevelM: round2(lp), BankM: 1.8,
			RiseCM2h: math.Round((lp - latPhraoLevel(t.Add(-2*time.Hour))) * 100)},
		{StationID: "BMA-CANAL-01", NameTH: "คลองแสนแสบ", NameEN: "Saen Saep Canal", Lat: 13.7470, Lng: 100.5640, LevelM: 0.85, BankM: 1.10, RiseCM2h: 5},
		{StationID: "BMA-CANAL-03", NameTH: "คลองเปรมประชากร", NameEN: "Prem Prachakorn Canal", Lat: 13.8900, Lng: 100.5800, LevelM: 0.60, BankM: 1.00},
		{StationID: "BMA-CANAL-04", NameTH: "คลองประเวศบุรีรมย์", NameEN: "Prawet Burirom Canal", Lat: 13.6900, Lng: 100.6400, LevelM: 0.70, BankM: 1.05, RiseCM2h: 3},
	}
	for i := range readings {
		readings[i].Source = Source
	}
	sortByDistance(readings, near)
	return readings, nil
}

func sortByDistance(rs []domain.CanalReading, p domain.LatLng) {
	for i := 1; i < len(rs); i++ {
		for j := i; j > 0 && geo.HaversineM(p, domain.LatLng{Lat: rs[j].Lat, Lng: rs[j].Lng}) < geo.HaversineM(p, domain.LatLng{Lat: rs[j-1].Lat, Lng: rs[j-1].Lng}); j-- {
			rs[j], rs[j-1] = rs[j-1], rs[j]
		}
	}
}

// Places are มิว's saved places, in the order the app lists them.
var Places = []domain.SavedPlace{
	{ID: "home", Kind: domain.KindHome, LabelTH: "บ้าน", Place: Home, Keywords: []string{"บ้าน", "ลาดพร้าว", "home"}},
	{ID: "work", Kind: domain.KindWork, LabelTH: "ที่ทำงาน", Place: Silom, Keywords: []string{"ที่ทำงาน", "ออฟฟิศ", "office", "สีลม", "silom", "work"}},
	{ID: "siam", Kind: domain.KindOther, LabelTH: "สยาม", Place: Siam, Keywords: []string{"สยามพารากอน", "สยาม", "พารากอน", "siam", "paragon"}},
	{ID: "thonglor", Kind: domain.KindOther, LabelTH: "ทองหล่อ", Place: Thonglor, Keywords: []string{"ทองหล่อ", "thonglor", "thong lo"}},
	{ID: "impact", Kind: domain.KindOther, LabelTH: "อิมแพ็ค", Place: Impact, Keywords: []string{"อิมแพ็ค", "อิมแพค", "เมืองทองธานี", "เมืองทอง", "impact"}},
}

// Whereabouts is the saved place มิว is at: the Silom office during weekday
// working hours (08:00-19:00), home otherwise.
func Whereabouts(now time.Time) string {
	now = now.In(domain.Bangkok)
	m := minuteOfDay(now)
	if wd := now.Weekday(); wd != time.Saturday && wd != time.Sunday && m >= 8*60 && m < 19*60 {
		return "work"
	}
	return "home"
}

// tripGrace keeps tonight's dinner on the list for a while after 18:30, so the
// later demo beats (18:55, 19:30) still talk about it; after that the next
// dinner is tomorrow's.
const tripGrace = 3 * time.Hour

// Trips are มิว's upcoming trips as of now: the Calendar dinner and the
// concert ticket found in Gmail. They are relative to now, so live mode shows
// today's dinner rather than the scenario date's.
func Trips(now time.Time) []domain.Trip {
	day := dayOf(now)
	dinner := at(day, 18, 30)
	if now.After(dinner.Add(tripGrace)) {
		dinner = dinner.AddDate(0, 0, 1)
	}
	concert := at(day, 19, 0)
	for concert.Weekday() != time.Saturday || !concert.After(now) {
		concert = concert.AddDate(0, 0, 1)
	}
	return []domain.Trip{
		{ID: "cal-dinner", TitleTH: "กินข้าวเย็นกับที่บ้าน", Source: "calendar", Origin: Silom, Destination: Home,
			ArriveBy: dinner, Mode: domain.ModeCar},
		{ID: "gmail-concert", TitleTH: "คอนเสิร์ตที่อิมแพ็ค", Source: "gmail", Origin: Silom, Destination: Impact,
			ArriveBy: concert, Mode: domain.ModeCar},
	}
}

// HeroAssessment is what Gemini vision said about มิว's 18:52 photo; it is the
// fallback when vision is unavailable.
func HeroAssessment() domain.Report {
	return domain.Report{
		DepthCMMin: 20, DepthCMMax: 25, Confidence: 0.84,
		DescriptionTH: "น้ำถึงประมาณครึ่งล้อรถเก๋ง เห็นทางเท้าจมแล้ว รถเก๋งผ่านได้ช้า ๆ ทางเลนขวา มอเตอร์ไซค์ไม่ควรผ่าน",
		Passable:      domain.Passable{Car: "slow", Transit: "yes", Moto: "no"},
	}
}

// SeedReports are the community reports that already exist on the scenario date:
// two on Ratchada just before มิว's, and eleven in their soi during flood mode.
func SeedReports() []domain.Report {
	day := time.Date(2026, 9, 29, 0, 0, 0, 0, domain.Bangkok)
	out := []domain.Report{
		{ID: "seed-ratchada-1", Lat: 13.8122, Lng: 100.5755, CreatedAt: at(day, 18, 41), DepthCMMin: 15, DepthCMMax: 20, Confidence: 0.78,
			DescriptionTH: "น้ำขังเลนซ้าย รถเก๋งเริ่มชะลอ", Passable: domain.Passable{Car: "slow", Transit: "yes", Moto: "no"}},
		{ID: "seed-ratchada-2", Lat: 13.8138, Lng: 100.5768, CreatedAt: at(day, 18, 47), DepthCMMin: 18, DepthCMMax: 24, Confidence: 0.81,
			DescriptionTH: "น้ำเกือบครึ่งล้อ ทางเท้าจม", Passable: domain.Passable{Car: "slow", Transit: "yes", Moto: "no"}},
	}
	for i := 0; i < 11; i++ {
		angle := float64(i) * 2 * math.Pi / 11
		out = append(out, domain.Report{
			ID:  fmt.Sprintf("seed-soi-%02d", i+1),
			Lat: Home.Lat + 0.0012*math.Sin(angle), Lng: Home.Lng + 0.0012*math.Cos(angle),
			CreatedAt:  at(day, 20, 55).Add(time.Duration(i*4) * time.Minute),
			DepthCMMin: 5 + i, DepthCMMax: 10 + i, Confidence: 0.7,
			DescriptionTH: "น้ำเอ่อจากคลองเข้าซอย", Passable: domain.Passable{Car: "slow", Transit: "yes", Moto: "no"},
		})
	}
	return out
}

// MockUsers are commuters with known routes: 27 cross Ratchada at Lat Phrao 32,
// the rest drive elsewhere in the city.
func MockUsers() []domain.MockUser {
	const mPerDegLat = 111320.0
	mPerDegLng := mPerDegLat * math.Cos(HeroReportPoint.Lat*math.Pi/180)
	offset := func(p domain.LatLng, east, north float64) domain.LatLng {
		return domain.LatLng{Lat: p.Lat + north/mPerDegLat, Lng: p.Lng + east/mPerDegLng}
	}
	var users []domain.MockUser
	for i := 0; i < 27; i++ {
		theta := float64(i) * math.Pi / 27
		ux, uy := math.Cos(theta), math.Sin(theta)
		side := float64(i%5-2) * 60
		mid := offset(HeroReportPoint, -uy*side, ux*side)
		users = append(users, domain.MockUser{
			ID:    fmt.Sprintf("u-ratchada-%02d", i+1),
			Route: []domain.LatLng{offset(mid, -ux*3000, -uy*3000), offset(mid, ux*3000, uy*3000)},
		})
	}
	for i := 0; i < 33; i++ {
		theta := float64(i) * 2 * math.Pi / 33
		dist := 4000 + float64(i%4)*1500
		c := offset(HeroReportPoint, math.Cos(theta)*dist, math.Sin(theta)*dist)
		tx, ty := -math.Sin(theta), math.Cos(theta)
		users = append(users, domain.MockUser{
			ID:    fmt.Sprintf("u-city-%02d", i+1),
			Route: []domain.LatLng{offset(c, -tx*1000, -ty*1000), offset(c, tx*1000, ty*1000)},
		})
	}
	return users
}

func round2(v float64) float64 { return math.Round(v*100) / 100 }

// HomeProfile is มิว's home for flood mode.
var HomeProfile = struct {
	Place          domain.Place
	FloodLevelM    float64
	SafeParkingTH  string
	SandbagPointTH string
	SafeParkingEN  string
	SandbagPointEN string
}{Home, HomeFloodLevelM, "ลานจอดเซ็นทรัลลาดพร้าว 1.2 กม.", "สำนักงานเขตจตุจักร เปิดถึงเที่ยงคืน",
	"the Central Ladprao car park (1.2 km)", "Chatuchak District Office (open until midnight)"}
