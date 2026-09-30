package api_test

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"

	"github.com/saransirichote/weather-resilience-gateway/internal/line"
)

// infiniteOrLargeReader generates a synthetic stream exceeding size without allocating full RAM
type limitedChunkReader struct {
	totalBytes int64
	bytesRead  int64
	chunk      []byte
}

func newLimitedChunkReader(totalBytes int64) *limitedChunkReader {
	chunk := bytes.Repeat([]byte("A"), 64*1024) // 64KB repetitive chunk
	return &limitedChunkReader{
		totalBytes: totalBytes,
		chunk:      chunk,
	}
}

func (r *limitedChunkReader) Read(p []byte) (n int, err error) {
	if r.bytesRead >= r.totalBytes {
		return 0, io.EOF
	}
	remaining := r.totalBytes - r.bytesRead
	toRead := int64(len(p))
	if toRead > remaining {
		toRead = remaining
	}
	if toRead > int64(len(r.chunk)) {
		toRead = int64(len(r.chunk))
	}
	copy(p[:toRead], r.chunk[:toRead])
	r.bytesRead += toRead
	return int(toRead), nil
}

// TestAdversarial_CryptographicBoundaries tests malicious, corrupted, and boundary signatures
func TestAdversarial_CryptographicBoundaries(t *testing.T) {
	const secret = "adversarial-channel-secret-line-2026"
	_, mux := setupTestServer(t, secret)

	validPayload := []byte(`{"destination":"U123456","events":[{"type":"message","timestamp":1620000000000,"source":{"type":"user","userId":"U1001"},"replyToken":"rTok","message":{"id":"m1","type":"text","text":"ทดสอบ"}}]}`)
	validSig := generateSignature(secret, validPayload)

	// Decode validSig to manipulate bits
	rawSig, err := base64.StdEncoding.DecodeString(validSig)
	if err != nil {
		t.Fatalf("failed to decode validSig: %v", err)
	}

	// 1. Bit-flipped signature (1 bit difference in digest)
	bitFlippedRaw := make([]byte, len(rawSig))
	copy(bitFlippedRaw, rawSig)
	bitFlippedRaw[0] ^= 0x01
	bitFlippedSig := base64.StdEncoding.EncodeToString(bitFlippedRaw)

	// 2. Byte-flipped signature (last byte modified)
	byteFlippedRaw := make([]byte, len(rawSig))
	copy(byteFlippedRaw, rawSig)
	byteFlippedRaw[len(byteFlippedRaw)-1] ^= 0xFF
	byteFlippedSig := base64.StdEncoding.EncodeToString(byteFlippedRaw)

	adversarialCases := []struct {
		name           string
		signature      string
		expectedStatus int
	}{
		{
			name:           "Exact valid signature",
			signature:      validSig,
			expectedStatus: http.StatusOK,
		},
		{
			name:           "Bit-flipped 1-bit corrupted HMAC digest",
			signature:      bitFlippedSig,
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "Byte-flipped last-byte corrupted HMAC digest",
			signature:      byteFlippedSig,
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "Truncated signature (43 chars instead of 44)",
			signature:      validSig[:len(validSig)-1],
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "Truncated signature (10 chars)",
			signature:      validSig[:10],
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "Single character signature",
			signature:      "A",
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "Random base64 44-char digest",
			signature:      base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{0x42}, 32)),
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "Signature with internal space (tampering attempt)",
			signature:      validSig[:20] + " " + validSig[20:],
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "Signature with internal newline",
			signature:      validSig[:20] + "\n" + validSig[20:],
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "Signature with internal null byte",
			signature:      validSig[:20] + "\x00" + validSig[20:],
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "Valid signature with leading/trailing whitespace (should be accepted via TrimSpace)",
			signature:      "  \t " + validSig + " \r\n",
			expectedStatus: http.StatusOK,
		},
		{
			name:           "Malformed base64 non-ASCII characters",
			signature:      "🔥🌧️🚗🚨🛑",
			expectedStatus: http.StatusUnauthorized,
		},
		{
			name:           "Giant 64KB signature string (header attack)",
			signature:      strings.Repeat("A", 64*1024),
			expectedStatus: http.StatusUnauthorized,
		},
	}

	for _, tc := range adversarialCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(validPayload))
			req.Header.Set("Content-Type", "application/json")
			req.Header.Set("X-Line-Signature", tc.signature)

			rec := httptest.NewRecorder()
			mux.ServeHTTP(rec, req)

			if rec.Code != tc.expectedStatus {
				t.Fatalf("expected HTTP status %d (%s), got %d (%s)",
					tc.expectedStatus, http.StatusText(tc.expectedStatus),
					rec.Code, http.StatusText(rec.Code))
			}
		})
	}
}

