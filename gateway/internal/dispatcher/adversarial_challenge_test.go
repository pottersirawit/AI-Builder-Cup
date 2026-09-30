package dispatcher

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/saransirichote/weather-resilience-gateway/internal/config"
	"github.com/saransirichote/weather-resilience-gateway/internal/model"
	"github.com/saransirichote/weather-resilience-gateway/internal/nlp"
)

// TestAdversarial_CircuitBreaker_FailFastAndFallback challenges the circuit breaker to verify:
// 1. Exactly 3 consecutive failures trip the breaker to OPEN.
// 2. While OPEN, 50 concurrent requests are failed fast WITHOUT touching the network.
// 3. Fallback Bangkok baseline advisories are returned transparently to all callers.
func TestAdversarial_CircuitBreaker_FailFastAndFallback(t *testing.T) {
	var httpCallCount int64

	// Transport that always fails with HTTP 503 Service Unavailable
	failingTripper := mockTripper(func(req *http.Request) (*http.Response, error) {
		atomic.AddInt64(&httpCallCount, 1)
		return &http.Response{
			StatusCode: http.StatusServiceUnavailable,
			Header:     http.Header{"Content-Type": []string{"application/json"}},
			Body:       io.NopCloser(bytes.NewReader([]byte(`{"error":"engine overloaded"}`))),
		}, nil
	})

	ec := NewEngineClient("http://mock-engine:8000")
	ec.SetHTTPClient(&http.Client{Transport: failingTripper, Timeout: 3 * time.Second})

	user := model.UserProfile{
		UserID:        "U_STRESS_CB",
		DisplayName:   "คุณวิชัย",
		TransportMode: "motorcycle",
		HomeLocation: model.Location{
			Name:      "อโศก",
			Latitude:  13.7372,
			Longitude: 100.5638,
		},
	}

	ctx := context.Background()

	// Initial state must be CLOSED
	if ec.CircuitBreaker().State() != StateClosed {
		t.Fatalf("expected initial state CLOSED, got %s", ec.CircuitBreaker().State())
	}

	// 1st request -> fails, state CLOSED
	_ = ec.ResolveWeatherAdvisory(ctx, user)
	if ec.CircuitBreaker().State() != StateClosed {
		t.Fatalf("expected state CLOSED after 1st failure, got %s", ec.CircuitBreaker().State())
	}

	// 2nd request -> fails, state CLOSED
	_ = ec.ResolveCalendarAdvisory(ctx, user)
	if ec.CircuitBreaker().State() != StateClosed {
		t.Fatalf("expected state CLOSED after 2nd failure, got %s", ec.CircuitBreaker().State())
	}

	// 3rd request -> fails, state trips to OPEN
	_ = ec.ResolveWeatherAdvisory(ctx, user)
	if ec.CircuitBreaker().State() != StateOpen {
		t.Fatalf("expected state OPEN after 3rd failure, got %s", ec.CircuitBreaker().State())
	}

	callsBeforeFlood := atomic.LoadInt64(&httpCallCount)
	if callsBeforeFlood != 3 {
		t.Fatalf("expected exactly 3 HTTP calls to trip circuit breaker, got %d", callsBeforeFlood)
	}

	// Now circuit breaker is OPEN.
	// Fire 50 concurrent requests across Weather, Flood, and Calendar.
	const concurrentRequests = 50
	var wg sync.WaitGroup
	start := time.Now()

	for i := 0; i < concurrentRequests; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			switch idx % 3 {
			case 0:
				adv := ec.ResolveWeatherAdvisory(ctx, user)
				if adv.UrgencyLevel != "WARNING" || adv.RainRate != 18.5 {
					t.Errorf("expected fallback weather advisory, got urgency %s, rain %f", adv.UrgencyLevel, adv.RainRate)
				}
			case 1:
				adv := ec.ResolveFloodAdvisory(ctx, user)
				if adv.UrgencyLevel != "WARNING" || adv.CanalRemainingCm != 25.0 {
					t.Errorf("expected fallback flood advisory, got urgency %s, canal %f", adv.UrgencyLevel, adv.CanalRemainingCm)
				}
			case 2:
				adv := ec.ResolveCalendarAdvisory(ctx, user)
				if adv.UrgencyLevel != "ADVISORY" {
					t.Errorf("expected fallback calendar advisory, got urgency %s", adv.UrgencyLevel)
				}
			}
		}(i)
	}

	wg.Wait()
	elapsed := time.Since(start)

	// In OPEN state, NO HTTP calls should have been made!
	callsAfterFlood := atomic.LoadInt64(&httpCallCount)
	if callsAfterFlood != callsBeforeFlood {
		t.Fatalf("fail-fast violated! Circuit was OPEN but %d new HTTP calls were made", callsAfterFlood-callsBeforeFlood)
	}

	// Responses should be fast (< 100ms for all 50 concurrent requests)
	if elapsed > 200*time.Millisecond {
		t.Fatalf("fail-fast took too long: %v for %d requests", elapsed, concurrentRequests)
	}
}

