package dispatcher

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"sync"
	"testing"
	"time"

	"github.com/saransirichote/weather-resilience-gateway/internal/config"
	"github.com/saransirichote/weather-resilience-gateway/internal/model"
	"github.com/saransirichote/weather-resilience-gateway/internal/nlp"
)

type mockTripper func(req *http.Request) (*http.Response, error)

func (m mockTripper) RoundTrip(req *http.Request) (*http.Response, error) {
	return m(req)
}

func TestCircuitBreaker_StateTransitions(t *testing.T) {
	cb := NewCircuitBreaker(3, 50*time.Millisecond)

	if cb.State() != StateClosed {
		t.Fatalf("expected initial state CLOSED, got %s", cb.State())
	}
	if !cb.AllowRequest() {
		t.Fatalf("expected request allowed in CLOSED state")
	}

	// 2 failures should remain CLOSED
	cb.RecordFailure()
	cb.RecordFailure()
	if cb.State() != StateClosed {
		t.Fatalf("expected state CLOSED after 2 failures, got %s", cb.State())
	}

	// 3rd failure trips to OPEN
	cb.RecordFailure()
	if cb.State() != StateOpen {
		t.Fatalf("expected state OPEN after 3 failures, got %s", cb.State())
	}
	if cb.AllowRequest() {
		t.Fatalf("expected request blocked in OPEN state before cooldown")
	}

	// Wait for cooldown
	time.Sleep(60 * time.Millisecond)

	// Next request transitions to HALF_OPEN
	if !cb.AllowRequest() {
		t.Fatalf("expected request allowed after cooldown")
	}
	if cb.State() != StateHalfOpen {
		t.Fatalf("expected state HALF_OPEN, got %s", cb.State())
	}

	// Failure in HALF_OPEN trips immediately back to OPEN
	cb.RecordFailure()
	if cb.State() != StateOpen {
		t.Fatalf("expected state OPEN after failure in HALF_OPEN, got %s", cb.State())
	}

	// Wait cooldown again and test success transition to CLOSED
	time.Sleep(60 * time.Millisecond)
	if !cb.AllowRequest() {
		t.Fatalf("expected request allowed after cooldown")
	}
	cb.RecordSuccess()
	if cb.State() != StateClosed {
		t.Fatalf("expected state CLOSED after success, got %s", cb.State())
	}

	// Test Reset
	cb.RecordFailure()
	cb.RecordFailure()
	cb.RecordFailure()
	if cb.State() != StateOpen {
		t.Fatalf("expected state OPEN, got %s", cb.State())
	}
	cb.Reset()
	if cb.State() != StateClosed {
		t.Fatalf("expected state CLOSED after Reset, got %s", cb.State())
	}
}

