package nlp

import (
	"strings"
	"sync"
	"testing"
)

// TestChallenger_ExtremeInputStress tests router behavior with massive payloads,
// null bytes, and malicious Unicode sequences.
func TestChallenger_ExtremeInputStress(t *testing.T) {
	// 1. Massive 100KB payload with keyword hidden in the middle
	longPadding := strings.Repeat("กขคงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ", 1500)
	massiveInput := longPadding + " วันนี้มีน้ำท่วมหรือเปล่า " + longPadding

	result := Route(massiveInput)
	if result.Intent != IntentFlood {
		t.Fatalf("expected IntentFlood from massive input, got %s", result.Intent)
	}
	if len(result.MatchedKeywords) == 0 {
		t.Fatalf("expected matched keywords from massive input")
	}

	// 2. Null bytes and non-printable control chars embedded in Thai keywords
	embeddedNullInput := "ขอเช็ค\x00สภาพอากาศ\x00วันนี้\r\n\t"
	resNull := Route(embeddedNullInput)
	if resNull.Intent != IntentWeather {
		t.Fatalf("expected IntentWeather with embedded null bytes, got %s", resNull.Intent)
	}

	// 3. Invisible characters and Unicode BOM stress
	invisibleInput := "\uFEFF\u200B\u200C\u200D\u00A0ปฏิทิน\u200Bนัดหมาย\uFEFF"
	resInvis := Route(invisibleInput)
	if resInvis.Intent != IntentCalendar {
		t.Fatalf("expected IntentCalendar with invisible Unicode chars, got %s", resInvis.Intent)
	}
	if len(resInvis.MatchedKeywords) < 2 {
		t.Fatalf("expected at least 2 matched keywords, got %d", len(resInvis.MatchedKeywords))
	}
	if resInvis.Confidence < 0.95 {
		t.Fatalf("expected confidence >= 0.95 for multi-keyword match, got %f", resInvis.Confidence)
	}
}

// TestChallenger_CompoundMultiIntentScoring verifies deterministic scoring and secondary intent resolution.
func TestChallenger_CompoundMultiIntentScoring(t *testing.T) {
	tests := []struct {
		name              string
		input             string
		expectedPrimary   Intent
		expectedSecondary Intent
		expectedVehicle   VehicleMode
	}{
		{
			name:              "Weather + Flood with longer Flood phrase",
			input:             "ฝนตกหนัก น้ำท่วมขัง ถนนลาดพร้าว",
			expectedPrimary:   IntentFlood,
			expectedSecondary: IntentWeather,
		},
		{
			name:              "Vehicle + Flood compound query",
			input:             "ขับรถเก๋งเตี้ยผ่านจุดเสี่ยงน้ำท่วม",
			expectedPrimary:   IntentFlood,
			expectedSecondary: IntentVehicleProfile,
			expectedVehicle:   VehicleModeSedan,
		},
		{
			name:              "Vehicle + Calendar compound query",
			input:             "นั่งรถไฟฟ้า BTS ไปประชุมนัดหมายช่วงบ่าย",
			expectedPrimary:   IntentCalendar,
			expectedSecondary: IntentVehicleProfile,
			expectedVehicle:   VehicleModeTransit,
		},
		{
			name:              "Vehicle profile only with multiple synonyms",
			input:             "ฉันเปลี่ยนพาหนะเป็นมอเตอร์ไซค์ มอไซค์รับจ้าง",
			expectedPrimary:   IntentVehicleProfile,
			expectedSecondary: "",
			expectedVehicle:   VehicleModeMotorcycle,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := Route(tt.input)
			if result.Intent != tt.expectedPrimary {
				t.Errorf("[%s] Expected primary intent %s, got %s", tt.name, tt.expectedPrimary, result.Intent)
			}
			if tt.expectedSecondary != "" && result.SecondaryIntent != tt.expectedSecondary {
				t.Errorf("[%s] Expected secondary intent %s, got %s", tt.name, tt.expectedSecondary, result.SecondaryIntent)
			}
			if tt.expectedVehicle != "" {
				mode, ok := result.VehicleMode()
				if !ok {
					t.Errorf("[%s] Expected vehicle mode %s to be extracted", tt.name, tt.expectedVehicle)
				} else if mode != tt.expectedVehicle {
					t.Errorf("[%s] Expected vehicle mode %s, got %s", tt.name, tt.expectedVehicle, mode)
				}
			}
		})
	}
}

