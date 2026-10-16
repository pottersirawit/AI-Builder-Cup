package scenario

import "github.com/pottersirawit/fontokmai/api/internal/domain"

// english maps the scenario's Thai display text (saved place names and labels,
// trip titles, route roads, report descriptions) to English. Bangkok road and
// station names are data, so they are transliterated rather than translated.
var english = map[string]string{
	"สีลม ซอย 3":           "Silom Soi 3",
	"บ้านลาดพร้าว":         "Home (Lat Phrao)",
	"อิมแพ็ค เมืองทองธานี": "IMPACT Muang Thong Thani",
	"สยาม":     "Siam",
	"ทองหล่อ":  "Thong Lo",
	"บ้าน":     "Home",
	"ที่ทำงาน": "Work",
	"อิมแพ็ค":  "IMPACT",
	"กินข้าวเย็นกับที่บ้าน":         "Dinner with family",
	"คอนเสิร์ตที่อิมแพ็ค":           "Concert at IMPACT",
	"สามย่านมิตรทาวน์":              "Samyan Mitrtown",
	"ฟิตเนส เซ็นทรัลลาดพร้าว":       "Fitness, Central Ladprao",
	"ทรู ดิจิทัล พาร์ค":             "True Digital Park",
	"สวนลุมพินี":                    "Lumphini Park",
	"ท่าอากาศยานดอนเมือง":           "Don Mueang Airport",
	"โรงพยาบาลพระราม 9":             "Praram 9 Hospital",
	"ประชุมลูกค้า Q4":               "Q4 client meeting",
	"เวทเทรนนิ่ง":                   "Weight training",
	"Daily standup ที่ออฟฟิศ":       "Daily standup at the office",
	"กินข้าวกับพี่เบียร์":           "Lunch with Beer",
	"โยคะสวนลุม":                    "Yoga at Lumphini Park",
	"เที่ยวบิน FD3433 ไปเชียงใหม่":  "Flight FD3433 to Chiang Mai",
	"ตรวจสุขภาพประจำปี":             "Annual health check-up",
	"พระราม 4":                      "Rama IV",
	"อโศก":                          "Asok",
	"รัชดาภิเษก":                    "Ratchadaphisek",
	"MRT สีลม":                      "MRT Silom",
	"MRT สุขุมวิท":                  "MRT Sukhumvit",
	"MRT ลาดพร้าว":                  "MRT Lat Phrao",
	"น้ำขังเลนซ้าย รถเก๋งเริ่มชะลอ": "Water pooling in the left lane; cars are starting to slow down.",
	"น้ำเกือบครึ่งล้อ ทางเท้าจม":    "Water is almost halfway up a wheel and the pavement is under.",
	"น้ำเอ่อจากคลองเข้าซอย":         "Canal water is spilling into the soi.",
	"น้ำถึงประมาณครึ่งล้อรถเก๋ง เห็นทางเท้าจมแล้ว รถเก๋งผ่านได้ช้า ๆ ทางเลนขวา มอเตอร์ไซค์ไม่ควรผ่าน": "Water is about halfway up a car wheel and the pavement is under. Cars can pass slowly in the right lane; motorbikes should not.",
}

// Text is a scenario display string in l. Text it does not know (user-entered
// names, dataset names) comes back unchanged.
func Text(th string, l domain.Lang) string {
	if l == domain.LangEN {
		if en, ok := english[th]; ok {
			return en
		}
	}
	return th
}

// LocalizePlace gives p a name in l.
func LocalizePlace(p domain.Place, l domain.Lang) domain.Place {
	p.NameTH = Text(p.NameTH, l)
	return p
}

// LocalizeReport gives r's description in l.
func LocalizeReport(r domain.Report, l domain.Lang) domain.Report {
	r.DescriptionTH = Text(r.DescriptionTH, l)
	return r
}

// LocalizeTrip gives t's title and place names in l.
func LocalizeTrip(t domain.Trip, l domain.Lang) domain.Trip {
	t.TitleTH = Text(t.TitleTH, l)
	t.Origin, t.Destination = LocalizePlace(t.Origin, l), LocalizePlace(t.Destination, l)
	return t
}
