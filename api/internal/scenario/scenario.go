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
	// The rest of มิว's week: the Events tab's Calendar and Gmail plans.
	Samyan      = domain.Place{NameTH: "สามย่านมิตรทาวน์", Lat: 13.7335, Lng: 100.5285}
	GymLadprao  = domain.Place{NameTH: "ฟิตเนส เซ็นทรัลลาดพร้าว", Lat: 13.8167, Lng: 100.5612}
	TrueDigital = domain.Place{NameTH: "ทรู ดิจิทัล พาร์ค", Lat: 13.6855, Lng: 100.6106}
	Lumpini     = domain.Place{NameTH: "สวนลุมพินี", Lat: 13.7314, Lng: 100.5414}
	DonMueang   = domain.Place{NameTH: "ท่าอากาศยานดอนเมือง", Lat: 13.9126, Lng: 100.6068}
	Rama9Hosp   = domain.Place{NameTH: "โรงพยาบาลพระราม 9", Lat: 13.7563, Lng: 100.5653}
	// Online is where a video call happens: no coordinates, no travel.
	Online = domain.Place{NameTH: "ออนไลน์"}
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
		mm := RainAt(t)
		prob := dayProfile[t.Hour()].prob
		if t.Hour() == 17 && t.Minute() < 30 {
			prob = 50
		}
		out = append(out, domain.RainSample{
			Time:    t,
			MMPerHr: mm,
			ProbPct: prob,
		})
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

type transitStop struct {
	nameTH string
	lineTH string
	idx    int
	lat    float64
	lng    float64
}

func (s transitStop) point() domain.LatLng { return domain.LatLng{Lat: s.lat, Lng: s.lng} }

