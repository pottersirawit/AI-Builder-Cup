package line

import (
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"testing"
	"unicode/utf8"

	"github.com/saransirichote/weather-resilience-gateway/internal/model"
)

// TestChallenger_ConcurrencyAndRaces stresses flex_builder under high concurrency
// to detect race conditions, state leakages, or concurrent map read/write panics.
func TestChallenger_ConcurrencyAndRaces(t *testing.T) {
	const goroutines = 100
	const iterations = 50

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for g := 0; g < goroutines; g++ {
		go func(routineID int) {
			defer wg.Done()
			for i := 0; i < iterations; i++ {
				adv := model.AdvisoryPayload{
					Title:            fmt.Sprintf("เตือนภัยรอบที่ %d-%d ⛈️", routineID, i),
					UrgencyLevel:     "CRITICAL",
					LocationName:     "สุขุมวิท / อโศก",
					Temperature:      32.5,
					Condition:        "ฝนฟ้าคะนอง",
					RainRate:         65.0,
					CanalName:        "คลองแสนแสบ",
					CanalStage:       1.35,
					CanalRemainingCm: 10.0,
					HeatIndex:        41.0,
					WindGust:         55.0,
					VehicleType:      "sedan",
					FloodDepthCm:     20.0,
					ActionChecklist: []string{
						"นำรถขึ้นที่สูง",
						"ติดตามเรดาร์ กทม.",
					},
					AlternativeRoutesOrActions: "ใช้ทางด่วน",
					LIFFURL:                    "https://liff.line.me/test-weather",
				}

				bubble := BuildFlexMessageBubble(adv)
				if bubble["type"] != "bubble" {
					t.Errorf("routine %d iteration %d: invalid bubble type", routineID, i)
				}

				// Concurrently build carousel
				bubbles := []map[string]interface{}{bubble, bubble}
				carousel := BuildFlexMessageCarousel(bubbles)
				if carousel["type"] != "carousel" {
					t.Errorf("routine %d iteration %d: invalid carousel type", routineID, i)
				}

				// Concurrently build quick replies
				qr := DefaultQuickReplies("https://liff.line.me/test-weather")
				if items, ok := qr["items"].([]map[string]interface{}); !ok || len(items) == 0 {
					t.Errorf("routine %d iteration %d: invalid quick reply items", routineID, i)
				}

				// Round-trip serialize to ensure JSON safety under concurrency
				jsonBytes, err := json.Marshal(carousel)
				if err != nil {
					t.Errorf("routine %d iteration %d: JSON marshal error: %v", routineID, i, err)
				}
				if len(jsonBytes) == 0 {
					t.Errorf("routine %d iteration %d: empty JSON bytes", routineID, i)
				}
			}
		}(g)
	}

	wg.Wait()
}

