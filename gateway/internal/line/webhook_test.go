package line_test

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"testing"

	"github.com/saransirichote/weather-resilience-gateway/internal/line"
)

func calcTestSignature(secret string, body []byte) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(body)
	return base64.StdEncoding.EncodeToString(mac.Sum(nil))
}

func TestValidateSignature(t *testing.T) {
	const secret = "test-channel-secret-abc123xyz"
	const wrongSecret = "wrong-channel-secret-diff999"

	payload := []byte(`{"destination":"U12345","events":[]}`)
	thaiPayload := []byte(`{"message":"ฝนตกหนัก น้ำท่วม ถนนอโศกมนตรี 🚗⛈️"}`)

	tests := []struct {
		name      string
		secret    string
		signature string
		body      []byte
		wantValid bool
	}{
		{
			name:      "Valid signature matches body",
			secret:    secret,
			signature: calcTestSignature(secret, payload),
			body:      payload,
			wantValid: true,
		},
		{
			name:      "Valid signature matches Thai UTF-8 body",
			secret:    secret,
			signature: calcTestSignature(secret, thaiPayload),
			body:      thaiPayload,
			wantValid: true,
		},
		{
			name:      "Valid signature with surrounding whitespace passes",
			secret:    secret,
			signature: "  " + calcTestSignature(secret, payload) + "  \n",
			body:      payload,
			wantValid: true,
		},
		{
			name:      "Tampered body fails validation",
			secret:    secret,
			signature: calcTestSignature(secret, payload),
			body:      append(payload, ' '),
			wantValid: false,
		},
		{
			name:      "Signature signed with different secret fails",
			secret:    secret,
			signature: calcTestSignature(wrongSecret, payload),
			body:      payload,
			wantValid: false,
		},
		{
			name:      "Empty signature fails",
			secret:    secret,
			signature: "",
			body:      payload,
			wantValid: false,
		},
		{
			name:      "Whitespace only signature fails",
			secret:    secret,
			signature: "   ",
			body:      payload,
			wantValid: false,
		},
		{
			name:      "Empty secret fails even if signature matches empty key",
			secret:    "",
			signature: calcTestSignature("", payload),
			body:      payload,
			wantValid: false,
		},
		{
			name:      "Invalid base64 signature fails gracefully",
			secret:    secret,
			signature: "!@#$%^&*()_+",
			body:      payload,
			wantValid: false,
		},
		{
			name:      "Corrupted base64 length fails gracefully",
			secret:    secret,
			signature: "aW52YWxpZA==",
			body:      payload,
			wantValid: false,
		},
		{
			name:      "Valid signature on empty body matches",
			secret:    secret,
			signature: calcTestSignature(secret, []byte{}),
			body:      []byte{},
			wantValid: true,
		},
	}

	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			got := line.ValidateSignature(tc.secret, tc.signature, tc.body)
			if got != tc.wantValid {
				t.Errorf("ValidateSignature() = %v, want %v", got, tc.wantValid)
			}
		})
	}
}

