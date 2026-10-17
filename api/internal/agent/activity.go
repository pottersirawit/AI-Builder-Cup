package agent

import (
	"context"
	"fmt"
	"math"
	"regexp"
	"strconv"
	"strings"
	"time"

	"google.golang.org/genai"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

// Activity kinds the app knows how to prepare for.
const (
	ActivityClimbing = "climbing"
	ActivityCamping  = "camping"
	ActivityHiking   = "hiking"
	ActivityBeach    = "beach"
	ActivityCycling  = "cycling"
	ActivityRunning  = "running"
	ActivityOther    = "other"
)

var activityKinds = []string{ActivityClimbing, ActivityCamping, ActivityHiking, ActivityBeach, ActivityCycling, ActivityRunning, ActivityOther}

// Activity is a day out the user is preparing for ("ไปปีนผา"). The app sends
// it back with the follow-up so "where?" answers stay about the same plan.
type Activity struct {
	Kind   string `json:"kind"`
	NameTH string `json:"name_th"`
	// Day is the Bangkok date it is on, YYYY-MM-DD, when known.
	Day string `json:"day,omitempty"`
}

// DayTime is midnight Bangkok of Day, or zero when unset or malformed.
func (a Activity) DayTime() time.Time {
	t, err := time.ParseInLocation("2006-01-02", a.Day, domain.Bangkok)
	if err != nil {
		return time.Time{}
	}
	return t
}

// ChecklistItem is one thing to take and why.
type ChecklistItem struct {
	ItemTH string `json:"item_th"`
	WhyTH  string `json:"why_th"`
}

// ActivityPlan is what to prepare for an activity: a general checklist, the
// weather of its day at its place when both are known, and, without a place,
// the question back with places known for it.
type ActivityPlan struct {
	Activity
	HeadlineTH string          `json:"headline_th"`
	Checklist  []ChecklistItem `json:"checklist"`
	// WeatherNotesTH come from the forecast, written by the engine.
	WeatherNotesTH []string            `json:"weather_notes_th"`
	Forecast       *domain.DayForecast `json:"forecast,omitempty"`
	// PlaceTH is where it is, when known.
	PlaceTH string `json:"place_th,omitempty"`
	// AskTH and SuggestionsTH ask where it is: search words for places known
	// for the activity. Empty once the place is known.
	AskTH         string   `json:"ask_th,omitempty"`
	SuggestionsTH []string `json:"suggestions_th,omitempty"`
	GeneratedBy   string   `json:"generated_by"`
}

// NeedsActivity answers a question about an activity with no place yet: the
// checklist now, and where and when to make it about the weather there.
type NeedsActivity struct{ Plan ActivityPlan }

func (n *NeedsActivity) Error() string { return "needs activity place: " + n.Plan.Kind }

var activityWords = []struct {
	kind  string
	words []string
}{
	{ActivityClimbing, []string{"ปีนผา", "ปีนหน้าผา", "ปีนเขา", "โบลเดอร์", "climbing", "climb", "bouldering"}},
	{ActivityCamping, []string{"แคมป์", "แคมปิ้ง", "กางเต็นท์", "กางเต้นท์", "นอนเต็นท์", "camping", "campsite", "camp "}},
	{ActivityHiking, []string{"เดินป่า", "เดินเขา", "ขึ้นดอย", "เทรคกิ้ง", "hiking", "hike", "trekking", "trek"}},
	{ActivityBeach, []string{"ทะเล", "ชายหาด", "เล่นน้ำ", "ดำน้ำ", "beach", "snorkel", "diving", "swim in the sea"}},
	{ActivityCycling, []string{"ปั่นจักรยาน", "ปั่นจักยาน", "cycling", "bicycle"}},
	{ActivityRunning, []string{"ไปวิ่ง", "วิ่งมาราธอน", "งานวิ่ง", "มาราธอน", "running", "marathon", "jogging", "go for a run"}},
}

// detectActivity finds an activity in q by keyword: the fallback when Gemini
// does not answer.
func detectActivity(q string) *Activity {
	lower := strings.ToLower(q) + " "
	for _, a := range activityWords {
		for _, w := range a.words {
			if strings.Contains(lower, w) {
				return &Activity{Kind: a.kind, NameTH: strings.TrimSpace(w)}
			}
		}
	}
	return nil
}

func validActivityKind(k string) bool {
	for _, v := range activityKinds {
		if v == k {
			return true
		}
	}
	return false
}

var (
	reWeekdayTH = regexp.MustCompile(`(?:วัน)?(จันทร์|อังคาร|พุธ|พฤหัส(?:บดี)?|ศุกร์|เสาร์|อาทิตย์)(?:นี้|หน้า)?`)
	reWeekdayEN = regexp.MustCompile(`(?i)\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b`)
	weekdaysTH  = map[string]time.Weekday{"จันทร์": time.Monday, "อังคาร": time.Tuesday, "พุธ": time.Wednesday, "พฤหัส": time.Thursday, "พฤหัสบดี": time.Thursday, "ศุกร์": time.Friday, "เสาร์": time.Saturday, "อาทิตย์": time.Sunday}
)

// ParseDay reads the day a question is about: today, tomorrow, the day after,
// a weekday (the next one, today included) or the weekend. Zero when none.
func ParseDay(q string, now time.Time) time.Time {
	now = now.In(domain.Bangkok)
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, domain.Bangkok)
	lower := strings.ToLower(q)
	next := func(wd time.Weekday) time.Time {
		return today.AddDate(0, 0, (int(wd)-int(today.Weekday())+7)%7)
	}
	switch {
	case strings.Contains(lower, "มะรืน") || strings.Contains(lower, "day after tomorrow"):
		return today.AddDate(0, 0, 2)
	case strings.Contains(lower, "พรุ่งนี้") || strings.Contains(lower, "tomorrow"):
		return today.AddDate(0, 0, 1)
	case strings.Contains(lower, "สุดสัปดาห์") || strings.Contains(lower, "weekend"):
		return next(time.Saturday)
	case strings.Contains(lower, "วันนี้") || strings.Contains(lower, "today") || strings.Contains(lower, "tonight") || strings.Contains(lower, "คืนนี้"):
		return today
	}
	if m := reWeekdayTH.FindStringSubmatch(q); m != nil {
		return next(weekdaysTH[m[1]])
	}
	if m := reWeekdayEN.FindStringSubmatch(q); m != nil {
		for wd := time.Sunday; wd <= time.Saturday; wd++ {
			if strings.EqualFold(wd.String(), m[1]) {
				return next(wd)
			}
		}
	}
	return time.Time{}
}