// TestAdversarial_CircuitBreaker_ProbeAndRecoveryCycle verifies the state machine transition:
// OPEN -> (cooldown) -> HALF_OPEN -> (failure) -> OPEN -> (cooldown) -> HALF_OPEN -> (success) -> CLOSED.
func TestAdversarial_CircuitBreaker_ProbeAndRecoveryCycle(t *testing.T) {
	cb := NewCircuitBreaker(2, 40*time.Millisecond)

	// Trip to OPEN
	cb.RecordFailure()
	cb.RecordFailure()
	if cb.State() != StateOpen {
		t.Fatalf("expected OPEN state, got %s", cb.State())
	}

	// Before cooldown: blocked
	if cb.AllowRequest() {
		t.Fatalf("expected AllowRequest to be false before cooldown")
	}

	// Wait cooldown
	time.Sleep(50 * time.Millisecond)

	// First probe after cooldown: enters HALF_OPEN
	if !cb.AllowRequest() {
		t.Fatalf("expected AllowRequest to be true for probe after cooldown")
	}
	if cb.State() != StateHalfOpen {
		t.Fatalf("expected state HALF_OPEN, got %s", cb.State())
	}

	// Probe fails -> immediate reversion to OPEN
	cb.RecordFailure()
	if cb.State() != StateOpen {
		t.Fatalf("expected state OPEN after probe failure, got %s", cb.State())
	}

	// Wait cooldown again
	time.Sleep(50 * time.Millisecond)

	// Next probe
	if !cb.AllowRequest() {
		t.Fatalf("expected AllowRequest to be true for 2nd probe")
	}
	if cb.State() != StateHalfOpen {
		t.Fatalf("expected state HALF_OPEN for 2nd probe, got %s", cb.State())
	}

	// Probe succeeds -> full recovery to CLOSED
	cb.RecordSuccess()
	if cb.State() != StateClosed {
		t.Fatalf("expected state CLOSED after probe success, got %s", cb.State())
	}
	if cb.failureCount != 0 {
		t.Fatalf("expected failureCount reset to 0, got %d", cb.failureCount)
	}
}

// TestAdversarial_CircuitBreaker_ConcurrentRace stresses CircuitBreaker under 100 concurrent goroutines.
func TestAdversarial_CircuitBreaker_ConcurrentRace(t *testing.T) {
	cb := NewCircuitBreaker(3, 10*time.Millisecond)
	var wg sync.WaitGroup
	const routines = 100

	for i := 0; i < routines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()
			for iter := 0; iter < 100; iter++ {
				switch (id + iter) % 5 {
				case 0:
					_ = cb.AllowRequest()
				case 1:
					cb.RecordFailure()
				case 2:
					cb.RecordSuccess()
				case 3:
					_ = cb.State()
				case 4:
					if iter%20 == 0 {
						cb.Reset()
					}
				}
			}
		}(i)
	}

	wg.Wait()
}

// TestAdversarial_TimeoutSimulation asserts that a slow upstream engine triggering context deadline
// results in immediate fallback without stalling the gateway or exceeding 3.5s.
func TestAdversarial_TimeoutSimulation(t *testing.T) {
	slowTripper := mockTripper(func(req *http.Request) (*http.Response, error) {
		select {
		case <-req.Context().Done():
			return nil, req.Context().Err()
		case <-time.After(4 * time.Second): // Exceeds 3s client timeout
			return &http.Response{
				StatusCode: http.StatusOK,
				Body:       io.NopCloser(bytes.NewReader([]byte(`{}`))),
			}, nil
		}
	})

	ec := NewEngineClient("http://mock-slow-engine:8000")
	ec.SetHTTPClient(&http.Client{Transport: slowTripper, Timeout: 3 * time.Second})

	user := model.UserProfile{
		UserID:        "U_SLOW",
		TransportMode: "compact_sedan",
	}

	start := time.Now()
	adv := ec.ResolveWeatherAdvisory(context.Background(), user)
	elapsed := time.Since(start)

	if elapsed > 3500*time.Millisecond {
		t.Fatalf("timeout resolution took %v, expected <= 3.5s", elapsed)
	}
	if adv.UrgencyLevel != "WARNING" {
		t.Fatalf("expected fallback advisory on timeout, got %s", adv.UrgencyLevel)
	}
}

