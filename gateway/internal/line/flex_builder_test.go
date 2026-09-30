package line

import (
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"strings"
	"testing"
	"unicode/utf8"

	"github.com/saransirichote/weather-resilience-gateway/internal/model"
)

// TestAppleSpatialFlexBubble_PaletteAndHierarchy validates Theme 1 dark frosted visual hierarchy
func TestAppleSpatialFlexBubble_PaletteAndHierarchy(t *testing.T) {
	adv := model.AdvisoryPayload{
		Title:          "⚠️ พายุฤดูร้อนและเสี่ยงน้ำท่วมขัง ถนนสุขุมวิท",
		UrgencyLevel:   "CRITICAL",
		SummaryText:    "เรดาร์ BMA ตรวจพบกลุ่มฝนฟ้าคะนองรุนแรง ลมกระโชกแรง และเสี่ยงน้ำท่วมขัง",
		CriticalWindow: "17:00 - 19:30 น.",
		LocationName:   "สุขุมวิท 21 (อโศกมนตรี)",
		Temperature:    29.0,
		Condition:      "⛈️ พายุฝนฟ้าคะนองรุนแรง",
		RainRate:       48.5,
		CanalName:      "คลองแสนแสบ",
		CanalStage:     0.85,
		HeatIndex:      37.6,
		WindGust:       54.0,
		VehicleType:    "sedan",
		FloodDepthCm:   18.0,
		ActionChecklist: []string{
			"หลีกเลี่ยงถนนสุขุมวิทและอโศกมนตรี",
			"ใช้รถไฟฟ้า BTS หรือ MRT แทน",
			"นำยานพาหนะขึ้นที่สูง",
		},
		AlternativeRoutesOrActions: "ใช้ทางด่วนเฉลิมมหานคร หรือถนนพระราม 9",
	}

	bubble := BuildFlexMessageBubble(adv)

	// 1. Verify Root bubble schema
	if bubble["type"] != "bubble" {
		t.Fatalf("expected bubble type 'bubble', got %v", bubble["type"])
	}
	if bubble["size"] != "mega" {
		t.Errorf("expected bubble size 'mega', got %v", bubble["size"])
	}

	// 2. Verify Styles block dark frosted colors
	styles, ok := bubble["styles"].(map[string]interface{})
	if !ok {
		t.Fatalf("missing styles block in Flex bubble")
	}
	headerStyle := styles["header"].(map[string]interface{})
	if headerStyle["backgroundColor"] != "#091122" {
		t.Errorf("expected styles.header.backgroundColor #091122, got %v", headerStyle["backgroundColor"])
	}
	bodyStyle := styles["body"].(map[string]interface{})
	if bodyStyle["backgroundColor"] != "#0B132B" {
		t.Errorf("expected styles.body.backgroundColor #0B132B, got %v", bodyStyle["backgroundColor"])
	}
	footerStyle := styles["footer"].(map[string]interface{})
	if footerStyle["backgroundColor"] != "#091122" {
		t.Errorf("expected styles.footer.backgroundColor #091122, got %v", footerStyle["backgroundColor"])
	}

	// 3. Verify Header contents: #091122 background, WeatherNext 3, BMA radar pulse, Urgency badge, Title, Location
	header, ok := bubble["header"].(map[string]interface{})
	if !ok {
		t.Fatalf("missing header block")
	}
	if header["backgroundColor"] != "#091122" {
		t.Errorf("expected header backgroundColor #091122, got %v", header["backgroundColor"])
	}

	headerContents := header["contents"].([]map[string]interface{})
	if len(headerContents) < 4 {
		t.Fatalf("expected at least 4 header content items, got %d", len(headerContents))
	}

	// WeatherNext 3 and BMA radar row
	pulseRow := headerContents[0]
	pulseContents := pulseRow["contents"].([]map[string]interface{})
	wn3Box := pulseContents[0]["contents"].([]map[string]interface{})
	if wn3Box[1]["text"] != "WEATHERNEXT 3 (5KM)" {
		t.Errorf("expected WEATHERNEXT 3 badge, got %v", wn3Box[1]["text"])
	}
	bmaBox := pulseContents[1]["contents"].([]map[string]interface{})
	if bmaBox[1]["text"] != "เรดาร์ กทม. ONLINE" {
		t.Errorf("expected BMA radar live pulse badge, got %v", bmaBox[1]["text"])
	}

	// Urgency badge pill
	urgencyPill := headerContents[1]
	urgencyContents := urgencyPill["contents"].([]map[string]interface{})
	badgeText := urgencyContents[0]["text"].(string)
	badgeColor := urgencyContents[0]["color"].(string)
	if !strings.Contains(badgeText, "CRITICAL") || badgeColor != "#F43F5E" {
		t.Errorf("expected CRITICAL badge text and #F43F5E accent, got %s / %s", badgeText, badgeColor)
	}

	// Title and Location
	titleText := headerContents[2]["text"].(string)
	if titleText != adv.Title {
		t.Errorf("expected title %q, got %q", adv.Title, titleText)
	}
	locationText := headerContents[3]["text"].(string)
	if !strings.Contains(locationText, "สุขุมวิท 21 (อโศกมนตรี)") || !strings.Contains(locationText, "17:00 - 19:30 น.") {
		t.Errorf("expected location metadata with critical window, got %q", locationText)
	}

	// 4. Verify Body: #0B132B frosted background
	body, ok := bubble["body"].(map[string]interface{})
	if !ok {
		t.Fatalf("missing body block")
	}
	if body["backgroundColor"] != "#0B132B" {
		t.Errorf("expected body backgroundColor #0B132B, got %v", body["backgroundColor"])
	}

	bodyContents := body["contents"].([]map[string]interface{})
	if len(bodyContents) < 5 {
		t.Fatalf("expected at least 5 body sections, got %d", len(bodyContents))
	}

	// Hero Section
	heroBox := bodyContents[0]
	heroContents := heroBox["contents"].([]map[string]interface{})
	tempText := heroContents[0]["text"].(string)
	if tempText != "29°" {
		t.Errorf("expected hero temperature '29°', got %q", tempText)
	}
	condText := heroContents[1]["text"].(string)
	if condText != "⛈️ พายุฝนฟ้าคะนองรุนแรง" {
		t.Errorf("expected condition text '⛈️ พายุฝนฟ้าคะนองรุนแรง', got %q", condText)
	}

	// 2x2 Bento grid
	bentoGrid := bodyContents[1]
	bentoRows := bentoGrid["contents"].([]map[string]interface{})
	if len(bentoRows) != 2 {
		t.Fatalf("expected 2 Bento rows, got %d", len(bentoRows))
	}

	// Vehicle clearance card
	vehCard := bodyContents[2]
	if vehCard["backgroundColor"] != "#2D121B" { // CRITICAL warning background for sedan in 18cm water
		t.Errorf("expected vehicle alert background #2D121B for deep flood, got %v", vehCard["backgroundColor"])
	}

	// Action checklist
	checklistBlock := bodyContents[3]
	checklistContents := checklistBlock["contents"].([]map[string]interface{})
	if len(checklistContents) < 4 { // header + 3 items
		t.Errorf("expected checklist header + 3 items, got %d", len(checklistContents))
	}

	// Alternative routes card
	altCard := bodyContents[4]
	if altCard["backgroundColor"] != "#162238" {
		t.Errorf("expected alternative route card background #162238, got %v", altCard["backgroundColor"])
	}

	// 5. Verify Footer: #091122 background, Dual CTA buttons with LIFF deep links
	footer, ok := bubble["footer"].(map[string]interface{})
	if !ok {
		t.Fatalf("missing footer block")
	}
	if footer["backgroundColor"] != "#091122" {
		t.Errorf("expected footer backgroundColor #091122, got %v", footer["backgroundColor"])
	}

	footerContents := footer["contents"].([]map[string]interface{})
	if len(footerContents) != 2 {
		t.Fatalf("expected 2 CTA buttons in footer, got %d", len(footerContents))
	}

	btn1Action := footerContents[0]["action"].(map[string]interface{})
	btn1URI := btn1Action["uri"].(string)
	if !strings.Contains(btn1URI, "tab=dashboard") || !strings.Contains(btn1URI, "vehicle=sedan") {
		t.Errorf("expected primary button URI to include tab=dashboard and vehicle=sedan, got %q", btn1URI)
	}

	btn2Action := footerContents[1]["action"].(map[string]interface{})
	btn2URI := btn2Action["uri"].(string)
	if !strings.Contains(btn2URI, "tab=calendar") {
		t.Errorf("expected secondary button URI to include tab=calendar, got %q", btn2URI)
	}
}