// settleActivity keeps the activity's own name out of the destination:
// "ไปปีนผาต้องเตรียมอะไร" names no place, "ไปปีนผาที่หินเหล็กไฟ" names one.
func (in *Intent) settleActivity() {
	if in.Activity == nil || in.Place != nil || in.PlaceQuery == "" || in.PlaceKind != "" {
		return
	}
	q := strings.ToLower(in.PlaceQuery)
	words := []string{strings.ToLower(in.Activity.NameTH)}
	for _, a := range activityWords {
		words = append(words, a.words...)
	}
	for _, w := range words {
		if w = strings.TrimSpace(w); w != "" {
			q = strings.ReplaceAll(q, w, " ")
		}
	}
	for _, stop := range []string{"ต้อง", "ควร", "เตรียม", "พก", "เอาอะไร", "what", "need", "should"} {
		if i := strings.Index(q, stop); i >= 0 {
			q = q[:i]
		}
	}
	q = stripDay(q)
	if len([]rune(q)) < 2 {
		in.PlaceQuery = ""
		return
	}
	in.PlaceQuery = q
}

// stripDay is q without its day words, to read the rest as a place.
func stripDay(q string) string {
	out := reWeekdayTH.ReplaceAllString(q, "")
	out = reWeekdayEN.ReplaceAllString(out, "")
	for _, w := range []string{"มะรืนนี้", "มะรืน", "พรุ่งนี้", "สุดสัปดาห์นี้", "สุดสัปดาห์", "วันนี้", "คืนนี้", "this weekend", "weekend", "tomorrow", "today", "tonight"} {
		out = strings.ReplaceAll(out, w, " ")
	}
	out = strings.Join(strings.Fields(out), " ")
	for _, lead := range []string{"ไปที่", "ไป", "ที่", "at ", "to "} {
		out = strings.TrimSpace(strings.TrimPrefix(out, lead))
	}
	return out
}

