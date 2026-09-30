package api_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"testing"
	"time"
	"unicode/utf8"

	"github.com/saransirichote/weather-resilience-gateway/internal/api"
	"github.com/saransirichote/weather-resilience-gateway/internal/config"
	"github.com/saransirichote/weather-resilience-gateway/internal/dispatcher"
)

type e2eMockTripper func(req *http.Request) (*http.Response, error)

func (m e2eMockTripper) RoundTrip(req *http.Request) (*http.Response, error) {
	return m(req)
}

// setupE2ETestServer spins up a fully integrated test server with active workers and mock reply client.
func setupE2ETestServer(t *testing.T, secret string) (*api.Server, *dispatcher.WorkerPool, *dispatcher.DefaultLineReplyClient, *http.ServeMux) {
	t.Helper()
	cfg := &config.Config{
		Port:              "8080",
		LineChannelSecret: secret,
		WorkerPoolSize:    4,
		LIFFEndpointURL:   "https://liff.line.me/weather-resilience-app",
	}

	mockReply := dispatcher.NewLineReplyClient("")
	pool := dispatcher.NewWorkerPool(cfg, 100)
	pool.SetReplyClient(mockReply)

	// Configure mock engine client conforming to exact Python Engine API response schemas
	tripper := e2eMockTripper(func(req *http.Request) (*http.Response, error) {
		switch {
		case strings.HasPrefix(req.URL.Path, "/api/v1/forecast"):
			body := `{"model":"WeatherNext 3 (Google DeepMind FGN 5km)","forecasts":[{"timestamp":"2026-09-25T17:00:00+07:00","temperature_c":31.0,"humidity_pct":80,"precipitation_rate_mm_hr":45.0,"precipitation_probability":0.95,"heat_index_c":38.0,"wind_speed_kmh":22.0,"wind_gust_kmh":58.0,"condition":"Heavy Rain"}]}`
			return &http.Response{StatusCode: 200, Header: http.Header{"Content-Type": []string{"application/json"}}, Body: io.NopCloser(bytes.NewReader([]byte(body)))}, nil
		case req.URL.Path == "/api/v1/canals":
			body := `{"canals":[{"station_id":"ASOKE","canal_name":"คลองแสนแสบ","location":"ประตูระบายน้ำวิทยุ-อโศก","water_level_m":1.65,"bank_height_m":1.75,"margin_to_overflow_m":0.10,"status":"CRITICAL"}]}`
			return &http.Response{StatusCode: 200, Header: http.Header{"Content-Type": []string{"application/json"}}, Body: io.NopCloser(bytes.NewReader([]byte(body)))}, nil
		case req.URL.Path == "/api/v1/radar":
			body := `{"max_reflectivity_dbz":55.0,"storm_cell_count":3,"timestamp":"2026-09-25T17:00:00+07:00"}`
			return &http.Response{StatusCode: 200, Header: http.Header{"Content-Type": []string{"application/json"}}, Body: io.NopCloser(bytes.NewReader([]byte(body)))}, nil
		case req.URL.Path == "/api/v1/calendar/sync_and_evaluate":
			body := `{"user_id":"U1","total_events_checked":2,"events_with_weather_hazards":1,"proactive_advisories":[{"event_id":"evt-1","event_title":"ประชุมที่สุขุมวิท","urgency":"WARNING","concern_type":"HEAVY_RAIN","advisory":{"headline":"ฝนตกหนักกระทบการเดินทาง","reasoning":"กลุ่มฝนเข้าช่วง 16:30 น.","proactive_recommendation":"แนะนำออกเดินทางเร็วขึ้น 30 นาที","departure_adjustment_mins":30,"recommended_action_type":"EARLY_DEPARTURE"}}]}`
			return &http.Response{StatusCode: 200, Header: http.Header{"Content-Type": []string{"application/json"}}, Body: io.NopCloser(bytes.NewReader([]byte(body)))}, nil
		default:
			return &http.Response{StatusCode: 404, Body: io.NopCloser(bytes.NewReader([]byte("not found")))}, nil
		}
	})

	ec := dispatcher.NewEngineClient("http://mock-engine:8000")
	ec.SetHTTPClient(&http.Client{Transport: tripper, Timeout: 2 * time.Second})
	pool.SetEngineClient(ec)

	pool.Start()

	server := api.NewServer(cfg, pool)
	mux := http.NewServeMux()
	server.RegisterRoutes(mux)

	return server, pool, mockReply, mux
}

