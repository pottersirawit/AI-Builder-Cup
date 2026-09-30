package dispatcher

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/saransirichote/weather-resilience-gateway/internal/config"
	"github.com/saransirichote/weather-resilience-gateway/internal/line"
	"github.com/saransirichote/weather-resilience-gateway/internal/model"
	"github.com/saransirichote/weather-resilience-gateway/internal/nlp"
)

// ReplyJob represents an incoming conversational webhook event queued for resolution and reply.
type ReplyJob struct {
	ReplyToken  string            `json:"reply_token"`
	UserID      string            `json:"user_id"`
	Text        string            `json:"text"`
	MatchResult nlp.MatchResult   `json:"match_result"`
	UserProfile model.UserProfile `json:"user_profile"`
	QueuedAt    time.Time         `json:"queued_at"`
}

type WorkerPool struct {
	cfg           *config.Config
	jobsChan      chan model.AlertDispatchJob
	replyJobsChan chan ReplyJob
	wg            sync.WaitGroup
	quitChan      chan struct{}
	httpClient    *http.Client
	engineClient  *EngineClient
	replyClient   LineReplyClient
	mu            sync.RWMutex
	stopOnce      sync.Once
	isStopped     bool
}

func NewWorkerPool(cfg *config.Config, queueCapacity int) *WorkerPool {
	return &WorkerPool{
		cfg:           cfg,
		jobsChan:      make(chan model.AlertDispatchJob, queueCapacity),
		replyJobsChan: make(chan ReplyJob, queueCapacity),
		quitChan:      make(chan struct{}),
		httpClient:    &http.Client{Timeout: 5 * time.Second},
		engineClient:  NewEngineClient(cfg.EngineBaseURL),
		replyClient:   NewLineReplyClient(cfg.LineChannelToken),
	}
}

func (wp *WorkerPool) SetEngineClient(ec *EngineClient) {
	wp.engineClient = ec
}

func (wp *WorkerPool) SetReplyClient(rc LineReplyClient) {
	wp.replyClient = rc
}

func (wp *WorkerPool) ReplyClient() LineReplyClient {
	return wp.replyClient
}

func (wp *WorkerPool) EngineClient() *EngineClient {
	return wp.engineClient
}

func (wp *WorkerPool) Start() {
	log.Printf("[WorkerPool] Starting %d Goroutine workers for alert & reply dispatching...", wp.cfg.WorkerPoolSize)
	for i := 1; i <= wp.cfg.WorkerPoolSize; i++ {
		wp.wg.Add(1)
		go wp.worker(i)
	}
}

// IsStopped returns true if the worker pool has been stopped.
func (wp *WorkerPool) IsStopped() bool {
	wp.mu.RLock()
	defer wp.mu.RUnlock()
	return wp.isStopped
}

func (wp *WorkerPool) Enqueue(job model.AlertDispatchJob) (enqueued bool) {
	wp.mu.RLock()
	defer wp.mu.RUnlock()

	if wp.isStopped {
		return false
	}

	defer func() {
		if r := recover(); r != nil {
			enqueued = false
		}
	}()

	select {
	case wp.jobsChan <- job:
		return true
	default:
		log.Printf("[WorkerPool] Warning: Alert job queue full, dropping alert for %s", job.UserID)
		return false
	}
}

func (wp *WorkerPool) EnqueueReply(job ReplyJob) (enqueued bool) {
	wp.mu.RLock()
	defer wp.mu.RUnlock()

	if wp.isStopped {
		return false
	}

	defer func() {
		if r := recover(); r != nil {
			enqueued = false
		}
	}()

	select {
	case wp.replyJobsChan <- job:
		return true
	default:
		log.Printf("[WorkerPool] Warning: Reply job queue full, dropping reply for %s", job.UserID)
		return false
	}
}