// fallbackChecklists are what each activity needs whatever the weather.
var fallbackChecklists = map[string][][4]string{
	ActivityClimbing: {
		{"รองเท้าปีนผา", "ยึดเกาะหินได้ดี", "Climbing shoes", "Grip on the rock"},
		{"ฮาร์เนสและเชือก หรือแผ่นรองตก (crash pad)", "ความปลอดภัยตามรูปแบบที่ปีน", "Harness and rope, or a crash pad", "Safety for the style you climb"},
		{"ถุงชอล์ก", "มือไม่ลื่นเพราะเหงื่อ", "Chalk bag", "Keeps sweaty hands dry"},
		{"หมวกกันน็อก", "กันหินร่วงจากด้านบน", "Helmet", "Protects from falling rock"},
		{"น้ำอย่างน้อย 2 ลิตรและของว่าง", "ปีนกลางแดดเสียเหงื่อมาก", "At least 2 litres of water and snacks", "Climbing in the sun is thirsty work"},
		{"ชุดปฐมพยาบาลและเทปพันนิ้ว", "แผลถลอกที่นิ้วและมือ", "First-aid kit and finger tape", "For scrapes on fingers and hands"},
	},
	ActivityCamping: {
		{"เต็นท์พร้อมฟลายชีท", "กันฝนและน้ำค้างตอนกลางคืน", "Tent with a rain fly", "Keeps rain and dew out at night"},
		{"ถุงนอนและแผ่นรองนอน", "พื้นดินเย็นตอนดึก", "Sleeping bag and pad", "The ground gets cold at night"},
		{"ไฟฉายหรือไฟคาดหัว และแบตสำรอง", "แคมป์มืดเร็ว", "Torch or headlamp and a power bank", "Camp gets dark early"},
		{"ยากันยุงและยาประจำตัว", "แมลงชุมใกล้ป่าและน้ำ", "Insect repellent and your medicines", "Bugs near forest and water"},
		{"น้ำดื่มและอาหาร", "ร้านค้าอาจอยู่ไกล", "Drinking water and food", "Shops may be far away"},
		{"ถุงขยะ", "เก็บขยะกลับออกมาด้วย", "Rubbish bags", "Pack out what you bring in"},
	},
	ActivityHiking: {
		{"รองเท้าเดินป่าที่เกาะพื้นดี", "ทางดินและหินลื่น", "Hiking shoes with good grip", "Dirt and rock trails get slippery"},
		{"น้ำและของว่างพลังงานสูง", "เดินนานหลายชั่วโมง", "Water and energy snacks", "Hours on the trail"},
		{"เสื้อแขนยาวระบายอากาศ", "กันแดด กิ่งไม้ และแมลง", "Breathable long sleeves", "Sun, branches and insects"},
		{"แผนที่หรือแอปนำทางแบบออฟไลน์", "บนเขาสัญญาณหาย", "Offline map", "No signal on the mountain"},
		{"ชุดปฐมพยาบาลและนกหวีด", "เรียกความช่วยเหลือถ้าหลงหรือเจ็บ", "First-aid kit and a whistle", "To call for help if lost or hurt"},
	},
	ActivityBeach: {
		{"ครีมกันแดดกันน้ำ", "แดดสะท้อนน้ำและทราย", "Water-resistant sunscreen", "Sun reflects off water and sand"},
		{"หมวกและแว่นกันแดด", "ที่ร่มน้อย", "Hat and sunglasses", "Little shade"},
		{"ชุดว่ายน้ำและผ้าขนหนู", "เล่นน้ำ", "Swimwear and towel", "For swimming"},
		{"ถุงกันน้ำใส่มือถือ", "กันน้ำทะเลและทราย", "Waterproof phone pouch", "Keeps out seawater and sand"},
		{"น้ำดื่ม", "แดดร้อนเสียเหงื่อ", "Drinking water", "Hot sun means sweating"},
	},
	ActivityCycling: {
		{"หมวกกันน็อก", "ความปลอดภัยบนถนน", "Helmet", "Safety on the road"},
		{"ไฟหน้าและไฟท้าย", "ให้รถคันอื่นมองเห็น", "Front and rear lights", "So drivers can see you"},
		{"ชุดปะยางและสูบลม", "ยางรั่วกลางทาง", "Puncture kit and pump", "For a flat on the way"},
		{"น้ำและเกลือแร่", "ปั่นนานเสียเหงื่อ", "Water and electrolytes", "Long rides are sweaty"},
	},
	ActivityRunning: {
		{"รองเท้าวิ่งที่ใส่ประจำ", "ไม่กัดเท้าระหว่างวิ่ง", "Your usual running shoes", "No blisters mid-run"},
		{"น้ำหรือเกลือแร่", "ชดเชยเหงื่อ", "Water or electrolytes", "Replace what you sweat"},
		{"เสื้อผ้าระบายอากาศ", "อากาศร้อนชื้น", "Breathable clothes", "Hot, humid air"},
		{"วาสลีนกันเสียดสี", "วิ่งไกลผิวถลอก", "Anti-chafe balm", "Long runs rub skin raw"},
	},
	ActivityOther: {
		{"น้ำดื่ม", "อยู่ข้างนอกนาน", "Drinking water", "Long time outdoors"},
		{"ครีมกันแดดและหมวก", "แดดแรงกลางวัน", "Sunscreen and a hat", "Strong midday sun"},
		{"ร่มพับหรือเสื้อกันฝน", "ฝนตกได้ทุกเมื่อช่วงนี้", "Folding umbrella or raincoat", "Rain can come any time this season"},
		{"แบตสำรอง", "ใช้มือถือนำทางทั้งวัน", "Power bank", "Navigating all day drains the phone"},
	},
}

