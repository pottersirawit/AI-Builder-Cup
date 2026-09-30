package line_test

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"
	"testing"
	"unicode/utf8"

	"github.com/saransirichote/weather-resilience-gateway/internal/line"
	"github.com/saransirichote/weather-resilience-gateway/internal/model"
)

var hexColorRegex = regexp.MustCompile(`^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$`)

// Strict LINE Messaging API Flex schema unmarshaling structs
type StrictLineBubble struct {
	Type      string                 `json:"type"`
	Size      string                 `json:"size,omitempty"`
	Direction string                 `json:"direction,omitempty"`
	Header    *StrictLineBox         `json:"header,omitempty"`
	Hero      *StrictLineBox         `json:"hero,omitempty"`
	Body      *StrictLineBox         `json:"body,omitempty"`
	Footer    *StrictLineBox         `json:"footer,omitempty"`
	Styles    map[string]StrictStyle `json:"styles,omitempty"`
}

type StrictStyle struct {
	BackgroundColor string `json:"backgroundColor,omitempty"`
	Separator       bool   `json:"separator,omitempty"`
	SeparatorColor  string `json:"separatorColor,omitempty"`
}

type StrictLineBox struct {
	Type            string            `json:"type"`
	Layout          string            `json:"layout"`
	Contents        []json.RawMessage `json:"contents"`
	BackgroundColor string            `json:"backgroundColor,omitempty"`
	BorderColor     string            `json:"borderColor,omitempty"`
	BorderWidth     string            `json:"borderWidth,omitempty"`
	CornerRadius    string            `json:"cornerRadius,omitempty"`
	PaddingAll      string            `json:"paddingAll,omitempty"`
	Spacing         string            `json:"spacing,omitempty"`
	Margin          string            `json:"margin,omitempty"`
	Flex            *int              `json:"flex,omitempty"`
}

type StrictComponentHeader struct {
	Type string `json:"type"`
}

type StrictLineText struct {
	Type    string `json:"type"`
	Text    string `json:"text"`
	Color   string `json:"color,omitempty"`
	Size    string `json:"size,omitempty"`
	Weight  string `json:"weight,omitempty"`
	Align   string `json:"align,omitempty"`
	Gravity string `json:"gravity,omitempty"`
	Wrap    bool   `json:"wrap,omitempty"`
	Flex    *int   `json:"flex,omitempty"`
	Margin  string `json:"margin,omitempty"`
}

type StrictLineButton struct {
	Type   string           `json:"type"`
	Style  string           `json:"style,omitempty"`
	Height string           `json:"height,omitempty"`
	Color  string           `json:"color,omitempty"`
	Action StrictLineAction `json:"action"`
}

type StrictLineAction struct {
	Type  string `json:"type"`
	Label string `json:"label,omitempty"`
	URI   string `json:"uri,omitempty"`
	Text  string `json:"text,omitempty"`
}

func validateColor(t *testing.T, col string, context string) {
	t.Helper()
	if col != "" && !hexColorRegex.MatchString(col) {
		t.Errorf("[%s] invalid hex color format: %q", context, col)
	}
}

