package nlp

import (
	"fmt"
	"math/rand"
	"strings"
	"sync"
	"testing"
	"time"
)

// TestAdversarial_ZeroWidthAndInvisibleChars challenges the router with various Unicode invisible chars
// embedded within, surrounding, and alternating inside keywords.
func TestAdversarial_ZeroWidthAndInvisibleChars(t *testing.T) {
	tests := []struct {
		name           string
		input          string
		expectedIntent Intent
		expectedMode   VehicleMode
		hasEntity      bool
	}{
		{
			name:           "Zero-width space \u200B embedded inside keyword สภาพอากาศ",
			input:          "ส\u200Bภาพ\u200Bอา\u200Bกาศ",
			expectedIntent: IntentWeather,
		},
		{
			name:           "Zero-width non-joiner \u200C and joiner \u200D inside น้ำท่วม",
			input:          "น้ำ\u200Cท่วม\u200D",
			expectedIntent: IntentFlood,
		},
		{
			name:           "BOM \uFEFF and non-breaking space \u00A0 in นัดหมาย",
			input:          "\uFEFFนัด\u00A0หมาย\uFEFF",
			expectedIntent: IntentCalendar,
		},
		{
			name:           "Alternating invisible characters in รถเก๋ง",
			input:          "\u200Bร\u200Cถ\u200Dเ\uFEFFก๋\u200Bง",
			expectedIntent: IntentVehicleProfile,
			expectedMode:   VehicleModeSedan,
			hasEntity:      true,
		},
		{
			name:           "Zero-width chars in motorcycle keyword มอเตอร์ไซค์",
			input:          "มอ\u200Bเตอร์\u200Cไซค์\u200D",
			expectedIntent: IntentVehicleProfile,
			expectedMode:   VehicleModeMotorcycle,
			hasEntity:      true,
		},
		{
			name:           "Leading and trailing invisible clusters with whitespace",
			input:          "\u200B\u200C\u200D\uFEFF   พยากรณ์   \uFEFF\u200D\u200C\u200B",
			expectedIntent: IntentWeather,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			res := Route(tt.input)
			if res.Intent != tt.expectedIntent {
				t.Errorf("input %q: expected intent %s, got %s", tt.input, tt.expectedIntent, res.Intent)
			}
			if tt.hasEntity {
				mode, ok := res.VehicleMode()
				if !ok || mode != tt.expectedMode {
					t.Errorf("input %q: expected vehicle mode %s, got %s (ok=%v)", tt.input, tt.expectedMode, mode, ok)
				}
			}
		})
	}
}

// TestAdversarial_SlangAndColloquialElongation challenges colloquial expressions,
// elongated vowels/consonants, and mixed English/Thai internet slang.
func TestAdversarial_SlangAndColloquialElongation(t *testing.T) {
	tests := []struct {
		name           string
		input          string
		expectedIntent Intent
		expectedLoc    string
		expectedMode   VehicleMode
	}{
		{
			name:           "Elongated water flood: น้ำท่วมมมมมมม",
			input:          "โอ้โหแถวบ้านน้ำท่วมมมมมมมหนักมากกกก",
			expectedIntent: IntentFlood,
		},
		{
			name:           "Elongated rain: ฝนตกกกกกกกกกก",
			input:          "ฝนตกกกกกกกกกกไม่หยุดเลย อากาศหนาวจัง",
			expectedIntent: IntentWeather,
		},
		{
			name:           "Elongated heat: ร้อนนนนนนมากกกก",
			input:          "วันนี้ร้อนนนนนนมากกกก แดดเปรี้ยงเลย",
			expectedIntent: IntentWeather,
		},
		{
			name:           "Colloquial motorcycle trip to Asoke during flood: ไปมอไซดีปะ แถวอโศกน้ำท่วมยัง",
			input:          "ไปมอไซดีปะ แถวอโศกน้ำท่วมยัง",
			expectedIntent: IntentFlood,
			expectedLoc:    "อโศก",
			expectedMode:   VehicleModeMotorcycle,
		},
		{
			name:           "Colloquial meeting schedule with calendar: มีนัดคุยงาน บ่ายนี้",
			input:          "มีนัดคุยงาน บ่ายนี้",
			expectedIntent: IntentCalendar,
		},
		{
			name:           "Irrelevant slang: รถติด ship lost ไม่ไหวแล้ว",
			input:          "รถติด ship lost ไม่ไหวแล้ว",
			expectedIntent: IntentUnknown,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			res := Route(tt.input)
			if res.Intent != tt.expectedIntent {
				t.Errorf("input %q: expected intent %s, got %s", tt.input, tt.expectedIntent, res.Intent)
			}
			if tt.expectedLoc != "" {
				loc := res.Entities["location"]
				if loc != tt.expectedLoc {
					t.Errorf("input %q: expected location entity %s, got %s", tt.input, tt.expectedLoc, loc)
				}
			}
			if tt.expectedMode != "" {
				mode, ok := res.VehicleMode()
				if !ok || mode != tt.expectedMode {
					t.Errorf("input %q: expected vehicle mode %s, got %s", tt.input, tt.expectedMode, mode)
				}
			}
		})
	}
}