// TestAppleSpatialFlexBubble_UrgencyBadgesAndColors tests the 4 urgency tiers
func TestAppleSpatialFlexBubble_UrgencyBadgesAndColors(t *testing.T) {
	tests := []struct {
		level         string
		expectedBadge string
		expectedColor string
	}{
		{"CRITICAL", "🚨 เตือนภัยระดับวิกฤต (CRITICAL)", "#F43F5E"},
		{"WARNING", "⚠️ แจ้งเตือนความเสี่ยงสูง (WARNING)", "#F59E0B"},
		{"ADVISORY", "☀️ คำแนะนำสภาพอากาศ (ADVISORY)", "#38BDF8"},
		{"INFO", "🌤️ ข้อมูลสภาพอากาศ (INFO)", "#34D399"},
		{"UNKNOWN", "🌤️ ข้อมูลสภาพอากาศ (INFO)", "#34D399"},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.level, func(t *testing.T) {
			adv := model.AdvisoryPayload{
				Title:        "การแจ้งเตือนสภาพอากาศ",
				UrgencyLevel: tc.level,
			}
			bubble := BuildFlexMessageBubble(adv)
			header := bubble["header"].(map[string]interface{})
			contents := header["contents"].([]map[string]interface{})
			pillContents := contents[1]["contents"].([]map[string]interface{})
			text := pillContents[0]["text"].(string)
			color := pillContents[0]["color"].(string)

			if text != tc.expectedBadge {
				t.Errorf("expected badge %q, got %q", tc.expectedBadge, text)
			}
			if color != tc.expectedColor {
				t.Errorf("expected badge color %q, got %q", tc.expectedColor, color)
			}
		})
	}
}

