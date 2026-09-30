package nlp

import (
	"sync"
	"testing"
)

func TestIntent_Methods(t *testing.T) {
	if IntentWeather.String() != "IntentWeather" {
		t.Fatalf("expected IntentWeather, got %s", IntentWeather.String())
	}
	if !IntentWeather.IsRecognized() {
		t.Fatalf("expected IntentWeather to be recognized")
	}
	if IntentUnknown.IsRecognized() {
		t.Fatalf("expected IntentUnknown not to be recognized")
	}
	var emptyIntent Intent
	if emptyIntent.IsRecognized() {
		t.Fatalf("expected empty intent not to be recognized")
	}
}

func TestRoute_WeatherIntent(t *testing.T) {
	tests := []struct {
		name            string
		input           string
		expectedKeyword string
	}{
		{"Exact 'อากาศ'", "อากาศ", "อากาศ"},
		{"Exact 'สภาพอากาศ'", "สภาพอากาศ", "สภาพอากาศ"},
		{"Exact 'พยากรณ์'", "พยากรณ์", "พยากรณ์"},
		{"Exact 'ฝนตก'", "ฝนตก", "ฝนตก"},
		{"Exact 'ร้อน'", "ร้อน", "ร้อน"},
		{"Exact 'ฝน'", "ฝน", "ฝน"},
		{"Exact 'แดด'", "แดด", "แดด"},
		{"Colloquial 'วันนี้อากาศเป็นยังไงบ้าง'", "วันนี้อากาศเป็นยังไงบ้าง", "อากาศ"},
		{"Colloquial 'ขอเช็คสภาพอากาศกรุงเทพหน่อย'", "ขอเช็คสภาพอากาศกรุงเทพหน่อย", "สภาพอากาศ"},
		{"Colloquial 'ดูพยากรณ์อากาศ 2 ชั่วโมงข้างหน้า'", "ดูพยากรณ์อากาศ 2 ชั่วโมงข้างหน้า", "พยากรณ์"},
		{"Colloquial 'ฝนตกไหมแถวนี้'", "ฝนตกไหมแถวนี้", "ฝนตก"},
		{"Colloquial 'วันนี้แดดร้อนไหม อากาศร้อนมาก'", "วันนี้แดดร้อนไหม อากาศร้อนมาก", "ร้อน"},
		{"English 'Weather forecast please'", "Weather forecast please", "weather"},
		{"English 'Is it going to rain?'", "Is it going to rain?", "rain"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := Route(tt.input)
			if result.Intent != IntentWeather {
				t.Fatalf("expected IntentWeather, got %s for input: %q", result.Intent, tt.input)
			}
			if result.Confidence <= 0 {
				t.Fatalf("expected positive confidence, got %f", result.Confidence)
			}
			if len(result.MatchedKeywords) == 0 {
				t.Fatalf("expected matched keywords, got empty")
			}
		})
	}
}

func TestRoute_FloodIntent(t *testing.T) {
	tests := []struct {
		name  string
		input string
	}{
		{"Exact 'น้ำท่วม'", "น้ำท่วม"},
		{"Exact 'จุดเสี่ยง'", "จุดเสี่ยง"},
		{"Exact 'คลอง'", "คลอง"},
		{"Exact 'ระดับน้ำ'", "ระดับน้ำ"},
		{"Exact 'น้ำรอระบาย'", "น้ำรอระบาย"},
		{"Exact 'ท่วม'", "ท่วม"},
		{"Colloquial 'มีจุดเสี่ยงน้ำท่วมไหม'", "มีจุดเสี่ยงน้ำท่วมไหม"},
		{"Colloquial 'ระดับน้ำคลองแสนแสบเป็นอย่างไร'", "ระดับน้ำคลองแสนแสบเป็นอย่างไร"},
		{"Colloquial 'ถนนลาดพร้าวน้ำรอระบายหรือยัง'", "ถนนลาดพร้าวน้ำรอระบายหรือยัง"},
		{"Colloquial 'เช็กน้ำท่วมขัง'", "เช็กน้ำท่วมขัง"},
		{"English 'Check flood situation'", "Check flood situation"},
		{"English 'Canal water stage'", "Canal water stage"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := Route(tt.input)
			if result.Intent != IntentFlood {
				t.Fatalf("expected IntentFlood, got %s for input: %q", result.Intent, tt.input)
			}
			if result.Confidence <= 0 {
				t.Fatalf("expected positive confidence, got %f", result.Confidence)
			}
		})
	}
}