func TestParseWebhook(t *testing.T) {
	const secret = "test-secret-line-1234"

	sampleJSON := []byte(`{
		"destination": "U1234567890abcdef1234567890abcdef",
		"events": [
			{
				"type": "message",
				"mode": "active",
				"timestamp": 1620000000000,
				"source": {
					"type": "user",
					"userId": "U1001"
				},
				"webhookEventId": "01FZ74A0TDDPYRVKNK77XKC3ZR",
				"deliveryContext": {
					"isRedelivery": false
				},
				"replyToken": "nHuyWiB7yP5Zw52FIkcQobQuGDXCTA",
				"message": {
					"id": "325708",
					"type": "text",
					"text": "สภาพอากาศ อโศกมนตรี"
				}
			}
		]
	}`)

	t.Run("Valid signature and payload parses all fields", func(t *testing.T) {
		sig := calcTestSignature(secret, sampleJSON)
		payload, err := line.ParseWebhook(secret, sig, sampleJSON)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		if payload.Destination != "U1234567890abcdef1234567890abcdef" {
			t.Errorf("expected destination %q, got %q", "U1234567890abcdef1234567890abcdef", payload.Destination)
		}
		if len(payload.Events) != 1 {
			t.Fatalf("expected 1 event, got %d", len(payload.Events))
		}

		ev := payload.Events[0]
		if ev.Type != line.EventTypeMessage {
			t.Errorf("expected type %q, got %q", line.EventTypeMessage, ev.Type)
		}
		if ev.ReplyToken != "nHuyWiB7yP5Zw52FIkcQobQuGDXCTA" {
			t.Errorf("expected replyToken %q, got %q", "nHuyWiB7yP5Zw52FIkcQobQuGDXCTA", ev.ReplyToken)
		}
		if ev.Source.Type != line.SourceTypeUser || ev.Source.UserID != "U1001" {
			t.Errorf("expected user U1001, got %+v", ev.Source)
		}
		if ev.Source.SenderID() != "U1001" {
			t.Errorf("expected SenderID U1001, got %q", ev.Source.SenderID())
		}
		if ev.WebhookEventID != "01FZ74A0TDDPYRVKNK77XKC3ZR" {
			t.Errorf("expected webhookEventId %q, got %q", "01FZ74A0TDDPYRVKNK77XKC3ZR", ev.WebhookEventID)
		}
		if ev.DeliveryContext == nil || ev.DeliveryContext.IsRedelivery != false {
			t.Errorf("expected isRedelivery false, got %+v", ev.DeliveryContext)
		}
		if !ev.IsTextMessage() {
			t.Errorf("expected IsTextMessage true")
		}
		if ev.Text() != "สภาพอากาศ อโศกมนตรี" {
			t.Errorf("expected text %q, got %q", "สภาพอากาศ อโศกมนตรี", ev.Text())
		}
		if ev.Time().UnixMilli() != 1620000000000 {
			t.Errorf("expected timestamp 1620000000000, got %d", ev.Time().UnixMilli())
		}
	})

	t.Run("Invalid signature returns ErrInvalidSignature", func(t *testing.T) {
		_, err := line.ParseWebhook(secret, "bad-signature", sampleJSON)
		if err == nil {
			t.Fatal("expected error, got nil")
		}
		if !line.IsInvalidSignature(err) && err != line.ErrInvalidSignature {
			t.Errorf("expected ErrInvalidSignature, got %v", err)
		}
	})

	t.Run("Empty body returns ErrEmptyBody", func(t *testing.T) {
		emptyBody := []byte("")
		sig := calcTestSignature(secret, emptyBody)
		_, err := line.ParseWebhook(secret, sig, emptyBody)
		if err != line.ErrEmptyBody {
			t.Errorf("expected ErrEmptyBody, got %v", err)
		}

		whitespaceBody := []byte("   \n\t  ")
		sigWS := calcTestSignature(secret, whitespaceBody)
		_, errWS := line.ParseWebhook(secret, sigWS, whitespaceBody)
		if errWS != line.ErrEmptyBody {
			t.Errorf("expected ErrEmptyBody for whitespace body, got %v", errWS)
		}
	})

	t.Run("Malformed JSON returns ErrMalformedJSON", func(t *testing.T) {
		malformedJSON := []byte(`{"destination": "U123", "events": [`)
		sig := calcTestSignature(secret, malformedJSON)
		_, err := line.ParseWebhook(secret, sig, malformedJSON)
		if err == nil {
			t.Fatal("expected error, got nil")
		}
		if !errorsIs(err, line.ErrMalformedJSON) {
			t.Errorf("expected ErrMalformedJSON, got %v", err)
		}
	})

	t.Run("Empty events array returns empty slice without error", func(t *testing.T) {
		emptyEvents := []byte(`{"destination":"U12345","events":[]}`)
		sig := calcTestSignature(secret, emptyEvents)
		payload, err := line.ParseWebhook(secret, sig, emptyEvents)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if payload.Events == nil || len(payload.Events) != 0 {
			t.Errorf("expected 0 events, got %d", len(payload.Events))
		}
	})

	t.Run("Null events field initializes empty slice", func(t *testing.T) {
		noEvents := []byte(`{"destination":"U12345"}`)
		sig := calcTestSignature(secret, noEvents)
		payload, err := line.ParseWebhook(secret, sig, noEvents)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if payload.Events == nil || len(payload.Events) != 0 {
			t.Errorf("expected non-nil empty events slice, got %+v", payload.Events)
		}
	})

	t.Run("Postback event parsed correctly", func(t *testing.T) {
		postbackJSON := []byte(`{
			"destination": "U12345",
			"events": [
				{
					"type": "postback",
					"mode": "active",
					"timestamp": 1620000005000,
					"source": {"type": "group", "groupId": "G1001"},
					"replyToken": "pbReplyToken",
					"postback": {
						"data": "action=view_hazard&district=wattana"
					}
				}
			]
		}`)
		sig := calcTestSignature(secret, postbackJSON)
		payload, err := line.ParseWebhook(secret, sig, postbackJSON)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if len(payload.Events) != 1 {
			t.Fatalf("expected 1 event, got %d", len(payload.Events))
		}
		ev := payload.Events[0]
		if ev.Type != line.EventTypePostback {
			t.Errorf("expected postback type, got %q", ev.Type)
		}
		if ev.Source.SenderID() != "G1001" {
			t.Errorf("expected SenderID G1001, got %q", ev.Source.SenderID())
		}
		if ev.Postback == nil || ev.Postback.Data != "action=view_hazard&district=wattana" {
			t.Errorf("unexpected postback: %+v", ev.Postback)
		}
		if ev.IsTextMessage() {
			t.Errorf("expected IsTextMessage false for postback")
		}
		if ev.Text() != "" {
			t.Errorf("expected empty Text() for postback, got %q", ev.Text())
		}
	})

	t.Run("SenderID falls back to GroupID or RoomID", func(t *testing.T) {
		sGroup := line.EventSource{Type: line.SourceTypeGroup, GroupID: "G999"}
		if sGroup.SenderID() != "G999" {
			t.Errorf("expected G999, got %q", sGroup.SenderID())
		}
		sRoom := line.EventSource{Type: line.SourceTypeRoom, RoomID: "R999"}
		if sRoom.SenderID() != "R999" {
			t.Errorf("expected R999, got %q", sRoom.SenderID())
		}
		sUser := line.EventSource{Type: line.SourceTypeUser, UserID: "U999", GroupID: "G999"}
		if sUser.SenderID() != "U999" {
			t.Errorf("expected U999, got %q", sUser.SenderID())
		}
	})

	t.Run("ParseWebhookPayload direct call", func(t *testing.T) {
		p, err := line.ParseWebhookPayload([]byte(`{"destination":"U001","events":[]}`))
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if p.Destination != "U001" {
			t.Errorf("expected U001, got %q", p.Destination)
		}
	})
}

func errorsIs(err, target error) bool {
	if err == target {
		return true
	}
	type causer interface {
		Unwrap() error
	}
	for err != nil {
		if err == target {
			return true
		}
		c, ok := err.(causer)
		if !ok {
			return false
		}
		err = c.Unwrap()
	}
	return false
}

