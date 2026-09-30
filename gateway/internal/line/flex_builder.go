package line

import (
	"fmt"
	"net/url"
	"os"
	"strings"

	"github.com/saransirichote/weather-resilience-gateway/internal/model"
)

const (
	// Theme 1: Apple Spatial Weather dark frosted visual hierarchy palette
	ColorBgHeaderFooter = "#091122" // Atmospheric dark header & footer background
	ColorBgBody         = "#0B132B" // Frosted dark navy body canvas background
	ColorBgCard         = "#162238" // Frosted 2x2 Bento & vehicle clearance card background
	ColorBorderCard     = "#2A3B5C" // Subtle frosted card border accent

	// Urgency level status badge & accent colors
	ColorUrgencyCritical = "#F43F5E" // Rose 500
	ColorUrgencyWarning  = "#F59E0B" // Amber 500
	ColorUrgencyAdvisory = "#38BDF8" // Sky 400
	ColorUrgencyInfo     = "#34D399" // Emerald 400

	// Text typography hierarchy
	ColorTextPrimary   = "#FFFFFF"
	ColorTextSecondary = "#E2E8F0"
	ColorTextMuted     = "#94A3B8"
	ColorTextDimmed    = "#64748B"

	// Constraints
	MaxCarouselBubbles      = 12
	MaxQuickReplyItems     = 13
	MaxQuickReplyLabelRunes = 20

	DefaultLiffEndpoint = "https://liff.line.me/placeholder"
)

// UrgencyTheme holds visual styling properties for urgency badge tiers
type UrgencyTheme struct {
	Level       string
	BadgeText   string
	AccentColor string
	BgColor     string
	BorderColor string
}

// truncateRunes safely truncates a string to maxRunes, appending an ellipsis if truncated.
func truncateRunes(s string, maxRunes int) string {
	r := []rune(s)
	if len(r) > maxRunes {
		return string(r[:maxRunes-1]) + "…"
	}
	return s
}

// escapeQueryString safely URL-encodes a raw query string without mangling delimiters or duplicating escapes.
func escapeQueryString(qs string) string {
	if qs == "" {
		return ""
	}
	qs = strings.TrimLeft(qs, "?&")
	parts := strings.Split(qs, "&")
	escapedParts := make([]string, 0, len(parts))
	for _, part := range parts {
		if part == "" {
			continue
		}
		kv := strings.SplitN(part, "=", 2)
		if len(kv) == 2 {
			unescapedKey, err := url.QueryUnescape(kv[0])
			if err != nil {
				unescapedKey = kv[0]
			}
			unescapedVal, err := url.QueryUnescape(kv[1])
			if err != nil {
				unescapedVal = kv[1]
			}
			escapedParts = append(escapedParts, fmt.Sprintf("%s=%s", url.QueryEscape(unescapedKey), url.QueryEscape(unescapedVal)))
		} else {
			unescaped, err := url.QueryUnescape(part)
			if err != nil {
				unescaped = part
			}
			escapedParts = append(escapedParts, url.QueryEscape(unescaped))
		}
	}
	return strings.Join(escapedParts, "&")
}

func getUrgencyTheme(level string) UrgencyTheme {
	switch strings.ToUpper(strings.TrimSpace(level)) {
	case "CRITICAL":
		return UrgencyTheme{
			Level:       "CRITICAL",
			BadgeText:   "🚨 เตือนภัยระดับวิกฤต (CRITICAL)",
			AccentColor: ColorUrgencyCritical,
			BgColor:     "#2D121B",
			BorderColor: "#F43F5E66",
		}
	case "WARNING":
		return UrgencyTheme{
			Level:       "WARNING",
			BadgeText:   "⚠️ แจ้งเตือนความเสี่ยงสูง (WARNING)",
			AccentColor: ColorUrgencyWarning,
			BgColor:     "#2D2210",
			BorderColor: "#F59E0B66",
		}
	case "ADVISORY":
		return UrgencyTheme{
			Level:       "ADVISORY",
			BadgeText:   "☀️ คำแนะนำสภาพอากาศ (ADVISORY)",
			AccentColor: ColorUrgencyAdvisory,
			BgColor:     "#102A45",
			BorderColor: "#38BDF866",
		}
	default:
		return UrgencyTheme{
			Level:       "INFO",
			BadgeText:   "🌤️ ข้อมูลสภาพอากาศ (INFO)",
			AccentColor: ColorUrgencyInfo,
			BgColor:     "#0F291E",
			BorderColor: "#34D39966",
		}
	}
}