func TestEngineClient_LiveAndFallback(t *testing.T) {
	tripper := mockTripper(func(req *http.Request) (*http.Response, error) {
		switch req.URL.Path {
		case "/api/v1/forecast":
			resp := EngineForecastResponse{
				Model: "WeatherNext 3 (Google DeepMind FGN 5km)",
				Forecasts: []EngineForecast{
					{
						Timestamp:             "2026-09-25T17:00:00+07:00",
						TemperatureC:          29.0,
						HumidityPct:           85,
						HeatIndexC:            34.0,
						PrecipitationRateMmHr: 42.0, // Critical rain
						WindGustKmh:           56.0,
						Condition:             "พายุฝนฟ้าคะนองรุนแรง",
					},
				},
			}
			b, _ := json.Marshal(resp)
			return &http.Response{
				StatusCode: http.StatusOK,
				Header:     http.Header{"Content-Type": []string{"application/json"}},
				Body:       io.NopCloser(bytes.NewReader(b)),
			}, nil
		case "/api/v1/canals":
			resp := EngineCanalsResponse{
				Canals: []EngineCanal{
					{
						StationID:         "CANAL-01",
						CanalName:         "คลองแสนแสบ",
						Location:          "ประตูระบายน้ำวิทยุ-อโศก",
						WaterLevelM:       0.95,
						BankHeightM:       1.10,
						MarginToOverflowM: 0.15,
						Status:            "CRITICAL",
					},
				},
			}
			b, _ := json.Marshal(resp)
			return &http.Response{
				StatusCode: http.StatusOK,
				Header:     http.Header{"Content-Type": []string{"application/json"}},
				Body:       io.NopCloser(bytes.NewReader(b)),
			}, nil
		case "/api/v1/radar":
			resp := EngineRadarResponse{
				MaxReflectivityDbz: 55.0,
				StormCellCount:     3,
				Timestamp:          "2026-09-25T17:00:00+07:00",
			}
			b, _ := json.Marshal(resp)
			return &http.Response{
				StatusCode: http.StatusOK,
				Header:     http.Header{"Content-Type": []string{"application/json"}},
				Body:       io.NopCloser(bytes.NewReader(b)),
			}, nil
		case "/api/v1/calendar/sync_and_evaluate":
			resp := EngineCalendarSyncResponse{
				UserID:                   "U1001",
				TotalEventsChecked:       2,
				EventsWithWeatherHazards: 1,
				ProactiveAdvisories: []EngineProactiveAdvisory{
					{
						EventID:     "EV1",
						EventTitle:  "ประชุมที่สีลม",
						Urgency:     "WARNING",
						ConcernType: "HEAVY_RAIN",
						Advisory: struct {
							Headline                string `json:"headline"`
							Reasoning               string `json:"reasoning"`
							ProactiveRecommendation string `json:"proactive_recommendation"`
							DepartureAdjustmentMins int    `json:"departure_adjustment_mins"`
							RecommendedActionType   string `json:"recommended_action_type"`
						}{
							Headline:                "เสี่ยงฝนตกหนัก",
							Reasoning:               "เรดาร์ตรวจพบกลุ่มฝน",
							ProactiveRecommendation: "ออกเดินทางเร็วขึ้น 30 นาที",
							DepartureAdjustmentMins: 30,
							RecommendedActionType:   "EARLY_DEPARTURE",
						},
					},
				},
			}
			b, _ := json.Marshal(resp)
			return &http.Response{
				StatusCode: http.StatusOK,
				Header:     http.Header{"Content-Type": []string{"application/json"}},
				Body:       io.NopCloser(bytes.NewReader(b)),
			}, nil
		default:
			return &http.Response{
				StatusCode: http.StatusNotFound,
				Body:       io.NopCloser(bytes.NewReader([]byte("not found"))),
			}, nil
		}
	})

	ec := NewEngineClient("http://mock-engine:8000")
	ec.SetHTTPClient(&http.Client{Transport: tripper, Timeout: 3 * time.Second})

	user := model.UserProfile{
		UserID:        "U1001",
		DisplayName:   "คุณสมชาย",
		TransportMode: "compact_sedan",
		HomeLocation: model.Location{
			Name:      "สุขุมวิท 21",
			Latitude:  13.7372,
			Longitude: 100.5638,
		},
	}

	ctx := context.Background()

	// 1. Weather Advisory
	wAdv := ec.ResolveWeatherAdvisory(ctx, user)
	if wAdv.UrgencyLevel != "CRITICAL" {
		t.Fatalf("expected CRITICAL weather urgency for 42mm/h rain, got %s", wAdv.UrgencyLevel)
	}
	if wAdv.RainRate != 42.0 {
		t.Fatalf("expected RainRate 42.0, got %f", wAdv.RainRate)
	}

	// 2. Flood Advisory
	fAdv := ec.ResolveFloodAdvisory(ctx, user)
	if fAdv.UrgencyLevel != "CRITICAL" {
		t.Fatalf("expected CRITICAL flood urgency, got %s", fAdv.UrgencyLevel)
	}
	if fAdv.CanalRemainingCm != 15.0 {
		t.Fatalf("expected CanalRemainingCm 15.0, got %f", fAdv.CanalRemainingCm)
	}

	// 3. Calendar Advisory
	cAdv := ec.ResolveCalendarAdvisory(ctx, user)
	if cAdv.UrgencyLevel != "WARNING" {
		t.Fatalf("expected WARNING calendar urgency, got %s", cAdv.UrgencyLevel)
	}

	// 4. Test Fallback when Engine Server errors
	errTripper := mockTripper(func(req *http.Request) (*http.Response, error) {
		return &http.Response{
			StatusCode: http.StatusInternalServerError,
			Body:       io.NopCloser(bytes.NewReader([]byte("server error"))),
		}, nil
	})
	downClient := NewEngineClient("http://mock-engine:8000")
	downClient.SetHTTPClient(&http.Client{Transport: errTripper, Timeout: 3 * time.Second})

	wFallback := downClient.ResolveWeatherAdvisory(ctx, user)
	if wFallback.UrgencyLevel != "WARNING" || wFallback.RainRate != 18.5 {
		t.Fatalf("expected fallback weather advisory values, got %s (rain: %f)", wFallback.UrgencyLevel, wFallback.RainRate)
	}

	fFallback := downClient.ResolveFloodAdvisory(ctx, user)
	if fFallback.UrgencyLevel != "WARNING" || fFallback.CanalRemainingCm != 25.0 {
		t.Fatalf("expected fallback flood advisory values, got %s", fFallback.UrgencyLevel)
	}

	cFallback := downClient.ResolveCalendarAdvisory(ctx, user)
	if cFallback.UrgencyLevel != "ADVISORY" {
		t.Fatalf("expected fallback calendar advisory values, got %s", cFallback.UrgencyLevel)
	}
}