var bkkTransitStops = []transitStop{
	// MRT Blue Line
	{nameTH: "MRT ท่าพระ", lineTH: "MRT สายสีน้ำเงิน", idx: 1, lat: 13.7297, lng: 100.4741},
	{nameTH: "MRT หัวลำโพง", lineTH: "MRT สายสีน้ำเงิน", idx: 5, lat: 13.7375, lng: 100.5171},
	{nameTH: "MRT สามย่าน", lineTH: "MRT สายสีน้ำเงิน", idx: 6, lat: 13.7323, lng: 100.5296},
	{nameTH: "MRT สีลม", lineTH: "MRT สายสีน้ำเงิน", idx: 7, lat: 13.7292, lng: 100.5365},
	{nameTH: "MRT ลุมพินี", lineTH: "MRT สายสีน้ำเงิน", idx: 8, lat: 13.7256, lng: 100.5456},
	{nameTH: "MRT คลองเตย", lineTH: "MRT สายสีน้ำเงิน", idx: 9, lat: 13.7224, lng: 100.5539},
	{nameTH: "MRT ศูนย์การประชุมแห่งชาติสิริกิติ์", lineTH: "MRT สายสีน้ำเงิน", idx: 10, lat: 13.7230, lng: 100.5601},
	{nameTH: "MRT สุขุมวิท", lineTH: "MRT สายสีน้ำเงิน", idx: 11, lat: 13.7378, lng: 100.5614},
	{nameTH: "MRT เพชรบุรี", lineTH: "MRT สายสีน้ำเงิน", idx: 12, lat: 13.7489, lng: 100.5634},
	{nameTH: "MRT พระราม 9", lineTH: "MRT สายสีน้ำเงิน", idx: 13, lat: 13.7578, lng: 100.5655},
	{nameTH: "MRT ห้วยขวาง", lineTH: "MRT สายสีน้ำเงิน", idx: 15, lat: 13.7786, lng: 100.5735},
	{nameTH: "MRT สุทธิสาร", lineTH: "MRT สายสีน้ำเงิน", idx: 16, lat: 13.7895, lng: 100.5742},
	{nameTH: "MRT รัชดาภิเษก", lineTH: "MRT สายสีน้ำเงิน", idx: 17, lat: 13.7997, lng: 100.5739},
	{nameTH: "MRT ลาดพร้าว", lineTH: "MRT สายสีน้ำเงิน", idx: 18, lat: 13.8062, lng: 100.5737},
	{nameTH: "MRT พหลโยธิน", lineTH: "MRT สายสีน้ำเงิน", idx: 19, lat: 13.8143, lng: 100.5612},
	{nameTH: "MRT สวนจตุจักร", lineTH: "MRT สายสีน้ำเงิน", idx: 20, lat: 13.8025, lng: 100.5537},
	{nameTH: "MRT บางซื่อ", lineTH: "MRT สายสีน้ำเงิน", idx: 21, lat: 13.8039, lng: 100.5398},
	{nameTH: "MRT เตาปูน", lineTH: "MRT สายสีน้ำเงิน", idx: 22, lat: 13.8062, lng: 100.5303},
	// BTS Silom Line
	{nameTH: "BTS บางหว้า", lineTH: "BTS สายสีลม", idx: 1, lat: 13.7205, lng: 100.4578},
	{nameTH: "BTS กรุงธนบุรี", lineTH: "BTS สายสีลม", idx: 5, lat: 13.7209, lng: 100.5026},
	{nameTH: "BTS ช่องนนทรี", lineTH: "BTS สายสีลม", idx: 8, lat: 13.7236, lng: 100.5293},
	{nameTH: "BTS ศาลาแดง", lineTH: "BTS สายสีลม", idx: 9, lat: 13.7285, lng: 100.5343},
	{nameTH: "BTS ราชดำริ", lineTH: "BTS สายสีลม", idx: 10, lat: 13.7394, lng: 100.5395},
	{nameTH: "BTS สยาม", lineTH: "BTS สายสีลม", idx: 11, lat: 13.7456, lng: 100.5341},
	{nameTH: "BTS สนามกีฬาแห่งชาติ", lineTH: "BTS สายสีลม", idx: 12, lat: 13.7465, lng: 100.5291},
	// BTS Sukhumvit Line
	{nameTH: "BTS แบริ่ง", lineTH: "BTS สายสุขุมวิท", idx: 1, lat: 13.6612, lng: 100.6019},
	{nameTH: "BTS บางนา", lineTH: "BTS สายสุขุมวิท", idx: 2, lat: 13.6681, lng: 100.6046},
	{nameTH: "BTS อ่อนนุช", lineTH: "BTS สายสุขุมวิท", idx: 5, lat: 13.7059, lng: 100.6009},
	{nameTH: "BTS เอกมัย", lineTH: "BTS สายสุขุมวิท", idx: 7, lat: 13.7190, lng: 100.5847},
	{nameTH: "BTS ทองหล่อ", lineTH: "BTS สายสุขุมวิท", idx: 8, lat: 13.7243, lng: 100.5853},
	{nameTH: "BTS พร้อมพงษ์", lineTH: "BTS สายสุขุมวิท", idx: 9, lat: 13.7303, lng: 100.5695},
	{nameTH: "BTS อโศก", lineTH: "BTS สายสุขุมวิท", idx: 10, lat: 13.7372, lng: 100.5604},
	{nameTH: "BTS นานา", lineTH: "BTS สายสุขุมวิท", idx: 11, lat: 13.7405, lng: 100.5553},
	{nameTH: "BTS ชิดลม", lineTH: "BTS สายสุขุมวิท", idx: 13, lat: 13.7441, lng: 100.5431},
	{nameTH: "BTS สยาม", lineTH: "BTS สายสุขุมวิท", idx: 14, lat: 13.7456, lng: 100.5341},
	{nameTH: "BTS พญาไท", lineTH: "BTS สายสุขุมวิท", idx: 16, lat: 13.7569, lng: 100.5349},
	{nameTH: "BTS อนุสาวรีย์ชัยสมรภูมิ", lineTH: "BTS สายสุขุมวิท", idx: 17, lat: 13.7628, lng: 100.5371},
	{nameTH: "BTS อารีย์", lineTH: "BTS สายสุขุมวิท", idx: 19, lat: 13.7797, lng: 100.5448},
	{nameTH: "BTS หมอชิต", lineTH: "BTS สายสุขุมวิท", idx: 22, lat: 13.8025, lng: 100.5537},
	{nameTH: "BTS ห้าแยกลาดพร้าว", lineTH: "BTS สายสุขุมวิท", idx: 23, lat: 13.8166, lng: 100.5615},
	{nameTH: "BTS มหาวิทยาลัยเกษตรศาสตร์", lineTH: "BTS สายสุขุมวิท", idx: 26, lat: 13.8430, lng: 100.5700},
	{nameTH: "BTS วัดพระศรีมหาธาตุ", lineTH: "BTS สายสุขุมวิท", idx: 29, lat: 13.8749, lng: 100.5968},
	// MRT Pink Line
	{nameTH: "MRT ศูนย์ราชการนนทบุรี", lineTH: "MRT สายสีชมพู", idx: 1, lat: 13.8601, lng: 100.5138},
	{nameTH: "MRT เมืองทองธานี", lineTH: "MRT สายสีชมพู", idx: 10, lat: 13.9056, lng: 100.5418},
	{nameTH: "MRT อิมแพ็ค เมืองทองธานี", lineTH: "MRT สายสีชมพู", idx: 11, lat: 13.9119, lng: 100.5480},
	{nameTH: "MRT วัดพระศรีมหาธาตุ", lineTH: "MRT สายสีชมพู", idx: 16, lat: 13.8749, lng: 100.5968},
	// MRT Yellow Line
	{nameTH: "MRT ลาดพร้าว", lineTH: "MRT สายสีเหลือง", idx: 1, lat: 13.8062, lng: 100.5737},
	{nameTH: "MRT บางกะปิ", lineTH: "MRT สายสีเหลือง", idx: 8, lat: 13.7644, lng: 100.6433},
	{nameTH: "MRT ศรีเอี่ยม", lineTH: "MRT สายสีเหลือง", idx: 17, lat: 13.6632, lng: 100.6458},
	// Airport Rail Link
	{nameTH: "ARL พญาไท", lineTH: "ARL แอร์พอร์ตเรลลิงก์", idx: 1, lat: 13.7569, lng: 100.5349},
	{nameTH: "ARL มักกะสัน", lineTH: "ARL แอร์พอร์ตเรลลิงก์", idx: 3, lat: 13.7508, lng: 100.5614},
	{nameTH: "ARL รามคำแหง", lineTH: "ARL แอร์พอร์ตเรลลิงก์", idx: 4, lat: 13.7429, lng: 100.6003},
	{nameTH: "ARL ลาดกระบัง", lineTH: "ARL แอร์พอร์ตเรลลิงก์", idx: 7, lat: 13.7279, lng: 100.7488},
}