// TestAppleSpatialFlexBubble_2x2BentoTiles verifies the 4 telemetry cards
func TestAppleSpatialFlexBubble_2x2BentoTiles(t *testing.T) {
	adv := model.AdvisoryPayload{
		Title:            "ทดสอบ Bento Telemetry",
		RainRate:         52.0,
		CanalName:        "คลองแสนแสบ",
		CanalStage:       1.20,
		CanalRemainingCm: 15.0,
		HeatIndex:        42.5,
		WindGust:         50.0,
	}

	bubble := BuildFlexMessageBubble(adv)
	body := bubble["body"].(map[string]interface{})
	contents := body["contents"].([]map[string]interface{})
	bentoGrid := contents[1]

	rows := bentoGrid["contents"].([]map[string]interface{})
	if len(rows) != 2 {
		t.Fatalf("expected 2 Bento rows, got %d", len(rows))
	}

	// Row 1: Rain Rate and Canal Stage
	row1Tiles := rows[0]["contents"].([]map[string]interface{})
	rainTile := row1Tiles[0]
	canalTile := row1Tiles[1]

	if rainTile["backgroundColor"] != "#162238" || rainTile["cornerRadius"] != "md" {
		t.Errorf("expected Rain Tile #162238 card with cornerRadius md")
	}
	if canalTile["backgroundColor"] != "#162238" || canalTile["cornerRadius"] != "md" {
		t.Errorf("expected Canal Tile #162238 card with cornerRadius md")
	}

	rainContents := rainTile["contents"].([]map[string]interface{})
	valRow := rainContents[1]["contents"].([]map[string]interface{})
	if valRow[0]["text"] != "52.0" || valRow[1]["text"] != "mm/h" {
		t.Errorf("expected 52.0 mm/h, got %v %v", valRow[0]["text"], valRow[1]["text"])
	}

	// Row 2: Heat Index and Wind Gust
	row2Tiles := rows[1]["contents"].([]map[string]interface{})
	heatTile := row2Tiles[0]
	windTile := row2Tiles[1]

	heatContents := heatTile["contents"].([]map[string]interface{})
	heatValRow := heatContents[1]["contents"].([]map[string]interface{})
	if heatValRow[0]["text"] != "42.5" || heatValRow[1]["text"] != "°C" {
		t.Errorf("expected 42.5 °C, got %v %v", heatValRow[0]["text"], heatValRow[1]["text"])
	}

	windContents := windTile["contents"].([]map[string]interface{})
	windValRow := windContents[1]["contents"].([]map[string]interface{})
	if windValRow[0]["text"] != "50.0" || windValRow[1]["text"] != "km/h" {
		t.Errorf("expected 50.0 km/h, got %v %v", windValRow[0]["text"], windValRow[1]["text"])
	}
}

// TestAppleSpatialFlexBubble_VehicleClearanceThresholds evaluates vehicle clearance limits
func TestAppleSpatialFlexBubble_VehicleClearanceThresholds(t *testing.T) {
	tests := []struct {
		name          string
		vehicleType   string
		depthCm       float64
		windKmh       float64
		expectedBadge string
		expectedColor string
	}{
		{
			name:          "Sedan under 10cm is safe",
			vehicleType:   "sedan",
			depthCm:       8.0,
			windKmh:       15.0,
			expectedBadge: "🚗 รถเก๋งเตี้ย: ระดับน้ำปกติ สัญจรได้",
			expectedColor: "#162238",
		},
		{
			name:          "Sedan 10-15cm is warning",
			vehicleType:   "compact_sedan",
			depthCm:       12.0,
			windKmh:       20.0,
			expectedBadge: "🚗 รถเก๋งเตี้ย: เฝ้าระวังระดับน้ำ",
			expectedColor: "#2D2210",
		},
		{
			name:          "Sedan >= 15cm is critical flood risk",
			vehicleType:   "sedan",
			depthCm:       16.0,
			windKmh:       25.0,
			expectedBadge: "🚗 รถเก๋งเตี้ย: วิกฤตน้ำท่วมขัง",
			expectedColor: "#2D121B",
		},
		{
			name:          "Motorcycle with wind > 45 km/h is critical",
			vehicleType:   "moto",
			depthCm:       5.0,
			windKmh:       48.0,
			expectedBadge: "🛵 มอเตอร์ไซค์: เสี่ยงลมกระโชกและน้ำท่วม",
			expectedColor: "#2D121B",
		},
		{
			name:          "Motorcycle with depth >= 10 cm is critical",
			vehicleType:   "motorcycle",
			depthCm:       11.0,
			windKmh:       20.0,
			expectedBadge: "🛵 มอเตอร์ไซค์: เสี่ยงลมกระโชกและน้ำท่วม",
			expectedColor: "#2D121B",
		},
		{
			name:          "Motorcycle with calm wind and shallow water is safe",
			vehicleType:   "motorcycle",
			depthCm:       4.0,
			windKmh:       15.0,
			expectedBadge: "🛵 มอเตอร์ไซค์: สภาพลมและถนนปลอดภัย",
			expectedColor: "#162238",
		},
		{
			name:          "Pickup with depth <= 35cm is safe",
			vehicleType:   "pickup",
			depthCm:       30.0,
			windKmh:       25.0,
			expectedBadge: "🚙 รถกระบะ/SUV: สัญจรได้ปลอดภัย",
			expectedColor: "#0F291E",
		},
		{
			name:          "Pickup with depth > 35cm is critical",
			vehicleType:   "pickup",
			depthCm:       38.0,
			windKmh:       30.0,
			expectedBadge: "🚙 รถกระบะ/SUV: น้ำท่วมระดับวิกฤต",
			expectedColor: "#2D121B",
		},
		{
			name:          "Transit BTS/MRT is 100% safe",
			vehicleType:   "transit",
			depthCm:       50.0,
			windKmh:       60.0,
			expectedBadge: "🚆 รถไฟฟ้า BTS/MRT: สัญจรปลอดภัย 100%",
			expectedColor: "#0F291E",
		},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			badge, _, bg, _ := EvaluateVehicleClearance(tc.vehicleType, tc.depthCm, tc.windKmh, "")
			if badge != tc.expectedBadge {
				t.Errorf("expected badge %q, got %q", tc.expectedBadge, badge)
			}
			if bg != tc.expectedColor {
				t.Errorf("expected background color %q, got %q", tc.expectedColor, bg)
			}
		})
	}
}

