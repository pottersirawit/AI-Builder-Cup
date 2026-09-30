package api_test

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/saransirichote/weather-resilience-gateway/internal/api"
	"github.com/saransirichote/weather-resilience-gateway/internal/config"
	"github.com/saransirichote/weather-resilience-gateway/internal/dispatcher"
)

func generateSignature(secret string, body []byte) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	return base64.StdEncoding.EncodeToString(mac.Sum(nil))
}

func setupTestServer(t *testing.T, secret string) (*api.Server, *http.ServeMux) {
	t.Helper()
	cfg := &config.Config{
		Port:              "8080",
		LineChannelSecret: secret,
		WorkerPoolSize:    2,
	}
	pool := dispatcher.NewWorkerPool(cfg, 100)
	server := api.NewServer(cfg, pool)
	mux := http.NewServeMux()
	server.RegisterRoutes(mux)
	return server, mux
}

func TestLineWebhookHandler_TableDriven(t *testing.T) {
	const secret = "test-secret-line-channel-12345678"
	const wrongSecret = "wrong-secret-attacker-channel-9999"

	_, mux := setupTestServer(t, secret)

	validBody := []byte(`{"destination":"U1234567890abcdef","events":[{"type":"message","mode":"active","timestamp":1620000000000,"source":{"type":"user","userId":"U1001"},"replyToken":"token1","message":{"id":"m1","type":"text","text":"hello"}}]}`)
	thaiBody := []byte(`{"destination":"U1234567890abcdef","events":[{"type":"message","mode":"active","timestamp":1620000001000,"source":{"type":"user","userId":"U1002"},"replyToken":"tokenThai","message":{"id":"m2","type":"text","text":"สภาพอากาศ อโศกมนตรี น้ำท่วมขังหรือไม่ 🚗⛈️"}}]}`)
	emptyEventsBody := []byte(`{"destination":"U1234567890abcdef","events":[]}`)
	multiEventBody := []byte(`{"destination":"U1234567890abcdef","events":[{"type":"message","source":{"type":"user","userId":"U1"},"replyToken":"r1","message":{"id":"1","type":"text","text":"น้ำท่วม"}},{"type":"follow","source":{"type":"user","userId":"U2"},"replyToken":"r2"}]}`)
	malformedJSONBody := []byte(`{"destination": "broken", "events": [`)
	emptyBody := []byte(``)
	whitespaceBody := []byte("   \n\t  ")

	tests := []struct {
		name                 string
		method               string
		body                 []byte
		omitSignatureHeader  bool
		customSignature      string
		overrideSignSecret   string
		expectedStatus       int
		expectedBodyContains string
	}{
		{
			name:                 "Valid signature returns 200 OK",
			method:               http.MethodPost,
			body:                 validBody,
			expectedStatus:       http.StatusOK,
			expectedBodyContains: "OK",
		},
		{
			name:                 "UTF-8 Thai unicode payload with valid signature returns 200 OK",
			method:               http.MethodPost,
			body:                 thaiBody,
			expectedStatus:       http.StatusOK,
			expectedBodyContains: "OK",
		},
		{
			name:                 "Valid signature with empty events array (LINE verify ping) returns 200 OK",
			method:               http.MethodPost,
			body:                 emptyEventsBody,
			expectedStatus:       http.StatusOK,
			expectedBodyContains: "OK",
		},
		{
			name:                 "Multi-event batch with valid signature returns 200 OK",
			method:               http.MethodPost,
			body:                 multiEventBody,
			expectedStatus:       http.StatusOK,
			expectedBodyContains: "OK",
		},
		{
			name:                "Missing X-Line-Signature header returns 401 Unauthorized",
			method:              http.MethodPost,
			body:                validBody,
			omitSignatureHeader: true,
			expectedStatus:      http.StatusUnauthorized,
		},
		{
			name:            "Empty X-Line-Signature header returns 401 Unauthorized",
			method:          http.MethodPost,
			body:            validBody,
			customSignature: "",
			expectedStatus:  http.StatusUnauthorized,
		},
		{
			name:            "Invalid signature digest returns 401 Unauthorized",
			method:          http.MethodPost,
			body:            validBody,
			customSignature: "aW52YWxpZC1kaWdlc3QtZm9yLWxpbmU=",
			expectedStatus:  http.StatusUnauthorized,
		},
		{
			name:            "Malformed non-base64 signature returns 401 Unauthorized",
			method:          http.MethodPost,
			body:            validBody,
			customSignature: "!@#$not-base64%^&*",
			expectedStatus:  http.StatusUnauthorized,
		},
		{
			name:               "Signature signed with different secret returns 401 Unauthorized",
			method:             http.MethodPost,
			body:               validBody,
			overrideSignSecret: wrongSecret,
			expectedStatus:     http.StatusUnauthorized,
		},
		{
			name:           "Valid signature on empty body returns 400 Bad Request",
			method:         http.MethodPost,
			body:           emptyBody,
			expectedStatus: http.StatusBadRequest,
		},
		{
			name:           "Valid signature on whitespace-only body returns 400 Bad Request",
			method:         http.MethodPost,
			body:           whitespaceBody,
			expectedStatus: http.StatusBadRequest,
		},
		{
			name:           "Valid signature on malformed JSON body returns 400 Bad Request",
			method:         http.MethodPost,
			body:           malformedJSONBody,
			expectedStatus: http.StatusBadRequest,
		},
		{
			name:           "GET method returns 405 Method Not Allowed",
			method:         http.MethodGet,
			body:           nil,
			expectedStatus: http.StatusMethodNotAllowed,
		},
		{
			name:           "PUT method returns 405 Method Not Allowed",
			method:         http.MethodPut,
			body:           validBody,
			expectedStatus: http.StatusMethodNotAllowed,
		},
		{
			name:           "DELETE method returns 405 Method Not Allowed",
			method:         http.MethodDelete,
			body:           nil,
			expectedStatus: http.StatusMethodNotAllowed,
		},
		{
			name:           "PATCH method returns 405 Method Not Allowed",
			method:         http.MethodPatch,
			body:           validBody,
			expectedStatus: http.StatusMethodNotAllowed,
		},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(tc.method, "/webhook/line", bytes.NewReader(tc.body))
			req.Header.Set("Content-Type", "application/json; charset=UTF-8")

			if !tc.omitSignatureHeader {
				if tc.customSignature != "" || tc.name == "Empty X-Line-Signature header returns 401 Unauthorized" {
					req.Header.Set("X-Line-Signature", tc.customSignature)
				} else {
					signSecret := secret
					if tc.overrideSignSecret != "" {
						signSecret = tc.overrideSignSecret
					}
					sig := generateSignature(signSecret, tc.body)
					req.Header.Set("X-Line-Signature", sig)
				}
			}

			rec := httptest.NewRecorder()
			mux.ServeHTTP(rec, req)

			if rec.Code != tc.expectedStatus {
				t.Fatalf("expected HTTP status %d (%s), got %d (%s), response body: %s",
					tc.expectedStatus, http.StatusText(tc.expectedStatus),
					rec.Code, http.StatusText(rec.Code),
					rec.Body.String(),
				)
			}

			if tc.expectedBodyContains != "" && !strings.Contains(rec.Body.String(), tc.expectedBodyContains) {
				t.Errorf("expected response body to contain %q, got %q", tc.expectedBodyContains, rec.Body.String())
			}
		})
	}
}