func recursivelyValidateBox(t *testing.T, box *StrictLineBox, depth int) {
	t.Helper()
	if box == nil {
		return
	}
	if box.Type != "box" {
		t.Errorf("box at depth %d has invalid type: %q", depth, box.Type)
	}
	switch box.Layout {
	case "horizontal", "vertical", "baseline":
	default:
		t.Errorf("box at depth %d has invalid layout: %q", depth, box.Layout)
	}
	validateColor(t, box.BackgroundColor, fmt.Sprintf("box depth %d bg", depth))
	validateColor(t, box.BorderColor, fmt.Sprintf("box depth %d border", depth))

	for i, raw := range box.Contents {
		var header StrictComponentHeader
		if err := json.Unmarshal(raw, &header); err != nil {
			t.Fatalf("failed to parse component header at depth %d index %d: %v", depth, i, err)
		}

		switch header.Type {
		case "box":
			var subBox StrictLineBox
			if err := json.Unmarshal(raw, &subBox); err != nil {
				t.Fatalf("failed to unmarshal sub-box at depth %d index %d: %v", depth, i, err)
			}
			recursivelyValidateBox(t, &subBox, depth+1)
		case "text":
			var text StrictLineText
			if err := json.Unmarshal(raw, &text); err != nil {
				t.Fatalf("failed to unmarshal text at depth %d index %d: %v", depth, i, err)
			}
			validateColor(t, text.Color, fmt.Sprintf("text depth %d index %d", depth, i))
			if text.Text == "" {
				t.Errorf("empty text component at depth %d index %d", depth, i)
			}
			if !utf8.ValidString(text.Text) {
				t.Errorf("corrupted UTF-8 in text component at depth %d index %d: %q", depth, i, text.Text)
			}
		case "button":
			var btn StrictLineButton
			if err := json.Unmarshal(raw, &btn); err != nil {
				t.Fatalf("failed to unmarshal button at depth %d index %d: %v", depth, i, err)
			}
			validateColor(t, btn.Color, fmt.Sprintf("button depth %d index %d", depth, i))
			if btn.Action.Type != "uri" && btn.Action.Type != "message" && btn.Action.Type != "postback" {
				t.Errorf("invalid action type %q on button", btn.Action.Type)
			}
			if btn.Action.Type == "uri" && !strings.HasPrefix(btn.Action.URI, "http://") && !strings.HasPrefix(btn.Action.URI, "https://") && !strings.HasPrefix(btn.Action.URI, "line://") {
				t.Errorf("invalid uri protocol in button: %q", btn.Action.URI)
			}
			if runeCount := utf8.RuneCountInString(btn.Action.Label); runeCount > 40 {
				t.Errorf("button action label exceeds 40 runes: %d runes (%q)", runeCount, btn.Action.Label)
			}
		default:
			t.Errorf("unrecognized component type %q at depth %d index %d", header.Type, depth, i)
		}
	}
}

// TestChallenger_FlexSchemaStrictUnmarshal generates bubbles across various scenarios
// and strictly unmarshals and validates them against the LINE Flex Message specification.
func TestChallenger_FlexSchemaStrictUnmarshal(t *testing.T) {
	testScenarios := []struct {
		name string
		adv  model.AdvisoryPayload
	}{
		{
			name: "Standard Critical Flood Asok",
			adv: model.AdvisoryPayload{
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
				},
				AlternativeRoutesOrActions: "ใช้ทางด่วนเฉลิมมหานคร",
			},
		},
		{
			name: "Warning Motorcycle Heat & Wind",
			adv: model.AdvisoryPayload{
				Title:          "⚠️ ลมกระโชกแรงและแดดจัด",
				UrgencyLevel:   "WARNING",
				SummaryText:    "ลมกระโชกแรงระดับเฝ้าระวัง ระวังสิ่งของปลิว",
				LocationName:   "ถนนรัชดาภิเษก",
				Temperature:    36.0,
				Condition:      "🌤️ มีเมฆบางส่วน",
				RainRate:       0.0,
				CanalStage:     0.30,
				HeatIndex:      40.5,
				WindGust:       30.0,
				VehicleType:    "motorcycle",
				FloodDepthCm:   0.0,
			},
		},
		{
			name: "Advisory High-Clearance Pickup",
			adv: model.AdvisoryPayload{
				Title:        "☀️ คำแนะนำการเดินทางสำหรับรถยกสูง",
				UrgencyLevel: "ADVISORY",
				SummaryText:  "น้ำรอการระบาย 20 ซม. รถกระบะสามารถสัญจรได้",
				LocationName: "ถนนแจ้งวัฒนะ",
				Temperature:  28.0,
				RainRate:     25.0,
				CanalStage:   0.60,
				HeatIndex:    33.0,
				WindGust:     18.0,
				VehicleType:  "pickup",
				FloodDepthCm: 20.0,
			},
		},
		{
			name: "Info Public Transit BTS/MRT",
			adv: model.AdvisoryPayload{
				Title:        "🌤️ รายงานสภาพอากาศทั่วไป",
				UrgencyLevel: "INFO",
				SummaryText:  "สภาพอากาศปกติ สัญจรได้ราบรื่น",
				LocationName: "สยามสแควร์",
				Temperature:  30.0,
				VehicleType:  "transit",
				FloodDepthCm: 5.0,
			},
		},
		{
			name: "Minimal Valid Advisory",
			adv: model.AdvisoryPayload{
				Title:       "การแจ้งเตือนพื้นฐาน",
				SummaryText: "สภาพอากาศและระดับน้ำอยู่ในเกณฑ์ปกติ",
			},
		},
	}

	for _, tc := range testScenarios {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			bubbleMap := line.BuildFlexMessageBubble(tc.adv)

			// Step 1: Marshal to JSON
			jsonBytes, err := json.Marshal(bubbleMap)
			if err != nil {
				t.Fatalf("failed to marshal bubble map to JSON: %v", err)
			}

			// Step 2: Unmarshal into strict LINE Bubble struct
			var strictBubble StrictLineBubble
			if err := json.Unmarshal(jsonBytes, &strictBubble); err != nil {
				t.Fatalf("failed to unmarshal JSON into strict LINE Bubble: %v", err)
			}

			// Step 3: Validate Bubble Container constraints
			if strictBubble.Type != "bubble" {
				t.Fatalf("expected bubble type 'bubble', got %q", strictBubble.Type)
			}
			if strictBubble.Size != "mega" {
				t.Errorf("expected bubble size 'mega', got %q", strictBubble.Size)
			}

			// Validate styles
			if strictBubble.Styles == nil {
				t.Fatalf("missing styles block in Flex bubble")
			}
			for section, style := range strictBubble.Styles {
				validateColor(t, style.BackgroundColor, "styles."+section)
			}

			// Validate Header
			if strictBubble.Header == nil {
				t.Fatalf("missing header in Flex bubble")
			}
			recursivelyValidateBox(t, strictBubble.Header, 1)

			// Validate Body
			if strictBubble.Body == nil {
				t.Fatalf("missing body in Flex bubble")
			}
			recursivelyValidateBox(t, strictBubble.Body, 1)

			// Validate Footer
			if strictBubble.Footer == nil {
				t.Fatalf("missing footer in Flex bubble")
			}
			recursivelyValidateBox(t, strictBubble.Footer, 1)
		})
	}
}