func TestRoute_CalendarIntent(t *testing.T) {
	tests := []struct {
		name  string
		input string
	}{
		{"Exact 'นัดหมาย'", "นัดหมาย"},
		{"Exact 'ปฏิทิน'", "ปฏิทิน"},
		{"Exact 'เดินทาง'", "เดินทาง"},
		{"Exact 'ตารางงาน'", "ตารางงาน"},
		{"Exact 'ประชุม'", "ประชุม"},
		{"Colloquial 'มีนัดหมายช่วงเย็น จะเจอฝนไหม'", "มีนัดหมายช่วงเย็น จะเจอฝนไหม"},
		{"Colloquial 'เช็คปฏิทินวันนี้'", "เช็คปฏิทินวันนี้"},
		{"Colloquial 'ตารางงานวันนี้มีอะไรบ้าง'", "ตารางงานวันนี้มีอะไรบ้าง"},
		{"Colloquial 'วางแผนการเดินทาง'", "วางแผนการเดินทาง"},
		{"English 'Check calendar clashes'", "Check calendar clashes"},
		{"English 'Meeting schedule'", "Meeting schedule"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := Route(tt.input)
			if result.Intent != IntentCalendar && result.SecondaryIntent != IntentCalendar {
				t.Fatalf("expected IntentCalendar (primary or secondary), got primary=%s, sec=%s for input: %q",
					result.Intent, result.SecondaryIntent, tt.input)
			}
			if result.Confidence <= 0 {
				t.Fatalf("expected positive confidence, got %f", result.Confidence)
			}
		})
	}
}

func TestRoute_VehicleProfileIntent_And_EntityExtraction(t *testing.T) {
	tests := []struct {
		name         string
		input        string
		expectedMode VehicleMode
	}{
		{"Exact 'รถเก๋ง'", "รถเก๋ง", VehicleModeSedan},
		{"Exact 'เก๋ง'", "เก๋ง", VehicleModeSedan},
		{"Exact 'มอเตอร์ไซค์'", "มอเตอร์ไซค์", VehicleModeMotorcycle},
		{"Exact 'suv'", "suv", VehicleModePickup},
		{"Uppercase 'SUV'", "SUV", VehicleModePickup},
		{"Mixed case 'SuV'", "SuV", VehicleModePickup},
		{"Exact 'bts'", "bts", VehicleModeTransit},
		{"Uppercase 'BTS'", "BTS", VehicleModeTransit},
		{"Exact 'mrt'", "mrt", VehicleModeTransit},
		{"Exact 'กระบะ'", "กระบะ", VehicleModePickup},
		{"Colloquial 'รถกระบะ'", "รถกระบะ", VehicleModePickup},
		{"Exact 'รถไฟฟ้า'", "รถไฟฟ้า", VehicleModeTransit},
		{"Colloquial 'มอไซค์'", "มอไซค์", VehicleModeMotorcycle},
		{"Colloquial 'เปลี่ยนเป็นรถเก๋ง'", "เปลี่ยนเป็นรถเก๋ง", VehicleModeSedan},
		{"Colloquial 'ผมขับมอเตอร์ไซค์ครับ'", "ผมขับมอเตอร์ไซค์ครับ", VehicleModeMotorcycle},
		{"Colloquial 'เดินทางด้วยรถไฟฟ้า'", "เดินทางด้วยรถไฟฟ้า", VehicleModeTransit},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := Route(tt.input)
			if result.Intent != IntentVehicleProfile && result.SecondaryIntent != IntentVehicleProfile {
				t.Fatalf("expected IntentVehicleProfile (primary or secondary), got primary=%s, sec=%s for input: %q",
					result.Intent, result.SecondaryIntent, tt.input)
			}
			mode, ok := result.VehicleMode()
			if !ok {
				t.Fatalf("expected vehicle_mode entity to be extracted for input: %q", tt.input)
			}
			if mode != tt.expectedMode {
				t.Fatalf("expected vehicle mode %q, got %q", tt.expectedMode, mode)
			}
			if !result.HasEntity("vehicle_mode") {
				t.Fatalf("expected HasEntity('vehicle_mode') to be true")
			}
		})
	}
}

