package line

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
)

// Standard sentinel errors for webhook validation and parsing
var (
	ErrInvalidSignature = errors.New("invalid or missing LINE signature")
	ErrEmptyBody        = errors.New("request body is empty")
	ErrMalformedJSON    = errors.New("malformed JSON payload")
)

// IsInvalidSignature reports whether err is or wraps ErrInvalidSignature
func IsInvalidSignature(err error) bool {
	return errors.Is(err, ErrInvalidSignature)
}

// EventType represents the type of LINE webhook event
type EventType string

const (
	EventTypeMessage       EventType = "message"
	EventTypeFollow        EventType = "follow"
	EventTypeUnfollow      EventType = "unfollow"
	EventTypeJoin          EventType = "join"
	EventTypeLeave         EventType = "leave"
	EventTypeMemberJoined  EventType = "memberJoined"
	EventTypeMemberLeft    EventType = "memberLeft"
	EventTypePostback      EventType = "postback"
	EventTypeVideoComplete EventType = "videoPlayComplete"
	EventTypeBeacon        EventType = "beacon"
	EventTypeAccountLink   EventType = "accountLink"
)

// MessageType represents the type of message within a message event
type MessageType string

const (
	MessageTypeText     MessageType = "text"
	MessageTypeImage    MessageType = "image"
	MessageTypeVideo    MessageType = "video"
	MessageTypeAudio    MessageType = "audio"
	MessageTypeFile     MessageType = "file"
	MessageTypeLocation MessageType = "location"
	MessageTypeSticker  MessageType = "sticker"
)

// SourceType represents the originator entity type
type SourceType string

const (
	SourceTypeUser  SourceType = "user"
	SourceTypeGroup SourceType = "group"
	SourceTypeRoom  SourceType = "room"
)

// WebhookPayload represents the top-level LINE Messaging API webhook request body
type WebhookPayload struct {
	Destination string         `json:"destination"`
	Events      []WebhookEvent `json:"events"`
}

// WebhookEvent represents an individual event sent by the LINE platform
type WebhookEvent struct {
	ReplyToken      string           `json:"replyToken,omitempty"`
	Type            EventType        `json:"type"`
	Mode            string           `json:"mode"`
	Timestamp       int64            `json:"timestamp"`
	Source          EventSource      `json:"source"`
	WebhookEventID  string           `json:"webhookEventId,omitempty"`
	DeliveryContext *DeliveryContext `json:"deliveryContext,omitempty"`
	Message         *EventMessage    `json:"message,omitempty"`
	Postback        *EventPostback   `json:"postback,omitempty"`
}

// EventSource identifies the sender (user, group, or chat room)
type EventSource struct {
	Type    SourceType `json:"type"`
	UserID  string     `json:"userId,omitempty"`
	GroupID string     `json:"groupId,omitempty"`
	RoomID  string     `json:"roomId,omitempty"`
}

// SenderID returns UserID if present; otherwise GroupID or RoomID
func (s EventSource) SenderID() string {
	if s.UserID != "" {
		return s.UserID
	}
	if s.GroupID != "" {
		return s.GroupID
	}
	return s.RoomID
}

// EventMessage represents the message content for "message" events
type EventMessage struct {
	ID         string      `json:"id"`
	Type       MessageType `json:"type"`
	Text       string      `json:"text,omitempty"`
	QuoteToken string      `json:"quoteToken,omitempty"`
}

// DeliveryContext carries metadata about redelivery status
type DeliveryContext struct {
	IsRedelivery bool `json:"isRedelivery"`
}

// EventPostback represents data returned from a postback action
type EventPostback struct {
	Data   string                 `json:"data"`
	Params map[string]interface{} `json:"params,omitempty"`
}

// Time converts the event's millisecond timestamp into a Go time.Time
func (e WebhookEvent) Time() time.Time {
	return time.UnixMilli(e.Timestamp)
}

// IsTextMessage returns true if the event is a message event containing text
func (e WebhookEvent) IsTextMessage() bool {
	return e.Type == EventTypeMessage && e.Message != nil && e.Message.Type == MessageTypeText
}

// Text returns the message text if this is a text message event, or an empty string
func (e WebhookEvent) Text() string {
	if e.IsTextMessage() {
		return e.Message.Text
	}
	return ""
}

// ValidateSignature verifies the HMAC-SHA256 signature against channelSecret and raw body
// using constant-time byte comparison (hmac.Equal) to prevent timing attacks.
// It returns false if channelSecret or signature is empty.
func ValidateSignature(channelSecret, signature string, body []byte) bool {
	signature = strings.TrimSpace(signature)
	if channelSecret == "" || signature == "" {
		return false
	}

	mac := hmac.New(sha256.New, []byte(channelSecret))
	mac.Write(body)
	expectedMAC := mac.Sum(nil)
	expectedSignature := base64.StdEncoding.EncodeToString(expectedMAC)

	return hmac.Equal([]byte(expectedSignature), []byte(signature))
}

// ParseWebhook verifies the request signature and unmarshals the raw JSON bytes into a WebhookPayload.
// It returns ErrInvalidSignature if signature verification fails,
// ErrEmptyBody if the body is empty or whitespace only,
// or ErrMalformedJSON if JSON unmarshaling fails.
func ParseWebhook(channelSecret, signature string, body []byte) (*WebhookPayload, error) {
	if !ValidateSignature(channelSecret, signature, body) {
		return nil, ErrInvalidSignature
	}
	return ParseWebhookPayload(body)
}

// ParseWebhookPayload unmarshals raw JSON bytes into a WebhookPayload without signature verification.
func ParseWebhookPayload(body []byte) (*WebhookPayload, error) {
	trimmed := bytes.TrimSpace(body)
	if len(trimmed) == 0 {
		return nil, ErrEmptyBody
	}

	var payload WebhookPayload
	if err := json.Unmarshal(trimmed, &payload); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrMalformedJSON, err)
	}

	if payload.Events == nil {
		payload.Events = []WebhookEvent{}
	}

	return &payload, nil
}
