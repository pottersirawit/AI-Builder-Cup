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
	"sync/atomic"
	"testing"
	"time"

	"github.com/saransirichote/weather-resilience-gateway/internal/api"
	"github.com/saransirichote/weather-resilience-gateway/internal/config"
	"github.com/saransirichote/weather-resilience-gateway/internal/dispatcher"
	"github.com/saransirichote/weather-resilience-gateway/internal/line"
	"github.com/saransirichote/weather-resilience-gateway/internal/model"
	"github.com/saransirichote/weather-resilience-gateway/internal/nlp"
)

// trackingReadCloser wraps an io.Reader and tracks whether Close() was invoked
type trackingReadCloser struct {
	io.Reader
	closed int32
}

func (t *trackingReadCloser) Close() error {
	atomic.StoreInt32(&t.closed, 1)
	return nil
}

func (t *trackingReadCloser) IsClosed() bool {
	return atomic.LoadInt32(&t.closed) == 1
}

type roundTripperFunc func(*http.Request) (*http.Response, error)

func (f roundTripperFunc) RoundTrip(r *http.Request) (*http.Response, error) {
	return f(r)
}

// ============================================================================
// VECTOR 1: RESOURCE LEAK ANALYSIS (resp.Body.Close() on non-200 engine responses)
// ============================================================================

func TestAdversarial_ResourceLeak_ResponseBodyUnclosedOnEngineError(t *testing.T) {
	// Custom HTTP transport that tracks Body.Close()
	var trackers []*trackingReadCloser
	var mu sync.Mutex

	recordTracker := func(bodyStr string) *trackingReadCloser {
		tr := &trackingReadCloser{Reader: strings.NewReader(bodyStr)}
		mu.Lock()
		trackers = append(trackers, tr)
		mu.Unlock()
		return tr
	}

	mockEngineBaseURL := "http://mock-engine:8000"

	cfg := &config.Config{
		Port:              "8080",
		LineChannelSecret: "test-secret",
		EngineBaseURL:     mockEngineBaseURL,
		WorkerPoolSize:    2,
	}

	pool := dispatcher.NewWorkerPool(cfg, 100)
	server := api.NewServer(cfg, pool)
	mux := http.NewServeMux()
	server.RegisterRoutes(mux)

	// Custom RoundTripper to intercept and return mock responses directly in memory
	origTransport := http.DefaultTransport
	http.DefaultTransport = roundTripperFunc(func(req *http.Request) (*http.Response, error) {
		tracker := recordTracker(`{"error":"internal engine failure"}`)
		return &http.Response{
			StatusCode: http.StatusInternalServerError,
			Header:     http.Header{"Content-Type": []string{"application/json"}},
			Body:       tracker,
		}, nil
	})
	defer func() {
		http.DefaultTransport = origTransport
	}()

	endpoints := []struct {
		name   string
		method string
		path   string
		body   string
	}{
		{
			name:   "handleCalendarSyncAndEvaluate",
			method: http.MethodPost,
			path:   "/api/v1/calendar/sync_and_evaluate",
			body:   `{"user_id":"U1001"}`,
		},
		{
			name:   "handleCalendarAuthURL",
			method: http.MethodGet,
			path:   "/api/v1/calendar/auth/url?user_id=U1001",
		},
		{
			name:   "handleCalendarAuthStatus",
			method: http.MethodGet,
			path:   "/api/v1/calendar/auth/status?user_id=U1001",
		},
		{
			name:   "handleCalendarAuthDisconnect",
			method: http.MethodPost,
			path:   "/api/v1/calendar/auth/disconnect",
			body:   `{"user_id":"U1001"}`,
		},
		{
			name:   "handleCalendarEvents",
			method: http.MethodGet,
			path:   "/api/v1/calendar/events?user_id=U1001",
		},
	}

	for _, ep := range endpoints {
		t.Run(ep.name, func(t *testing.T) {
			mu.Lock()
			trackers = nil
			mu.Unlock()

			var bodyReader io.Reader
			if ep.body != "" {
				bodyReader = strings.NewReader(ep.body)
			}
			req := httptest.NewRequest(ep.method, ep.path, bodyReader)
			if ep.body != "" {
				req.Header.Set("Content-Type", "application/json")
			}
			rec := httptest.NewRecorder()
			mux.ServeHTTP(rec, req)

			mu.Lock()
			currentTrackers := make([]*trackingReadCloser, len(trackers))
			copy(currentTrackers, trackers)
			mu.Unlock()

			if len(currentTrackers) == 0 {
				t.Fatalf("[%s] No HTTP request was intercepted", ep.name)
			}

			for idx, tr := range currentTrackers {
				if !tr.IsClosed() {
					t.Logf("EMPIRICAL PROOF OF DEFECT: [%s] tracker #%d was NOT closed! Response body is leaked when engine returns non-200 status code", ep.name, idx)
				}
			}
		})
	}
}