func TestLineWebhookHandler_MaxBodyLimit(t *testing.T) {
	const secret = "test-secret-line-channel-12345678"
	_, mux := setupTestServer(t, secret)

	// Construct an oversized body (> 10MB)
	oversizedBody := make([]byte, 11*1024*1024)
	copy(oversizedBody, []byte(`{"destination":"U123","events":[`))
	oversizedBody[len(oversizedBody)-1] = ']'

	sig := generateSignature(secret, oversizedBody)
	req := httptest.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(oversizedBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Line-Signature", sig)

	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	// Should reject with status 400 Bad Request due to MaxBytesReader exceeding limit
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected HTTP 400 for payload > 10MB, got %d (%s)", rec.Code, http.StatusText(rec.Code))
	}
}

func TestLineWebhookHandler_ThaiIntentRoutingAndDispatch(t *testing.T) {
	const secret = "test-secret-line-channel-12345678"
	server, mux := setupTestServer(t, secret)
	pool := server.Dispatcher()
	mockReply := pool.ReplyClient()
	pool.Start()
	defer pool.Stop()

	// 1. Vehicle profile intent update test
	vehiclePayload := []byte(`{
		"destination": "U1234567890abcdef",
		"events": [
			{
				"type": "message",
				"source": {"type": "user", "userId": "U_TEST_VEHICLE"},
				"replyToken": "token_vehicle",
				"message": {"id": "m1", "type": "text", "text": "ฉันเปลี่ยนมาขับ มอเตอร์ไซค์ แล้วนะ"}
			}
		]
	}`)

	sig := generateSignature(secret, vehiclePayload)
	req := httptest.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(vehiclePayload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Line-Signature", sig)

	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected HTTP 200, got %d", rec.Code)
	}

	// Wait briefly for asynchronous goroutine processing
	time.Sleep(100 * time.Millisecond)

	// Verify profile persistence in server.users
	u, ok := server.GetUserProfile("U_TEST_VEHICLE")
	if !ok {
		t.Fatalf("expected user U_TEST_VEHICLE to exist in session")
	}
	if u.TransportMode != "motorcycle" {
		t.Fatalf("expected TransportMode 'motorcycle', got %q", u.TransportMode)
	}

	// 2. Weather & Flood batch queries
	batchPayload := []byte(`{
		"destination": "U1234567890abcdef",
		"events": [
			{
				"type": "message",
				"source": {"type": "user", "userId": "U_TEST_VEHICLE"},
				"replyToken": "token_weather",
				"message": {"id": "m2", "type": "text", "text": "ขอตรวจสอบสภาพอากาศวันนี้หน่อยครับ"}
			},
			{
				"type": "message",
				"source": {"type": "user", "userId": "U1001"},
				"replyToken": "token_flood",
				"message": {"id": "m3", "type": "text", "text": "ตอนนี้มีจุดเสี่ยงน้ำท่วมและระดับคลองเป็นอย่างไร"}
			},
			{
				"type": "message",
				"source": {"type": "user", "userId": "U1001"},
				"replyToken": "token_calendar",
				"message": {"id": "m4", "type": "text", "text": "วันนี้มีนัดหมายประชุม"}
			}
		]
	}`)

	sigBatch := generateSignature(secret, batchPayload)
	reqBatch := httptest.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(batchPayload))
	reqBatch.Header.Set("Content-Type", "application/json")
	reqBatch.Header.Set("X-Line-Signature", sigBatch)

	recBatch := httptest.NewRecorder()
	mux.ServeHTTP(recBatch, reqBatch)

	if recBatch.Code != http.StatusOK {
		t.Fatalf("expected HTTP 200 for batch, got %d", recBatch.Code)
	}

	time.Sleep(150 * time.Millisecond)

	replies := mockReply.GetRecordedReplies()
	if len(replies) < 4 {
		t.Fatalf("expected at least 4 recorded replies, got %d", len(replies))
	}
}