// QuickReplyItem represents a contextual quick reply action button
type QuickReplyItem struct {
	ActionType string `json:"action_type,omitempty"` // "message" or "uri"
	Label      string `json:"label"`                 // Display label (max 20 runes)
	Text       string `json:"text,omitempty"`        // Text for message action
	URI        string `json:"uri,omitempty"`         // Destination for uri action
}

// BuildFlexMessageBubble transforms an AdvisoryPayload into Theme 1: Apple Spatial Weather Flex Bubble
func BuildFlexMessageBubble(adv model.AdvisoryPayload) map[string]interface{} {
	urgencyTheme := getUrgencyTheme(adv.UrgencyLevel)

	locationName := adv.GetLocationName()
	temperature := adv.GetTemperature()
	condition := adv.GetCondition()
	rainRate := adv.GetRainRate()
	canalName := adv.GetCanalName()
	canalStage := adv.GetCanalStage()
	canalRemaining := adv.GetCanalRemainingCm()
	heatIndex := adv.GetHeatIndex()
	windGust := adv.GetWindGust()
	vehicleType := adv.GetVehicleType()
	floodDepth := adv.GetFloodDepth()

	// 1. Header: #091122 background
	// WeatherNext 3 badge + BMA radar live pulse + Urgency badge + Title + Location
	locationMetadata := fmt.Sprintf("📍 %s", locationName)
	if adv.CriticalWindow != "" {
		locationMetadata = fmt.Sprintf("📍 %s · ⏱️ %s", locationName, adv.CriticalWindow)
	}

	headerContents := []map[string]interface{}{
		{
			"type":   "box",
			"layout": "horizontal",
			"contents": []map[string]interface{}{
				{
					"type":    "box",
					"layout":  "horizontal",
					"spacing": "xs",
					"contents": []map[string]interface{}{
						{"type": "text", "text": "●", "color": "#38BDF8", "size": "xxs", "flex": 0},
						{"type": "text", "text": "WEATHERNEXT 3 (5KM)", "color": "#38BDF8", "size": "xxs", "weight": "bold"},
					},
				},
				{
					"type":    "box",
					"layout":  "horizontal",
					"spacing": "xs",
					"contents": []map[string]interface{}{
						{"type": "text", "text": "●", "color": "#34D399", "size": "xxs", "flex": 0},
						{"type": "text", "text": "เรดาร์ กทม. ONLINE", "color": "#34D399", "size": "xxs", "weight": "bold", "align": "end"},
					},
				},
			},
		},
		{
			"type":            "box",
			"layout":          "horizontal",
			"backgroundColor": urgencyTheme.BgColor,
			"borderColor":     urgencyTheme.BorderColor,
			"borderWidth":     "light",
			"cornerRadius":    "md",
			"paddingAll":      "6px",
			"margin":          "sm",
			"contents": []map[string]interface{}{
				{
					"type":   "text",
					"text":   urgencyTheme.BadgeText,
					"color":  urgencyTheme.AccentColor,
					"size":   "xs",
					"weight": "bold",
				},
			},
		},
		{
			"type":   "text",
			"text":   truncateRunes(adv.Title, 60),
			"color":  ColorTextPrimary,
			"size":   "md",
			"weight": "bold",
			"wrap":   true,
			"margin": "sm",
		},
		{
			"type":   "text",
			"text":   locationMetadata,
			"color":  ColorTextMuted,
			"size":   "xxs",
			"wrap":   true,
			"margin": "xs",
		},
	}

	// 2. Body: #0B132B frosted background
	// Hero temperature & condition + 2x2 Bento telemetry tiles + Vehicle clearance alert card + Action checklist + Alternative routes
	heroSection := map[string]interface{}{
		"type":    "box",
		"layout":  "vertical",
		"spacing": "xs",
		"contents": []map[string]interface{}{
			{
				"type":   "text",
				"text":   fmt.Sprintf("%.0f°", temperature),
				"color":  ColorTextPrimary,
				"size":   "4xl",
				"weight": "bold",
				"align":  "center",
			},
			{
				"type":   "text",
				"text":   condition,
				"color":  ColorTextSecondary,
				"size":   "sm",
				"weight": "bold",
				"align":  "center",
			},
			{
				"type":   "text",
				"text":   truncateRunes(adv.SummaryText, 85),
				"wrap":   true,
				"size":   "xs",
				"color":  ColorTextMuted,
				"align":  "center",
				"margin": "xs",
			},
		},
	}

	// 2x2 Bento Telemetry Tiles (#162238 cards with cornerRadius: "md")
	rainPill, rainColor := getRainSeverityPill(rainRate)
	canalPill, canalColor := getCanalSeverityPill(canalRemaining)
	heatPill, heatColor := getHeatSeverityPill(heatIndex)
	windPill, windColor := getWindSeverityPill(windGust)

	bentoRow1 := map[string]interface{}{
		"type":    "box",
		"layout":  "horizontal",
		"spacing": "sm",
		"contents": []map[string]interface{}{
			buildBentoTile("ฝนสะสม", "🌧️", fmt.Sprintf("%.1f", rainRate), "mm/h", rainPill, rainColor),
			buildBentoTile(canalName, "🌊", fmt.Sprintf("%.2f", canalStage), "m MSL", canalPill, canalColor),
		},
	}

	bentoRow2 := map[string]interface{}{
		"type":    "box",
		"layout":  "horizontal",
		"spacing": "sm",
		"contents": []map[string]interface{}{
			buildBentoTile("ดัชนีความร้อน", "🌡️", fmt.Sprintf("%.1f", heatIndex), "°C", heatPill, heatColor),
			buildBentoTile("ลมกระโชกแรง", "💨", fmt.Sprintf("%.1f", windGust), "km/h", windPill, windColor),
		},
	}

	bentoGrid := map[string]interface{}{
		"type":    "box",
		"layout":  "vertical",
		"spacing": "sm",
		"contents": []map[string]interface{}{
			bentoRow1,
			bentoRow2,
		},
	}

	// Vehicle clearance alert card (sedan <15cm, moto >45km/h, pickup <=35cm, transit BTS/MRT)
	vehBadge, vehDesc, vehBg, vehBorder := EvaluateVehicleClearance(vehicleType, floodDepth, windGust, adv.VehicleImpact)
	vehicleCard := map[string]interface{}{
		"type":            "box",
		"layout":          "vertical",
		"backgroundColor": vehBg,
		"borderColor":     vehBorder,
		"borderWidth":     "light",
		"cornerRadius":    "md",
		"paddingAll":      "10px",
		"spacing":         "xs",
		"contents": []map[string]interface{}{
			{
				"type":   "text",
				"text":   vehBadge,
				"size":   "xs",
				"weight": "bold",
				"color":  ColorTextPrimary,
			},
			{
				"type":  "text",
				"text":  vehDesc,
				"size":  "xxs",
				"color": ColorTextSecondary,
				"wrap":  true,
			},
		},
	}

	// Action checklist with emerald checkmarks (capped to max 5 items to respect LINE 10KB limit)
	actionItems := adv.ActionChecklist
	if len(actionItems) == 0 {
		actionItems = []string{
			"ตรวจสอบสภาพอากาศก่อนออกเดินทาง",
			"หลีกเลี่ยงเส้นทางจุดเสี่ยงน้ำท่วมขัง",
		}
	} else if len(actionItems) > 5 {
		actionItems = actionItems[:5]
	}

	checklistComponents := make([]map[string]interface{}, 0, len(actionItems))
	for _, item := range actionItems {
		item = truncateRunes(item, 75)
		checklistComponents = append(checklistComponents, map[string]interface{}{
			"type":            "box",
			"layout":          "horizontal",
			"spacing":         "sm",
			"backgroundColor": ColorBgCard,
			"borderColor":     ColorBorderCard,
			"borderWidth":     "light",
			"cornerRadius":    "md",
			"paddingAll":      "6px",
			"contents": []map[string]interface{}{
				{
					"type":   "text",
					"text":   "✓",
					"color":  ColorUrgencyInfo,
					"size":   "xs",
					"weight": "bold",
					"flex":   0,
				},
				{
					"type":  "text",
					"text":  item,
					"wrap":  true,
					"size":  "xs",
					"color": ColorTextSecondary,
					"flex":  1,
				},
			},
		})
	}

	checklistBlock := map[string]interface{}{
		"type":    "box",
		"layout":  "vertical",
		"spacing": "xs",
		"contents": append([]map[string]interface{}{
			{
				"type":   "text",
				"text":   "📋 แผนการเตรียมตัวเชิงรุก (Action Checklist):",
				"weight": "bold",
				"size":   "xs",
				"color":  ColorTextPrimary,
				"margin": "xs",
			},
		}, checklistComponents...),
	}

	// Alternative route recommendations
	altRoute := adv.AlternativeRoutesOrActions
	if altRoute == "" {
		altRoute = "ใช้ทางด่วนเฉลิมมหานครหรือระบบขนส่งมวลชน BTS/MRT"
	}
	altRoute = truncateRunes(altRoute, 80)

	alternativeRouteBlock := map[string]interface{}{
		"type":            "box",
		"layout":          "horizontal",
		"spacing":         "xs",
		"backgroundColor": ColorBgCard,
		"borderColor":     ColorBorderCard,
		"borderWidth":     "light",
		"cornerRadius":    "md",
		"paddingAll":      "8px",
		"contents": []map[string]interface{}{
			{"type": "text", "text": "🛣️", "size": "xs", "flex": 0},
			{
				"type":  "text",
				"text":  fmt.Sprintf("เส้นทางสำรอง: %s", altRoute),
				"wrap":  true,
				"size":  "xs",
				"color": ColorUrgencyAdvisory,
				"flex":  1,
			},
		},
	}

	// 3. Footer: #091122 background, Dual CTA buttons with URI actions (?tab=dashboard, ?tab=calendar)
	liffBase := adv.GetLIFFURL()
	if liffBase == "" {
		liffBase = os.Getenv("LIFF_ENDPOINT_URL")
		if liffBase == "" {
			liffBase = DefaultLiffEndpoint
		}
	}
	liffBase = strings.TrimRight(liffBase, "/")

	targetTab := "dashboard"
	if adv.TabDestination != "" {
		targetTab = adv.TabDestination
	}

	dashboardURI := fmt.Sprintf("%s?tab=%s&vehicle=%s", liffBase, url.QueryEscape(targetTab), url.QueryEscape(vehicleType))
	if adv.ExtraParams != "" {
		escapedExtra := escapeQueryString(adv.ExtraParams)
		if !strings.Contains(dashboardURI, escapedExtra) {
			dashboardURI = fmt.Sprintf("%s&%s", dashboardURI, escapedExtra)
		}
	} else if adv.UrgencyLevel == "CRITICAL" || adv.UrgencyLevel == "WARNING" {
		dashboardURI = fmt.Sprintf("%s&focus=hazard", dashboardURI)
	}

	calendarURI := fmt.Sprintf("%s?tab=calendar", liffBase)

	footerBlock := map[string]interface{}{
		"type":            "box",
		"layout":          "horizontal",
		"backgroundColor": ColorBgHeaderFooter,
		"paddingAll":      "12px",
		"spacing":         "sm",
		"contents": []map[string]interface{}{
			{
				"type":   "button",
				"style":  "primary",
				"color":  "#0284C7",
				"height": "sm",
				"action": map[string]interface{}{
					"type":  "uri",
					"label": "📊 ดูเรดาร์ & แผนที่",
					"uri":   dashboardURI,
				},
			},
			{
				"type":   "button",
				"style":  "secondary",
				"height": "sm",
				"action": map[string]interface{}{
					"type":  "uri",
					"label": "📅 เช็กนัดหมาย",
					"uri":   calendarURI,
				},
			},
		},
	}

	// Root Bubble Assembly
	bubble := map[string]interface{}{
		"type": "bubble",
		"size": "mega",
		"styles": map[string]interface{}{
			"header": map[string]interface{}{"backgroundColor": ColorBgHeaderFooter},
			"body":   map[string]interface{}{"backgroundColor": ColorBgBody},
			"footer": map[string]interface{}{"backgroundColor": ColorBgHeaderFooter},
		},
		"header": map[string]interface{}{
			"type":            "box",
			"layout":          "vertical",
			"backgroundColor": ColorBgHeaderFooter,
			"paddingAll":      "16px",
			"spacing":         "sm",
			"contents":        headerContents,
		},
		"body": map[string]interface{}{
			"type":            "box",
			"layout":          "vertical",
			"backgroundColor": ColorBgBody,
			"paddingAll":      "16px",
			"spacing":         "md",
			"contents": []map[string]interface{}{
				heroSection,
				bentoGrid,
				vehicleCard,
				checklistBlock,
				alternativeRouteBlock,
			},
		},
		"footer": footerBlock,
	}

	return bubble
}