// ============================================================================
// VECTOR 2: WORKER POOL SHUTDOWN SEQUENCING & CHANNEL CLOSING PANICS
// ============================================================================

func TestAdversarial_WorkerPool_ShutdownSequencingAndPanicSafety(t *testing.T) {
	t.Run("Enqueue or EnqueueReply after Stop() causes panic", func(t *testing.T) {
		cfg := &config.Config{
			WorkerPoolSize:  2,
			LIFFEndpointURL: "https://liff.line.me/test",
		}
		wp := dispatcher.NewWorkerPool(cfg, 10)
		wp.Start()
		wp.Stop()

		// Attempting EnqueueReply on a stopped pool
		var panickedReply bool
		func() {
			defer func() {
				if r := recover(); r != nil {
					panickedReply = true
				}
			}()
			wp.EnqueueReply(dispatcher.ReplyJob{ReplyToken: "tok", UserID: "U1"})
		}()

		if panickedReply {
			t.Logf("EMPIRICAL PROOF OF DEFECT: EnqueueReply panics on closed channel if called after Stop()")
		}

		// Attempting Enqueue on a stopped pool
		var panickedAlert bool
		func() {
			defer func() {
				if r := recover(); r != nil {
					panickedAlert = true
				}
			}()
			wp.Enqueue(model.AlertDispatchJob{UserID: "U1"})
		}()

		if panickedAlert {
			t.Logf("EMPIRICAL PROOF OF DEFECT: Enqueue panics on closed channel if called after Stop()")
		}
	})

	t.Run("Calling Stop() twice panics with close of closed channel", func(t *testing.T) {
		cfg := &config.Config{
			WorkerPoolSize:  1,
			LIFFEndpointURL: "https://liff.line.me/test",
		}
		wp := dispatcher.NewWorkerPool(cfg, 10)
		wp.Start()
		wp.Stop()

		var doubleStopPanicked bool
		func() {
			defer func() {
				if r := recover(); r != nil {
					doubleStopPanicked = true
				}
			}()
			wp.Stop()
		}()

		if doubleStopPanicked {
			t.Logf("EMPIRICAL PROOF OF DEFECT: Calling Stop() twice panics because quitChan / jobsChan close is not idempotent (missing sync.Once)")
		}
	})
}

// ============================================================================
// VECTOR 3: FLEX MESSAGE BUILDER URI ENCODING ON DEEP-LINK CTA BUTTONS
// ============================================================================

func TestAdversarial_FlexBuilder_DeepLinkURIEncoding(t *testing.T) {
	tests := []struct {
		name        string
		vehicleType string
		extraParams string
	}{
		{
			name:        "Vehicle with spaces (compact sedan)",
			vehicleType: "compact sedan",
		},
		{
			name:        "Vehicle with Thai characters",
			vehicleType: "รถเก๋ง",
		},
		{
			name:        "Vehicle with ampersand and spaces",
			vehicleType: "sedan & suv",
		},
		{
			name:        "ExtraParams with unencoded space or Thai",
			vehicleType: "motorcycle",
			extraParams: "landmark=อโศก มนตรี",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			adv := model.AdvisoryPayload{
				Title:          "ทดสอบ URL Encoding",
				UrgencyLevel:   "CRITICAL",
				VehicleType:    tt.vehicleType,
				ExtraParams:    tt.extraParams,
				LIFFURL:        "https://liff.line.me/weather-app",
				TabDestination: "dashboard",
			}

			bubble := line.BuildFlexMessageBubble(adv)
			footer, ok := bubble["footer"].(map[string]interface{})
			if !ok {
				t.Fatalf("missing footer block")
			}
			contents, ok := footer["contents"].([]map[string]interface{})
			if !ok || len(contents) == 0 {
				t.Fatalf("missing footer contents")
			}

			btnAction, _ := contents[0]["action"].(map[string]interface{})
			uriStr, _ := btnAction["uri"].(string)

			// Check URI validity
			parsedURL, err := url.ParseRequestURI(uriStr)
			if err != nil {
				t.Logf("EMPIRICAL PROOF OF DEFECT: Deep-link URI %q is INVALID RFC 3986 URI: %v. LINE API will reject this Flex Message with 400 Bad Request!", uriStr, err)
			} else if strings.Contains(uriStr, " ") {
				t.Logf("EMPIRICAL PROOF OF DEFECT: Deep-link URI %q contains raw unencoded spaces!", uriStr)
			} else {
				_ = parsedURL
			}
		})
	}
}

// ============================================================================
// VECTOR 4: THAI NLP ROUTER UNICODE EDGE CASES & INVISIBLE CHARACTERS
// ============================================================================

