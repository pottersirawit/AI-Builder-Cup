package dispatcher

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"
	"time"
)

// RecordedReply captures an outbound reply invocation for testing and verification.
type RecordedReply struct {
	ReplyToken string                   `json:"reply_token"`
	Messages   []map[string]interface{} `json:"messages"`
	Timestamp  time.Time                `json:"timestamp"`
}

// LineReplyClient abstracts message dispatching to the LINE Messaging API.
type LineReplyClient interface {
	Reply(ctx context.Context, replyToken string, messages []map[string]interface{}) error
	GetLastReply() *RecordedReply
	GetRecordedReplies() []RecordedReply
	ClearRecorded()
}

// DefaultLineReplyClient implements outbound LINE reply with mock/live modes.
type DefaultLineReplyClient struct {
	channelToken string
	httpClient   *http.Client
	mockMode     bool
	mu           sync.RWMutex
	recorded     []RecordedReply
}

func NewLineReplyClient(channelToken string) *DefaultLineReplyClient {
	mock := channelToken == ""
	return &DefaultLineReplyClient{
		channelToken: channelToken,
		httpClient:   &http.Client{Timeout: 5 * time.Second},
		mockMode:     mock,
		recorded:     make([]RecordedReply, 0),
	}
}

func (c *DefaultLineReplyClient) SetMockMode(mock bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.mockMode = mock
}

func (c *DefaultLineReplyClient) SetHTTPClient(client *http.Client) {
	c.httpClient = client
}

func (c *DefaultLineReplyClient) Reply(ctx context.Context, replyToken string, messages []map[string]interface{}) error {
	c.mu.Lock()
	rec := RecordedReply{
		ReplyToken: replyToken,
		Messages:   messages,
		Timestamp:  time.Now(),
	}
	c.recorded = append(c.recorded, rec)
	const maxRecorded = 100
	if len(c.recorded) > maxRecorded {
		c.recorded = append([]RecordedReply(nil), c.recorded[len(c.recorded)-maxRecorded:]...)
	}
	mock := c.mockMode || c.channelToken == ""
	c.mu.Unlock()

	if mock {
		log.Printf("[LineReplyClient] [SIMULATION REPLY] Token: %s | Messages: %d", replyToken, len(messages))
		return nil
	}

	replyURL := "https://api.line.me/v2/bot/message/reply"
	payload := map[string]interface{}{
		"replyToken": replyToken,
		"messages":   messages,
	}

	jsonBytes, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshaling reply payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, replyURL, bytes.NewBuffer(jsonBytes))
	if err != nil {
		return fmt.Errorf("creating http request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.channelToken)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("line api request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("line api returned non-200 (%d): %s", resp.StatusCode, string(respBody))
	}

	return nil
}

func (c *DefaultLineReplyClient) GetLastReply() *RecordedReply {
	c.mu.RLock()
	defer c.mu.RUnlock()
	if len(c.recorded) == 0 {
		return nil
	}
	last := c.recorded[len(c.recorded)-1]
	return &last
}

func (c *DefaultLineReplyClient) GetRecordedReplies() []RecordedReply {
	c.mu.RLock()
	defer c.mu.RUnlock()
	out := make([]RecordedReply, len(c.recorded))
	copy(out, c.recorded)
	return out
}

func (c *DefaultLineReplyClient) ClearRecorded() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.recorded = make([]RecordedReply, 0)
}