func TestRoute_EdgeCases(t *testing.T) {
	t.Run("Empty string returns IntentUnknown", func(t *testing.T) {
		result := Route("")
		if result.Intent != IntentUnknown || result.Confidence != 0 {
			t.Fatalf("expected IntentUnknown with 0 confidence, got %s (%f)", result.Intent, result.Confidence)
		}
		if result.HasEntity("vehicle_mode") {
			t.Fatalf("expected no entity on empty string")
		}
		if _, ok := result.VehicleMode(); ok {
			t.Fatalf("expected VehicleMode() ok to be false")
		}
	})

	t.Run("Whitespace only returns IntentUnknown", func(t *testing.T) {
		result := Route("   \t\n\r  ")
		if result.Intent != IntentUnknown || result.Confidence != 0 {
			t.Fatalf("expected IntentUnknown with 0 confidence, got %s (%f)", result.Intent, result.Confidence)
		}
	})

	t.Run("Emojis with Thai text parsed correctly", func(t *testing.T) {
		res1 := Route("🌧️ อากาศเป็นไงบ้าง")
		if res1.Intent != IntentWeather {
			t.Fatalf("expected IntentWeather, got %s", res1.Intent)
		}

		res2 := Route("🌊 จุดเสี่ยงน้ำท่วม ⚠️")
		if res2.Intent != IntentFlood {
			t.Fatalf("expected IntentFlood, got %s", res2.Intent)
		}

		res3 := Route("🚗 รถเก๋ง")
		if res3.Intent != IntentVehicleProfile {
			t.Fatalf("expected IntentVehicleProfile, got %s", res3.Intent)
		}
		if mode, ok := res3.VehicleMode(); !ok || mode != VehicleModeSedan {
			t.Fatalf("expected compact_sedan, got %s (ok=%v)", mode, ok)
		}

		res4 := Route("🛵 มอเตอร์ไซค์")
		if res4.Intent != IntentVehicleProfile {
			t.Fatalf("expected IntentVehicleProfile, got %s", res4.Intent)
		}
		if mode, ok := res4.VehicleMode(); !ok || mode != VehicleModeMotorcycle {
			t.Fatalf("expected motorcycle, got %s (ok=%v)", mode, ok)
		}
	})

	t.Run("Emojis only returns IntentUnknown", func(t *testing.T) {
		result := Route("🌧️🚗💨")
		if result.Intent != IntentUnknown {
			t.Fatalf("expected IntentUnknown for emojis only, got %s", result.Intent)
		}
	})

	t.Run("Off-topic and greeting returns IntentUnknown", func(t *testing.T) {
		unrecognized := []string{
			"สวัสดีครับ",
			"ขอบคุณครับ",
			"กินข้าวหรือยัง",
			"123456789",
			"test test",
			"!@#$%^&*()",
		}
		for _, u := range unrecognized {
			res := Route(u)
			if res.Intent != IntentUnknown {
				t.Fatalf("expected IntentUnknown for %q, got %s", u, res.Intent)
			}
		}
	})

	t.Run("Punctuation with Thai keywords", func(t *testing.T) {
		res := Route("น้ำท่วม????")
		if res.Intent != IntentFlood {
			t.Fatalf("expected IntentFlood, got %s", res.Intent)
		}

		res2 := Route("สภาพอากาศ!!!")
		if res2.Intent != IntentWeather {
			t.Fatalf("expected IntentWeather, got %s", res2.Intent)
		}
	})

	t.Run("Zero-width characters stripped cleanly", func(t *testing.T) {
		res := Route("\u200Bสภาพอากาศ\u200B")
		if res.Intent != IntentWeather {
			t.Fatalf("expected IntentWeather, got %s", res.Intent)
		}

		resNBSP := Route("\u00A0ฝนตก\u00A0")
		if resNBSP.Intent != IntentWeather {
			t.Fatalf("expected IntentWeather, got %s", resNBSP.Intent)
		}
	})

	t.Run("Invisible Unicode formatting characters stripped cleanly", func(t *testing.T) {
		testCases := []struct {
			name     string
			input    string
			expected Intent
		}{
			{"Word Joiner in Calendar", "ปฏิ\u2060ทิน", IntentCalendar},
			{"Word Joiner in Vehicle", "มอเตอร์\u2060ไซค์", IntentVehicleProfile},
			{"Left-to-Right Mark in Weather", "สภา\u200Eพอากาศ", IntentWeather},
			{"Right-to-Left Mark in Flood", "น้ำ\u200Fท่วม", IntentFlood},
			{"Soft Hyphen in Appointment", "นัด\u00ADหมาย", IntentCalendar},
			{"Mongolian Vowel Separator in Canal", "ค\u180Eลอง", IntentFlood},
		}

		for _, tc := range testCases {
			t.Run(tc.name, func(t *testing.T) {
				res := Route(tc.input)
				if res.Intent != tc.expected {
					t.Fatalf("for input %q expected intent %s, got %s", tc.input, tc.expected, res.Intent)
				}
			})
		}
	})
}

