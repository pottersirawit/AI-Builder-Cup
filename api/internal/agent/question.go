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
}

// SummaryTH describes the intent for the reasoning trace.
func (i Intent) SummaryTH() string {
	var parts []string
	if i.DepartAt != nil {
		parts = append(parts, "ออก "+i.DepartAt.Format("15:04"))
	}
	if i.Mode != nil {
		parts = append(parts, "ไปด้วย"+i.Mode.NameTH())
	}
	if len(parts) == 0 {
		return "ไม่พบเวลาหรือวิธีเดินทางใหม่ในคำถาม ใช้แผนเดิม"
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

// ParseQuestion asks Gemini for structured intent and falls back to the regex.
func ParseQuestion(ctx context.Context, g *Gemini, q string, now time.Time, trip domain.Trip) (Intent, string) {
	if !g.Available() {
		return ParseQuestionTH(q, now), "fallback"
	}
	cfg := &genai.GenerateContentConfig{
		Temperature:      temperature(0),
		ResponseMIMEType: "application/json",
		ResponseSchema: &genai.Schema{Type: genai.TypeObject, Properties: map[string]*genai.Schema{
			"depart_at": {Type: genai.TypeString, Description: "เวลาออกเดินทางแบบ HH:MM 24 ชั่วโมง หรือว่างถ้าไม่ได้พูดถึงเวลา"},
			"mode":      {Type: genai.TypeString, Description: "car, transit หรือ moto หรือว่างถ้าไม่ได้พูดถึง"},
		}},
	}
	prompt := fmt.Sprintf("ตอนนี้ %s (เวลาไทย) ผู้ใช้กำลังจะเดินทาง %s จาก %s ไป %s ต้องถึงก่อน %s ด้วย %s\n"+
		"คำถาม: %q\nแปลงคำถามเป็นเวลาออกเดินทางที่ผู้ใช้หมายถึง (เช่น สองทุ่ม = 20:00, ห้าโมงครึ่ง = 17:30) และวิธีเดินทางถ้าเปลี่ยน (BTS/MRT = transit, มอไซค์ = moto, รถยนต์/แท็กซี่ = car)",
		now.Format("15:04"), trip.TitleTH, trip.Origin.NameTH, trip.Destination.NameTH, trip.ArriveBy.Format("15:04"), trip.Mode, q)
	resp, err := g.Gen.GenerateContent(ctx, g.Model, []*genai.Content{genai.NewContentFromText(prompt, genai.RoleUser)}, cfg)
	if err != nil {
		return ParseQuestionTH(q, now), "fallback"
	}
	var out struct {
		DepartAt string `json:"depart_at"`
		Mode     string `json:"mode"`
	}
	if err := decodeJSON(resp.Text(), &out); err != nil {
		return ParseQuestionTH(q, now), "fallback"
	}
	var in Intent
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