func TestLineReplyClient_MockMode(t *testing.T) {
	client := NewLineReplyClient("")
	if !client.mockMode {
		t.Fatalf("expected mockMode to be true when token is empty")
	}

	ctx := context.Background()
	msg := map[string]interface{}{"type": "text", "text": "hello"}
	err := client.Reply(ctx, "token_123", []map[string]interface{}{msg})
	if err != nil {
		t.Fatalf("unexpected reply error: %v", err)
	}

	last := client.GetLastReply()
	if last == nil || last.ReplyToken != "token_123" {
		t.Fatalf("expected last reply to have token_123, got %v", last)
	}

	records := client.GetRecordedReplies()
	if len(records) != 1 {
		t.Fatalf("expected 1 recorded reply, got %d", len(records))
	}

	client.ClearRecorded()
	if client.GetLastReply() != nil {
		t.Fatalf("expected nil after ClearRecorded")
	}
}

func TestWorkerPool_DualChannelDispatch(t *testing.T) {
	cfg := &config.Config{
		WorkerPoolSize:  3,
		LIFFEndpointURL: "https://liff.line.me/test-app",
	}

	wp := NewWorkerPool(cfg, 50)
	mockReply := NewLineReplyClient("")
	wp.SetReplyClient(mockReply)
	wp.Start()
	defer wp.Stop()

	user := model.UserProfile{
		UserID:        "U1001",
		DisplayName:   "สมชาย",
		TransportMode: "compact_sedan",
	}

	// 1. Dispatch AlertPush job
	okPush := wp.Enqueue(model.AlertDispatchJob{
		UserID: "U1001",
		Payload: model.AdvisoryPayload{
			Title:        "พายุฝนฟ้าคะนอง",
			UrgencyLevel: "CRITICAL",
			RainRate:     50.0,
		},
	})
	if !okPush {
		t.Fatalf("failed to enqueue alert dispatch job")
	}

	// 2. Dispatch ReplyJobs for all intents
	testCases := []struct {
		intent nlp.Intent
		text   string
	}{
		{nlp.IntentWeather, "ขอเช็คสภาพอากาศ"},
		{nlp.IntentFlood, "น้ำท่วมไหม"},
		{nlp.IntentCalendar, "นัดหมายวันนี้"},
		{nlp.IntentVehicleProfile, "มอเตอร์ไซค์"},
		{nlp.IntentUnknown, "สวัสดีครับ"},
	}

	for i, tc := range testCases {
		match := nlp.Route(tc.text)
		replyJob := ReplyJob{
			ReplyToken:  tc.text,
			UserID:      user.UserID,
			Text:        tc.text,
			MatchResult: match,
			UserProfile: user,
			QueuedAt:    time.Now(),
		}
		ok := wp.EnqueueReply(replyJob)
		if !ok {
			t.Fatalf("failed to enqueue reply job %d", i)
		}
	}

	// Wait briefly for workers to process
	time.Sleep(100 * time.Millisecond)

	replies := mockReply.GetRecordedReplies()
	if len(replies) < len(testCases) {
		t.Fatalf("expected at least %d replies recorded, got %d", len(testCases), len(replies))
	}

	// Verify reply content structure
	first := replies[0]
	if len(first.Messages) == 0 {
		t.Fatalf("expected message in reply")
	}
	msgMap := first.Messages[0]
	if msgMap["type"] != "flex" {
		t.Fatalf("expected flex message type, got %v", msgMap["type"])
	}
	if msgMap["contents"] == nil {
		t.Fatalf("expected contents to be present in flex message")
	}
	if msgMap["quickReply"] == nil {
		t.Fatalf("expected quickReply to be present")
	}
}