func fallbackChecklist(kind string, lang domain.Lang) []ChecklistItem {
	rows, ok := fallbackChecklists[kind]
	if !ok {
		rows = fallbackChecklists[ActivityOther]
	}
	out := make([]ChecklistItem, 0, len(rows))
	for _, r := range rows {
		out = append(out, ChecklistItem{ItemTH: lang.Pick(r[0], r[2]), WhyTH: lang.Pick(r[1], r[3])})
	}
	return out
}

// fallbackSpots are places known for each activity, as search words.
var fallbackSpots = map[string][]string{
	ActivityClimbing: {"หินเหล็กไฟ ราชบุรี", "ไร่เลย์ กระบี่", "ครัวแลง เชียงใหม่", "Rock Domain Bangkok"},
	ActivityCamping:  {"เขาใหญ่", "ดอยอินทนนท์", "เขื่อนศรีนครินทร์", "ภูทับเบิก"},
	ActivityHiking:   {"เขาใหญ่", "ดอยอินทนนท์", "ภูกระดึง", "น้ำตกเอราวัณ"},
	ActivityBeach:    {"บางแสน", "หัวหิน", "เกาะเสม็ด", "พัทยา"},
	ActivityCycling:  {"สวนลุมพินี", "บางกระเจ้า", "สกายเลน สุวรรณภูมิ"},
	ActivityRunning:  {"สวนลุมพินี", "สวนเบญจกิติ", "สวนรถไฟ"},
}

// activityName is how the plan names the activity in lang.
func activityName(a Activity, lang domain.Lang) string {
	names := map[string][2]string{
		ActivityClimbing: {"ปีนผา", "rock climbing"},
		ActivityCamping:  {"แคมปิ้ง", "camping"},
		ActivityHiking:   {"เดินป่า", "hiking"},
		ActivityBeach:    {"เที่ยวทะเล", "the beach"},
		ActivityCycling:  {"ปั่นจักรยาน", "cycling"},
		ActivityRunning:  {"วิ่ง", "running"},
	}
	if n, ok := names[a.Kind]; ok {
		return lang.Pick(n[0], n[1])
	}
	if a.NameTH != "" {
		return a.NameTH
	}
	return lang.Pick("กิจกรรมนี้", "this trip")
}

