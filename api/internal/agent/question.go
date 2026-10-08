package agent

import (
	"context"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"

	"google.golang.org/genai"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
)

// Intent is what a Thai follow-up question changes about the trip.
type Intent struct {
	DepartAt *time.Time
	Mode     *domain.Mode
	// Place is the saved place the question asks to go to, if any.
	Place *domain.SavedPlace
	// Without a Place, PlaceQuery is the destination as typed ("เซ็นทรัลเวิลด์")
	// and PlaceKind is home or work when that is what was asked for.
	PlaceQuery string
	PlaceKind  string
}

// SummaryTH describes the intent for the reasoning trace.
func (i Intent) SummaryTH() string {
	var parts []string
	if i.Place != nil {
		parts = append(parts, "ไป"+i.Place.LabelTH)
	}
	if i.DepartAt != nil {
		parts = append(parts, "ออก "+i.DepartAt.Format("15:04"))
	}
	if i.Mode != nil {
		parts = append(parts, "ไปด้วย"+i.Mode.NameTH())
	}
	if len(parts) == 0 {
		return "ไม่พบปลายทาง เวลา หรือวิธีเดินทางใหม่ในคำถาม ใช้แผนเดิม"
	}
	return "ตีความคำถามว่า " + strings.Join(parts, " ")
}

const thaiNum = `(สิบเอ็ด|สิบสอง|หนึ่ง|สอง|สาม|สี่|ห้า|หก|เจ็ด|แปด|เก้า|สิบ|\d{1,2})`

var (
	thaiDigits = map[string]int{"หนึ่ง": 1, "สอง": 2, "สาม": 3, "สี่": 4, "ห้า": 5, "หก": 6, "เจ็ด": 7, "แปด": 8, "เก้า": 9, "สิบ": 10, "สิบเอ็ด": 11, "สิบสอง": 12}

	reClock    = regexp.MustCompile(`(\d{1,2})[:.](\d{2})`)
	reThum     = regexp.MustCompile(thaiNum + `?\s*ทุ่ม(ครึ่ง)?`)
	reBai      = regexp.MustCompile(`บ่าย\s*` + thaiNum + `?\s*(?:โมง)?(ครึ่ง)?`)
	reMong     = regexp.MustCompile(thaiNum + `\s*โมง\s*(เย็น|เช้า)?\s*(ครึ่ง)?`)
	reIn       = regexp.MustCompile(`อีก\s*` + thaiNum + `?\s*(ครึ่ง)?\s*(ชั่วโมง|ชม|นาที)`)
	reMidnight = regexp.MustCompile(`เที่ยงคืน`)
	reNoon     = regexp.MustCompile(`เที่ยง`)
	reNow      = regexp.MustCompile(`ตอนนี้|เดี๋ยวนี้|เลยไหม`)

	reTransit = regexp.MustCompile(`(?i)bts|mrt|รถไฟฟ้า|ใต้ดิน|รถเมล์|ขนส่งสาธารณะ|transit`)
	reMoto    = regexp.MustCompile(`(?i)มอไซ|มอเตอร์ไซ|วินมอ|moto|bike`)
	reCar     = regexp.MustCompile(`(?i)รถยนต์|ขับรถ|รถเก๋ง|แท็กซี่|taxi|grab|แกร็บ|\bcar\b`)
)

func num(s string, def int) int {
	if s == "" {
		return def
	}
	if n, ok := thaiDigits[s]; ok {
		return n
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return def
	}
	return n
}

// ParseQuestionTH is the regex fallback: Thai clock words ("สองทุ่ม" = 20:00,
// "ห้าโมงครึ่ง" = 17:30, "อีก 30 นาที") and mode words ("BTS", "มอไซค์").
func ParseQuestionTH(q string, now time.Time) Intent {
	now = now.In(domain.Bangkok)
	var in Intent
	day := func(h, m int) *time.Time {
		t := time.Date(now.Year(), now.Month(), now.Day(), h, m, 0, 0, domain.Bangkok)
		if t.Before(now.Add(-30 * time.Minute)) {
			t = t.AddDate(0, 0, 1)
		}
		return &t
	}
	half := func(s string) int {
		if s != "" {
			return 30
		}
		return 0
	}
	switch {
	case reClock.MatchString(q):
		m := reClock.FindStringSubmatch(q)
		in.DepartAt = day(num(m[1], 0)%24, num(m[2], 0)%60)
	case reThum.MatchString(q):
		m := reThum.FindStringSubmatch(q)
		in.DepartAt = day(18+num(m[1], 1), half(m[2]))
	case reBai.MatchString(q):
		m := reBai.FindStringSubmatch(q)
		in.DepartAt = day(12+num(m[1], 1), half(m[2]))
	case reMong.MatchString(q):
		m := reMong.FindStringSubmatch(q)
		h := num(m[1], 0)
		if m[2] == "เย็น" || (m[2] == "" && h >= 1 && h <= 6) {
			h += 12
		}
		in.DepartAt = day(h%24, half(m[3]))
	case reIn.MatchString(q):
		m := reIn.FindStringSubmatch(q)
		n := num(m[1], 1)
		d := time.Duration(n) * time.Minute
		if m[3] != "นาที" {
			d = time.Duration(n)*time.Hour + time.Duration(half(m[2]))*time.Minute
			if m[1] == "" && m[2] != "" {
				d = 30 * time.Minute
			}
		}
		t := now.Add(d)
		in.DepartAt = &t
	case reMidnight.MatchString(q):
		in.DepartAt = day(0, 0)
	case reNoon.MatchString(q):
		in.DepartAt = day(12, 0)
	case reNow.MatchString(q):
		t := now
		in.DepartAt = &t
	}
	var mode domain.Mode
	switch {
	case reTransit.MatchString(q):
		mode = domain.ModeTransit
	case reMoto.MatchString(q):
		mode = domain.ModeMoto
	case reCar.MatchString(q):
		mode = domain.ModeCar
	}
	if mode != "" {
		in.Mode = &mode
	}
	return in
}