// TestFlexMessageCarousel_Capping validates capping at 12 bubbles and safety on empty slices
func TestFlexMessageCarousel_Capping(t *testing.T) {
	makeBubbles := func(n int) []map[string]interface{} {
		list := make([]map[string]interface{}, n)
		for i := 0; i < n; i++ {
			list[i] = map[string]interface{}{
				"type": "bubble",
				"body": map[string]interface{}{
					"index": i + 1,
				},
			}
		}
		return list
	}

	tests := []struct {
		name          string
		inputCount    int
		expectedCount int
	}{
		{"Empty slice produces empty carousel without error", 0, 0},
		{"Single bubble produces 1 item", 1, 1},
		{"Five bubbles produce 5 items", 5, 5},
		{"Exactly 12 bubbles produce 12 items", 12, 12},
		{"13 bubbles capped at 12", 13, 12},
		{"20 bubbles capped at 12", 20, 12},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			input := makeBubbles(tc.inputCount)
			carousel := BuildFlexMessageCarousel(input)

			if carousel["type"] != "carousel" {
				t.Fatalf("expected type 'carousel', got %v", carousel["type"])
			}

			contents, ok := carousel["contents"].([]map[string]interface{})
			if !ok {
				t.Fatalf("expected contents to be []map[string]interface{}")
			}

			if len(contents) != tc.expectedCount {
				t.Fatalf("expected %d bubbles in carousel, got %d", tc.expectedCount, len(contents))
			}

			// Verify items preserved in order
			for i := 0; i < tc.expectedCount; i++ {
				body := contents[i]["body"].(map[string]interface{})
				if body["index"] != i+1 {
					t.Errorf("expected bubble index %d, got %v", i+1, body["index"])
				}
			}

			// Verify BuildFlexCarousel alias produces same result
			aliasCarousel := BuildFlexCarousel(input)
			aliasContents := aliasCarousel["contents"].([]map[string]interface{})
			if len(aliasContents) != tc.expectedCount {
				t.Errorf("alias expected %d bubbles, got %d", tc.expectedCount, len(aliasContents))
			}
		})
	}

	// Verify nil slice handling
	nilCarousel := BuildFlexMessageCarousel(nil)
	nilContents, ok := nilCarousel["contents"].([]map[string]interface{})
	if !ok || len(nilContents) != 0 {
		t.Fatalf("expected non-nil empty slice on nil input, got %v", nilCarousel["contents"])
	}
}