func TestRoute_CompoundAndMultiIntent(t *testing.T) {
	t.Run("Vehicle + Flood compound query", func(t *testing.T) {
		input := "ขับมอเตอร์ไซค์ไปดูน้ำท่วมที่คลองแสนแสบ"
		result := Route(input)

		if result.Intent != IntentFlood {
			t.Fatalf("expected primary IntentFlood, got %s", result.Intent)
		}
		if result.SecondaryIntent != IntentVehicleProfile {
			t.Fatalf("expected secondary IntentVehicleProfile, got %s", result.SecondaryIntent)
		}
		mode, ok := result.VehicleMode()
		if !ok || mode != VehicleModeMotorcycle {
			t.Fatalf("expected motorcycle mode, got %s (ok=%v)", mode, ok)
		}
		if loc, ok := result.Entities["location"]; !ok || loc != "คลองแสนแสบ" {
			t.Fatalf("expected location 'คลองแสนแสบ', got %s (ok=%v)", loc, ok)
		}
	})

	t.Run("Calendar + Weather compound query", func(t *testing.T) {
		input := "นัดหมายเดินทางวันนี้จะมีฝนตกไหม"
		result := Route(input)

		hasCalendar := result.Intent == IntentCalendar || result.SecondaryIntent == IntentCalendar
		hasWeather := result.Intent == IntentWeather || result.SecondaryIntent == IntentWeather

		if !hasCalendar || !hasWeather {
			t.Fatalf("expected both Calendar and Weather represented, primary=%s, sec=%s",
				result.Intent, result.SecondaryIntent)
		}
	})
}

func TestRoute_ConcurrentSafety(t *testing.T) {
	var wg sync.WaitGroup
	inputs := []string{
		"สภาพอากาศวันนี้",
		"น้ำท่วมไหม",
		"ปฏิทินงาน",
		"รถเก๋ง",
		"มอเตอร์ไซค์",
		"SUV",
		"BTS",
		"สวัสดีครับ",
	}

	for i := 0; i < 50; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			input := inputs[idx%len(inputs)]
			res := Route(input)
			if input == "สวัสดีครับ" && res.Intent != IntentUnknown {
				t.Errorf("expected IntentUnknown for %s, got %s", input, res.Intent)
			}
		}(i)
	}

	wg.Wait()
}
