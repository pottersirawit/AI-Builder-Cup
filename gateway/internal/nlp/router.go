package nlp

import (
	"strings"
	"unicode/utf8"
)

// Intent represents the classified conversational category of an incoming message.
type Intent string

const (
	IntentWeather        Intent = "IntentWeather"
	IntentFlood          Intent = "IntentFlood"
	IntentCalendar       Intent = "IntentCalendar"
	IntentVehicleProfile Intent = "IntentVehicleProfile"
	IntentUnknown        Intent = "IntentUnknown"
)

// String returns the string representation of an Intent.
func (i Intent) String() string {
	return string(i)
}

// IsRecognized returns true if the intent is a known domain intent.
func (i Intent) IsRecognized() bool {
	return i != IntentUnknown && i != ""
}

// VehicleMode represents the normalized transportation persona mode.
type VehicleMode string

const (
	VehicleModeSedan      VehicleMode = "compact_sedan"
	VehicleModeMotorcycle VehicleMode = "motorcycle"
	VehicleModePickup     VehicleMode = "pickup"
	VehicleModeTransit    VehicleMode = "transit"
)

// MatchResult contains the comprehensive outcome of intent matching and entity extraction.
type MatchResult struct {
	Intent           Intent            `json:"intent"`
	Confidence       float64           `json:"confidence"`
	MatchedKeywords  []string          `json:"matched_keywords"`
	Entities         map[string]string `json:"entities,omitempty"`
	SecondaryIntent  Intent            `json:"secondary_intent,omitempty"`
	SecondaryMatches []string          `json:"secondary_matches,omitempty"`
	RawText          string            `json:"raw_text"`
}

// HasEntity checks whether an entity key is present.
func (r MatchResult) HasEntity(key string) bool {
	if r.Entities == nil {
		return false
	}
	_, ok := r.Entities[key]
	return ok
}

// VehicleMode returns the extracted vehicle mode if present.
func (r MatchResult) VehicleMode() (VehicleMode, bool) {
	if r.Entities == nil {
		return "", false
	}
	val, ok := r.Entities["vehicle_mode"]
	return VehicleMode(val), ok
}

// VehicleEntityRule associates keywords to vehicle modes.
type VehicleEntityRule struct {
	Keyword     string
	VehicleMode VehicleMode
}

// Default keyword sets defined per specification
var defaultWeatherKeywords = []string{
	"สภาพอากาศ",
	"อากาศ",
	"พยากรณ์",
	"ฝนตก",
	"ร้อน",
	"ฝน",
	"แดด",
	"เรดาร์",
	"พายุ",
	"อุณหภูมิ",
	"weather",
	"forecast",
	"rain",
}

var defaultFloodKeywords = []string{
	"น้ำรอระบาย",
	"จุดเสี่ยง",
	"ระดับน้ำ",
	"น้ำท่วม",
	"คลอง",
	"น้ำท่วมขัง",
	"น้ำล้น",
	"แสนแสบ",
	"ลาดพร้าว",
	"ท่วม",
	"flood",
	"canal",
}

var defaultCalendarKeywords = []string{
	"ตารางงาน",
	"นัดหมาย",
	"ปฏิทิน",
	"เดินทาง",
	"ตารางนัด",
	"ประชุม",
	"นัด",
	"calendar",
	"schedule",
	"meeting",
}