// TestQuickReply_RuneTruncation validates safe UTF-8 rune slicing to max 20 runes
func TestQuickReply_RuneTruncation(t *testing.T) {
	tests := []struct {
		name          string
		label         string
		expectedLabel string
	}{
		{
			name:          "English short label (13 runes)",
			label:         "Check Weather",
			expectedLabel: "Check Weather",
		},
		{
			name:          "English exactly 20 runes",
			label:         "12345678901234567890",
			expectedLabel: "12345678901234567890",
		},
		{
			name:          "English 25 runes truncated to 20 runes",
			label:         "1234567890123456789012345",
			expectedLabel: "12345678901234567890",
		},
		{
			name:          "Thai short label (9 runes, 27 bytes)",
			label:         "สภาพอากาศ",
			expectedLabel: "สภาพอากาศ",
		},
		{
			name:          "Thai 35 runes safely truncated to 20 runes without Unicode corruption",
			label:         "ตรวจสอบสภาพอากาศและน้ำท่วมขังกรุงเทพ",
			expectedLabel: string([]rune("ตรวจสอบสภาพอากาศและน้ำท่วมขังกรุงเทพ")[:20]),
		},
		{
			name:          "Thai with emoji (18 runes)",
			label:         "🌊 จุดเสี่ยงน้ำท่วม",
			expectedLabel: "🌊 จุดเสี่ยงน้ำท่วม",
		},
		{
			name:          "Thai with emoji > 20 runes truncated safely",
			label:         "🌧️ ฝนตกหนักมากกกกกกกกกกกกกกกก",
			expectedLabel: string([]rune("🌧️ ฝนตกหนักมากกกกกกกกกกกกกกกก")[:20]),
		},
		{
			name:          "Empty label falls back safely to default menu",
			label:         "",
			expectedLabel: "เมนู",
		},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			qr := BuildQuickReplies([]QuickReplyItem{
				{Label: tc.label, Text: "query"},
			})
			items := qr["items"].([]map[string]interface{})
			action := items[0]["action"].(map[string]interface{})
			actualLabel := action["label"].(string)

			if actualLabel != tc.expectedLabel {
				t.Fatalf("expected label %q, got %q", tc.expectedLabel, actualLabel)
			}

			// Validate rune count limit
			runeCount := utf8.RuneCountInString(actualLabel)
			if runeCount > 20 {
				t.Errorf("label exceeds 20 runes limit: %d runes", runeCount)
			}

			// Validate UTF-8 validity
			if !utf8.ValidString(actualLabel) {
				t.Errorf("label is corrupted UTF-8: %v", actualLabel)
			}
		})
	}
}

// TestQuickReply_CountCapping verifies capping quick reply items at 13
func TestQuickReply_CountCapping(t *testing.T) {
	makeItems := func(n int) []QuickReplyItem {
		items := make([]QuickReplyItem, n)
		for i := 0; i < n; i++ {
			items[i] = QuickReplyItem{
				Label: fmt.Sprintf("ปุ่ม %d", i+1),
				Text:  fmt.Sprintf("ข้อความ %d", i+1),
			}
		}
		return items
	}

	tests := []struct {
		name          string
		inputCount    int
		expectedCount int
	}{
		{"0 items produces 0 items", 0, 0},
		{"5 items produces 5 items", 5, 5},
		{"13 items produces 13 items", 13, 13},
		{"15 items capped at 13 items", 15, 13},
		{"25 items capped at 13 items", 25, 13},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			input := makeItems(tc.inputCount)
			qr := BuildQuickReplies(input)
			items := qr["items"].([]map[string]interface{})
			if len(items) != tc.expectedCount {
				t.Fatalf("expected %d items, got %d", tc.expectedCount, len(items))
			}
		})
	}
}

// TestDefaultQuickReplies verifies standard Thai intent quick reply actions
func TestDefaultQuickReplies(t *testing.T) {
	qr := DefaultQuickReplies("https://liff.line.me/test-app")
	items, ok := qr["items"].([]map[string]interface{})
	if !ok {
		t.Fatalf("missing items slice")
	}

	if len(items) > 13 {
		t.Errorf("items count %d exceeds 13", len(items))
	}

	// Verify all labels <= 20 runes and valid UTF-8
	for i, it := range items {
		action := it["action"].(map[string]interface{})
		lbl := action["label"].(string)
		runeCount := utf8.RuneCountInString(lbl)
		if runeCount > 20 {
			t.Errorf("item %d label %q has %d runes (>20)", i, lbl, runeCount)
		}
		if !utf8.ValidString(lbl) {
			t.Errorf("item %d label is not valid UTF-8: %v", i, lbl)
		}
	}

	// Verify presence of deep links
	foundDashboard := false
	foundCalendar := false
	for _, it := range items {
		action := it["action"].(map[string]interface{})
		if action["type"] == "uri" {
			uri := action["uri"].(string)
			if strings.Contains(uri, "tab=dashboard") {
				foundDashboard = true
			}
			if strings.Contains(uri, "tab=calendar") {
				foundCalendar = true
			}
		}
	}

	if !foundDashboard || !foundCalendar {
		t.Errorf("expected dashboard and calendar deep link quick replies")
	}

	// Verify BuildDefaultQuickReplies alias
	defQR := BuildDefaultQuickReplies()
	defItems := defQR["items"].([]map[string]interface{})
	if len(defItems) != 8 {
		t.Errorf("expected 8 standard message quick reply items, got %d", len(defItems))
	}
}