func (wp *WorkerPool) worker(id int) {
	defer wp.wg.Done()
	for {
		select {
		case <-wp.quitChan:
			return
		case job, ok := <-wp.jobsChan:
			if !ok {
				return
			}
			wp.processJob(id, job)
		case replyJob, ok := <-wp.replyJobsChan:
			if !ok {
				return
			}
			wp.processReplyJob(id, replyJob)
		}
	}
}

func (wp *WorkerPool) processReplyJob(workerID int, job ReplyJob) {
	start := time.Now()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// 1. Resolve AdvisoryPayload according to Intent
	var payload model.AdvisoryPayload
	switch job.MatchResult.Intent {
	case nlp.IntentWeather:
		payload = wp.engineClient.ResolveWeatherAdvisory(ctx, job.UserProfile)
	case nlp.IntentFlood:
		payload = wp.engineClient.ResolveFloodAdvisory(ctx, job.UserProfile)
	case nlp.IntentCalendar:
		payload = wp.engineClient.ResolveCalendarAdvisory(ctx, job.UserProfile)
	case nlp.IntentVehicleProfile:
		payload = buildVehicleProfileAdvisory(job.MatchResult, job.UserProfile)
	default:
		payload = buildUnknownAdvisory(job.UserProfile)
	}

	// 2. Ensure transport mode and LIFF URL are populated
	if payload.VehicleType == "" {
		payload.VehicleType = job.UserProfile.TransportMode
	}
	if payload.LIFFURL == "" {
		payload.LIFFURL = wp.cfg.LIFFEndpointURL
	}

	// 3. Construct Theme 1 Apple Spatial Weather Flex Bubble
	flexBubble := line.BuildFlexMessageBubble(payload)

	// 4. Construct Contextual Quick Reply Pills
	quickReplies := line.DefaultQuickReplies(wp.cfg.LIFFEndpointURL)

	// 5. Package LINE Message structure
	msg := map[string]interface{}{
		"type":       "flex",
		"altText":    fmt.Sprintf("[%s] %s", payload.UrgencyLevel, payload.Title),
		"contents":   flexBubble,
		"quickReply": quickReplies,
	}

	// 6. Send Reply via ReplyClient
	err := wp.replyClient.Reply(ctx, job.ReplyToken, []map[string]interface{}{msg})
	duration := time.Since(start)
	if err != nil {
		log.Printf("[Worker %d] Failed to reply for %s: %v (took %v)", workerID, job.UserID, err, duration)
	} else {
		log.Printf("[Worker %d] Successfully replied to %s (intent=%s, took %v)", workerID, job.UserID, job.MatchResult.Intent, duration)
	}
}

func buildVehicleProfileAdvisory(match nlp.MatchResult, user model.UserProfile) model.AdvisoryPayload {
	mode, ok := match.VehicleMode()
	if !ok || mode == "" {
		if user.TransportMode != "" {
			mode = nlp.VehicleMode(user.TransportMode)
		} else {
			mode = nlp.VehicleModeSedan
		}
	}
	thaiName := "รถเก๋ง / รถยนต์ส่วนบุคคล"
	switch mode {
	case nlp.VehicleModeSedan:
		thaiName = "รถเก๋ง / รถยนต์ส่วนบุคคล"
	case nlp.VehicleModeMotorcycle:
		thaiName = "มอเตอร์ไซค์"
	case nlp.VehicleModePickup:
		thaiName = "กระบะ / SUV ยกสูง"
	case nlp.VehicleModeTransit:
		thaiName = "รถไฟฟ้า (BTS/MRT)"
	}

	return model.AdvisoryPayload{
		Title:        "บันทึกพาหนะเรียบร้อยแล้ว",
		UrgencyLevel: "INFO",
		SummaryText:  fmt.Sprintf("ระบบได้อัปเดตพาหนะหลักของคุณเป็น '%s' แล้ว ระบบจะปรับเกณฑ์การเตือนภัยน้ำท่วมตามความสูงของยานพาหนะนี้โดยอัตโนมัติ", thaiName),
		VehicleType:  string(mode),
		ActionChecklist: []string{
			"เกณฑ์ความลึกน้ำท่วมจะคำนวณตามความสูงยานพาหนะคุณ",
			"พิมพ์ 'สภาพอากาศ' หรือ 'น้ำท่วม' เพื่อตรวจสอบความปลอดภัย",
			"สามารถเปลี่ยนพาหนะได้ตลอดเวลาผ่าน Quick Reply",
		},
		TabDestination: "profile",
		ExtraParams:    fmt.Sprintf("vehicle=%s", mode),
	}
}