// TestChallenger_ConfidenceCalibration verifies exact confidence tiers.
func TestChallenger_ConfidenceCalibration(t *testing.T) {
	// 0 keywords -> Confidence 0.0
	resUnknown := Route("สวัสดีตอนเช้าครับ มีข่าวอะไรบ้าง")
	if resUnknown.Confidence != 0.0 {
		t.Errorf("expected 0.0 confidence for unknown, got %f", resUnknown.Confidence)
	}

	// 1 short keyword (< 4 runes, e.g. "ฝน" which is 2 runes) -> Confidence 0.85
	resShort := Route("แถวนี้มีฝนไหม")
	if resShort.Confidence != 0.85 {
		t.Errorf("expected 0.85 confidence for short keyword, got %f", resShort.Confidence)
	}

	// 1 long keyword (>= 4 runes, e.g. "พยากรณ์" which is 7 runes) -> Confidence 0.90
	resLong := Route("ขอพยากรณ์หน่อยครับ")
	if resLong.Confidence != 0.90 {
		t.Errorf("expected 0.90 confidence for long keyword, got %f", resLong.Confidence)
	}

	// 2+ keywords -> Confidence 0.95
	resMulti := Route("สภาพอากาศ พยากรณ์ ฝนตก")
	if resMulti.Confidence != 0.95 {
		t.Errorf("expected 0.95 confidence for 2+ keywords, got %f", resMulti.Confidence)
	}
}

// TestChallenger_HighConcurrencyAndRaces stresses Route under concurrent goroutines.
func TestChallenger_HighConcurrencyAndRaces(t *testing.T) {
	const goroutines = 100
	const iterations = 100

	var wg sync.WaitGroup
	wg.Add(goroutines)

	inputs := []string{
		"สภาพอากาศ กรุงเทพ 2569",
		"น้ำท่วม จุดเสี่ยง คลองแสนแสบ",
		"ปฏิทิน นัดหมาย ตารางงาน",
		"ฉันขับรถเก๋ง eco car",
		"ขี่มอเตอร์ไซค์ ซิ่งไปทำงาน",
		"เดินทางด้วย BTS และ MRT",
		"คำถามทั่วไป ไม่เกี่ยวกับระบบ",
	}

	for g := 0; g < goroutines; g++ {
		go func(gid int) {
			defer wg.Done()
			for i := 0; i < iterations; i++ {
				text := inputs[(gid+i)%len(inputs)]
				res := Route(text)
				if !res.Intent.IsRecognized() && res.Intent != IntentUnknown {
					t.Errorf("routine %d invalid intent: %s", gid, res.Intent)
				}
				_ = res.HasEntity("vehicle_mode")
			}
		}(g)
	}

	wg.Wait()
}

// TestChallenger_CustomRouterIndependence verifies independent instances don't mutate defaults.
func TestChallenger_CustomRouterIndependence(t *testing.T) {
	custom := NewRouter()
	custom.weatherKeywords = []string{"monsoon_super_storm"}
	custom.floodKeywords = []string{"dam_overflow"}

	resCustom := custom.Route("monsoon_super_storm alert")
	if resCustom.Intent != IntentWeather {
		t.Fatalf("expected custom router to match monsoon_super_storm")
	}

	// Ensure default router is unchanged
	resDefault := Route("monsoon_super_storm alert")
	if resDefault.Intent == IntentWeather {
		t.Fatalf("default router should not match custom keywords")
	}

	resDefaultOriginal := Route("สภาพอากาศวันนี้")
	if resDefaultOriginal.Intent != IntentWeather {
		t.Fatalf("default router should still match default keywords")
	}
}