// EvaluateVehicleClearance evaluates flood and wind safety thresholds per vehicle persona
func EvaluateVehicleClearance(vehicleType string, depthCm float64, windKmh float64, customImpact string) (string, string, string, string) {
	norm := strings.ToLower(strings.TrimSpace(vehicleType))
	switch norm {
	case "moto", "motorcycle":
		if windKmh > 45 || depthCm >= 10 {
			desc := fmt.Sprintf("ลมกระโชก %.1f km/h (>45 km/h) และน้ำท่วมขัง %.0f cm เสี่ยงลื่นไถลและสิ่งของปลิว งดขับขี่หรือหลบในอาคาร", windKmh, depthCm)
			if customImpact != "" {
				desc = fmt.Sprintf("%s (%s)", customImpact, desc)
			}
			return "🛵 มอเตอร์ไซค์: เสี่ยงลมกระโชกและน้ำท่วม", desc, "#2D121B", ColorUrgencyCritical
		}
		desc := "สภาพลมและพื้นผิวถนนอยู่ในเกณฑ์ปลอดภัย สัญจรได้ปกติ"
		if customImpact != "" {
			desc = customImpact
		}
		return "🛵 มอเตอร์ไซค์: สภาพลมและถนนปลอดภัย", desc, ColorBgCard, ColorBorderCard

	case "pickup", "suv":
		if depthCm > 35 {
			desc := fmt.Sprintf("ระดับน้ำท่วม %.0f cm สูงเกินระยะปลอดภัยสูงสุด (35 cm) เสี่ยงกระแสน้ำพัด หลีกเลี่ยงเส้นทาง", depthCm)
			if customImpact != "" {
				desc = fmt.Sprintf("%s (%s)", customImpact, desc)
			}
			return "🚙 รถกระบะ/SUV: น้ำท่วมระดับวิกฤต", desc, "#2D121B", ColorUrgencyCritical
		}
		desc := fmt.Sprintf("ระดับน้ำท่วม %.0f cm อยู่ในขีดความสามารถของรถยกสูง (เกณฑ์ปลอดภัย <= 35 cm)", depthCm)
		if customImpact != "" {
			desc = customImpact
		}
		return "🚙 รถกระบะ/SUV: สัญจรได้ปลอดภัย", desc, "#0F291E", ColorUrgencyInfo

	case "transit", "bts", "mrt":
		desc := "ระบบรางยกระดับและใต้ดินไม่ได้รับผลกระทบจากน้ำท่วมขังผิวถนน 100% ตรวจสอบเฉพาะจุดทางขึ้นลงสถานี"
		if customImpact != "" {
			desc = customImpact
		}
		return "🚆 รถไฟฟ้า BTS/MRT: สัญจรปลอดภัย 100%", desc, "#0F291E", ColorUrgencyInfo

	default: // sedan, compact_sedan, eco-car
		if depthCm >= 15 {
			desc := fmt.Sprintf("ระดับน้ำท่วม %.0f cm เกินเกณฑ์ปลอดภัย (<15 cm) เสี่ยงน้ำเข้าท่อไอเสียและห้องเครื่อง หลีกเลี่ยงเส้นทางเด็ดขาด", depthCm)
			if customImpact != "" {
				desc = fmt.Sprintf("%s (%s)", customImpact, desc)
			}
			return "🚗 รถเก๋งเตี้ย: วิกฤตน้ำท่วมขัง", desc, "#2D121B", ColorUrgencyCritical
		} else if depthCm >= 10 {
			desc := fmt.Sprintf("ระดับน้ำท่วม %.0f cm ใกล้ขีดจำกัดปลอดภัย (15 cm) ขับช้าๆ ห้ามชะลอหรือแช่น้ำ", depthCm)
			if customImpact != "" {
				desc = fmt.Sprintf("%s (%s)", customImpact, desc)
			}
			return "🚗 รถเก๋งเตี้ย: เฝ้าระวังระดับน้ำ", desc, "#2D2210", ColorUrgencyWarning
		}
		desc := "ระดับน้ำปกติ สัญจรได้ตามปกติ"
		if customImpact != "" {
			desc = customImpact
		}
		return "🚗 รถเก๋งเตี้ย: ระดับน้ำปกติ สัญจรได้", desc, ColorBgCard, ColorBorderCard
	}
}