func TestWorkerPool_ConcurrentReplies(t *testing.T) {
	cfg := &config.Config{
		WorkerPoolSize:  5,
		LIFFEndpointURL: "https://liff.line.me/test-app",
	}

	wp := NewWorkerPool(cfg, 200)
	mockReply := NewLineReplyClient("")
	wp.SetReplyClient(mockReply)
	wp.Start()
	defer wp.Stop()

	var wg sync.WaitGroup
	const total = 40

	for i := 0; i < total; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			match := nlp.Route("สภาพอากาศ")
			job := ReplyJob{
				ReplyToken:  "token",
				UserID:      "U_CONC",
				Text:        "สภาพอากาศ",
				MatchResult: match,
				UserProfile: model.UserProfile{
					UserID:        "U_CONC",
					TransportMode: "compact_sedan",
				},
				QueuedAt: time.Now(),
			}
			wp.EnqueueReply(job)
		}(i)
	}

	wg.Wait()
	time.Sleep(150 * time.Millisecond)

	records := mockReply.GetRecordedReplies()
	if len(records) != total {
		t.Fatalf("expected %d records, got %d", total, len(records))
	}
}

func TestWorkerPool_IdempotentStopAndPanicSafety(t *testing.T) {
	cfg := &config.Config{
		WorkerPoolSize:  2,
		LIFFEndpointURL: "https://liff.line.me/test",
	}

	t.Run("Sequential Stop() calls do not panic", func(t *testing.T) {
		wp := NewWorkerPool(cfg, 10)
		wp.Start()
		wp.Stop()
		wp.Stop()
		wp.Stop()
		if !wp.IsStopped() {
			t.Errorf("expected IsStopped() to be true")
		}
	})

	t.Run("Concurrent Stop() calls do not panic", func(t *testing.T) {
		wp := NewWorkerPool(cfg, 10)
		wp.Start()

		var wg sync.WaitGroup
		for i := 0; i < 10; i++ {
			wg.Add(1)
			go func() {
				defer wg.Done()
				wp.Stop()
			}()
		}
		wg.Wait()
		if !wp.IsStopped() {
			t.Errorf("expected IsStopped() to be true")
		}
	})

	t.Run("Enqueue and EnqueueReply return false on stopped pool", func(t *testing.T) {
		wp := NewWorkerPool(cfg, 10)
		wp.Start()
		wp.Stop()

		enqueuedAlert := wp.Enqueue(model.AlertDispatchJob{UserID: "U1"})
		if enqueuedAlert {
			t.Errorf("expected Enqueue on stopped pool to return false")
		}

		enqueuedReply := wp.EnqueueReply(ReplyJob{ReplyToken: "tok", UserID: "U1"})
		if enqueuedReply {
			t.Errorf("expected EnqueueReply on stopped pool to return false")
		}
	})

	t.Run("Concurrent Enqueue and Stop race condition safety", func(t *testing.T) {
		wp := NewWorkerPool(cfg, 20)
		wp.Start()

		var wg sync.WaitGroup
		const callers = 20
		for i := 0; i < callers; i++ {
			wg.Add(1)
			go func(idx int) {
				defer wg.Done()
				for j := 0; j < 50; j++ {
					_ = wp.EnqueueReply(ReplyJob{
						ReplyToken: fmt.Sprintf("tok-%d-%d", idx, j),
						UserID:     "U_RACE",
					})
				}
			}(i)
		}

		time.Sleep(2 * time.Millisecond)
		wp.Stop()
		wg.Wait()
	})
}