// TestAdversarial_EmojiSurges challenges emojis with variation selectors, skin tone modifiers,
// and complex multi-codepoint sequences.
func TestAdversarial_EmojiSurges(t *testing.T) {
	tests := []struct {
		name           string
		input          string
		expectedIntent Intent
	}{
		{
			name:           "Rain and thunderstorm emojis wrapping Thai text",
			input:          "🌧️⛈️🌧️ สภาพอากาศวันนี้เป็นอย่างไรบ้างครับ ⛈️🌧️⛈️",
			expectedIntent: IntentWeather,
		},
		{
			name:           "Water wave and flood emojis",
			input:          "🌊🌊🌊 จุดเสี่ยงน้ำท่วม 🌊🌊🌊",
			expectedIntent: IntentFlood,
		},
		{
			name:           "Calendar and clock emojis with Thai keyword",
			input:          "📅🕒 นัดหมาย 🕒📅",
			expectedIntent: IntentCalendar,
		},
		{
			name:           "Vehicles emojis with vehicle persona keyword",
			input:          "🚗🚙🏎️ ขับรถเก๋ง 🚗🚙🏎️",
			expectedIntent: IntentVehicleProfile,
		},
		{
			name:           "Only complex emojis with no matching text",
			input:          "🌧️⛈️🌊🚗🛵👨‍👩‍👧‍👦👍🏾🔥✨",
			expectedIntent: IntentUnknown,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			res := Route(tt.input)
			if res.Intent != tt.expectedIntent {
				t.Errorf("input %q: expected %s, got %s", tt.input, tt.expectedIntent, res.Intent)
			}
		})
	}
}

// TestAdversarial_ConflictingMultiIntentSentences stress tests compound sentences containing
// keywords from ALL intents simultaneously.
func TestAdversarial_ConflictingMultiIntentSentences(t *testing.T) {
	input := "วันนี้นัดหมายประชุมแถวอโศกแต่กลัวน้ำท่วมเลยจะขี่มอเตอร์ไซค์ไปดูสภาพอากาศ"

	res := Route(input)

	// In this compound sentence:
	// - Calendar matches: "นัดหมาย", "ประชุม", "นัด"
	// - Flood matches: "น้ำท่วม", "ท่วม"
	// - Weather matches: "สภาพอากาศ", "อากาศ"
	// - Vehicle matches: "มอเตอร์ไซค์", "มอไซค์"
	// - Landmark matches: "อโศก"
	if !res.Intent.IsRecognized() {
		t.Fatalf("expected recognized intent, got %s", res.Intent)
	}
	if !res.SecondaryIntent.IsRecognized() {
		t.Fatalf("expected recognized secondary intent, got %s", res.SecondaryIntent)
	}
	if res.Entities["location"] != "อโศก" {
		t.Errorf("expected location entity 'อโศก', got %q", res.Entities["location"])
	}
	mode, ok := res.VehicleMode()
	if !ok || mode != VehicleModeMotorcycle {
		t.Errorf("expected vehicle mode motorcycle, got %s (ok=%v)", mode, ok)
	}
	if res.Confidence < 0.80 || res.Confidence > 1.0 {
		t.Errorf("expected valid confidence in [0.80, 1.0], got %f", res.Confidence)
	}
}