// TestChallenger_AllFourVehicleTypesClearanceAlerts validates:
// 1. Sedan: Safe (<10cm), Caution (10-15cm), Critical (>=15cm)
// 2. Motorcycle: Critical (wind >45 or depth >=10), Safe (otherwise)
// 3. Pickup/SUV: Safe (<=35cm), Critical (>35cm)
// 4. Public Transit (BTS/MRT): Safe 100% (independent of depth/wind)
func TestChallenger_AllFourVehicleTypesClearanceAlerts(t *testing.T) {
	tests := []struct {
		persona        string
		vehicleInput   string
		depthCm        float64
		windKmh        float64
		expectedTier   string // "SAFE", "WARNING", "CRITICAL"
		expectedBadge  string
		expectedBg     string
		expectedBorder string
	}{
		// ---------------- SEDAN Persona ----------------
		{
			persona:        "Sedan Depth 0cm (Dry road)",
			vehicleInput:   "sedan",
			depthCm:        0.0,
			windKmh:        10.0,
			expectedTier:   "SAFE",
			expectedBadge:  "🚗 รถเก๋งเตี้ย: ระดับน้ำปกติ สัญจรได้",
			expectedBg:     "#162238",
			expectedBorder: "#2A3B5C",
		},
		{
			persona:        "Sedan Depth 9.9cm (Just below warning threshold 10cm)",
			vehicleInput:   "sedan",
			depthCm:        9.9,
			windKmh:        15.0,
			expectedTier:   "SAFE",
			expectedBadge:  "🚗 รถเก๋งเตี้ย: ระดับน้ำปกติ สัญจรได้",
			expectedBg:     "#162238",
			expectedBorder: "#2A3B5C",
		},
		{
			persona:        "Sedan Depth 10.0cm (Exact warning threshold)",
			vehicleInput:   "compact_sedan",
			depthCm:        10.0,
			windKmh:        20.0,
			expectedTier:   "WARNING",
			expectedBadge:  "🚗 รถเก๋งเตี้ย: เฝ้าระวังระดับน้ำ",
			expectedBg:     "#2D2210",
			expectedBorder: "#F59E0B",
		},
		{
			persona:        "Sedan Depth 14.9cm (Just below critical threshold 15cm)",
			vehicleInput:   "eco-car",
			depthCm:        14.9,
			windKmh:        22.0,
			expectedTier:   "WARNING",
			expectedBadge:  "🚗 รถเก๋งเตี้ย: เฝ้าระวังระดับน้ำ",
			expectedBg:     "#2D2210",
			expectedBorder: "#F59E0B",
		},
		{
			persona:        "Sedan Depth 15.0cm (Exact critical threshold)",
			vehicleInput:   "sedan",
			depthCm:        15.0,
			windKmh:        25.0,
			expectedTier:   "CRITICAL",
			expectedBadge:  "🚗 รถเก๋งเตี้ย: วิกฤตน้ำท่วมขัง",
			expectedBg:     "#2D121B",
			expectedBorder: "#F43F5E",
		},
		{
			persona:        "Sedan Depth 30.0cm (Submerged exhaust)",
			vehicleInput:   "sedan",
			depthCm:        30.0,
			windKmh:        25.0,
			expectedTier:   "CRITICAL",
			expectedBadge:  "🚗 รถเก๋งเตี้ย: วิกฤตน้ำท่วมขัง",
			expectedBg:     "#2D121B",
			expectedBorder: "#F43F5E",
		},

		// ---------------- MOTORCYCLE Persona ----------------
		{
			persona:        "Motorcycle Calm & Shallow (Safe)",
			vehicleInput:   "motorcycle",
			depthCm:        4.0,
			windKmh:        20.0,
			expectedTier:   "SAFE",
			expectedBadge:  "🛵 มอเตอร์ไซค์: สภาพลมและถนนปลอดภัย",
			expectedBg:     "#162238",
			expectedBorder: "#2A3B5C",
		},
		{
			persona:        "Motorcycle Wind 45.0 km/h boundary (Safe)",
			vehicleInput:   "moto",
			depthCm:        8.0,
			windKmh:        45.0,
			expectedTier:   "SAFE",
			expectedBadge:  "🛵 มอเตอร์ไซค์: สภาพลมและถนนปลอดภัย",
			expectedBg:     "#162238",
			expectedBorder: "#2A3B5C",
		},
		{
			persona:        "Motorcycle Wind 45.1 km/h (Critical gust)",
			vehicleInput:   "motorcycle",
			depthCm:        2.0,
			windKmh:        45.1,
			expectedTier:   "CRITICAL",
			expectedBadge:  "🛵 มอเตอร์ไซค์: เสี่ยงลมกระโชกและน้ำท่วม",
			expectedBg:     "#2D121B",
			expectedBorder: "#F43F5E",
		},
		{
			persona:        "Motorcycle Flood 10.0cm boundary (Critical water level)",
			vehicleInput:   "moto",
			depthCm:        10.0,
			windKmh:        15.0,
			expectedTier:   "CRITICAL",
			expectedBadge:  "🛵 มอเตอร์ไซค์: เสี่ยงลมกระโชกและน้ำท่วม",
			expectedBg:     "#2D121B",
			expectedBorder: "#F43F5E",
		},
		{
			persona:        "Motorcycle High Wind (60 km/h) & Flood (18cm)",
			vehicleInput:   "motorcycle",
			depthCm:        18.0,
			windKmh:        60.0,
			expectedTier:   "CRITICAL",
			expectedBadge:  "🛵 มอเตอร์ไซค์: เสี่ยงลมกระโชกและน้ำท่วม",
			expectedBg:     "#2D121B",
			expectedBorder: "#F43F5E",
		},

		// ---------------- PICKUP / SUV Persona ----------------
		{
			persona:        "Pickup Shallow Flood 15cm (Safe)",
			vehicleInput:   "pickup",
			depthCm:        15.0,
			windKmh:        25.0,
			expectedTier:   "SAFE",
			expectedBadge:  "🚙 รถกระบะ/SUV: สัญจรได้ปลอดภัย",
			expectedBg:     "#0F291E",
			expectedBorder: "#34D399",
		},
		{
			persona:        "Pickup Depth 35.0cm boundary (Safe)",
			vehicleInput:   "suv",
			depthCm:        35.0,
			windKmh:        30.0,
			expectedTier:   "SAFE",
			expectedBadge:  "🚙 รถกระบะ/SUV: สัญจรได้ปลอดภัย",
			expectedBg:     "#0F291E",
			expectedBorder: "#34D399",
		},
		{
			persona:        "Pickup Depth 35.1cm (Critical flood exceeding 35cm limit)",
			vehicleInput:   "pickup",
			depthCm:        35.1,
			windKmh:        30.0,
			expectedTier:   "CRITICAL",
			expectedBadge:  "🚙 รถกระบะ/SUV: น้ำท่วมระดับวิกฤต",
			expectedBg:     "#2D121B",
			expectedBorder: "#F43F5E",
		},
		{
			persona:        "Pickup Depth 60cm (Severe inundation)",
			vehicleInput:   "pickup",
			depthCm:        60.0,
			windKmh:        30.0,
			expectedTier:   "CRITICAL",
			expectedBadge:  "🚙 รถกระบะ/SUV: น้ำท่วมระดับวิกฤต",
			expectedBg:     "#2D121B",
			expectedBorder: "#F43F5E",
		},

		// ---------------- PUBLIC TRANSIT (BTS/MRT) Persona ----------------
		{
			persona:        "Transit in Dry Weather (100% Safe)",
			vehicleInput:   "transit",
			depthCm:        0.0,
			windKmh:        10.0,
			expectedTier:   "SAFE",
			expectedBadge:  "🚆 รถไฟฟ้า BTS/MRT: สัญจรปลอดภัย 100%",
			expectedBg:     "#0F291E",
			expectedBorder: "#34D399",
		},
		{
			persona:        "Transit in Severe Road Flood 50cm (100% Safe)",
			vehicleInput:   "bts",
			depthCm:        50.0,
			windKmh:        60.0,
			expectedTier:   "SAFE",
			expectedBadge:  "🚆 รถไฟฟ้า BTS/MRT: สัญจรปลอดภัย 100%",
			expectedBg:     "#0F291E",
			expectedBorder: "#34D399",
		},
		{
			persona:        "Transit in Catastrophic Road Flood 100cm (100% Safe)",
			vehicleInput:   "mrt",
			depthCm:        100.0,
			windKmh:        80.0,
			expectedTier:   "SAFE",
			expectedBadge:  "🚆 รถไฟฟ้า BTS/MRT: สัญจรปลอดภัย 100%",
			expectedBg:     "#0F291E",
			expectedBorder: "#34D399",
		},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.persona, func(t *testing.T) {
			badge, desc, bg, border := line.EvaluateVehicleClearance(tc.vehicleInput, tc.depthCm, tc.windKmh, "")

			if badge != tc.expectedBadge {
				t.Errorf("[%s] badge mismatch:\nwant: %q\ngot:  %q", tc.persona, tc.expectedBadge, badge)
			}
			if bg != tc.expectedBg {
				t.Errorf("[%s] background color mismatch: want %q, got %q", tc.persona, tc.expectedBg, bg)
			}
			if border != tc.expectedBorder {
				t.Errorf("[%s] border color mismatch: want %q, got %q", tc.persona, tc.expectedBorder, border)
			}
			if desc == "" {
				t.Errorf("[%s] description should not be empty", tc.persona)
			}
			if !utf8.ValidString(desc) {
				t.Errorf("[%s] description contains invalid UTF-8: %q", tc.persona, desc)
			}

			// Also verify that BuildFlexMessageBubble incorporates this vehicle card into the JSON
			adv := model.AdvisoryPayload{
				Title:        tc.persona,
				VehicleType:  tc.vehicleInput,
				FloodDepthCm: tc.depthCm,
				WindGust:     tc.windKmh,
			}
			bubble := line.BuildFlexMessageBubble(adv)
			jsonBytes, err := json.Marshal(bubble)
			if err != nil {
				t.Fatalf("[%s] failed to marshal bubble: %v", tc.persona, err)
			}

			var roundTrip StrictLineBubble
			if err := json.Unmarshal(jsonBytes, &roundTrip); err != nil {
				t.Fatalf("[%s] failed to strictly unmarshal bubble: %v", tc.persona, err)
			}

			// Validate vehicle card inside body contents index 2
			var vehCard StrictLineBox
			if err := json.Unmarshal(roundTrip.Body.Contents[2], &vehCard); err != nil {
				t.Fatalf("[%s] failed to unmarshal vehicle card: %v", tc.persona, err)
			}
			if vehCard.BackgroundColor != tc.expectedBg {
				t.Errorf("[%s] serialized vehicle card background: want %q, got %q", tc.persona, tc.expectedBg, vehCard.BackgroundColor)
			}
			if vehCard.BorderColor != tc.expectedBorder {
				t.Errorf("[%s] serialized vehicle card border: want %q, got %q", tc.persona, tc.expectedBorder, vehCard.BorderColor)
			}
		})
	}
}