// MatchPlace is the keyword fallback for the destination: the saved place whose
// keyword appears in q, ignoring places marked as the origin ("จากสีลม").
// The longest keyword wins, then the earliest.
func MatchPlace(q string, places []domain.SavedPlace) (domain.SavedPlace, bool) {
	q = strings.ToLower(q)
	best, bestLen, bestPos := -1, 0, 0
	for i, p := range places {
		for _, kw := range p.Keywords {
			kw = strings.ToLower(kw)
			for from := 0; ; {
				j := strings.Index(q[from:], kw)
				if j < 0 {
					break
				}
				pos := from + j
				from = pos + len(kw)
				if strings.HasSuffix(strings.TrimSpace(q[:pos]), "จาก") {
					continue
				}
				if n := len([]rune(kw)); n > bestLen || (n == bestLen && pos < bestPos) {
					best, bestLen, bestPos = i, n, pos
				}
			}
		}
	}
	if best < 0 {
		return domain.SavedPlace{}, false
	}
	return places[best], true
}

var (
	// phraseStops end a destination phrase: question words, days, fillers.
	phraseStops = []string{"ตอน", "ดีไหม", "ได้ไหม", "ไหม", "มั้ย", "ป่ะ", "ล่ะ", "เลย", "แทน", "ด้วย", "กี่โมง", "ยังไง", "อย่างไร",
		"พรุ่งนี้", "วันนี้", "คืนนี้", "เย็นนี้", "เช้านี้", "หน่อย", "ครับ", "ค่ะ", "คะ", "ก่อน", "ตั้งแต่", "ภายใน", "โดย", "แล้ว", "?"}
	// phraseLeads are words between "ไป" and the place ("ไปกินข้าวแถวสุขุมวิท").
	phraseLeads = []string{"ที่", "ถึง", "กินข้าว", "แถว", "เที่ยว", "ประชุม", "ดูหนัง"}
	phraseCuts  = []*regexp.Regexp{reClock, reThum, reBai, reMong, reIn, reMidnight, reNoon, reNow, reTransit, reMoto, reCar}
	kindWords   = map[string]string{"บ้าน": domain.KindHome, "home": domain.KindHome,
		"ทำงาน": domain.KindWork, "ออฟฟิศ": domain.KindWork, "office": domain.KindWork, "work": domain.KindWork}
)

// DestinationPhrase is the place a question asks to go to, as typed: the
// words after "ไป" or "กลับ" up to the first time, mode or question word.
// "หกโมงไปกินข้าวแถวสุขุมวิท 55" -> "สุขุมวิท 55". Empty when there is none.
func DestinationPhrase(q string) string {
	start := -1
	for _, verb := range []string{"ไป", "กลับ"} {
		if i := strings.Index(q, verb); i >= 0 && (start < 0 || i < start) {
			start = i + len(verb)
		}
	}
	if start < 0 {
		return ""
	}
	rest := q[start:]
	for _, re := range phraseCuts {
		if loc := re.FindStringIndex(rest); loc != nil {
			rest = rest[:loc[0]]
		}
	}
	for _, stop := range phraseStops {
		if i := strings.Index(rest, stop); i >= 0 {
			rest = rest[:i]
		}
	}
	rest = strings.TrimSpace(rest)
	for trimmed := true; trimmed; {
		trimmed = false
		for _, lead := range phraseLeads {
			if r, ok := strings.CutPrefix(rest, lead); ok {
				rest, trimmed = strings.TrimSpace(r), true
			}
		}
	}
	if len([]rune(rest)) < 2 {
		return ""
	}
	return rest
}

// withDestination fills PlaceQuery and PlaceKind when no saved place matched.
func (in *Intent) withDestination(phrase string) {
	if in.Place != nil || phrase == "" {
		return
	}
	in.PlaceQuery = phrase
	in.PlaceKind = kindWords[strings.ToLower(phrase)]
}