// TestAdversarial_HugePayloadsStress tests router performance and resilience on oversized strings (up to 500KB).
func TestAdversarial_HugePayloadsStress(t *testing.T) {
	// 1. Pathological 100KB repeating string without keywords
	hugeNoise := strings.Repeat("สวัสดีครับคุณสบายดีไหมวันนี้ไปเที่ยวไหนดีนะ", 2500) // ~100KB
	start := time.Now()
	res := Route(hugeNoise)
	elapsed := time.Since(start)
	if res.Intent != IntentUnknown {
		t.Errorf("expected IntentUnknown for noise, got %s", res.Intent)
	}
	if elapsed > 100*time.Millisecond {
		t.Errorf("processing 100KB noise took too long: %v", elapsed)
	}

	// 2. 100KB noise with weather keyword embedded at the very end
	hugeWithKeyword := hugeNoise + " สภาพอากาศเป็นอย่างไร"
	start = time.Now()
	res = Route(hugeWithKeyword)
	elapsed = time.Since(start)
	if res.Intent != IntentWeather {
		t.Errorf("expected IntentWeather for keyword at end, got %s", res.Intent)
	}
	if elapsed > 100*time.Millisecond {
		t.Errorf("processing 100KB with keyword took too long: %v", elapsed)
	}

	// 3. String of 1,000 zero-width spaces
	allZeroWidth := strings.Repeat("\u200B\u200C\u200D\uFEFF", 500)
	res = Route(allZeroWidth)
	if res.Intent != IntentUnknown {
		t.Errorf("expected IntentUnknown for pure zero-width string, got %s", res.Intent)
	}

	// 4. Control characters (ASCII 0-31)
	var ctrlChars strings.Builder
	for i := 0; i < 32; i++ {
		ctrlChars.WriteByte(byte(i))
	}
	ctrlChars.WriteString("น้ำท่วม")
	res = Route(ctrlChars.String())
	if res.Intent != IntentFlood {
		t.Errorf("expected IntentFlood despite control chars, got %s", res.Intent)
	}
}

// TestAdversarial_HighConcurrencyStress executes 1,000 queries concurrently across 50 goroutines.
func TestAdversarial_HighConcurrencyStress(t *testing.T) {
	inputs := []string{
		"สภาพอากาศวันนี้",
		"น้ำท่วมไหมแถวคลองแสนแสบ",
		"เช็คตารางนัดหมาย",
		"ผมใช้มอเตอร์ไซค์ครับ",
		"ขับรถเก๋งไปทำงาน",
		"วันนี้นัดหมายประชุมแถวอโศกแต่กลัวน้ำท่วม",
		"🌧️⛈️ ฝนตกหนักมาก 🌧️",
		strings.Repeat("น้ำท่วม", 50),
		"",
		"สวัสดีวันจันทร์",
	}

	var wg sync.WaitGroup
	numWorkers := 50
	queriesPerWorker := 50

	for w := 0; w < numWorkers; w++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()
			r := rand.New(rand.NewSource(time.Now().UnixNano() + int64(workerID)))
			for q := 0; q < queriesPerWorker; q++ {
				idx := r.Intn(len(inputs))
				res := Route(inputs[idx])
				_ = res.Confidence
				_ = res.Intent.String()
				_ = fmt.Sprintf("%v", res.Entities)
			}
		}(w)
	}

	wg.Wait()
}