// TestAdversarial_BodyBufferLimit tests body boundaries: <10MB, exactly 10MB, >10MB, and streaming 50MB
func TestAdversarial_BodyBufferLimit(t *testing.T) {
	const secret = "body-buffer-limit-secret"
	_, mux := setupTestServer(t, secret)

	const limit = 10 * 1024 * 1024 // 10MB

	t.Run("Payload just under limit (10MB - 1KB) passes size limit check", func(t *testing.T) {
		// Construct valid JSON of size ~ (10MB - 1KB)
		prefix := []byte(`{"destination":"U123","events":[],"padding":"`)
		suffix := []byte(`"}`)
		paddingLen := limit - 1024 - len(prefix) - len(suffix)
		body := make([]byte, 0, limit)
		body = append(body, prefix...)
		body = append(body, bytes.Repeat([]byte("X"), paddingLen)...)
		body = append(body, suffix...)

		sig := generateSignature(secret, body)
		req := httptest.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Line-Signature", sig)

		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusOK {
			t.Fatalf("expected 200 OK for payload under 10MB limit, got %d (%s)", rec.Code, http.StatusText(rec.Code))
		}
	})

	t.Run("Payload exceeding limit by 1 byte is rejected with 400", func(t *testing.T) {
		oversized := make([]byte, limit+1)
		copy(oversized, []byte(`{"destination":"U123","events":[`))
		oversized[len(oversized)-1] = ']'

		sig := generateSignature(secret, oversized)
		req := httptest.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(oversized))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Line-Signature", sig)

		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Fatalf("expected 400 Bad Request for payload 10MB+1 byte, got %d (%s)", rec.Code, http.StatusText(rec.Code))
		}
	})

	t.Run("Streaming 50MB payload is throttled and rejected at 10MB without OOM", func(t *testing.T) {
		// Use limitedChunkReader to stream 50MB without allocating 50MB in memory
		stream50MB := newLimitedChunkReader(50 * 1024 * 1024)

		req := httptest.NewRequest(http.MethodPost, "/webhook/line", stream50MB)
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Line-Signature", "arbitrary-signature-1234567890abcdef12345678==")

		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Fatalf("expected 400 Bad Request for 50MB streamed payload, got %d (%s)", rec.Code, http.StatusText(rec.Code))
		}

		// Verify reader didn't have to read all 50MB (it should have stopped shortly past 10MB)
		if stream50MB.bytesRead > 12*1024*1024 {
			t.Errorf("server read too many bytes (%d) instead of stopping near 10MB limit", stream50MB.bytesRead)
		}
	})
}

// TestAdversarial_MethodNotAllowed_AllVerbs checks all HTTP methods other than POST
func TestAdversarial_MethodNotAllowed_AllVerbs(t *testing.T) {
	const secret = "method-secret-line"
	_, mux := setupTestServer(t, secret)

	methods := []string{
		http.MethodGet,
		http.MethodHead,
		http.MethodPut,
		http.MethodDelete,
		http.MethodPatch,
		http.MethodOptions,
		http.MethodConnect,
		http.MethodTrace,
		"CUSTOM_VERB",
	}

	for _, method := range methods {
		t.Run("Method "+method+" returns 405 with Allow: POST", func(t *testing.T) {
			req := httptest.NewRequest(method, "/webhook/line", strings.NewReader(`{"test":true}`))
			req.Header.Set("X-Line-Signature", "some-sig")
			rec := httptest.NewRecorder()
			mux.ServeHTTP(rec, req)

			if rec.Code != http.StatusMethodNotAllowed {
				t.Fatalf("expected 405 Method Not Allowed for %s, got %d", method, rec.Code)
			}

			allowHeader := rec.Header().Get("Allow")
			if !strings.Contains(allowHeader, "POST") {
				t.Errorf("expected Allow header to contain 'POST', got %q", allowHeader)
			}
		})
	}
}

// TestAdversarial_ServerConfigurationBoundaries tests edge cases in server configuration
func TestAdversarial_ServerConfigurationBoundaries(t *testing.T) {
	t.Run("Server with empty LineChannelSecret rejects all incoming requests with 401", func(t *testing.T) {
		_, mux := setupTestServer(t, "") // empty secret!

		body := []byte(`{"destination":"U123","events":[]}`)
		// Even if client calculates HMAC with empty secret
		mac := hmac.New(sha256.New, []byte(""))
		mac.Write(body)
		emptySecretSig := base64.StdEncoding.EncodeToString(mac.Sum(nil))

		req := httptest.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Line-Signature", emptySecretSig)

		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Fatalf("expected 401 Unauthorized when server secret is empty, got %d", rec.Code)
		}
	})
}