// TestAppleSpatialFlexBubble_DualCTA_DeepLinks tests deep link generation with LIFF endpoints
func TestAppleSpatialFlexBubble_DualCTA_DeepLinks(t *testing.T) {
	tests := []struct {
		name               string
		liffEnv            string
		advLiff            string
		tabDestination     string
		urgencyLevel       string
		vehicleType        string
		extraParams        string
		expectedDashSub    string
		expectedCalSub     string
		expectedHazardSub  string
	}{
		{
			name:              "Critical alert adds focus=hazard automatically",
			liffEnv:           "https://liff.line.me/weather-app",
			advLiff:           "",
			tabDestination:    "",
			urgencyLevel:      "CRITICAL",
			vehicleType:       "sedan",
			extraParams:       "",
			expectedDashSub:   "tab=dashboard&vehicle=sedan&focus=hazard",
			expectedCalSub:    "tab=calendar",
			expectedHazardSub: "focus=hazard",
		},
		{
			name:              "Info alert without focus=hazard",
			liffEnv:           "https://liff.line.me/weather-app",
			advLiff:           "",
			tabDestination:    "",
			urgencyLevel:      "INFO",
			vehicleType:       "motorcycle",
			extraParams:       "",
			expectedDashSub:   "tab=dashboard&vehicle=motorcycle",
			expectedCalSub:    "tab=calendar",
			expectedHazardSub: "",
		},
		{
			name:              "Explicit ExtraParams honored",
			liffEnv:           "",
			advLiff:           "https://liff.line.me/custom-override",
			tabDestination:    "",
			urgencyLevel:      "WARNING",
			vehicleType:       "pickup",
			extraParams:       "focus=hazard&zoom=14",
			expectedDashSub:   "focus=hazard&zoom=14",
			expectedCalSub:    "tab=calendar",
			expectedHazardSub: "focus=hazard",
		},
		{
			name:              "Profile tab destination honored with moto",
			liffEnv:           "https://liff.line.me/weather-app",
			advLiff:           "",
			tabDestination:    "profile",
			urgencyLevel:      "INFO",
			vehicleType:       "moto",
			extraParams:       "",
			expectedDashSub:   "tab=profile&vehicle=moto",
			expectedCalSub:    "tab=calendar",
			expectedHazardSub: "",
		},
		{
			name:              "Profile tab destination honored with motorcycle and clean extraParams",
			liffEnv:           "https://liff.line.me/weather-app",
			advLiff:           "",
			tabDestination:    "profile",
			urgencyLevel:      "INFO",
			vehicleType:       "motorcycle",
			extraParams:       "vehicle=motorcycle",
			expectedDashSub:   "tab=profile&vehicle=motorcycle",
			expectedCalSub:    "tab=calendar",
			expectedHazardSub: "",
		},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			if tc.liffEnv != "" {
				os.Setenv("LIFF_ENDPOINT_URL", tc.liffEnv)
				defer os.Unsetenv("LIFF_ENDPOINT_URL")
			} else {
				os.Unsetenv("LIFF_ENDPOINT_URL")
			}

			adv := model.AdvisoryPayload{
				Title:          "ทดสอบ CTA",
				UrgencyLevel:   tc.urgencyLevel,
				VehicleType:    tc.vehicleType,
				TabDestination: tc.tabDestination,
				LIFFURL:        tc.advLiff,
				ExtraParams:    tc.extraParams,
			}

			bubble := BuildFlexMessageBubble(adv)
			footer := bubble["footer"].(map[string]interface{})
			contents := footer["contents"].([]map[string]interface{})

			dashBtn := contents[0]["action"].(map[string]interface{})
			dashURI := dashBtn["uri"].(string)

			calBtn := contents[1]["action"].(map[string]interface{})
			calURI := calBtn["uri"].(string)

			if !strings.Contains(dashURI, tc.expectedDashSub) {
				t.Errorf("expected dashboard URI to contain %q, got %q", tc.expectedDashSub, dashURI)
			}
			if !strings.Contains(calURI, tc.expectedCalSub) {
				t.Errorf("expected calendar URI to contain %q, got %q", tc.expectedCalSub, calURI)
			}
			if tc.expectedHazardSub != "" && !strings.Contains(dashURI, tc.expectedHazardSub) {
				t.Errorf("expected hazard focus in dashboard URI, got %q", dashURI)
			}
		})
	}
}

// TestAppleSpatialFlexBubble_TabDestination tests that setting TabDestination alters primary button URI
func TestAppleSpatialFlexBubble_TabDestination(t *testing.T) {
	tests := []struct {
		name           string
		tabDestination string
		vehicleType    string
		extraParams    string
		expectedURI    string
	}{
		{
			name:           "Profile tab destination with moto",
			tabDestination: "profile",
			vehicleType:    "moto",
			expectedURI:    "tab=profile&vehicle=moto",
		},
		{
			name:           "Profile tab destination with motorcycle",
			tabDestination: "profile",
			vehicleType:    "motorcycle",
			expectedURI:    "tab=profile&vehicle=motorcycle",
		},
		{
			name:           "Calendar tab destination",
			tabDestination: "calendar",
			vehicleType:    "sedan",
			expectedURI:    "tab=calendar&vehicle=sedan",
		},
		{
			name:           "Empty tab destination defaults to dashboard",
			tabDestination: "",
			vehicleType:    "sedan",
			expectedURI:    "tab=dashboard&vehicle=sedan",
		},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			adv := model.AdvisoryPayload{
				Title:          "ทดสอบ Tab Destination",
				UrgencyLevel:   "INFO",
				VehicleType:    tc.vehicleType,
				TabDestination: tc.tabDestination,
				ExtraParams:    tc.extraParams,
			}
			bubble := BuildFlexMessageBubble(adv)
			footer := bubble["footer"].(map[string]interface{})
			contents := footer["contents"].([]map[string]interface{})
			primaryBtn := contents[0]["action"].(map[string]interface{})
			primaryURI := primaryBtn["uri"].(string)

			if !strings.Contains(primaryURI, tc.expectedURI) {
				t.Errorf("expected primary URI to contain %q, got %q", tc.expectedURI, primaryURI)
			}
		})
	}
}