var defaultVehicleRules = []VehicleEntityRule{
	// compact_sedan
	{Keyword: "รถเก๋ง", VehicleMode: VehicleModeSedan},
	{Keyword: "เก๋ง", VehicleMode: VehicleModeSedan},
	{Keyword: "compact_sedan", VehicleMode: VehicleModeSedan},
	{Keyword: "sedan", VehicleMode: VehicleModeSedan},
	{Keyword: "eco car", VehicleMode: VehicleModeSedan},
	{Keyword: "ecocar", VehicleMode: VehicleModeSedan},

	// motorcycle
	{Keyword: "มอเตอร์ไซค์", VehicleMode: VehicleModeMotorcycle},
	{Keyword: "มอเตอร์ไซด์", VehicleMode: VehicleModeMotorcycle},
	{Keyword: "มอไซค์", VehicleMode: VehicleModeMotorcycle},
	{Keyword: "มอไซ", VehicleMode: VehicleModeMotorcycle},
	{Keyword: "motorcycle", VehicleMode: VehicleModeMotorcycle},
	{Keyword: "moto", VehicleMode: VehicleModeMotorcycle},

	// pickup / SUV
	{Keyword: "รถกระบะ", VehicleMode: VehicleModePickup},
	{Keyword: "กระบะ", VehicleMode: VehicleModePickup},
	{Keyword: "suv", VehicleMode: VehicleModePickup},
	{Keyword: "pickup", VehicleMode: VehicleModePickup},
	{Keyword: "รถยกสูง", VehicleMode: VehicleModePickup},

	// transit
	{Keyword: "รถไฟฟ้า", VehicleMode: VehicleModeTransit},
	{Keyword: "bts", VehicleMode: VehicleModeTransit},
	{Keyword: "mrt", VehicleMode: VehicleModeTransit},
	{Keyword: "transit", VehicleMode: VehicleModeTransit},
	{Keyword: "บีทีเอส", VehicleMode: VehicleModeTransit},
	{Keyword: "เอ็มอาร์ที", VehicleMode: VehicleModeTransit},
	{Keyword: "รถเมล์", VehicleMode: VehicleModeTransit},
}

var defaultLandmarks = []string{
	"อโศก", "สุขุมวิท", "ลาดพร้าว", "อุดมสุข", "แจ้งวัฒนะ",
	"รัชดา", "บางนา", "สาทร", "สีลม", "พระราม 9", "พระราม 4",
	"พญาไท", "อนุสาวรีย์", "หมอชิต", "ดอนเมือง", "สุวรรณภูมิ",
	"คลองแสนแสบ", "คลองลาดพร้าว",
}

// Router classifies incoming natural language messages into actionable intents.
type Router struct {
	weatherKeywords  []string
	floodKeywords    []string
	calendarKeywords []string
	vehicleRules     []VehicleEntityRule
	landmarks        []string
}

// NewRouter constructs a Router with default Bangkok Weather resilience rules.
func NewRouter() *Router {
	return &Router{
		weatherKeywords:  defaultWeatherKeywords,
		floodKeywords:    defaultFloodKeywords,
		calendarKeywords: defaultCalendarKeywords,
		vehicleRules:     defaultVehicleRules,
		landmarks:        defaultLandmarks,
	}
}

var defaultRouterInstance = NewRouter()

// DefaultRouter returns the shared package-level Router instance.
func DefaultRouter() *Router {
	return defaultRouterInstance
}

// Route classifies text using the default Router.
func Route(text string) MatchResult {
	return defaultRouterInstance.Route(text)
}

// cleanInput normalizes text: strips invisible zero-width chars and converts ASCII to lowercase.
func cleanInput(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	for _, r := range s {
		switch r {
		case '\u200B', '\u200C', '\u200D', '\uFEFF',
			'\u2060', '\u200E', '\u200F', '\u00AD', '\u180E':
			continue
		case '\u00A0':
			b.WriteRune(' ')
		default:
			b.WriteRune(r)
		}
	}
	return strings.ToLower(strings.TrimSpace(b.String()))
}

// matchKeywords searches for keywords within the normalized text and returns matches and score.
func matchKeywords(text string, keywords []string) ([]string, float64) {
	var matched []string
	var score float64
	for _, kw := range keywords {
		kwNorm := strings.ToLower(kw)
		if strings.Contains(text, kwNorm) {
			matched = append(matched, kw)
			runeLen := utf8.RuneCountInString(kw)
			score += 1.0 + (float64(runeLen) * 0.1)
		}
	}
	return matched, score
}