// TestAdversarial_HighConcurrencyStress tests race condition safety under 500 concurrent requests
func TestAdversarial_HighConcurrencyStress(t *testing.T) {
	const secret = "concurrency-secret-line-12345"
	_, mux := setupTestServer(t, secret)

	validBody := []byte(`{"destination":"U1001","events":[{"type":"message","timestamp":1620000000000,"source":{"type":"user","userId":"U1001"},"replyToken":"rTok","message":{"id":"m1","type":"text","text":"สภาพอากาศ กรุงเทพ"}}]}`)
	validSig := generateSignature(secret, validBody)

	invalidBody := []byte(`{"destination":"U9999","events":[{"type":"message","text":"tampered"}]}`)

	const numWorkers = 50
	const requestsPerWorker = 10
	var wg sync.WaitGroup

	errChan := make(chan error, numWorkers*requestsPerWorker)

	startGate := make(chan struct{})

	for w := 0; w < numWorkers; w++ {
		workerID := w
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-startGate // Synchronized blast

			for r := 0; r < requestsPerWorker; r++ {
				var req *http.Request
				var wantStatus int

				if (workerID+r)%2 == 0 {
					// Valid request
					req = httptest.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(validBody))
					req.Header.Set("Content-Type", "application/json")
					req.Header.Set("X-Line-Signature", validSig)
					wantStatus = http.StatusOK
				} else {
					// Invalid request (tampered or wrong sig)
					req = httptest.NewRequest(http.MethodPost, "/webhook/line", bytes.NewReader(invalidBody))
					req.Header.Set("Content-Type", "application/json")
					req.Header.Set("X-Line-Signature", "wrong-signature-value-=================")
					wantStatus = http.StatusUnauthorized
				}

				rec := httptest.NewRecorder()
				mux.ServeHTTP(rec, req)

				if rec.Code != wantStatus {
					errChan <- fmt.Errorf("worker %d req %d expected %d got %d", workerID, r, wantStatus, rec.Code)
					return
				}
			}
		}()
	}

	// Release start gate to maximize concurrency
	close(startGate)
	wg.Wait()
	close(errChan)

	for err := range errChan {
		t.Errorf("concurrency error: %v", err)
	}
}

// TestAdversarial_LineDomainStructEdgeCases tests malformed or missing fields in LINE event structures
func TestAdversarial_LineDomainStructEdgeCases(t *testing.T) {
	t.Run("SenderID resolution precedence", func(t *testing.T) {
		// When UserID is present, it must take precedence over GroupID and RoomID
		srcAll := line.EventSource{Type: line.SourceTypeGroup, UserID: "U1", GroupID: "G1", RoomID: "R1"}
		if srcAll.SenderID() != "U1" {
			t.Errorf("expected UserID U1 to take precedence, got %q", srcAll.SenderID())
		}

		// When UserID is empty, GroupID takes precedence over RoomID
		srcGroupRoom := line.EventSource{Type: line.SourceTypeGroup, UserID: "", GroupID: "G1", RoomID: "R1"}
		if srcGroupRoom.SenderID() != "G1" {
			t.Errorf("expected GroupID G1 to take precedence, got %q", srcGroupRoom.SenderID())
		}

		// When UserID and GroupID are empty, RoomID is used
		srcRoom := line.EventSource{Type: line.SourceTypeRoom, UserID: "", GroupID: "", RoomID: "R1"}
		if srcRoom.SenderID() != "R1" {
			t.Errorf("expected RoomID R1, got %q", srcRoom.SenderID())
		}

		// All empty
		srcEmpty := line.EventSource{}
		if srcEmpty.SenderID() != "" {
			t.Errorf("expected empty string, got %q", srcEmpty.SenderID())
		}
	})

	t.Run("IsTextMessage and Text on nil Message or non-text Message", func(t *testing.T) {
		evNilMsg := line.WebhookEvent{Type: line.EventTypeMessage, Message: nil}
		if evNilMsg.IsTextMessage() {
			t.Errorf("expected IsTextMessage=false for nil Message")
		}
		if evNilMsg.Text() != "" {
			t.Errorf("expected empty Text() for nil Message, got %q", evNilMsg.Text())
		}

		evImage := line.WebhookEvent{
			Type:    line.EventTypeMessage,
			Message: &line.EventMessage{ID: "img1", Type: line.MessageTypeImage, Text: "ignored"},
		}
		if evImage.IsTextMessage() {
			t.Errorf("expected IsTextMessage=false for image message")
		}
		if evImage.Text() != "" {
			t.Errorf("expected empty Text() for image message, got %q", evImage.Text())
		}
	})

	t.Run("Time converts zero timestamp properly without crashing", func(t *testing.T) {
		evZero := line.WebhookEvent{Timestamp: 0}
		zeroTime := evZero.Time()
		if zeroTime.Unix() != 0 {
			t.Errorf("expected Unix epoch 0, got %v", zeroTime)
		}
	})
}