// matchDestination is MatchPlace, except that when the question has a
// destination phrase the keyword must start it: "ไปไอคอนสยาม" is not สยาม.
func matchDestination(q string, places []domain.SavedPlace) *domain.SavedPlace {
	p, ok := MatchPlace(q, places)
	if !ok {
		return nil
	}
	phrase := strings.ToLower(DestinationPhrase(q))
	if phrase == "" {
		return &p
	}
	for _, kw := range p.Keywords {
		if strings.HasPrefix(phrase, strings.ToLower(kw)) {
			return &p
		}
	}
	return nil
}

func parseFallback(q string, now time.Time, places []domain.SavedPlace) Intent {
	in := ParseQuestionTH(q, now)
	in.Place = matchDestination(q, places)
	in.withDestination(DestinationPhrase(q))
	return in
}

// ParseQuestion asks Gemini for structured intent (time, mode and destination
// among the saved places) and falls back to the regex and keyword matching.
func ParseQuestion(ctx context.Context, g *Gemini, q string, now time.Time, trip domain.Trip, places []domain.SavedPlace) (Intent, string) {
	if !g.Available() {
		return parseFallback(q, now, places), "fallback"
	}
	cfg := &genai.GenerateContentConfig{
		Temperature:      temperature(0),
		ResponseMIMEType: "application/json",
		ResponseSchema: &genai.Schema{Type: genai.TypeObject, Properties: map[string]*genai.Schema{
			"depart_at":        {Type: genai.TypeString, Description: "เวลาออกเดินทางแบบ HH:MM 24 ชั่วโมง หรือว่างถ้าไม่ได้พูดถึงเวลา"},
			"mode":             {Type: genai.TypeString, Description: "car, transit หรือ moto หรือว่างถ้าไม่ได้พูดถึง"},
			"destination":      {Type: genai.TypeString, Description: "id ของสถานที่ที่บันทึกไว้ซึ่งผู้ใช้จะไป หรือว่างถ้าไม่ได้พูดถึงปลายทาง"},
			"destination_text": {Type: genai.TypeString, Description: "ชื่อปลายทางตามที่ผู้ใช้พิมพ์ ถ้าไม่ตรงกับสถานที่ที่บันทึกไว้ (เช่น เซ็นทรัลเวิลด์) หรือว่าง"},
		}},
	}
	var saved []string
	for _, p := range places {
		saved = append(saved, fmt.Sprintf("%s = %s (%s)", p.ID, p.LabelTH, p.NameTH))
	}
	deadline := "ไม่มีเวลานัด"
	if !trip.ArriveBy.IsZero() {
		deadline = "ต้องถึงก่อน " + trip.ArriveBy.Format("15:04")
	}
	prompt := fmt.Sprintf("ตอนนี้ %s (เวลาไทย) ทริปปัจจุบันของผู้ใช้คือ %s จาก %s ไป %s %s ด้วย %s\n"+
		"สถานที่ที่บันทึกไว้: %s\n"+
		"คำถาม: %q\nแปลงคำถามเป็นเวลาออกเดินทางที่ผู้ใช้หมายถึง (เช่น สองทุ่ม = 20:00, ห้าโมงครึ่ง = 17:30), วิธีเดินทางถ้าเปลี่ยน (BTS/MRT = transit, มอไซค์ = moto, รถยนต์/แท็กซี่ = car) "+
		"และ id ของสถานที่ปลายทางถ้าคำถามระบุว่าจะไปที่ไหน (สถานที่ที่ใกล้ที่สุดในรายการ เช่น สุขุมวิท 55 = thonglor) ห้ามใส่ต้นทาง",
		now.Format("15:04"), trip.TitleTH, trip.Origin.NameTH, trip.Destination.NameTH, deadline, trip.Mode, strings.Join(saved, ", "), q)
	resp, err := g.Gen.GenerateContent(ctx, g.Model, []*genai.Content{genai.NewContentFromText(prompt, genai.RoleUser)}, cfg)
	if err != nil {
		return parseFallback(q, now, places), "fallback"
	}
	var out struct {
		DepartAt        string `json:"depart_at"`
		Mode            string `json:"mode"`
		Destination     string `json:"destination"`
		DestinationText string `json:"destination_text"`
	}
	if err := decodeJSON(resp.Text(), &out); err != nil {
		return parseFallback(q, now, places), "fallback"
	}
	var in Intent
	for i := range places {
		if places[i].ID == out.Destination {
			in.Place = &places[i]
		}
	}
	if in.Place == nil {
		in.Place = matchDestination(q, places)
	}
	if out.DestinationText == "" {
		out.DestinationText = DestinationPhrase(q)
	}
	in.withDestination(strings.TrimSpace(out.DestinationText))
	if out.DepartAt != "" {
		if t, err := planner.ParseTime(out.DepartAt, now); err == nil {
			if t.Before(now.Add(-30 * time.Minute)) {
				t = t.AddDate(0, 0, 1)
			}
			in.DepartAt = &t
		}
	}
	if m := domain.Mode(out.Mode); m.Valid() {
		in.Mode = &m
	}
	return in, "gemini"
}