// TestChallenger_ExtremeWeatherValues verifies system resilience against extreme inputs:
// - Extreme rainfall (>500 mm/h)
// - Negative rainfall (<0 mm/h)
// - Extreme heat (>50 °C)
// - Sub-zero heat index (<0 °C)
// - Extreme wind gust (>100 km/h)
// - Negative flood depths (<0 cm)
// - Extreme flood depths (>200 cm)
// - Canal overflow with negative remaining capacity
func TestChallenger_ExtremeWeatherValues(t *testing.T) {
	tests := []struct {
		name                 string
		adv                  model.AdvisoryPayload
		expectedRainSeverity string
		expectedRainColor    string
		expectedCanalColor   string
		expectedHeatSeverity string
		expectedHeatColor    string
		expectedWindSeverity string
		expectedWindColor    string
		expectedVehBadgeSub  string
		expectedVehColor     string
	}{
		{
			name: "Extreme rainfall > 500 mm/h (flash flood cloudburst)",
			adv: model.AdvisoryPayload{
				Title:            "พายุฝนระดับรุนแรงสูงสุดเป็นประวัติการณ์",
				UrgencyLevel:     "CRITICAL",
				RainRate:         550.0,
				CanalName:        "คลองลาดพร้าว",
				CanalStage:       2.50,
				CanalRemainingCm: -10.0, // Water has completely overflowed bank by 10cm
				HeatIndex:        28.0,
				WindGust:         75.0,
				VehicleType:      "sedan",
				FloodDepthCm:     45.0,
			},
			expectedRainSeverity: "ฝนตกหนักมาก",
			expectedRainColor:    ColorUrgencyCritical,
			expectedCanalColor:   ColorUrgencyCritical,
			expectedHeatSeverity: "ระดับปกติ",
			expectedHeatColor:    ColorUrgencyInfo,
			expectedWindSeverity: "ระวังกิ่งไม้/ป้ายปลิว",
			expectedWindColor:    ColorUrgencyCritical,
			expectedVehBadgeSub:  "วิกฤตน้ำท่วมขัง",
			expectedVehColor:     "#2D121B",
		},
		{
			name: "Extreme heat > 50 °C (severe heatstroke danger)",
			adv: model.AdvisoryPayload{
				Title:            "คลื่นความร้อนรุนแรงสูงสุด",
				UrgencyLevel:     "CRITICAL",
				RainRate:         0.0,
				CanalName:        "คลองบางเขน",
				CanalStage:       0.30,
				CanalRemainingCm: 150.0,
				HeatIndex:        54.5,
				WindGust:         12.0,
				VehicleType:      "motorcycle",
				FloodDepthCm:     0.0,
			},
			expectedRainSeverity: "ไม่มีกลุ่มฝน",
			expectedRainColor:    ColorUrgencyInfo,
			expectedCanalColor:   ColorUrgencyInfo,
			expectedHeatSeverity: "ระดับอันตราย",
			expectedHeatColor:    ColorUrgencyCritical,
			expectedWindSeverity: "ลมสงบปกติ",
			expectedWindColor:    ColorUrgencyInfo,
			expectedVehBadgeSub:  "สภาพลมและถนนปลอดภัย",
			expectedVehColor:     ColorBgCard,
		},
		{
			name: "Extreme wind gust > 100 km/h (typhoon / microburst)",
			adv: model.AdvisoryPayload{
				Title:            "ลมพายุหมุนกระโชกแรงระดับพายุโซนร้อน",
				UrgencyLevel:     "CRITICAL",
				RainRate:         120.0,
				CanalName:        "คลองเปรมประชากร",
				CanalStage:       1.80,
				CanalRemainingCm: 5.0,
				HeatIndex:        30.0,
				WindGust:         115.0,
				VehicleType:      "moto",
				FloodDepthCm:     15.0,
			},
			expectedRainSeverity: "ฝนตกหนักมาก",
			expectedRainColor:    ColorUrgencyCritical,
			expectedCanalColor:   ColorUrgencyCritical,
			expectedHeatSeverity: "ระดับปกติ",
			expectedHeatColor:    ColorUrgencyInfo,
			expectedWindSeverity: "ระวังกิ่งไม้/ป้ายปลิว",
			expectedWindColor:    ColorUrgencyCritical,
			expectedVehBadgeSub:  "เสี่ยงลมกระโชกและน้ำท่วม",
			expectedVehColor:     "#2D121B",
		},
		{
			name: "Negative flood depth (-10 cm) & negative rain (-5 mm/h)",
			adv: model.AdvisoryPayload{
				Title:            "สภาวะแห้งแล้ง / ตัวเลขติดลบ",
				UrgencyLevel:     "INFO",
				RainRate:         -5.0,
				CanalName:        "คลองพระโขนง",
				CanalStage:       -0.50,
				CanalRemainingCm: 200.0,
				HeatIndex:        -2.0,
				WindGust:         -1.0,
				VehicleType:      "sedan",
				FloodDepthCm:     -10.0,
			},
			expectedRainSeverity: "ไม่มีกลุ่มฝน",
			expectedRainColor:    ColorUrgencyInfo,
			expectedCanalColor:   ColorUrgencyInfo,
			expectedHeatSeverity: "ระดับปกติ",
			expectedHeatColor:    ColorUrgencyInfo,
			expectedWindSeverity: "ลมสงบปกติ",
			expectedWindColor:    ColorUrgencyInfo,
			expectedVehBadgeSub:  "ระดับน้ำปกติ สัญจรได้",
			expectedVehColor:     ColorBgCard,
		},
		{
			name: "Extreme flood depth > 200 cm (pickup submergence)",
			adv: model.AdvisoryPayload{
				Title:            "มหาอุทกภัยน้ำท่วมสูง 2 เมตร",
				UrgencyLevel:     "CRITICAL",
				RainRate:         150.0,
				CanalName:        "แม่น้ำเจ้าพระยา",
				CanalStage:       3.20,
				CanalRemainingCm: -50.0,
				HeatIndex:        31.0,
				WindGust:         40.0,
				VehicleType:      "pickup",
				FloodDepthCm:     210.0,
			},
			expectedRainSeverity: "ฝนตกหนักมาก",
			expectedRainColor:    ColorUrgencyCritical,
			expectedCanalColor:   ColorUrgencyCritical,
			expectedHeatSeverity: "ระดับปกติ",
			expectedHeatColor:    ColorUrgencyInfo,
			expectedWindSeverity: "ลมกระโชกปานกลาง",
			expectedWindColor:    ColorUrgencyWarning,
			expectedVehBadgeSub:  "น้ำท่วมระดับวิกฤต",
			expectedVehColor:     "#2D121B",
		},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			bubble := BuildFlexMessageBubble(tc.adv)

			// 1. Must serialize to valid JSON without error
			jsonBytes, err := json.Marshal(bubble)
			if err != nil {
				t.Fatalf("failed to marshal bubble with extreme values: %v", err)
			}

			// 2. Must deserialize cleanly
			var parsed map[string]interface{}
			if err := json.Unmarshal(jsonBytes, &parsed); err != nil {
				t.Fatalf("failed to unmarshal JSON: %v", err)
			}

			// 3. Check Bento tile values & severity pills
			body := bubble["body"].(map[string]interface{})
			contents := body["contents"].([]map[string]interface{})
			bentoGrid := contents[1]["contents"].([]map[string]interface{})

			// Rain tile
			rainTile := bentoGrid[0]["contents"].([]map[string]interface{})[0]
			rainPillText := rainTile["contents"].([]map[string]interface{})[2]["text"].(string)
			if rainPillText != tc.expectedRainSeverity {
				t.Errorf("expected rain pill %q, got %q", tc.expectedRainSeverity, rainPillText)
			}

			// Heat tile
			heatTile := bentoGrid[1]["contents"].([]map[string]interface{})[0]
			heatPillText := heatTile["contents"].([]map[string]interface{})[2]["text"].(string)
			if heatPillText != tc.expectedHeatSeverity {
				t.Errorf("expected heat pill %q, got %q", tc.expectedHeatSeverity, heatPillText)
			}

			// Wind tile
			windTile := bentoGrid[1]["contents"].([]map[string]interface{})[1]
			windPillText := windTile["contents"].([]map[string]interface{})[2]["text"].(string)
			if windPillText != tc.expectedWindSeverity {
				t.Errorf("expected wind pill %q, got %q", tc.expectedWindSeverity, windPillText)
			}

			// Vehicle clearance card
			vehCard := contents[2]
			vehContents := vehCard["contents"].([]map[string]interface{})
			badgeText := vehContents[0]["text"].(string)
			if !strings.Contains(badgeText, tc.expectedVehBadgeSub) {
				t.Errorf("expected vehicle badge to contain %q, got %q", tc.expectedVehBadgeSub, badgeText)
			}
			if vehCard["backgroundColor"] != tc.expectedVehColor {
				t.Errorf("expected vehicle card background %q, got %v", tc.expectedVehColor, vehCard["backgroundColor"])
			}
		})
	}
}