func TestAdversarial_NLPRouter_InvisibleUnicodeEvasion(t *testing.T) {
	// The current cleanInput only strips \u200B, \u200C, \u200D, \uFEFF.
	// Common invisible formatting marks in Unicode:
	// - \u200E: Left-to-Right Mark (LRM)
	// - \u200F: Right-to-Left Mark (RLM)
	// - \u2060: Word Joiner (WJ)

	evasionTests := []struct {
		name           string
		input          string
		expectedIntent nlp.Intent
	}{
		{
			name:           "Left-to-Right Mark (\\u200E) embedded in สภาพอากาศ",
			input:          "สภา\u200Eพอากาศ",
			expectedIntent: nlp.IntentWeather,
		},
		{
			name:           "Right-to-Left Mark (\\u200F) embedded in น้ำท่วม",
			input:          "น้ำ\u200Fท่วม",
			expectedIntent: nlp.IntentFlood,
		},
		{
			name:           "Word Joiner (\\u2060) embedded in ปฏิทิน",
			input:          "ปฏิ\u2060ทิน",
			expectedIntent: nlp.IntentCalendar,
		},
		{
			name:           "Word Joiner (\\u2060) embedded in มอเตอร์ไซค์",
			input:          "มอเตอร์\u2060ไซค์",
			expectedIntent: nlp.IntentVehicleProfile,
		},
	}

	for _, tt := range evasionTests {
		t.Run(tt.name, func(t *testing.T) {
			res := nlp.Route(tt.input)
			if res.Intent != tt.expectedIntent {
				t.Logf("EMPIRICAL PROOF OF GAP: input %q with invisible unicode returned %s, expected %s. Router cleanInput does not sanitize Unicode Word Joiner (\\u2060) or directional markers.",
					tt.input, res.Intent, tt.expectedIntent)
			}
		})
	}
}

// ============================================================================
// VECTOR 5: WEBHOOK REPLAY ATTACK VULNERABILITY
// ============================================================================

func TestAdversarial_Webhook_ReplayAttacksWithOldTimestamps(t *testing.T) {
	const secret = "test-secret"
	cfg := &config.Config{
		Port:              "8080",
		LineChannelSecret: secret,
		WorkerPoolSize:    2,
	}
	pool := dispatcher.NewWorkerPool(cfg, 100)
	server := api.NewServer(cfg, pool)
	mux := http.NewServeMux()
	server.RegisterRoutes(mux)

	// An event with a timestamp from 24 hours ago
	oldTimestampMs := time.Now().Add(-24 * time.Hour).UnixMilli()
	oldPayload := []byte(fmt.Sprintf(`{"destination":"U123","events":[{"type":"message","timestamp":%d,"source":{"type":"user","userId":"U1001"},"replyToken":"rTok","message":{"id":"m1","type":"text","text":"สภาพอากาศ"}}]`, oldTimestampMs))

	sig := generateSignature(secret, oldPayload)
	req := httptest.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(oldPayload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Line-Signature", sig)

	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code == http.StatusOK {
		t.Logf("EMPIRICAL PROOF OF GAP: Webhook endpoint accepted 24-hour-old replayed event with HTTP 200 OK. No timestamp freshness window is enforced.")
	}
}

// ============================================================================
// VECTOR 6: FLEX BUILDER UNBOUNDED PAYLOAD SIZE (LINE 10KB LIMIT BLOWUP)
// ============================================================================

func TestAdversarial_FlexBuilder_PayloadSizeLimits(t *testing.T) {
	longChecklist := make([]string, 40)
	for i := 0; i < 40; i++ {
		longChecklist[i] = fmt.Sprintf("รายการตรวจสอบความปลอดภัยข้อที่ %d: ตรวจเช็กระบบไฟส่องสว่าง แรงดันลมยาง แบตเตอรี่ และระบบปัดน้ำฝนก่อนออกเดินทาง", i+1)
	}

	adv := model.AdvisoryPayload{
		Title:            "เตือนภัยสภาพอากาศขั้นวิกฤต",
		UrgencyLevel:     "CRITICAL",
		SummaryText:      strings.Repeat("ตรวจพบกลุ่มฝนฟ้าคะนองขนาดใหญ่และรุนแรงมาก ", 10),
		ActionChecklist:  longChecklist,
		VehicleType:      "sedan",
		FloodDepthCm:     25.0,
		RainRate:         80.0,
		CanalRemainingCm: 5.0,
	}

	bubble := line.BuildFlexMessageBubble(adv)
	b, err := json.Marshal(bubble)
	if err != nil {
		t.Fatalf("failed to marshal bubble: %v", err)
	}

	sizeKB := float64(len(b)) / 1024.0
	t.Logf("Flex bubble payload size with 40 checklist items: %.2f KB (%d bytes)", sizeKB, len(b))

	const lineBubbleLimitKB = 10.0
	if sizeKB > lineBubbleLimitKB {
		t.Logf("EMPIRICAL PROOF OF GAP: Flex bubble size is %.2f KB, exceeding LINE platform limit of 10 KB! BuildFlexMessageBubble does not cap checklist items or text length.", sizeKB)
	}
}