func buildBentoTile(title, icon, value, unit, statusPill, accentColor string) map[string]interface{} {
	return map[string]interface{}{
		"type":            "box",
		"layout":          "vertical",
		"flex":            1,
		"backgroundColor": ColorBgCard,
		"borderColor":     ColorBorderCard,
		"borderWidth":     "light",
		"cornerRadius":    "md",
		"paddingAll":      "10px",
		"spacing":         "xs",
		"contents": []map[string]interface{}{
			{
				"type":   "text",
				"text":   fmt.Sprintf("%s %s", title, icon),
				"size":   "xxs",
				"color":  ColorTextMuted,
				"weight": "bold",
			},
			{
				"type":    "box",
				"layout":  "horizontal",
				"spacing": "xs",
				"contents": []map[string]interface{}{
					{
						"type":   "text",
						"text":   value,
						"size":   "md",
						"weight": "bold",
						"color":  accentColor,
						"flex":   0,
					},
					{
						"type":    "text",
						"text":    unit,
						"size":    "xxs",
						"color":   ColorTextDimmed,
						"gravity": "bottom",
						"flex":    1,
					},
				},
			},
			{
				"type":  "text",
				"text":  statusPill,
				"size":  "xxs",
				"color": ColorTextMuted,
				"wrap":  true,
			},
		},
	}
}