// WeatherNotes is what the day's weather means for the activity, from the
// forecast's own numbers.
func WeatherNotes(kind string, f *domain.DayForecast, lang domain.Lang) []string {
	if f == nil {
		return nil
	}
	r := func(v float64) int { return int(math.Round(v)) }
	cond := f.ConditionText
	if cond == "" {
		cond = lang.Pick("อากาศ", "Weather")
	}
	notes := []string{lang.Pick(
		fmt.Sprintf("%s %d–%d° โอกาสฝน %d%%", cond, r(f.MinC), r(f.MaxC), f.RainProbPct),
		fmt.Sprintf("%s, %d–%d°, %d%% chance of rain", cond, r(f.MinC), r(f.MaxC), f.RainProbPct),
	)}
	if f.ThunderProbPct >= 30 {
		notes = append(notes, lang.Pick(
			fmt.Sprintf("มีโอกาสพายุฝนฟ้าคะนอง %d%% หลบจากที่โล่ง หน้าผา และยอดเขาเมื่อได้ยินฟ้าร้อง", f.ThunderProbPct),
			fmt.Sprintf("%d%% chance of thunderstorms. Get off open ground, cliffs and summits when you hear thunder.", f.ThunderProbPct),
		))
	}
	if f.RainProbPct >= 60 {
		var th, en string
		switch kind {
		case ActivityClimbing:
			th, en = "หินเปียกจะลื่นและอันตราย ถ้าฝนตกควรรอให้ผาแห้งก่อนปีน", "Wet rock is slippery and dangerous. If it rains, wait for the wall to dry before climbing."
		case ActivityCamping:
			th, en = "กางเต็นท์ที่สูง ห่างทางน้ำ และขึงฟลายชีทให้ตึง", "Pitch on high ground away from streams and keep the rain fly taut."
		case ActivityHiking:
			th, en = "ทางลื่นและอาจมีน้ำป่า เลี่ยงการข้ามลำธารหลังฝนหนัก", "Trails get slippery and flash floods can come. Avoid crossing streams after heavy rain."
		case ActivityBeach:
			th, en = "คลื่นลมอาจแรง ดูธงเตือนก่อนลงเล่นน้ำ", "The sea can get rough. Check the warning flags before swimming."
		default:
			th, en = "เตรียมเสื้อกันฝนและถุงกันน้ำใส่ของสำคัญ", "Bring a raincoat and a dry bag for valuables."
		}
		notes = append(notes, lang.Pick(fmt.Sprintf("โอกาสฝน %d%% %s", f.RainProbPct, th), fmt.Sprintf("%d%% chance of rain. %s", f.RainProbPct, en)))
	}
	if f.FeelsMinC <= coldFeelsC || f.MinC <= coldFeelsC {
		low := r(math.Min(f.MinC, f.FeelsMinC))
		th, en := "เตรียมเสื้อกันหนาว", "Bring a warm layer."
		if kind == ActivityCamping {
			th, en = "เตรียมเสื้อกันหนาวและถุงนอนที่กันหนาวได้", "Bring a warm layer and a sleeping bag rated for the cold."
		}
		notes = append(notes, lang.Pick(fmt.Sprintf("ช่วงเย็นถึงเช้ารู้สึกเหมือน %d° %s", low, th), fmt.Sprintf("Feels like %d° overnight. %s", low, en)))
	}
	if f.FeelsMaxC >= hotFeelsC {
		notes = append(notes, lang.Pick(
			fmt.Sprintf("กลางวันรู้สึกเหมือน %d° พกน้ำมากกว่าปกติ และพักในที่ร่มบ่อย ๆ", r(f.FeelsMaxC)),
			fmt.Sprintf("Feels like %d° by day. Carry extra water and rest in the shade often.", r(f.FeelsMaxC)),
		))
	}
	if f.UVIndex >= 8 {
		notes = append(notes, lang.Pick(
			fmt.Sprintf("แดดแรงมาก (UV %d) ทาครีมกันแดดซ้ำทุก 2 ชั่วโมงและใส่หมวก", f.UVIndex),
			fmt.Sprintf("Very strong sun (UV %d). Reapply sunscreen every 2 hours and wear a hat.", f.UVIndex),
		))
	}
	return notes
}