// TestChallenger_DeepLinksAndCTAValidation tests LIFF URL query synchronization in the footer buttons
func TestChallenger_DeepLinksAndCTAValidation(t *testing.T) {
	tests := []struct {
		name              string
		adv               model.AdvisoryPayload
		expectedDashParam []string
		expectedCalParam  []string
	}{
		{
			name: "Critical Sedan Alert includes hazard focus",
			adv: model.AdvisoryPayload{
				Title:        "พายุฤดูร้อน",
				UrgencyLevel: "CRITICAL",
				VehicleType:  "sedan",
				LIFFURL:      "https://liff.line.me/test-app",
			},
			expectedDashParam: []string{"tab=dashboard", "vehicle=sedan", "focus=hazard"},
			expectedCalParam:  []string{"tab=calendar"},
		},
		{
			name: "Warning Moto Alert includes hazard focus",
			adv: model.AdvisoryPayload{
				Title:        "เตือนลมแรง",
				UrgencyLevel: "WARNING",
				VehicleType:  "motorcycle",
				LIFFURL:      "https://liff.line.me/test-app",
			},
			expectedDashParam: []string{"tab=dashboard", "vehicle=motorcycle", "focus=hazard"},
			expectedCalParam:  []string{"tab=calendar"},
		},
		{
			name: "Info Pickup Alert does not include hazard focus",
			adv: model.AdvisoryPayload{
				Title:        "ข้อมูลสภาพอากาศ",
				UrgencyLevel: "INFO",
				VehicleType:  "pickup",
				LIFFURL:      "https://liff.line.me/test-app",
			},
			expectedDashParam: []string{"tab=dashboard", "vehicle=pickup"},
			expectedCalParam:  []string{"tab=calendar"},
		},
		{
			name: "Custom ExtraParams takes precedence",
			adv: model.AdvisoryPayload{
				Title:        "พิเศษ",
				UrgencyLevel: "WARNING",
				VehicleType:  "transit",
				LIFFURL:      "https://liff.line.me/test-app",
				ExtraParams:  "station=asok&mode=realtime",
			},
			expectedDashParam: []string{"tab=dashboard", "vehicle=transit", "station=asok&mode=realtime"},
			expectedCalParam:  []string{"tab=calendar"},
		},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			bubble := line.BuildFlexMessageBubble(tc.adv)
			jsonBytes, err := json.Marshal(bubble)
			if err != nil {
				t.Fatalf("failed to marshal bubble: %v", err)
			}

			var roundTrip StrictLineBubble
			if err := json.Unmarshal(jsonBytes, &roundTrip); err != nil {
				t.Fatalf("failed to unmarshal bubble: %v", err)
			}

			if roundTrip.Footer == nil || len(roundTrip.Footer.Contents) != 2 {
				t.Fatalf("expected 2 CTA buttons in footer, got %v", roundTrip.Footer)
			}

			var btn1, btn2 StrictLineButton
			if err := json.Unmarshal(roundTrip.Footer.Contents[0], &btn1); err != nil {
				t.Fatalf("failed to unmarshal btn1: %v", err)
			}
			if err := json.Unmarshal(roundTrip.Footer.Contents[1], &btn2); err != nil {
				t.Fatalf("failed to unmarshal btn2: %v", err)
			}

			for _, sub := range tc.expectedDashParam {
				if !strings.Contains(btn1.Action.URI, sub) {
					t.Errorf("button 1 URI missing %q: got %q", sub, btn1.Action.URI)
				}
			}
			for _, sub := range tc.expectedCalParam {
				if !strings.Contains(btn2.Action.URI, sub) {
					t.Errorf("button 2 URI missing %q: got %q", sub, btn2.Action.URI)
				}
			}
		})
	}
}