func buildWebhookEventJSON(events []map[string]interface{}) []byte {
	payload := map[string]interface{}{
		"destination": "U1234567890abcdef",
		"events":      events,
	}
	b, _ := json.Marshal(payload)
	return b
}

func buildTextMessageEventMap(userID, text, replyToken string) map[string]interface{} {
	return map[string]interface{}{
		"type":           "message",
		"mode":           "active",
		"timestamp":      time.Now().UnixMilli(),
		"source":         map[string]interface{}{"type": "user", "userId": userID},
		"webhookEventId": fmt.Sprintf("evt_%d", time.Now().UnixNano()),
		"deliveryContext": map[string]interface{}{
			"isRedelivery": false,
		},
		"replyToken": replyToken,
		"message": map[string]interface{}{
			"id":   fmt.Sprintf("msg_%d", time.Now().UnixNano()),
			"type": "text",
			"text": text,
		},
	}
}

// TestE2E_SimulatedWebhook_ThaiRouting_And_FlexCardReply verifies end-to-end integration:
// 1. Simulated webhook requests route Thai queries properly.
// 2. Outbound replies are recorded with correct Theme 1 Apple Spatial Flex cards.
// 3. LIFF CTA buttons carry valid parseable URLs with appropriate tab and vehicle parameters.
func TestE2E_SimulatedWebhook_ThaiRouting_And_FlexCardReply(t *testing.T) {
	const secret = "test-e2e-secret-2026"
	server, pool, mockReply, mux := setupE2ETestServer(t, secret)
	defer pool.Stop()

	testScenarios := []struct {
		name               string
		userID             string
		queryText          string
		replyToken         string
		expectedTitleSub   string
		expectedUrgency    string
		expectedTab        string
		expectedVehicle    string
		expectedInCTA      string
		verifyProfileMode  string
	}{
		{
			name:              "Thai Weather Query ('สภาพอากาศ')",
			userID:            "U_TEST_WEATHER",
			queryText:         "ขอสอบถามสภาพอากาศและพยากรณ์ฝนหน่อยครับ",
			replyToken:        "tok_weather_001",
			expectedTitleSub:  "สภาพอากาศ",
			expectedUrgency:   "CRITICAL", // 45mm/h >= 35mm/h triggers CRITICAL
			expectedTab:       "dashboard",
			expectedVehicle:   "compact_sedan",
			expectedInCTA:     "tab=dashboard",
		},
		{
			name:              "Thai Flood & Canal Query ('น้ำท่วม', 'คลอง')",
			userID:            "U_TEST_FLOOD",
			queryText:         "ระดับน้ำคลองแสนแสบเป็นอย่างไร มีจุดเสี่ยงน้ำท่วมไหม",
			replyToken:        "tok_flood_002",
			expectedTitleSub:  "เตือนภัยน้ำท่วม",
			expectedUrgency:   "CRITICAL", // canal status CRITICAL & margin 10cm < 15cm
			expectedTab:       "dashboard",
			expectedVehicle:   "compact_sedan",
			expectedInCTA:     "focus=hazard",
		},
		{
			name:              "Thai Calendar Query ('นัดหมาย', 'ปฏิทิน')",
			userID:            "U_TEST_CALENDAR",
			queryText:         "วันนี้มีนัดหมายและตารางงานช่วงเย็น จะเจอฝนกระทบไหม",
			replyToken:        "tok_cal_003",
			expectedTitleSub:  "กำหนดการ",
			expectedUrgency:   "WARNING", // engine advisory WARNING
			expectedTab:       "calendar",
			expectedVehicle:   "compact_sedan",
			expectedInCTA:     "tab=calendar",
		},
		{
			name:              "Thai Vehicle Update ('มอเตอร์ไซค์')",
			userID:            "U_TEST_VEHICLE_MOTO",
			queryText:         "เปลี่ยนพาหนะเป็น มอเตอร์ไซค์",
			replyToken:        "tok_veh_004",
			expectedTitleSub:  "บันทึกพาหนะเรียบร้อยแล้ว",
			expectedUrgency:   "INFO",
			expectedTab:       "profile",
			expectedVehicle:   "motorcycle",
			expectedInCTA:     "tab=profile&vehicle=motorcycle",
			verifyProfileMode: "motorcycle",
		},
		{
			name:              "Thai Vehicle Update ('รถเก๋ง')",
			userID:            "U_TEST_VEHICLE_SEDAN",
			queryText:         "ผมขับ รถเก๋ง ครับ",
			replyToken:        "tok_veh_005",
			expectedTitleSub:  "บันทึกพาหนะเรียบร้อยแล้ว",
			expectedUrgency:   "INFO",
			expectedTab:       "profile",
			expectedVehicle:   "compact_sedan",
			expectedInCTA:     "tab=profile&vehicle=compact_sedan",
			verifyProfileMode: "compact_sedan",
		},
		{
			name:              "Thai Vehicle Update ('suv')",
			userID:            "U_TEST_VEHICLE_SUV",
			queryText:         "ใช้ SUV ยกสูง",
			replyToken:        "tok_veh_006",
			expectedTitleSub:  "บันทึกพาหนะเรียบร้อยแล้ว",
			expectedUrgency:   "INFO",
			expectedTab:       "profile",
			expectedVehicle:   "pickup",
			expectedInCTA:     "tab=profile&vehicle=pickup",
			verifyProfileMode: "pickup",
		},
		{
			name:              "Thai Vehicle Update ('bts')",
			userID:            "U_TEST_VEHICLE_BTS",
			queryText:         "เปลี่ยนเป็น BTS ครับ",
			replyToken:        "tok_veh_007",
			expectedTitleSub:  "บันทึกพาหนะเรียบร้อยแล้ว",
			expectedUrgency:   "INFO",
			expectedTab:       "profile",
			expectedVehicle:   "transit",
			expectedInCTA:     "tab=profile&vehicle=transit",
			verifyProfileMode: "transit",
		},
		{
			name:              "Compound Query ('เดินทางด้วย BTS รถไฟฟ้า')",
			userID:            "U_TEST_COMPOUND",
			queryText:         "เดินทางด้วย BTS รถไฟฟ้า",
			replyToken:        "tok_compound_008",
			expectedTitleSub:  "กำหนดการ",
			expectedUrgency:   "WARNING",
			expectedTab:       "calendar",
			expectedVehicle:   "transit",
			expectedInCTA:     "tab=calendar",
			verifyProfileMode: "transit",
		},
		{
			name:              "Unknown / Greeting Query ('สวัสดี')",
			userID:            "U_TEST_UNKNOWN",
			queryText:         "สวัสดีครับ ขอบคุณมาก",
			replyToken:        "tok_unknown_009",
			expectedTitleSub:  "ศูนย์ข้อมูลสภาพอากาศ",
			expectedUrgency:   "INFO",
			expectedTab:       "dashboard",
			expectedVehicle:   "compact_sedan",
			expectedInCTA:     "tab=dashboard",
		},
	}

	for _, sc := range testScenarios {
		t.Run(sc.name, func(t *testing.T) {
			mockReply.ClearRecorded()

			event := buildTextMessageEventMap(sc.userID, sc.queryText, sc.replyToken)
			body := buildWebhookEventJSON([]map[string]interface{}{event})
			sig := generateSignature(secret, body)

			req, err := http.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(body))
			if err != nil {
				t.Fatalf("failed to create request: %v", err)
			}
			req.Header.Set("Content-Type", "application/json")
			req.Header.Set("X-Line-Signature", sig)

			rec := httptest.NewRecorder()
			mux.ServeHTTP(rec, req)

			if rec.Code != http.StatusOK {
				t.Fatalf("expected HTTP 200, got %d: %s", rec.Code, rec.Body.String())
			}

			// Wait for worker pool to process the asynchronous reply job
			var recorded *dispatcher.RecordedReply
			for i := 0; i < 40; i++ {
				time.Sleep(25 * time.Millisecond)
				r := mockReply.GetLastReply()
				if r != nil && r.ReplyToken == sc.replyToken {
					recorded = r
					break
				}
			}

			if recorded == nil {
				t.Fatalf("no outbound reply recorded for replyToken %s", sc.replyToken)
			}

			// 1. Verify Message Envelope
			if len(recorded.Messages) == 0 {
				t.Fatalf("recorded reply has 0 messages")
			}
			msg := recorded.Messages[0]
			if msg["type"] != "flex" {
				t.Fatalf("expected message type 'flex', got '%v'", msg["type"])
			}

			altText, _ := msg["altText"].(string)
			if !strings.Contains(altText, sc.expectedUrgency) {
				t.Errorf("expected altText to contain urgency '%s', got '%s'", sc.expectedUrgency, altText)
			}

			// 2. Verify Theme 1 Apple Spatial Flex Bubble Structure
			contents, ok := msg["contents"].(map[string]interface{})
			if !ok {
				t.Fatalf("contents is not a map: %v", msg["contents"])
			}
			if contents["type"] != "bubble" {
				t.Errorf("expected contents type 'bubble', got '%v'", contents["type"])
			}

			// Verify Dark Frosted Palette
			styles, ok := contents["styles"].(map[string]interface{})
			if !ok {
				t.Fatalf("missing styles block in bubble")
			}
			bodyStyle, _ := styles["body"].(map[string]interface{})
			if bodyStyle["backgroundColor"] != "#0B132B" {
				t.Errorf("expected body backgroundColor #0B132B, got %v", bodyStyle["backgroundColor"])
			}
			headerStyle, _ := styles["header"].(map[string]interface{})
			if headerStyle["backgroundColor"] != "#091122" {
				t.Errorf("expected header backgroundColor #091122, got %v", headerStyle["backgroundColor"])
			}

			// 3. Verify Footer CTA Buttons and Valid URI Formats
			footer, ok := contents["footer"].(map[string]interface{})
			if !ok {
				t.Fatalf("missing footer block in bubble")
			}
			footerContents, ok := footer["contents"].([]map[string]interface{})
			if !ok || len(footerContents) < 2 {
				t.Fatalf("expected at least 2 CTA buttons in footer, got %d", len(footerContents))
			}

			primaryButton := footerContents[0]
			primaryAction, _ := primaryButton["action"].(map[string]interface{})
			primaryURI, _ := primaryAction["uri"].(string)
			if primaryURI == "" {
				t.Fatalf("primary button URI is empty")
			}

			// Parse and validate primary URI
			parsedPrimary, err := url.ParseRequestURI(primaryURI)
			if err != nil {
				t.Fatalf("primary button URI '%s' is not a valid URI: %v", primaryURI, err)
			}
			if parsedPrimary.Scheme != "https" {
				t.Errorf("expected https scheme for LIFF, got '%s'", parsedPrimary.Scheme)
			}
			q := parsedPrimary.Query()
			tabVal := q.Get("tab")
			if tabVal != sc.expectedTab {
				t.Errorf("expected tab='%s' in primary CTA, got '%s' (URI: %s)", sc.expectedTab, tabVal, primaryURI)
			}
			if !strings.Contains(primaryURI, sc.expectedInCTA) {
				t.Errorf("expected primary URI to contain '%s', got '%s'", sc.expectedInCTA, primaryURI)
			}

			secondaryButton := footerContents[1]
			secondaryAction, _ := secondaryButton["action"].(map[string]interface{})
			secondaryURI, _ := secondaryAction["uri"].(string)
			if secondaryURI == "" {
				t.Fatalf("secondary button URI is empty")
			}
			parsedSec, err := url.ParseRequestURI(secondaryURI)
			if err != nil {
				t.Fatalf("secondary button URI '%s' is not a valid URI: %v", secondaryURI, err)
			}
			if parsedSec.Query().Get("tab") != "calendar" {
				t.Errorf("expected secondary CTA tab=calendar, got '%s'", parsedSec.Query().Get("tab"))
			}

			// 4. Verify Quick Reply Compliance (<= 13 items, <= 20 runes each)
			qr, ok := msg["quickReply"].(map[string]interface{})
			if !ok {
				t.Fatalf("quickReply block missing")
			}
			items, ok := qr["items"].([]map[string]interface{})
			if !ok {
				t.Fatalf("quickReply items not a list")
			}
			if len(items) > 13 {
				t.Errorf("quickReply items count %d exceeds LINE limit of 13", len(items))
			}
			for idx, item := range items {
				action, _ := item["action"].(map[string]interface{})
				label, _ := action["label"].(string)
				runeCount := utf8.RuneCountInString(label)
				if runeCount > 20 {
					t.Errorf("quickReply item %d label '%s' has %d runes, exceeds 20 rune limit", idx, label, runeCount)
				}
			}

			// 5. Verify User Profile Mode persistence if updated
			if sc.verifyProfileMode != "" {
				user, exists := server.GetUserProfile(sc.userID)
				if !exists {
					t.Errorf("expected user profile for %s to exist in session", sc.userID)
				} else if user.TransportMode != sc.verifyProfileMode {
					t.Errorf("expected user transportMode to be '%s', got '%s'", sc.verifyProfileMode, user.TransportMode)
				}
			}
		})
	}
}