// TestChallenger_ThaiUnicodeAndEmojis tests multi-byte Thai strings, combining vowels,
// tone marks, complex compound emojis, and long text in titles and checklists.
func TestChallenger_ThaiUnicodeAndEmojis(t *testing.T) {
	// Thai text with combining marks, tone marks, and complex emojis
	titleWithToneMarks := "⚠️ พายุฤดูร้อนถล่มกรุงเทพฯ น้ำท่วมขังรอการระบาย ⛈️🌊🚨"
	locationWithSpecialChars := "เขตวัฒนา / คลองเตย / ถ.สุขุมวิท ๗๑ (ปรีดี พนมยงค์) 📍"
	checklistWithEmojis := []string{
		"🚨 หลีกเลี่ยงเส้นทางน้ำท่วมขัง: ถ.พระราม ๔, ถ.สุขุมวิท ๒๑",
		"🚗 ตรวจเช็กระดับน้ำ: หากเกิน ๑๕ ซม. ห้ามลุยเด็ดขาด",
		"📱 ติดตามการแจ้งเตือนจากศูนย์ควบคุมระบบป้องกันน้ำท่วม กทม. ผ่าน LINE",
		"🌧️ เฝ้าระวังฝนตกหนักสะสมในพื้นที่ ๒๔ ชั่วโมงข้างหน้า",
		"👨‍👩‍👧‍👦 แจ้งเตือนคนในครอบครัวและวางแผนการเดินทางล่วงหน้า",
	}

	adv := model.AdvisoryPayload{
		Title:                      titleWithToneMarks,
		UrgencyLevel:               "CRITICAL",
		SummaryText:                "รายงานสถานการณ์น้ำท่วมฉับพลันและน้ำป่าไหลหลากในพื้นที่กรุงเทพมหานครและปริมณฑล",
		CriticalWindow:             "๑๖:๓๐ - ๑๙:๓๐ น.",
		LocationName:               locationWithSpecialChars,
		Temperature:                27.5,
		Condition:                  "⛈️ ฝนฟ้าคะนองร้อยละ ๘๐ ของพื้นที่",
		RainRate:                   95.0,
		CanalName:                  "คลองแสนแสบ (ประตูระบายน้ำสระปทุม)",
		CanalStage:                 1.85,
		CanalRemainingCm:           8.0,
		HeatIndex:                  36.0,
		WindGust:                   48.0,
		VehicleType:                "sedan",
		FloodDepthCm:               22.0,
		ActionChecklist:            checklistWithEmojis,
		AlternativeRoutesOrActions: "ใช้ทางพิเศษศรีรัช หรือรถไฟฟ้า BTS สายสุขุมวิท 🚆",
		LIFFURL:                    "https://liff.line.me/weather-thailand",
	}

	bubble := BuildFlexMessageBubble(adv)

	// Validate JSON serialization
	jsonBytes, err := json.Marshal(bubble)
	if err != nil {
		t.Fatalf("failed to marshal bubble with Thai unicode & emojis: %v", err)
	}

	if !utf8.Valid(jsonBytes) {
		t.Fatalf("marshaled JSON contains invalid UTF-8 bytes")
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(jsonBytes, &parsed); err != nil {
		t.Fatalf("failed to unmarshal JSON: %v", err)
	}

	// Verify Header Title text matches verbatim
	header := parsed["header"].(map[string]interface{})
	headerContents := header["contents"].([]interface{})
	parsedTitle := headerContents[2].(map[string]interface{})["text"].(string)
	if parsedTitle != titleWithToneMarks {
		t.Errorf("title mismatch: expected %q, got %q", titleWithToneMarks, parsedTitle)
	}
	if !utf8.ValidString(parsedTitle) {
		t.Errorf("title contains invalid UTF-8")
	}

	// Verify Checklist items match verbatim and retain all emojis
	body := parsed["body"].(map[string]interface{})
	bodyContents := body["contents"].([]interface{})
	checklistBlock := bodyContents[3].(map[string]interface{})
	parsedChecklist := checklistBlock["contents"].([]interface{})

	// Index 0 is the checklist header; indices 1..5 are items
	if len(parsedChecklist) != len(checklistWithEmojis)+1 {
		t.Fatalf("expected %d checklist items (including header), got %d", len(checklistWithEmojis)+1, len(parsedChecklist))
	}

	for i, expectedItem := range checklistWithEmojis {
		itemBox := parsedChecklist[i+1].(map[string]interface{})
		itemContents := itemBox["contents"].([]interface{})
		itemText := itemContents[1].(map[string]interface{})["text"].(string)
		if itemText != expectedItem {
			t.Errorf("checklist item %d mismatch: expected %q, got %q", i, expectedItem, itemText)
		}
		if !utf8.ValidString(itemText) {
			t.Errorf("checklist item %d is corrupted UTF-8: %q", i, itemText)
		}
	}
}

// TestChallenger_CarouselCapping_ExactBounds challenges the carousel container
// with exact boundary counts: 0, 1, 12, 13, 50 bubbles.
func TestChallenger_CarouselCapping_ExactBounds(t *testing.T) {
	createBubble := func(id int) map[string]interface{} {
		return map[string]interface{}{
			"type": "bubble",
			"body": map[string]interface{}{
				"type": "box",
				"contents": []map[string]interface{}{
					{"type": "text", "text": fmt.Sprintf("Bubble #%d", id)},
				},
			},
		}
	}

	tests := []struct {
		name          string
		inputCount    int
		expectedCount int
	}{
		{name: "0 bubbles (empty slice)", inputCount: 0, expectedCount: 0},
		{name: "1 bubble (minimum carousel)", inputCount: 1, expectedCount: 1},
		{name: "12 bubbles (maximum allowed by LINE)", inputCount: 12, expectedCount: 12},
		{name: "13 bubbles (exceeds limit by 1 -> capped at 12)", inputCount: 13, expectedCount: 12},
		{name: "50 bubbles (stress overload -> capped at 12)", inputCount: 50, expectedCount: 12},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			bubbles := make([]map[string]interface{}, tc.inputCount)
			for i := 0; i < tc.inputCount; i++ {
				bubbles[i] = createBubble(i + 1)
			}

			carousel := BuildFlexMessageCarousel(bubbles)

			if carousel["type"] != "carousel" {
				t.Fatalf("expected type 'carousel', got %v", carousel["type"])
			}

			contents, ok := carousel["contents"].([]map[string]interface{})
			if !ok {
				t.Fatalf("expected contents to be []map[string]interface{}, got %T", carousel["contents"])
			}

			if len(contents) != tc.expectedCount {
				t.Fatalf("expected %d bubbles, got %d", tc.expectedCount, len(contents))
			}

			// Verify capping does not mutate beyond 12
			if len(contents) > 12 {
				t.Errorf("VIOLATION: Carousel contains %d bubbles, exceeding LINE limit of 12!", len(contents))
			}

			// Validate JSON serialization
			jsonBytes, err := json.Marshal(carousel)
			if err != nil {
				t.Fatalf("failed to marshal carousel: %v", err)
			}

			var parsed map[string]interface{}
			if err := json.Unmarshal(jsonBytes, &parsed); err != nil {
				t.Fatalf("failed to unmarshal carousel JSON: %v", err)
			}
			parsedContents := parsed["contents"].([]interface{})
			if len(parsedContents) != tc.expectedCount {
				t.Errorf("round-trip mismatch: expected %d, got %d", tc.expectedCount, len(parsedContents))
			}
		})
	}
}