// TestAppleSpatialFlexBubble_StrictJSONSchema validates serialization against LINE Flex schema
func TestAppleSpatialFlexBubble_StrictJSONSchema(t *testing.T) {
	adv := model.AdvisoryPayload{
		Title:                      "⛈️ เตือนภัยพายุฝนฟ้าคะนองและน้ำท่วมขัง ถนนอโศกมนตรี",
		UrgencyLevel:               "CRITICAL",
		SummaryText:                "ฝนตกสะสม 54 มม./ชม. ระดับน้ำคลองแสนแสบวิกฤต น้ำท่วมผิวจราจร 18 ซม.",
		CriticalWindow:             "17:30 - 19:30 น.",
		LocationName:               "สุขุมวิท 21 (อโศกมนตรี)",
		Temperature:                28.0,
		Condition:                  "⛈️ พายุฝนฟ้าคะนองรุนแรง",
		RainRate:                   54.0,
		CanalName:                  "คลองแสนแสบ",
		CanalStage:                 1.45,
		CanalRemainingCm:           12.0,
		HeatIndex:                  38.0,
		WindGust:                   52.0,
		VehicleType:                "sedan",
		FloodDepthCm:               18.0,
		ActionChecklist:            []string{"หลีกเลี่ยงถนนสุขุมวิท", "ใช้ระบบรถไฟฟ้า BTS/MRT"},
		AlternativeRoutesOrActions: "ใช้ทางด่วนเฉลิมมหานคร",
		LIFFURL:                    "https://liff.line.me/weather-bkk",
	}

	bubble := BuildFlexMessageBubble(adv)

	// 1. Serialization
	jsonBytes, err := json.Marshal(bubble)
	if err != nil {
		t.Fatalf("failed to marshal Flex Bubble: %v", err)
	}

	// 2. Round-trip Deserialization
	var roundTrip map[string]interface{}
	if err := json.Unmarshal(jsonBytes, &roundTrip); err != nil {
		t.Fatalf("failed to unmarshal JSON: %v", err)
	}

	// 3. Schema Verification
	if roundTrip["type"] != "bubble" {
		t.Errorf("expected type 'bubble', got %v", roundTrip["type"])
	}
	if roundTrip["size"] != "mega" {
		t.Errorf("expected size 'mega', got %v", roundTrip["size"])
	}

	jsonString := string(jsonBytes)
	requiredTokens := []string{
		`"backgroundColor":"#091122"`,
		`"backgroundColor":"#0B132B"`,
		`"backgroundColor":"#162238"`,
		`WEATHERNEXT 3 (5KM)`,
		`เรดาร์ กทม. ONLINE`,
		`🚨 เตือนภัยระดับวิกฤต (CRITICAL)`,
		`#F43F5E`,
		`54.0`,
		`mm/h`,
		`คลองแสนแสบ`,
		`1.45`,
		`m MSL`,
		`38.0`,
		`°C`,
		`52.0`,
		`km/h`,
		`🚗 รถเก๋งเตี้ย: วิกฤตน้ำท่วมขัง`,
		`📋 แผนการเตรียมตัวเชิงรุก (Action Checklist):`,
		`เส้นทางสำรอง: ใช้ทางด่วนเฉลิมมหานคร`,
		`ดูเรดาร์`,
		`แผนที่`,
		`📅 เช็กนัดหมาย`,
		`https://liff.line.me/weather-bkk?tab=dashboard`,
		`https://liff.line.me/weather-bkk?tab=calendar`,
	}

	for _, token := range requiredTokens {
		if !strings.Contains(jsonString, token) {
			t.Errorf("serialized JSON missing token: %s", token)
		}
	}

	// Validate decoded footer button labels in roundTrip
	footer := roundTrip["footer"].(map[string]interface{})
	footerContents := footer["contents"].([]interface{})
	btn1Action := footerContents[0].(map[string]interface{})["action"].(map[string]interface{})
	if btn1Action["label"] != "📊 ดูเรดาร์ & แผนที่" {
		t.Errorf("expected primary button label '📊 ดูเรดาร์ & แผนที่', got %v", btn1Action["label"])
	}
}