func buildUnknownAdvisory(user model.UserProfile) model.AdvisoryPayload {
	return model.AdvisoryPayload{
		Title:        "ศูนย์ข้อมูลสภาพอากาศและเตือนภัย กทม.",
		UrgencyLevel: "INFO",
		SummaryText:  "ยินดีต้อนรับสู่ Bangkok Weather Resilience กรุณาเลือกเมนูจากปุ่มลัดด้านล่าง หรือพิมพ์ 'สภาพอากาศ', 'น้ำท่วม', 'ปฏิทิน', 'รถเก๋ง', 'มอเตอร์ไซค์'",
		VehicleType:  user.TransportMode,
		ActionChecklist: []string{
			"พิมพ์ 'สภาพอากาศ' เพื่อดูพยากรณ์ WeatherNext 3",
			"พิมพ์ 'น้ำท่วม' เพื่อเช็กระดับน้ำคลองและจุดเสี่ยง",
			"พิมพ์ 'ปฏิทิน' เพื่อประเมินความเสี่ยงตารางนัดหมาย",
			"ระบุพาหนะของคุณเพื่อปรับเกณฑ์การเตือนเฉพาะบุคคล",
		},
		TabDestination: "dashboard",
	}
}

// processJob retains original push alert functionality for proactive warnings.
func (wp *WorkerPool) processJob(workerID int, job model.AlertDispatchJob) {
	start := time.Now()
	flexBubble := line.BuildFlexMessageBubble(job.Payload)

	if wp.cfg.LineChannelToken == "" {
		duration := time.Since(start)
		log.Printf("[Worker %d] [SIMULATION DISPATCH] User: %s | Urgency: %s | Title: %s (took %v)",
			workerID, job.UserID, job.Payload.UrgencyLevel, job.Payload.Title, duration)
		return
	}

	pushURL := "https://api.line.me/v2/bot/message/push"
	bodyMap := map[string]interface{}{
		"to": job.UserID,
		"messages": []map[string]interface{}{
			{
				"type":    "flex",
				"altText": fmt.Sprintf("[%s] %s", job.Payload.UrgencyLevel, job.Payload.Title),
				"contents": flexBubble,
			},
		},
	}

	jsonBytes, err := json.Marshal(bodyMap)
	if err != nil {
		log.Printf("[Worker %d] Error marshaling push message: %v", workerID, err)
		return
	}

	req, err := http.NewRequest("POST", pushURL, bytes.NewBuffer(jsonBytes))
	if err != nil {
		log.Printf("[Worker %d] Error building HTTP request: %v", workerID, err)
		return
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+wp.cfg.LineChannelToken)

	resp, err := wp.httpClient.Do(req)
	duration := time.Since(start)
	if err != nil {
		log.Printf("[Worker %d] Failed to push to LINE for %s: %v", workerID, job.UserID, err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Printf("[Worker %d] LINE API returned non-200 (%d) for user %s", workerID, resp.StatusCode, job.UserID)
	} else {
		log.Printf("[Worker %d] Successfully pushed alert to %s (%v)", workerID, job.UserID, duration)
	}
}

func (wp *WorkerPool) Stop() {
	wp.stopOnce.Do(func() {
		wp.mu.Lock()
		wp.isStopped = true
		close(wp.quitChan)
		wp.mu.Unlock()

		wp.wg.Wait()

		wp.mu.Lock()
		close(wp.jobsChan)
		close(wp.replyJobsChan)
		wp.mu.Unlock()

		log.Println("[WorkerPool] All workers stopped cleanly.")
	})
}