func getRainSeverityPill(rainRate float64) (string, string) {
	if rainRate >= 90.0 {
		return "ฝนตกหนักมาก", ColorUrgencyCritical
	} else if rainRate >= 35.0 {
		return "ฝนตกหนัก", ColorUrgencyCritical
	} else if rainRate >= 10.0 {
		return "ฝนปานกลาง", ColorUrgencyWarning
	} else if rainRate > 0.0 {
		return "ฝนเล็กน้อย", ColorUrgencyAdvisory
	}
	return "ไม่มีกลุ่มฝน", ColorUrgencyInfo
}

func getCanalSeverityPill(canalRemaining float64) (string, string) {
	if canalRemaining <= 15.0 {
		return fmt.Sprintf("เหลือ %.0f cm วิกฤตล้นตลิ่ง", canalRemaining), ColorUrgencyCritical
	} else if canalRemaining <= 30.0 {
		return fmt.Sprintf("เหลือ %.0f cm เฝ้าระวังน้ำล้น", canalRemaining), ColorUrgencyWarning
	}
	return fmt.Sprintf("เหลือ %.0f cm ระดับปกติ", canalRemaining), ColorUrgencyInfo
}

func getHeatSeverityPill(heatIndex float64) (string, string) {
	if heatIndex >= 41.0 {
		return "ระดับอันตราย", ColorUrgencyCritical
	} else if heatIndex >= 37.0 {
		return "เฝ้าระวังเตือนภัย", ColorUrgencyWarning
	} else if heatIndex >= 32.0 {
		return "ใช้ความระมัดระวัง", ColorUrgencyAdvisory
	}
	return "ระดับปกติ", ColorUrgencyInfo
}