func TestLiffStaticServingAndContract(t *testing.T) {
	_, mux := setupTestServer(t, "test-secret")

	tests := []struct {
		name                 string
		targetURL            string
		expectedStatus       int
		expectedBodyContains []string
	}{
		{
			name:           "Serve LIFF root index",
			targetURL:      "/liff/",
			expectedStatus: http.StatusOK,
			expectedBodyContains: []string{
				"Bangkok Weather Resilience - LINE LIFF",
				`id="tab-dashboard"`,
				`id="tab-calendar"`,
				`id="tab-profile"`,
				`id="badge-vehicle"`,
				`id="card-hazard"`,
				`parseLIFFParams`,
				`syncLIFFParameters`,
				`liff.state`,
				`hazard-pulse-highlight`,
			},
		},
		{
			name:           "Serve LIFF with query parameters",
			targetURL:      "/liff/?tab=calendar&vehicle=moto&focus=hazard",
			expectedStatus: http.StatusOK,
			expectedBodyContains: []string{
				`id="tab-calendar"`,
				`id="btn-v-moto"`,
				`focusHazardCard`,
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, tc.targetURL, nil)
			rec := httptest.NewRecorder()
			mux.ServeHTTP(rec, req)

			if rec.Code != tc.expectedStatus {
				t.Fatalf("expected HTTP status %d, got %d", tc.expectedStatus, rec.Code)
			}

			body := rec.Body.String()
			for _, expected := range tc.expectedBodyContains {
				if !strings.Contains(body, expected) {
					t.Errorf("expected response body to contain %q", expected)
				}
			}
		})
	}
}