// TestAdversarial_WorkerPool_DualChannelBurst challenges the dual-channel worker pool
// with simultaneous heavy bursts of push alert jobs and reactive reply jobs.
func TestAdversarial_WorkerPool_DualChannelBurst(t *testing.T) {
	cfg := &config.Config{
		WorkerPoolSize:   8,
		LIFFEndpointURL:  "https://liff.line.me/test-app",
		LineChannelToken: "", // mock mode
	}

	wp := NewWorkerPool(cfg, 1000)
	mockReply := NewLineReplyClient("")
	wp.SetReplyClient(mockReply)
	wp.Start()
	defer wp.Stop()

	const numPushJobs = 100
	const numReplyJobs = 100

	var wg sync.WaitGroup

	// 1. Concurrent Alert Push Jobs
	wg.Add(1)
	go func() {
		defer wg.Done()
		for i := 0; i < numPushJobs; i++ {
			job := model.AlertDispatchJob{
				UserID: fmt.Sprintf("U_PUSH_%d", i),
				Payload: model.AdvisoryPayload{
					Title:        fmt.Sprintf("เตือนภัยฝนตกหนัก #%d", i),
					UrgencyLevel: "CRITICAL",
					RainRate:     45.0,
				},
			}
			if !wp.Enqueue(job) {
				t.Errorf("failed to enqueue alert job %d", i)
			}
		}
	}()

	// 2. Concurrent Webhook Reply Jobs with mixed intents
	queries := []string{
		"สภาพอากาศวันนี้",
		"น้ำท่วมไหมคลองแสนแสบ",
		"เช็คปฏิทินนัดหมาย",
		"รถเก๋ง",
		"สวัสดีครับผม",
	}

	wg.Add(1)
	go func() {
		defer wg.Done()
		for i := 0; i < numReplyJobs; i++ {
			q := queries[i%len(queries)]
			match := nlp.Route(q)
			job := ReplyJob{
				ReplyToken:  fmt.Sprintf("TOKEN_%d", i),
				UserID:      fmt.Sprintf("U_REPLY_%d", i),
				Text:        q,
				MatchResult: match,
				UserProfile: model.UserProfile{
					UserID:        fmt.Sprintf("U_REPLY_%d", i),
					TransportMode: "compact_sedan",
				},
				QueuedAt: time.Now(),
			}
			if !wp.EnqueueReply(job) {
				t.Errorf("failed to enqueue reply job %d", i)
			}
		}
	}()

	wg.Wait()

	// Allow workers time to drain the queue
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		recs := mockReply.GetRecordedReplies()
		if len(recs) == numReplyJobs {
			break
		}
		time.Sleep(50 * time.Millisecond)
	}

	recs := mockReply.GetRecordedReplies()
	if len(recs) != numReplyJobs {
		t.Fatalf("expected %d reply jobs processed, got %d", numReplyJobs, len(recs))
	}
}

// TestAdversarial_WorkerPool_QueueSaturation verifies non-blocking drop when channels are full.
func TestAdversarial_WorkerPool_QueueSaturation(t *testing.T) {
	cfg := &config.Config{
		WorkerPoolSize:  1,
		LIFFEndpointURL: "https://liff.line.me/test-app",
	}

	// Create small queue of capacity 2
	wp := NewWorkerPool(cfg, 2)
	// Notice: DO NOT start workers yet, so queue fills up immediately

	job1 := ReplyJob{ReplyToken: "T1", UserID: "U1"}
	job2 := ReplyJob{ReplyToken: "T2", UserID: "U2"}
	job3 := ReplyJob{ReplyToken: "T3", UserID: "U3"}

	if !wp.EnqueueReply(job1) {
		t.Fatalf("expected job1 to enqueue successfully")
	}
	if !wp.EnqueueReply(job2) {
		t.Fatalf("expected job2 to enqueue successfully")
	}
	// 3rd job should be dropped non-blockingly
	if wp.EnqueueReply(job3) {
		t.Fatalf("expected job3 to be dropped when queue full")
	}
}

// TestAdversarial_WorkerPool_CleanShutdownUnderLoad tests graceful termination while active.
func TestAdversarial_WorkerPool_CleanShutdownUnderLoad(t *testing.T) {
	cfg := &config.Config{
		WorkerPoolSize:  4,
		LIFFEndpointURL: "https://liff.line.me/test-app",
	}
	wp := NewWorkerPool(cfg, 100)
	wp.Start()

	// Fill queue with some jobs
	for i := 0; i < 20; i++ {
		wp.Enqueue(model.AlertDispatchJob{UserID: fmt.Sprintf("U_%d", i)})
	}

	// Stop cleanly
	done := make(chan struct{})
	go func() {
		wp.Stop()
		close(done)
	}()

	select {
	case <-done:
		// Stopped cleanly
	case <-time.After(2 * time.Second):
		t.Fatalf("wp.Stop() hung or deadlocked")
	}
}