// Route parses raw text, identifies conversational intent, extracts entities, and scores confidence.
func (r *Router) Route(rawText string) MatchResult {
	cleaned := cleanInput(rawText)
	if cleaned == "" {
		return MatchResult{
			Intent:     IntentUnknown,
			Confidence: 0.0,
			RawText:    rawText,
		}
	}

	entities := make(map[string]string)

	// 1. Vehicle entity extraction
	var matchedVehicleKeywords []string
	var vehicleScore float64
	for _, rule := range r.vehicleRules {
		kwNorm := strings.ToLower(rule.Keyword)
		if strings.Contains(cleaned, kwNorm) {
			if _, exists := entities["vehicle_mode"]; !exists {
				entities["vehicle_mode"] = string(rule.VehicleMode)
			}
			matchedVehicleKeywords = append(matchedVehicleKeywords, rule.Keyword)
			vehicleScore += 1.0 + (float64(utf8.RuneCountInString(rule.Keyword)) * 0.1)
		}
	}

	// 2. Landmark entity extraction
	for _, landmark := range r.landmarks {
		if strings.Contains(cleaned, strings.ToLower(landmark)) {
			if _, exists := entities["location"]; !exists {
				entities["location"] = landmark
			}
			break
		}
	}

	// 3. Match domain intents
	weatherMatches, weatherScore := matchKeywords(cleaned, r.weatherKeywords)
	floodMatches, floodScore := matchKeywords(cleaned, r.floodKeywords)
	calendarMatches, calendarScore := matchKeywords(cleaned, r.calendarKeywords)

	type scoredIntent struct {
		intent  Intent
		score   float64
		matches []string
	}

	var candidates []scoredIntent
	if weatherScore > 0 {
		candidates = append(candidates, scoredIntent{IntentWeather, weatherScore, weatherMatches})
	}
	if floodScore > 0 {
		candidates = append(candidates, scoredIntent{IntentFlood, floodScore, floodMatches})
	}
	if calendarScore > 0 {
		candidates = append(candidates, scoredIntent{IntentCalendar, calendarScore, calendarMatches})
	}

	// Case 1: No query intents matched
	if len(candidates) == 0 {
		if vehicleScore > 0 {
			conf := calculateConfidence(matchedVehicleKeywords)
			return MatchResult{
				Intent:          IntentVehicleProfile,
				Confidence:      conf,
				MatchedKeywords: matchedVehicleKeywords,
				Entities:        entities,
				RawText:         rawText,
			}
		}
		return MatchResult{
			Intent:     IntentUnknown,
			Confidence: 0.0,
			Entities:   entities,
			RawText:    rawText,
		}
	}

	// Sort candidates by score descending
	for i := 0; i < len(candidates)-1; i++ {
		for j := i + 1; j < len(candidates); j++ {
			if candidates[j].score > candidates[i].score {
				candidates[i], candidates[j] = candidates[j], candidates[i]
			}
		}
	}

	primary := candidates[0]
	var secondaryIntent Intent
	var secondaryMatches []string

	if len(candidates) > 1 {
		secondaryIntent = candidates[1].intent
		secondaryMatches = candidates[1].matches
	} else if vehicleScore > 0 {
		secondaryIntent = IntentVehicleProfile
		secondaryMatches = matchedVehicleKeywords
	}

	conf := calculateConfidence(primary.matches)

	return MatchResult{
		Intent:           primary.intent,
		Confidence:       conf,
		MatchedKeywords:  primary.matches,
		Entities:         entities,
		SecondaryIntent:  secondaryIntent,
		SecondaryMatches: secondaryMatches,
		RawText:          rawText,
	}
}

func calculateConfidence(matches []string) float64 {
	if len(matches) == 0 {
		return 0.0
	}
	if len(matches) >= 2 {
		return 0.95
	}
	rLen := utf8.RuneCountInString(matches[0])
	if rLen >= 4 {
		return 0.90
	}
	return 0.85
}