// TestFlexCarousel_StrictJSONSchema validates carousel JSON container serialization
func TestFlexCarousel_StrictJSONSchema(t *testing.T) {
	b1 := BuildFlexMessageBubble(model.AdvisoryPayload{
		Title:        "การ์ดที่ 1",
		UrgencyLevel: "WARNING",
	})
	b2 := BuildFlexMessageBubble(model.AdvisoryPayload{
		Title:        "การ์ดที่ 2",
		UrgencyLevel: "CRITICAL",
	})

	carousel := BuildFlexMessageCarousel([]map[string]interface{}{b1, b2})

	jsonBytes, err := json.Marshal(carousel)
	if err != nil {
		t.Fatalf("failed to marshal carousel: %v", err)
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(jsonBytes, &parsed); err != nil {
		t.Fatalf("failed to unmarshal carousel JSON: %v", err)
	}

	if parsed["type"] != "carousel" {
		t.Errorf("expected type 'carousel', got %v", parsed["type"])
	}

	contents, ok := parsed["contents"].([]interface{})
	if !ok || len(contents) != 2 {
		t.Fatalf("expected 2 bubbles in contents array, got %d", len(contents))
	}
}

func TestFlexBuilder_DeepLinkQueryEscaping(t *testing.T) {
	cases := []struct {
		name        string
		vehicle     string
		extra       string
		mustContain []string
	}{
		{
			name:        "Vehicle with spaces",
			vehicle:     "compact sedan",
			mustContain: []string{"vehicle=compact+sedan"},
		},
		{
			name:        "Vehicle with ampersand and spaces",
			vehicle:     "sedan & suv",
			mustContain: []string{"vehicle=sedan+%26+suv"},
		},
		{
			name:        "Vehicle in Thai",
			vehicle:     "รถเก๋ง",
			mustContain: []string{"vehicle=" + url.QueryEscape("รถเก๋ง")},
		},
		{
			name:        "Extra params with Thai and spaces",
			vehicle:     "sedan",
			extra:       "landmark=อโศก มนตรี&mode=nowcast",
			mustContain: []string{"vehicle=sedan", "landmark=" + url.QueryEscape("อโศก มนตรี"), "mode=nowcast"},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			adv := model.AdvisoryPayload{
				Title:          "ทดสอบ URI Escaping",
				UrgencyLevel:   "CRITICAL",
				VehicleType:    tc.vehicle,
				ExtraParams:    tc.extra,
				LIFFURL:        "https://liff.line.me/weather-test",
				TabDestination: "dashboard",
			}
			bubble := BuildFlexMessageBubble(adv)
			footer := bubble["footer"].(map[string]interface{})
			contents := footer["contents"].([]map[string]interface{})
			btnAction := contents[0]["action"].(map[string]interface{})
			uriStr := btnAction["uri"].(string)

			// 1. Confirm valid RFC 3986 URL
			_, err := url.ParseRequestURI(uriStr)
			if err != nil {
				t.Fatalf("URI %q is not a valid RFC 3986 URI: %v", uriStr, err)
			}

			// 2. Confirm no literal unencoded spaces
			if strings.Contains(uriStr, " ") {
				t.Errorf("URI %q contains literal unencoded spaces", uriStr)
			}

			// 3. Confirm expected encoded tokens exist
			for _, token := range tc.mustContain {
				if !strings.Contains(uriStr, token) {
					t.Errorf("URI %q missing expected token %q", uriStr, token)
				}
			}
		})
	}
}

func TestFlexBuilder_PayloadSizeCapping(t *testing.T) {
	// Create an extreme payload with 50 verbose checklist items and massive summary
	verboseItems := make([]string, 50)
	for i := 0; i < 50; i++ {
		verboseItems[i] = fmt.Sprintf("รายการตรวจสอบเร่งด่วนข้อที่ %d: ตรวจเช็กระบบระบายน้ำ ระบบไฟสำรอง ประตูระบายน้ำ และการสื่อสารฉุกเฉิน กทม.", i+1)
	}

	adv := model.AdvisoryPayload{
		Title:            "เตือนภัยพิบัติระดับสูงสุดกรณีฉุกเฉินเร่งด่วนทั่วกรุงเทพมหานครและปริมณฑล",
		UrgencyLevel:     "CRITICAL",
		SummaryText:      strings.Repeat("เรดาร์ตรวจพบฝนฟ้าคะนองรุนแรงระดับวิกฤต น้ำท่วมขังผิวจราจรฉับพลัน ", 20),
		ActionChecklist:  verboseItems,
		VehicleType:      "sedan",
		FloodDepthCm:     30.0,
		RainRate:         90.0,
		CanalRemainingCm: 0.0,
	}

	bubble := BuildFlexMessageBubble(adv)
	b, err := json.Marshal(bubble)
	if err != nil {
		t.Fatalf("failed to marshal bubble: %v", err)
	}

	sizeKB := float64(len(b)) / 1024.0
	const lineLimitKB = 10.0
	if sizeKB > lineLimitKB {
		t.Errorf("flex bubble size %.2f KB exceeds LINE limit of %.1f KB", sizeKB, lineLimitKB)
	}

	// Verify checklist items were capped to at most 5
	body := bubble["body"].(map[string]interface{})
	bodyContents := body["contents"].([]map[string]interface{})
	// The 4th item in body is checklistBlock
	checklistBlock := bodyContents[3]
	chkContents := checklistBlock["contents"].([]map[string]interface{})
	// chkContents has 1 header text + checklist item boxes
	itemsCount := len(chkContents) - 1
	if itemsCount > 5 {
		t.Errorf("expected at most 5 checklist items, got %d", itemsCount)
	}
}