// TestE2E_HighVolumeBatch_And_ConcurrencyStress stress tests the system under burst workloads:
// 1. Sends a batch of 25 simultaneous events in a single HTTP POST request.
// 2. Concurrently sends 20 separate webhook HTTP POST requests from parallel goroutines.
// 3. Confirms that all events are parsed, dispatched, and produce valid Apple Spatial replies without races.
func TestE2E_HighVolumeBatch_And_ConcurrencyStress(t *testing.T) {
	const secret = "burst-stress-secret-2026"
	_, pool, mockReply, mux := setupE2ETestServer(t, secret)
	defer pool.Stop()

	// 1. Batch Payload Test: 25 events in one request
	t.Run("Batch25Events_SingleWebhookRequest", func(t *testing.T) {
		mockReply.ClearRecorded()
		const eventCount = 25
		events := make([]map[string]interface{}, eventCount)
		for i := 0; i < eventCount; i++ {
			token := fmt.Sprintf("batch_token_%d", i)
			var query string
			switch i % 4 {
			case 0:
				query = "สภาพอากาศ"
			case 1:
				query = "น้ำท่วม"
			case 2:
				query = "นัดหมาย"
			case 3:
				query = "มอเตอร์ไซค์"
			}
			events[i] = buildTextMessageEventMap(fmt.Sprintf("U_BATCH_%d", i), query, token)
		}

		body := buildWebhookEventJSON(events)
		sig := generateSignature(secret, body)

		req, err := http.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(body))
		if err != nil {
			t.Fatalf("failed to create batch request: %v", err)
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Line-Signature", sig)

		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected HTTP 200, got %d: %s", rec.Code, rec.Body.String())
		}

		// Wait for all 25 replies to be processed
		deadline := time.Now().Add(3 * time.Second)
		for time.Now().Before(deadline) {
			if len(mockReply.GetRecordedReplies()) >= eventCount {
				break
			}
			time.Sleep(30 * time.Millisecond)
		}

		recorded := mockReply.GetRecordedReplies()
		if len(recorded) < eventCount {
			t.Fatalf("expected %d recorded replies, got %d", eventCount, len(recorded))
		}

		for _, recItem := range recorded {
			if len(recItem.Messages) == 0 {
				t.Fatalf("reply token %s recorded empty messages", recItem.ReplyToken)
			}
			msg := recItem.Messages[0]
			if msg["type"] != "flex" {
				t.Fatalf("expected flex message, got %v", msg["type"])
			}
		}
	})

	// 2. Parallel Requests: 20 separate goroutines firing simultaneously
	t.Run("Concurrent20WebhookRequests", func(t *testing.T) {
		mockReply.ClearRecorded()
		const concurrentClients = 20
		var wg sync.WaitGroup
		errChan := make(chan error, concurrentClients)

		for i := 0; i < concurrentClients; i++ {
			wg.Add(1)
			go func(idx int) {
				defer wg.Done()
				token := fmt.Sprintf("concurrent_token_%d", idx)
				event := buildTextMessageEventMap(fmt.Sprintf("U_CONCURRENT_%d", idx), "เช็กสภาพอากาศ", token)
				b := buildWebhookEventJSON([]map[string]interface{}{event})
				s := generateSignature(secret, b)

				r, err := http.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(b))
				if err != nil {
					errChan <- fmt.Errorf("client %d create req error: %w", idx, err)
					return
				}
				r.Header.Set("Content-Type", "application/json")
				r.Header.Set("X-Line-Signature", s)

				rec := httptest.NewRecorder()
				mux.ServeHTTP(rec, r)

				if rec.Code != http.StatusOK {
					errChan <- fmt.Errorf("client %d status code %d", idx, rec.Code)
				}
			}(i)
		}

		wg.Wait()
		close(errChan)

		for err := range errChan {
			t.Fatalf("concurrent request error: %v", err)
		}

		// Wait for replies
		deadline := time.Now().Add(3 * time.Second)
		for time.Now().Before(deadline) {
			if len(mockReply.GetRecordedReplies()) >= concurrentClients {
				break
			}
			time.Sleep(30 * time.Millisecond)
		}

		recorded := mockReply.GetRecordedReplies()
		if len(recorded) < concurrentClients {
			t.Fatalf("expected %d recorded replies, got %d", concurrentClients, len(recorded))
		}
	})
}