func absInt(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func nearestStop(pt domain.LatLng, lineFilter string) (transitStop, float64) {
	var best transitStop
	bestD := math.Inf(1)
	for _, s := range bkkTransitStops {
		if lineFilter != "" && s.lineTH != lineFilter {
			continue
		}
		if d := geo.HaversineM(pt, s.point()); d < bestD {
			best, bestD = s, d
		}
	}
	return best, bestD
}

func stopByName(lineTH, nameTH string) (transitStop, bool) {
	for _, s := range bkkTransitStops {
		if s.lineTH == lineTH && s.nameTH == nameTH {
			return s, true
		}
	}
	return transitStop{}, false
}

// DescribeRoute returns the road corridors or transit stations/legs used to
// travel between from and to in Bangkok.
func DescribeRoute(from, to domain.LatLng, mode domain.Mode) (viaTH []string, legs []domain.TransitLeg) {
	if isHeroTrip(from, to) {
		if mode == domain.ModeTransit {
			return []string{"MRT สีลม", "MRT สุขุมวิท", "MRT ลาดพร้าว"}, []domain.TransitLeg{{
				LineTH:        "MRT สายสีน้ำเงิน",
				FromStationTH: "MRT สีลม",
				ToStationTH:   "MRT ลาดพร้าว",
				StopCount:     11,
			}}
		}
		return []string{"พระราม 4", "อโศก", "รัชดาภิเษก"}, nil
	}
	if mode != domain.ModeTransit {
		switch {
		case geo.HaversineM(to, Impact.Point()) < 1500:
			return []string{"ทางพิเศษศรีรัช", "แจ้งวัฒนะ"}, nil
		case geo.HaversineM(from, Silom.Point()) < 1500 && geo.HaversineM(to, Siam.Point()) < 1500:
			return []string{"พระราม 4", "ราชดำริ"}, nil
		case geo.HaversineM(to, Thonglor.Point()) < 1500 || to.Lng > 100.56:
			return []string{"พระราม 4", "สุขุมวิท"}, nil
		case to.Lat > 13.78:
			return []string{"พหลโยธิน", "วิภาวดีรังสิต"}, nil
		default:
			return []string{"พระราม 4", "เพชรบุรี"}, nil
		}
	}

	orig, dOrig := nearestStop(from, "")
	dest, dDest := nearestStop(to, "")
	// Prefer a direct single-line ride when a single line serves both ends within 700 m extra walk.
	for _, line := range []string{"MRT สายสีน้ำเงิน", "BTS สายสุขุมวิท", "BTS สายสีลม", "MRT สายสีชมพู", "MRT สายสีเหลือง", "ARL แอร์พอร์ตเรลลิงก์"} {
		oL, doL := nearestStop(from, line)
		dL, ddL := nearestStop(to, line)
		if oL.nameTH != "" && dL.nameTH != "" && oL.nameTH != dL.nameTH && (doL+ddL) <= (dOrig+dDest)+700 {
			orig, dest = oL, dL
			break
		}
	}
	if orig.lineTH == dest.lineTH {
		stops := maxInt(1, absInt(orig.idx-dest.idx))
		return []string{orig.nameTH, dest.nameTH}, []domain.TransitLeg{{
			LineTH:        orig.lineTH,
			FromStationTH: orig.nameTH,
			ToStationTH:   dest.nameTH,
			StopCount:     stops,
		}}
	}

	// Interchange lookup between orig.lineTH and dest.lineTH.
	type xferPair struct{ stopA, stopB string }
	interchanges := map[[2]string]xferPair{
		{"BTS สายสีลม", "BTS สายสุขุมวิท"}:          {"BTS สยาม", "BTS สยาม"},
		{"BTS สายสุขุมวิท", "BTS สายสีลม"}:          {"BTS สยาม", "BTS สยาม"},
		{"MRT สายสีน้ำเงิน", "BTS สายสุขุมวิท"}:     {"MRT สุขุมวิท", "BTS อโศก"},
		{"BTS สายสุขุมวิท", "MRT สายสีน้ำเงิน"}:     {"BTS อโศก", "MRT สุขุมวิท"},
		{"MRT สายสีน้ำเงิน", "BTS สายสีลม"}:         {"MRT สีลม", "BTS ศาลาแดง"},
		{"BTS สายสีลม", "MRT สายสีน้ำเงิน"}:         {"BTS ศาลาแดง", "MRT สีลม"},
		{"BTS สายสุขุมวิท", "MRT สายสีชมพู"}:        {"BTS วัดพระศรีมหาธาตุ", "MRT วัดพระศรีมหาธาตุ"},
		{"MRT สายสีชมพู", "BTS สายสุขุมวิท"}:        {"MRT วัดพระศรีมหาธาตุ", "BTS วัดพระศรีมหาธาตุ"},
		{"MRT สายสีน้ำเงิน", "MRT สายสีชมพู"}:       {"MRT สวนจตุจักร", "MRT วัดพระศรีมหาธาตุ"},
		{"MRT สายสีชมพู", "MRT สายสีน้ำเงิน"}:       {"MRT วัดพระศรีมหาธาตุ", "MRT สวนจตุจักร"},
		{"MRT สายสีน้ำเงิน", "MRT สายสีเหลือง"}:     {"MRT ลาดพร้าว", "MRT ลาดพร้าว"},
		{"MRT สายสีเหลือง", "MRT สายสีน้ำเงิน"}:     {"MRT ลาดพร้าว", "MRT ลาดพร้าว"},
		{"BTS สายสุขุมวิท", "ARL แอร์พอร์ตเรลลิงก์"}: {"BTS พญาไท", "ARL พญาไท"},
		{"ARL แอร์พอร์ตเรลลิงก์", "BTS สายสุขุมวิท"}: {"ARL พญาไท", "BTS พญาไท"},
		{"MRT สายสีน้ำเงิน", "ARL แอร์พอร์ตเรลลิงก์"}: {"MRT เพชรบุรี", "ARL มักกะสัน"},
		{"ARL แอร์พอร์ตเรลลิงก์", "MRT สายสีน้ำเงิน"}: {"ARL มักกะสัน", "MRT เพชรบุรี"},
	}
	xp, ok := interchanges[[2]string{orig.lineTH, dest.lineTH}]
	if !ok {
		xp = xferPair{stopA: orig.nameTH, stopB: dest.nameTH}
	}
	stops1, stops2 := 3, 4
	if sA, ok := stopByName(orig.lineTH, xp.stopA); ok {
		stops1 = maxInt(1, absInt(orig.idx-sA.idx))
	}
	if sB, ok := stopByName(dest.lineTH, xp.stopB); ok {
		stops2 = maxInt(1, absInt(dest.idx-sB.idx))
	}
	via := []string{orig.nameTH, xp.stopA}
	if xp.stopB != xp.stopA {
		via = append(via, xp.stopB)
	}
	via = append(via, dest.nameTH)
	return via, []domain.TransitLeg{
		{LineTH: orig.lineTH, FromStationTH: orig.nameTH, ToStationTH: xp.stopA, StopCount: stops1},
		{LineTH: dest.lineTH, FromStationTH: xp.stopB, ToStationTH: dest.nameTH, StopCount: stops2},
	}
}

func (r Routes) Route(_ context.Context, from, to domain.LatLng, mode domain.Mode, departAt time.Time) (domain.Route, error) {
	if !mode.Valid() {
		return domain.Route{}, fmt.Errorf("unknown mode %q", mode)
	}
	route := domain.Route{Mode: mode, Source: Source}
	if isHeroTrip(from, to) {
		route.Polyline = carCorridor
		if mode == domain.ModeTransit {
			route.Polyline = mrtCorridor
		}
	} else {
		route.Polyline = []domain.LatLng{from, to}
	}
	route.ViaTH, route.TransitLegs = DescribeRoute(from, to, mode)
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

// tripPast is how late a week trip may be and still count as upcoming.
const tripPast = 10 * time.Minute

// Trips are มิว's upcoming trips as of now: the Calendar dinner and the
// concert ticket found in Gmail first, then the rest of the week in arrival
// order. They are relative to now, so live mode shows today's dinner rather
// than the scenario date's.
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
	trips := []domain.Trip{
		{ID: "cal-dinner", TitleTH: "กินข้าวเย็นกับที่บ้าน", Source: "calendar", Origin: Silom, Destination: Home,
			ArriveBy: dinner, EndsAt: dinner.Add(90 * time.Minute), Mode: domain.ModeCar},
		{ID: "gmail-concert", TitleTH: "คอนเสิร์ตที่อิมแพ็ค", Source: "gmail", Origin: Silom, Destination: Impact,
			ArriveBy: concert, EndsAt: concert.Add(3 * time.Hour), Mode: domain.ModeCar},
	}
	d1, d2 := day.AddDate(0, 0, 1), day.AddDate(0, 0, 2)
	week := []domain.Trip{
		{ID: "cal-client", TitleTH: "ประชุมลูกค้า Q4", Source: "calendar", Origin: Silom, Destination: Samyan,
			ArriveBy: at(day, 14, 0), EndsAt: at(day, 15, 30), Mode: domain.ModeTransit},
		{ID: "cal-gym", TitleTH: "เวทเทรนนิ่ง", Source: "calendar", Origin: Home, Destination: GymLadprao,
			ArriveBy: at(day, 20, 30), EndsAt: at(day, 21, 30), Mode: domain.ModeMoto},
		{ID: "cal-standup", TitleTH: "Daily standup ที่ออฟฟิศ", Source: "calendar", Origin: Home, Destination: Silom,
			ArriveBy: at(d1, 9, 30), EndsAt: at(d1, 10, 0), Mode: domain.ModeTransit},
		{ID: "cal-sync", TitleTH: "ซิงก์งานกับทีม (Google Meet)", Source: "calendar", Origin: Silom, Destination: Online,
			ArriveBy: at(d1, 11, 0), EndsAt: at(d1, 11, 30), Mode: domain.ModeTransit, Virtual: true},
		{ID: "cal-lunch", TitleTH: "กินข้าวกับพี่เบียร์", Source: "calendar", Origin: Silom, Destination: Siam,
			ArriveBy: at(d1, 12, 0), EndsAt: at(d1, 12, 45), Mode: domain.ModeTransit},
		// Starts 15 minutes after lunch at Siam ends: a deliberately tight connection.
		{ID: "cal-review", TitleTH: "รีวิวงานที่ทองหล่อ", Source: "calendar", Origin: Siam, Destination: Thonglor,
			ArriveBy: at(d1, 13, 0), EndsAt: at(d1, 14, 0), Mode: domain.ModeTransit},
		{ID: "cal-pitch", TitleTH: "Pitch AI Builder Cup", Source: "calendar", Origin: Home, Destination: TrueDigital,
			ArriveBy: at(d2, 10, 0), EndsAt: at(d2, 11, 0), Mode: domain.ModeCar},
		{ID: "cal-yoga", TitleTH: "โยคะสวนลุม", Source: "calendar", Origin: Silom, Destination: Lumpini,
			ArriveBy: at(d2, 19, 0), EndsAt: at(d2, 20, 0), Mode: domain.ModeTransit},
		{ID: "gmail-flight", TitleTH: "เที่ยวบิน FD3433 ไปเชียงใหม่", Source: "gmail", Origin: Home, Destination: DonMueang,
			ArriveBy: at(day.AddDate(0, 0, 5), 7, 30), Mode: domain.ModeCar},
		{ID: "cal-checkup", TitleTH: "ตรวจสุขภาพประจำปี", Source: "calendar", Origin: Home, Destination: Rama9Hosp,
			ArriveBy: at(day.AddDate(0, 0, 7), 8, 0), EndsAt: at(day.AddDate(0, 0, 7), 10, 0), Mode: domain.ModeCar},
	}
	for _, t := range week {
		if !now.After(t.ArriveBy.Add(tripPast)) {
			trips = append(trips, t)
		}
	}
	return trips
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

// WeatherNext replays scenario WeatherNext 3 telemetry (5km grid wind gust and temperature).
type WeatherNext struct{}

func (WeatherNext) Name() string { return "Google DeepMind WeatherNext 3 (scenario)" }

func (WeatherNext) PeakConditionsAlongRoute(_ []domain.LatLng) (maxGust float64, maxTemp float64, err error) {
	return 25.0, 32.0, nil
}

// BMAFlood replays scenario BMA road flood sensors along commuter routes.
type BMAFlood struct{}

func (BMAFlood) Name() string { return "BMA Road Flood Sensors (scenario)" }

func (BMAFlood) SensorsNearRoute(polyline []domain.LatLng, radiusM float64) ([]domain.RoadFloodSensor, error) {
	scenarioSensors := []domain.RoadFloodSensor{
		{
			Code:      "TN.DDG.01",
			NameTH:    "อุโมงค์ทางลอดดินแดง",
			NameEN:    "Din Daeng Underpass Tunnel",
			Lat:       13.76391,
			Lng:       100.54820,
			DepthCM:   12.0,
			UpdatedAt: time.Date(2026, 9, 29, 18, 0, 0, 0, domain.Bangkok),
		},
		{
			Code:      "FL.RTC.01",
			NameTH:    "ถนนรัชดาภิเษก หน้าศาลอาญา",
			NameEN:    "Ratchadapisek Rd (Criminal Court)",
			Lat:       13.8135,
			Lng:       100.5758,
			DepthCM:   18.0,
			UpdatedAt: time.Date(2026, 9, 29, 18, 0, 0, 0, domain.Bangkok),
		},
	}
	var out []domain.RoadFloodSensor
	for _, s := range scenarioSensors {
		if geo.DistanceToPolylineM(s.Point(), polyline) <= radiusM {
			out = append(out, s)
		}
	}
	return out, nil
}

// BMATidal replays scenario BMA KlongMap high tide telemetry.
type BMATidal struct{}

func (BMATidal) Name() string { return "BMA Canal Flow & Tidal Map (scenario)" }

func (BMATidal) TidalStatus(_ context.Context, at time.Time) (domain.TidalReading, error) {
	return domain.TidalReading{
		HighTideM:    1.09,
		HighTideTime: at,
		LowTideM:     -0.41,
		SurgeRisk:    "high",
	}, nil
}

// DirectoryHotlines provides verified emergency contact helplines for flood rescue, medical, road, and electricity assistance.
type DirectoryHotlines struct{}

func (DirectoryHotlines) Name() string {
	return "สายด่วนฉุกเฉิน (ปภ. 1784 / สพฉ. 1669)"
}

func (DirectoryHotlines) EmergencyContacts() []domain.EmergencyContact {
	return []domain.EmergencyContact{
		{
			AgencyTH:  "กรมป้องกันและบรรเทาสาธารณภัย (ปภ.)",
			AgencyEN:  "Disaster Prevention & Mitigation (DDPM)",
			Number:    "1784",
			PurposeTH: "ขอความช่วยเหลือ/อพยพ เหตุน้ำท่วม ตลอด 24 ชม.",
			PurposeEN: "Flood rescue & evacuation assistance (24/7)",
			LineID:    "@1784DDPM",
		},
		{
			AgencyTH:  "สถาบันการแพทย์ฉุกเฉินแห่งชาติ (สพฉ.)",
			AgencyEN:  "National Emergency Medical Services (EMS)",
			Number:    "1669",
			PurposeTH: "เจ็บป่วยฉุกเฉิน อุบัติเหตุ กู้ชีพเร่งด่วน",
			PurposeEN: "Life-threatening medical emergencies & ambulance",
		},
		{
			AgencyTH:  "กรมทางหลวง",
			AgencyEN:  "Department of Highways",
			Number:    "1586",
			PurposeTH: "สอบถามเส้นทางน้ำท่วม ทางเบี่ยงทางหลวง",
			PurposeEN: "Highway flood road conditions & detours",
		},
		{
			AgencyTH:  "กรมทางหลวงชนบท",
			AgencyEN:  "Department of Rural Roads",
			Number:    "1146",
			PurposeTH: "สอบถามเส้นทางถนนชนบทและสายรอง",
			PurposeEN: "Rural road flood advisories & detours",
		},
		{
			AgencyTH:  "การไฟฟ้านครหลวง (กทม.-นนทบุรี-สมุทรปราการ)",
			AgencyEN:  "Metropolitan Electricity Authority (MEA)",
			Number:    "1130",
			PurposeTH: "ไฟฟ้ารั่ว ไฟดับ เสาไฟล้ม น้ำท่วมหม้อแปลง",
			PurposeEN: "Electrical hazards, power outages & flooded equipment",
			LineID:    "@meathailand",
		},
		{
			AgencyTH:  "การไฟฟ้าส่วนภูมิภาค (ต่างจังหวัด)",
			AgencyEN:  "Provincial Electricity Authority (PEA)",
			Number:    "1129",
			PurposeTH: "แจ้งเหตุไฟฟ้าขัดข้อง เหตุด่วนไฟฟ้าต่างจังหวัด",
			PurposeEN: "Provincial electrical hazards & power outages",
		},
	}
}