// TestChallenger_QuickReply_ExactBounds challenges the quick reply container
// with exact boundary counts: 0, 1, 13, 14, 50 items.
func TestChallenger_QuickReply_ExactBounds(t *testing.T) {
	createItem := func(id int) QuickReplyItem {
		return QuickReplyItem{
			ActionType: "message",
			Label:      fmt.Sprintf("เมนู %d", id),
			Text:       fmt.Sprintf("คำสั่ง %d", id),
		}
	}

	tests := []struct {
		name          string
		inputCount    int
		expectedCount int
	}{
		{name: "0 items (empty slice)", inputCount: 0, expectedCount: 0},
		{name: "1 item (single quick reply)", inputCount: 1, expectedCount: 1},
		{name: "13 items (maximum allowed by LINE)", inputCount: 13, expectedCount: 13},
		{name: "14 items (exceeds limit by 1 -> capped at 13)", inputCount: 14, expectedCount: 13},
		{name: "50 items (stress overload -> capped at 13)", inputCount: 50, expectedCount: 13},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			items := make([]QuickReplyItem, tc.inputCount)
			for i := 0; i < tc.inputCount; i++ {
				items[i] = createItem(i + 1)
			}

			qr := BuildQuickReplies(items)

			actions, ok := qr["items"].([]map[string]interface{})
			if !ok {
				t.Fatalf("expected items to be []map[string]interface{}, got %T", qr["items"])
			}

			if len(actions) != tc.expectedCount {
				t.Fatalf("expected %d items, got %d", tc.expectedCount, len(actions))
			}

			if len(actions) > 13 {
				t.Errorf("VIOLATION: Quick Reply contains %d items, exceeding LINE limit of 13!", len(actions))
			}

			// Validate JSON serialization
			jsonBytes, err := json.Marshal(qr)
			if err != nil {
				t.Fatalf("failed to marshal quick replies: %v", err)
			}

			var parsed map[string]interface{}
			if err := json.Unmarshal(jsonBytes, &parsed); err != nil {
				t.Fatalf("failed to unmarshal quick reply JSON: %v", err)
			}
			parsedItems := parsed["items"].([]interface{})
			if len(parsedItems) != tc.expectedCount {
				t.Errorf("round-trip mismatch: expected %d, got %d", tc.expectedCount, len(parsedItems))
			}
		})
	}
}