func getWindSeverityPill(windGust float64) (string, string) {
	if windGust >= 45.0 {
		return "ระวังกิ่งไม้/ป้ายปลิว", ColorUrgencyCritical
	} else if windGust >= 25.0 {
		return "ลมกระโชกปานกลาง", ColorUrgencyWarning
	}
	return "ลมสงบปกติ", ColorUrgencyInfo
}

// BuildFlexMessageCarousel bundles up to 12 bubble containers into a horizontal carousel container
func BuildFlexMessageCarousel(bubbles []map[string]interface{}) map[string]interface{} {
	capped := bubbles
	if len(capped) > MaxCarouselBubbles {
		capped = capped[:MaxCarouselBubbles]
	}
	if capped == nil {
		capped = []map[string]interface{}{}
	}
	return map[string]interface{}{
		"type":     "carousel",
		"contents": capped,
	}
}

// BuildFlexCarousel is an alias for BuildFlexMessageCarousel
func BuildFlexCarousel(bubbles []map[string]interface{}) map[string]interface{} {
	return BuildFlexMessageCarousel(bubbles)
}

// TruncateRunes safely truncates a string to maxRunes without splitting multi-byte UTF-8 sequences.
// If string is shorter than maxRunes, it returns the string safely without panic.
func TruncateRunes(s string, maxRunes int) string {
	if maxRunes <= 0 {
		return ""
	}
	r := []rune(s)
	if len(r) > maxRunes {
		return string(r[:maxRunes])
	}
	return s
}