const (
	coldFeelsC = 20.0
	hotFeelsC  = 38.0
)

// forecastNumbers are the numbers a checklist may quote about the weather.
func forecastNumbers(f *domain.DayForecast) map[string]bool {
	ok := map[string]bool{"2": true}
	if f == nil {
		return ok
	}
	for _, v := range []float64{f.MaxC, f.MinC, f.FeelsMaxC, f.FeelsMinC, f.RainMM} {
		ok[strconv.Itoa(int(math.Round(v)))] = true
	}
	for _, v := range []int{f.RainProbPct, f.ThunderProbPct, f.UVIndex} {
		ok[strconv.Itoa(v)] = true
	}
	return ok
}

var reNumber = regexp.MustCompile(`\d+`)

// groundChecklist drops a reason that quotes a number the forecast did not
// give, keeping the item itself.
func groundChecklist(items []ChecklistItem, f *domain.DayForecast) []ChecklistItem {
	ok := forecastNumbers(f)
	out := make([]ChecklistItem, 0, len(items))
	for _, it := range items {
		if strings.TrimSpace(it.ItemTH) == "" {
			continue
		}
		for _, n := range reNumber.FindAllString(it.WhyTH, -1) {
			if !ok[n] {
				it.WhyTH = ""
				break
			}
		}
		out = append(out, it)
	}
	return out
}

const activityCacheTTL = 30 * time.Minute

func thaiIn(out geminiActivityOut) bool {
	if domain.HasThai(out.HeadlineTH) {
		return true
	}
	for _, it := range out.Checklist {
		if domain.HasThai(it.ItemTH) || domain.HasThai(it.WhyTH) {
			return true
		}
	}
	return false
}

// PlanActivity writes what to prepare for a: Gemini's checklist (the fixed
// list without it), the engine's weather notes for f, and, without a place,
// the question back with places known for the activity.
func PlanActivity(ctx context.Context, g *Gemini, lang domain.Lang, a Activity, place string, f *domain.DayForecast) ActivityPlan {
	name := activityName(a, lang)
	p := ActivityPlan{
		Activity:       a,
		PlaceTH:        place,
		HeadlineTH:     lang.Pick("เตรียมตัวไป"+name, "Getting ready for "+name),
		WeatherNotesTH: WeatherNotes(a.Kind, f, lang),
		Forecast:       f,
		GeneratedBy:    "fallback",
	}
	if place == "" {
		p.AskTH = lang.Pick("ไป"+name+"ที่ไหน วันไหน? บอกแล้วจะเช็กฝนกับอากาศที่นั่นให้", "Where and when? Tell me and I'll check the rain and weather there.")
	}
	if g.Available() {
		if out, ok := geminiActivity(ctx, g, lang, a, name, place, f); ok {
			p.HeadlineTH = out.HeadlineTH
			p.Checklist = groundChecklist(out.Checklist, f)
			if place == "" && len(out.SuggestionsTH) > 0 {
				p.SuggestionsTH = out.SuggestionsTH
			}
			p.GeneratedBy = "gemini"
		}
	}
	if len(p.Checklist) == 0 {
		p.Checklist = fallbackChecklist(a.Kind, lang)
		p.GeneratedBy = "fallback"
	}
	if place == "" && len(p.SuggestionsTH) == 0 {
		p.SuggestionsTH = fallbackSpots[a.Kind]
	}
	if len(p.SuggestionsTH) > 4 {
		p.SuggestionsTH = p.SuggestionsTH[:4]
	}
	return p
}

type geminiActivityOut struct {
	HeadlineTH    string          `json:"headline_th"`
	Checklist     []ChecklistItem `json:"checklist"`
	SuggestionsTH []string        `json:"suggestions_th"`
}