// TestChallenger_QuickReply_RuneTruncation_MultiByte challenges label rune truncation
// specifically on multi-byte UTF-8 Thai runes, combining vowels, and emojis around
// the 20-rune boundary. Ensures that multi-byte UTF-8 runes are NEVER cut in half.
func TestChallenger_QuickReply_RuneTruncation_MultiByte(t *testing.T) {
	tests := []struct {
		name          string
		inputLabel    string
		expectedRunes int
		checkPrefix   string
	}{
		{
			name:          "Thai exactly 19 runes (under limit)",
			inputLabel:    "สภาพอากาศกรุงเทพ๑๒๓", // 19 runes
			expectedRunes: 19,
			checkPrefix:   "สภาพอากาศกรุงเทพ๑๒๓",
		},
		{
			name:          "Thai exactly 20 runes (boundary)",
			inputLabel:    "สภาพอากาศกรุงเทพ๑๒๓๔", // 20 runes
			expectedRunes: 20,
			checkPrefix:   "สภาพอากาศกรุงเทพ๑๒๓๔",
		},
		{
			name:          "Thai 21 runes (1 rune over limit -> truncated to 20)",
			inputLabel:    "สภาพอากาศกรุงเทพ๑๒๓๔๕", // 21 runes
			expectedRunes: 20,
			checkPrefix:   "สภาพอากาศกรุงเทพ๑๒๓๔",
		},
		{
			name:          "Thai 40 runes (long text -> truncated to 20)",
			inputLabel:    "ตรวจสอบสภาพอากาศน้ำท่วมขังและเส้นทางจราจรแบบสด",
			expectedRunes: 20,
			checkPrefix:   string([]rune("ตรวจสอบสภาพอากาศน้ำท่วมขังและเส้นทางจราจรแบบสด")[:20]),
		},
		{
			name:          "Thai with emojis around 20 runes boundary",
			inputLabel:    "⛈️ ฝนตกหนักมาก 🌊 ระดับน้ำสูงมาก 🚗 รถติดหนัก",
			expectedRunes: 20,
			checkPrefix:   string([]rune("⛈️ ฝนตกหนักมาก 🌊 ระดับน้ำสูงมาก 🚗 รถติดหนัก")[:20]),
		},
		{
			name:          "Multi-byte ZWJ complex emojis with Thai",
			inputLabel:    "👨‍👩‍👧‍👦 ครอบครัวปลอดภัย 🏠 อยู่ในบ้าน",
			expectedRunes: 20,
			checkPrefix:   string([]rune("👨‍👩‍👧‍👦 ครอบครัวปลอดภัย 🏠 อยู่ในบ้าน")[:20]),
		},
		{
			name:          "Pure English 25 characters truncated to 20",
			inputLabel:    "ABCDEFGHIJKLMNOPQRSTUVWXY",
			expectedRunes: 20,
			checkPrefix:   "ABCDEFGHIJKLMNOPQRST",
		},
		{
			name:          "Empty string fallback to เมนู (4 runes)",
			inputLabel:    "",
			expectedRunes: 4,
			checkPrefix:   "เมนู",
		},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			qr := BuildQuickReplies([]QuickReplyItem{
				{Label: tc.inputLabel, Text: "test"},
			})

			items := qr["items"].([]map[string]interface{})
			action := items[0]["action"].(map[string]interface{})
			label := action["label"].(string)

			// 1. Assert UTF-8 is 100% valid (never cut in half)
			if !utf8.ValidString(label) {
				t.Fatalf("CORRUPTION DETECTED: label %q is not valid UTF-8!", label)
			}

			// 2. Assert rune count is <= 20
			runeCount := utf8.RuneCountInString(label)
			if runeCount > 20 {
				t.Fatalf("VIOLATION: label has %d runes (> 20 runes limit): %q", runeCount, label)
			}

			if runeCount != tc.expectedRunes {
				t.Fatalf("expected %d runes, got %d (%q)", tc.expectedRunes, runeCount, label)
			}

			// 3. Assert label matches expected prefix
			if label != tc.checkPrefix {
				t.Fatalf("expected label %q, got %q", tc.checkPrefix, label)
			}

			// 4. Verify no replacement character (U+FFFD) was introduced from corrupt slicing
			if strings.ContainsRune(label, utf8.RuneError) {
				t.Fatalf("CORRUPTION DETECTED: label contains Unicode replacement rune (U+FFFD): %q", label)
			}
		})
	}
}

// TestChallenger_TruncateRunes_EdgeCases tests TruncateRunes directly on negative and zero maxRunes
func TestChallenger_TruncateRunes_EdgeCases(t *testing.T) {
	if TruncateRunes("สวัสดี", -5) != "" {
		t.Errorf("expected empty string for negative maxRunes")
	}
	if TruncateRunes("สวัสดี", 0) != "" {
		t.Errorf("expected empty string for zero maxRunes")
	}
	if TruncateRunes("กขคง", 2) != "กข" {
		t.Errorf("expected 'กข', got %q", TruncateRunes("กขคง", 2))
	}
	if TruncateRunes("", 10) != "" {
		t.Errorf("expected empty string for empty input")
	}
}