// BuildQuickReplies constructs a LINE Quick Reply container (capped at 13 items, labels <= 20 runes)
func BuildQuickReplies(items []QuickReplyItem) map[string]interface{} {
	if len(items) > MaxQuickReplyItems {
		items = items[:MaxQuickReplyItems]
	}

	actionItems := make([]map[string]interface{}, 0, len(items))
	for _, it := range items {
		lbl := strings.TrimSpace(it.Label)
		if lbl == "" {
			lbl = "เมนู"
		}
		lbl = TruncateRunes(lbl, MaxQuickReplyLabelRunes)

		actionType := strings.ToLower(strings.TrimSpace(it.ActionType))
		var act map[string]interface{}
		if actionType == "uri" && it.URI != "" {
			act = map[string]interface{}{
				"type":  "uri",
				"label": lbl,
				"uri":   it.URI,
			}
		} else {
			txt := strings.TrimSpace(it.Text)
			if txt == "" {
				txt = lbl
			}
			act = map[string]interface{}{
				"type":  "message",
				"label": lbl,
				"text":  txt,
			}
		}

		actionItems = append(actionItems, map[string]interface{}{
			"type":   "action",
			"action": act,
		})
	}

	return map[string]interface{}{
		"items": actionItems,
	}
}

// DefaultQuickReplies returns pre-configured contextual quick reply items for Bangkok Weather (capped at 13 items, labels <= 20 runes)
func DefaultQuickReplies(liffBaseURL string) map[string]interface{} {
	items := []QuickReplyItem{
		{Label: "🌧️ สภาพอากาศ", Text: "อากาศ"},
		{Label: "🌊 ระดับน้ำคลอง", Text: "น้ำท่วม"},
		{Label: "📍 จุดเสี่ยงน้ำท่วม", Text: "จุดเสี่ยง"},
		{Label: "📅 เช็กปฏิทิน", Text: "ปฏิทิน"},
		{Label: "🚗 รถเก๋งเตี้ย", Text: "รถเก๋ง"},
		{Label: "🛵 มอเตอร์ไซค์", Text: "มอเตอร์ไซค์"},
		{Label: "🚙 กระบะยกสูง", Text: "กระบะ"},
		{Label: "🚆 รถไฟฟ้า BTS", Text: "bts"},
	}

	if liffBaseURL != "" {
		baseURL := strings.TrimRight(liffBaseURL, "/")
		items = append(items,
			QuickReplyItem{
				ActionType: "uri",
				Label:      "📱 แดชบอร์ดสด",
				URI:        baseURL + "?tab=dashboard",
			},
			QuickReplyItem{
				ActionType: "uri",
				Label:      "🗓️ ปฏิทินเชิงรุก",
				URI:        baseURL + "?tab=calendar",
			},
		)
	}

	return BuildQuickReplies(items)
}

// BuildDefaultQuickReplies is an alias for DefaultQuickReplies("")
func BuildDefaultQuickReplies() map[string]interface{} {
	return DefaultQuickReplies("")
}