func geminiActivity(ctx context.Context, g *Gemini, lang domain.Lang, a Activity, name, place string, f *domain.DayForecast) (geminiActivityOut, bool) {
	weather := "ยังไม่รู้สภาพอากาศ"
	if f != nil {
		weather = fmt.Sprintf("พยากรณ์วันนั้น: %s อุณหภูมิ %.0f–%.0f° รู้สึกเหมือน %.0f–%.0f° โอกาสฝน %d%% ฝน %.0f มม. โอกาสฟ้าคะนอง %d%% UV %d",
			f.ConditionText, f.MinC, f.MaxC, f.FeelsMinC, f.FeelsMaxC, f.RainProbPct, f.RainMM, f.ThunderProbPct, f.UVIndex)
	}
	key := fmt.Sprintf("activity|%s|%s|%s|%s|%s", lang, a.Kind, strings.ToLower(a.NameTH), place, weather)
	if cached, ok := g.GetCached(key); ok {
		if out, ok := cached.(geminiActivityOut); ok {
			return out, true
		}
	}
	where := place
	if where == "" {
		where = "ยังไม่รู้ว่าที่ไหน"
	}
	prompt := fmt.Sprintf("ผู้ใช้ในประเทศไทยจะไป%s (คำที่ผู้ใช้พิมพ์: %q) สถานที่: %s\n%s\n"+
		"เขียนรายการของที่ควรเตรียม 5-8 ข้อ สำหรับกิจกรรมนี้ เรียงจากสำคัญสุด แต่ละข้อมีเหตุผลสั้น ๆ 1 วลี "+
		"ถ้ารู้พยากรณ์ ให้ปรับรายการตามอากาศ (เช่น หนาวให้เพิ่มเสื้อกันหนาว ฝนให้เพิ่มของกันฝน) และห้ามใส่ตัวเลขที่ไม่ได้อยู่ในพยากรณ์ "+
		"ถ้ายังไม่รู้สถานที่ ให้ suggestions_th เป็นชื่อสถานที่จริงที่มีชื่อเสียงสำหรับกิจกรรมนี้ในไทย 3-4 แห่ง พร้อมจังหวัด (ใช้ค้นหาบนแผนที่ได้) ถ้ารู้สถานที่แล้วให้เป็น [] "+
		"headline_th ไม่เกิน 30 ตัวอักษร",
		name, a.NameTH, where, weather)
	if lang == domain.LangEN {
		prompt = "LANGUAGE: the user reads English. Write headline_th, every item_th and every why_th in short, friendly English, never Thai (keep the JSON keys). Only place names in suggestions_th may stay Thai.\n\n" + prompt
	} else {
		prompt += "\nเขียนเป็นภาษาไทย"
	}
	cfg := &genai.GenerateContentConfig{
		Temperature:      temperature(0.3),
		ResponseMIMEType: "application/json",
		ResponseSchema: &genai.Schema{Type: genai.TypeObject, Properties: map[string]*genai.Schema{
			"headline_th": {Type: genai.TypeString},
			"checklist": {Type: genai.TypeArray, Items: &genai.Schema{Type: genai.TypeObject, Properties: map[string]*genai.Schema{
				"item_th": {Type: genai.TypeString},
				"why_th":  {Type: genai.TypeString},
			}}},
			"suggestions_th": {Type: genai.TypeArray, Items: &genai.Schema{Type: genai.TypeString}},
		}},
	}
	ctx, cancel := context.WithTimeout(ctx, parseQuestionTimeout)
	defer cancel()
	resp, _, err := g.GenerateFast(ctx, []*genai.Content{genai.NewContentFromText(prompt, genai.RoleUser)}, cfg)
	if err != nil {
		return geminiActivityOut{}, false
	}
	var out geminiActivityOut
	if err := decodeJSON(resp.Text(), &out); err != nil || len(out.Checklist) == 0 {
		return geminiActivityOut{}, false
	}
	if lang == domain.LangEN && thaiIn(out) {
		// An English reader gets the fixed English list over a Thai one.
		return geminiActivityOut{}, false
	}
	if out.HeadlineTH == "" || len([]rune(out.HeadlineTH)) > 40 {
		out.HeadlineTH = lang.Pick("เตรียมตัวไป"+name, "Getting ready for "+name)
	}
	if len(out.Checklist) > 8 {
		out.Checklist = out.Checklist[:8]
	}
	g.SetCached(key, out, activityCacheTTL)
	return out, true
}
