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
	"กินข้าวเย็นกับที่บ้าน":                 "Dinner with family",
	"คอนเสิร์ตที่อิมแพ็ค":                   "Concert at IMPACT",
	"สามย่านมิตรทาวน์":                      "Samyan Mitrtown",
	"ฟิตเนส เซ็นทรัลลาดพร้าว":               "Fitness, Central Ladprao",
	"ทรู ดิจิทัล พาร์ค":                     "True Digital Park",
	"สวนลุมพินี":                            "Lumphini Park",
	"ท่าอากาศยานดอนเมือง":                   "Don Mueang Airport",
	"โรงพยาบาลพระราม 9":                     "Praram 9 Hospital",
	"ประชุมลูกค้า Q4":                       "Q4 client meeting",
	"เวทเทรนนิ่ง":                           "Weight training",
	"Daily standup ที่ออฟฟิศ":               "Daily standup at the office",
	"กินข้าวกับพี่เบียร์":                   "Lunch with Beer",
	"โยคะสวนลุม":                            "Yoga at Lumphini Park",
	"เที่ยวบิน FD3433 ไปเชียงใหม่":          "Flight FD3433 to Chiang Mai",
	"ตรวจสุขภาพประจำปี":                     "Annual health check-up",
	"ซิงก์งานกับทีม (Google Meet)":          "Team sync (Google Meet)",
	"รีวิวงานที่ทองหล่อ":                    "Work review in Thong Lo",
	"ออนไลน์":                               "Online",
	"สีลม (ยังไม่ได้ตั้งบ้าน)":              "Silom (no home set)",
	"นัดหมายในปฏิทิน":                       "Calendar event",
	"ตั๋วหรือนัดหมายการเดินทาง":             "Ticket or booking",
	"สายด่วนฉุกเฉิน (ปภ. 1784 / สพฉ. 1669)": "Emergency hotlines (DDPM 1784 / EMS 1669)",
	"Gemini อ่านจากอีเมลของคุณ":             "Read by Gemini from your email",
	"พระราม 4":                              "Rama IV",
	"อโศก":                                  "Asok",
	"รัชดาภิเษก":                            "Ratchadaphisek",
	"ทางพิเศษศรีรัช":                        "Si Rat Expressway",
	"แจ้งวัฒนะ":                             "Chaeng Watthana",
	"ราชดำริ":                               "Ratchadamri",
	"สุขุมวิท":                              "Sukhumvit",
	"พหลโยธิน":                              "Phahon Yothin",
	"วิภาวดีรังสิต":                          "Vibhavadi Rangsit",
	"เพชรบุรี":                              "Phetchaburi",
	"MRT สายสีน้ำเงิน":                      "MRT Blue Line",
	"BTS สายสีลม":                           "BTS Silom Line",
	"BTS สายสุขุมวิท":                        "BTS Sukhumvit Line",
	"MRT สายสีชมพู":                         "MRT Pink Line",
	"MRT สายสีเหลือง":                       "MRT Yellow Line",
	"ARL แอร์พอร์ตเรลลิงก์":                  "Airport Rail Link",
	"MRT ท่าพระ":                            "MRT Tha Phra",
	"MRT หัวลำโพง":                          "MRT Hua Lamphong",
	"MRT สามย่าน":                           "MRT Sam Yan",
	"MRT สีลม":                              "MRT Silom",
	"MRT ลุมพินี":                           "MRT Lumphini",
	"MRT คลองเตย":                           "MRT Khlong Toei",
	"MRT ศูนย์การประชุมแห่งชาติสิริกิติ์":         "MRT Queen Sirikit Center",
	"MRT สุขุมวิท":                          "MRT Sukhumvit",
	"MRT เพชรบุรี":                          "MRT Phetchaburi",
	"MRT พระราม 9":                          "MRT Phra Ram 9",
	"MRT ห้วยขวาง":                          "MRT Huai Khwang",
	"MRT สุทธิสาร":                          "MRT Sutthisan",
	"MRT รัชดาภิเษก":                        "MRT Ratchadaphisek",
	"MRT ลาดพร้าว":                          "MRT Lat Phrao",
	"MRT พหลโยธิน":                          "MRT Phahon Yothin",
	"MRT สวนจตุจักร":                        "MRT Chatuchak Park",
	"MRT บางซื่อ":                           "MRT Bang Sue",
	"MRT เตาปูน":                            "MRT Tao Poon",
	"BTS บางหว้า":                           "BTS Bang Wa",
	"BTS กรุงธนบุรี":                        "BTS Krung Thon Buri",
	"BTS ช่องนนทรี":                         "BTS Chong Nonsi",
	"BTS ศาลาแดง":                           "BTS Sala Daeng",
	"BTS ราชดำริ":                           "BTS Ratchadamri",
	"BTS สยาม":                              "BTS Siam",
	"BTS สนามกีฬาแห่งชาติ":                   "BTS National Stadium",
	"BTS แบริ่ง":                            "BTS Bearing",
	"BTS บางนา":                             "BTS Bang Na",
	"BTS อ่อนนุช":                           "BTS On Nut",
	"BTS เอกมัย":                            "BTS Ekkamai",
	"BTS ทองหล่อ":                           "BTS Thong Lo",
	"BTS พร้อมพงษ์":                         "BTS Phrom Phong",
	"BTS อโศก":                              "BTS Asok",
	"BTS นานา":                              "BTS Nana",
	"BTS ชิดลม":                             "BTS Chit Lom",
	"BTS พญาไท":                             "BTS Phaya Thai",
	"BTS อนุสาวรีย์ชัยสมรภูมิ":               "BTS Victory Monument",
	"BTS อารีย์":                            "BTS Ari",
	"BTS หมอชิต":                            "BTS Mo Chit",
	"BTS ห้าแยกลาดพร้าว":                    "BTS Ha Yaek Lat Phrao",
	"BTS มหาวิทยาลัยเกษตรศาสตร์":             "BTS Kasetsart University",
	"BTS วัดพระศรีมหาธาตุ":                   "BTS Wat Phra Sri Mahathat",
	"MRT ศูนย์ราชการนนทบุรี":                 "MRT Nonthaburi Civic Center",
	"MRT เมืองทองธานี":                       "MRT Muang Thong Thani",
	"MRT อิมแพ็ค เมืองทองธานี":               "MRT IMPACT Muang Thong Thani",
	"MRT วัดพระศรีมหาธาตุ":                   "MRT Wat Phra Sri Mahathat",
	"MRT บางกะปิ":                           "MRT Bang Kapi",
	"MRT ศรีเอี่ยม":                         "MRT Si Iam",
	"ARL พญาไท":                             "ARL Phaya Thai",
	"ARL มักกะสัน":                          "ARL Makkasan",
	"ARL รามคำแหง":                          "ARL Ramkhamhaeng",
	"ARL ลาดกระบัง":                         "ARL Lat Krabang",
	"น้ำขังเลนซ้าย รถเก๋งเริ่มชะลอ":         "Water pooling in the left lane; cars are starting to slow down.",
	"น้ำเกือบครึ่งล้อ ทางเท้าจม":            "Water is almost halfway up a wheel and the pavement is under.",
	"น้ำเอ่อจากคลองเข้าซอย":                 "Canal water is spilling into the soi.",
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
	t.TitleTH, t.NoteTH = Text(t.TitleTH, l), Text(t.NoteTH, l)
	t.Origin, t.Destination = LocalizePlace(t.Origin, l), LocalizePlace(t.Destination, l)
	return t
}

// LocalizeRoute translates r's ViaTH and TransitLegs into l.
func LocalizeRoute(r domain.Route, l domain.Lang) domain.Route {
	if l != domain.LangEN {
		return r
	}
	if len(r.ViaTH) > 0 {
		via := make([]string, len(r.ViaTH))
		for i, v := range r.ViaTH {
			via[i] = Text(v, l)
		}
		r.ViaTH = via
	}
	if len(r.TransitLegs) > 0 {
		legs := make([]domain.TransitLeg, len(r.TransitLegs))
		for i, leg := range r.TransitLegs {
			legs[i] = domain.TransitLeg{
				LineTH:        Text(leg.LineTH, l),
				FromStationTH: Text(leg.FromStationTH, l),
				ToStationTH:   Text(leg.ToStationTH, l),
				StopCount:     leg.StopCount,
			}
		}
		r.TransitLegs = legs
	}
	return r
}