func TestCalendarEndpoints(t *testing.T) {
	_, mux := setupTestServer(t, "test-secret")

	// 1. POST /api/v1/calendar/sync_and_evaluate returns 200 OK with valid JSON
	t.Run("POST /api/v1/calendar/sync_and_evaluate returns 200 OK", func(t *testing.T) {
		payload := []byte(`{"user_id":"U1001","name":"คุณสมชาย","transport_mode":"compact_sedan"}`)
		req := httptest.NewRequest(http.MethodPost, "/api/v1/calendar/sync_and_evaluate", bytes.NewReader(payload))
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected HTTP 200, got %d (body: %s)", rec.Code, rec.Body.String())
		}
		body := rec.Body.String()
		if !strings.Contains(body, "proactive_advisories") {
			t.Errorf("expected body to contain 'proactive_advisories', got: %s", body)
		}
		if !strings.Contains(body, "GCAL-EVT-001") {
			t.Errorf("expected body to contain 'GCAL-EVT-001', got: %s", body)
		}
	})

	// 2. GET /api/v1/calendar/sync_and_evaluate returns 405 Method Not Allowed
	t.Run("GET /api/v1/calendar/sync_and_evaluate returns 405", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/calendar/sync_and_evaluate", nil)
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusMethodNotAllowed {
			t.Fatalf("expected HTTP 405, got %d", rec.Code)
		}
	})

	// 3. GET /api/v1/calendar/auth/url returns 200 OK with auth_url
	t.Run("GET /api/v1/calendar/auth/url returns 200 OK", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/calendar/auth/url?user_id=U1001", nil)
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected HTTP 200, got %d", rec.Code)
		}
		body := rec.Body.String()
		if !strings.Contains(body, "auth_url") && !strings.Contains(body, "authorization_url") {
			t.Errorf("expected body to contain auth url, got: %s", body)
		}
	})

	// 4. GET /api/v1/calendar/auth/callback redirects to LIFF with auth=success
	t.Run("GET /api/v1/calendar/auth/callback redirects to LIFF", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/calendar/auth/callback?code=mock_code&state=mock_state", nil)
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusTemporaryRedirect {
			t.Fatalf("expected HTTP 307 redirect, got %d", rec.Code)
		}
		loc := rec.Header().Get("Location")
		if !strings.Contains(loc, "auth=success") || !strings.Contains(loc, "tab=calendar") {
			t.Errorf("expected redirect location with auth=success, got %q", loc)
		}
	})

	// 5. GET /api/v1/calendar/auth/status returns 200 OK
	t.Run("GET /api/v1/calendar/auth/status returns 200 OK", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/calendar/auth/status?user_id=U1001", nil)
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected HTTP 200, got %d", rec.Code)
		}
		body := rec.Body.String()
		if !strings.Contains(body, "is_connected") {
			t.Errorf("expected body to contain 'is_connected', got: %s", body)
		}
	})

	// 6. POST /api/v1/calendar/auth/disconnect returns 200 OK
	t.Run("POST /api/v1/calendar/auth/disconnect returns 200 OK", func(t *testing.T) {
		payload := []byte(`{"user_id":"U1001"}`)
		req := httptest.NewRequest(http.MethodPost, "/api/v1/calendar/auth/disconnect", bytes.NewReader(payload))
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected HTTP 200, got %d", rec.Code)
		}
		body := rec.Body.String()
		if !strings.Contains(body, "disconnected") {
			t.Errorf("expected body to contain 'disconnected', got: %s", body)
		}
	})

	// 7. GET /api/v1/calendar/events returns 200 OK
	t.Run("GET /api/v1/calendar/events returns 200 OK", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/calendar/events", nil)
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected HTTP 200, got %d", rec.Code)
		}
		body := rec.Body.String()
		if !strings.Contains(body, "events") {
			t.Errorf("expected body to contain 'events', got: %s", body)
		}
	})
}

func TestWebhook_TimestampFreshnessEnforcement(t *testing.T) {
	const secret = "test-secret-freshness-12345"
	_, mux := setupTestServer(t, secret)

	nowMs := time.Now().UnixMilli()
	oldMs := time.Now().Add(-15 * time.Minute).UnixMilli()
	futureMs := time.Now().Add(10 * time.Minute).UnixMilli()

	tests := []struct {
		name           string
		timestamp      int64
		expectedStatus int
	}{
		{
			name:           "Fresh event timestamp returns 200 OK",
			timestamp:      nowMs,
			expectedStatus: http.StatusOK,
		},
		{
			name:           "Stale timestamp (> 10 mins ago) returns 400 Bad Request",
			timestamp:      oldMs,
			expectedStatus: http.StatusBadRequest,
		},
		{
			name:           "Far-future timestamp (> 5 mins ahead) returns 400 Bad Request",
			timestamp:      futureMs,
			expectedStatus: http.StatusBadRequest,
		},
		{
			name:           "Zero timestamp passes without freshness error",
			timestamp:      0,
			expectedStatus: http.StatusOK,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			payload := []byte(fmt.Sprintf(`{"destination":"U123456","events":[{"type":"message","timestamp":%d,"source":{"type":"user","userId":"U1001"},"replyToken":"rTok","message":{"id":"m1","type":"text","text":"สวัสดี"}}]}`, tt.timestamp))
			sig := generateSignature(secret, payload)

			req := httptest.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(payload))
			req.Header.Set("Content-Type", "application/json")
			req.Header.Set("X-Line-Signature", sig)

			rec := httptest.NewRecorder()
			mux.ServeHTTP(rec, req)

			if rec.Code != tt.expectedStatus {
				t.Errorf("expected status %d, got %d (body: %s)", tt.expectedStatus, rec.Code, rec.Body.String())
			}
		})
	}
}



