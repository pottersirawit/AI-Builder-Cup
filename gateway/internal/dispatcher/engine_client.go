package dispatcher

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/saransirichote/weather-resilience-gateway/internal/model"
)

var (
	ErrCircuitOpen = errors.New("circuit breaker is open: python engine temporarily unavailable")
	ErrTimeout     = errors.New("python engine request timed out")
)

// CircuitState represents the operational health state of the connector.
type CircuitState int

const (
	StateClosed CircuitState = iota
	StateHalfOpen
	StateOpen
)

func (s CircuitState) String() string {
	switch s {
	case StateClosed:
		return "CLOSED"
	case StateHalfOpen:
		return "HALF_OPEN"
	case StateOpen:
		return "OPEN"
	default:
		return "UNKNOWN"
	}
}

// CircuitBreaker guards against cascading failures when the Python Engine is degraded.
type CircuitBreaker struct {
	mu              sync.RWMutex
	state           CircuitState
	failureCount    int
	maxFailures     int
	cooldownPeriod  time.Duration
	lastStateChange time.Time
}

func NewCircuitBreaker(maxFailures int, cooldown time.Duration) *CircuitBreaker {
	return &CircuitBreaker{
		state:          StateClosed,
		maxFailures:    maxFailures,
		cooldownPeriod: cooldown,
	}
}

func (cb *CircuitBreaker) AllowRequest() bool {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	now := time.Now()
	if cb.state == StateOpen {
		if now.Sub(cb.lastStateChange) > cb.cooldownPeriod {
			cb.state = StateHalfOpen
			cb.lastStateChange = now
			log.Println("[CircuitBreaker] Transitioning from OPEN to HALF_OPEN (probing engine health)")
			return true
		}
		return false
	}
	return true
}

func (cb *CircuitBreaker) RecordSuccess() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	if cb.state != StateClosed {
		log.Printf("[CircuitBreaker] Engine recovered! Transitioning from %s to CLOSED", cb.state)
	}
	cb.state = StateClosed
	cb.failureCount = 0
}

func (cb *CircuitBreaker) RecordFailure() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failureCount++
	if cb.state == StateHalfOpen || cb.failureCount >= cb.maxFailures {
		cb.state = StateOpen
		cb.lastStateChange = time.Now()
		log.Printf("[CircuitBreaker] Tripped! Transitioning to OPEN (failures: %d)", cb.failureCount)
	}
}

func (cb *CircuitBreaker) State() CircuitState {
	cb.mu.RLock()
	defer cb.mu.RUnlock()
	return cb.state
}

func (cb *CircuitBreaker) Reset() {
	cb.mu.Lock()
	defer cb.mu.Unlock()
	cb.state = StateClosed
	cb.failureCount = 0
	cb.lastStateChange = time.Time{}
}

// EngineClient handles communication with the Python AI Engine.
type EngineClient struct {
	baseURL    string
	httpClient *http.Client
	cb         *CircuitBreaker
}

func NewEngineClient(baseURL string) *EngineClient {
	if baseURL == "" {
		baseURL = "http://localhost:8000"
	}
	return &EngineClient{
		baseURL: baseURL,
		httpClient: &http.Client{
			Timeout: 3 * time.Second,
		},
		cb: NewCircuitBreaker(3, 10*time.Second),
	}
}

func (ec *EngineClient) SetHTTPClient(client *http.Client) {
	ec.httpClient = client
}

func (ec *EngineClient) CircuitBreaker() *CircuitBreaker {
	return ec.cb
}

// --- DTOs matching Python Engine routes ---

type EngineForecastResponse struct {
	Location struct {
		Lat float64 `json:"lat"`
		Lng float64 `json:"lng"`
	} `json:"location"`
	Model     string           `json:"model"`
	Forecasts []EngineForecast `json:"forecasts"`
}

type EngineForecast struct {
	Timestamp                string  `json:"timestamp"`
	TemperatureC             float64 `json:"temperature_c"`
	HumidityPct              float64 `json:"humidity_pct"`
	HeatIndexC               float64 `json:"heat_index_c"`
	PrecipitationRateMmHr    float64 `json:"precipitation_rate_mm_hr"`
	PrecipitationProbability float64 `json:"precipitation_probability"`
	WindSpeedKmh             float64 `json:"wind_speed_kmh"`
	WindGustKmh              float64 `json:"wind_gust_kmh"`
	Condition                string  `json:"condition"`
}

type EngineCanalsResponse struct {
	Canals []EngineCanal `json:"canals"`
}

type EngineCanal struct {
	StationID         string  `json:"station_id"`
	CanalName         string  `json:"canal_name"`
	Location          string  `json:"location"`
	WaterLevelM       float64 `json:"water_level_m"`
	BankHeightM       float64 `json:"bank_height_m"`
	MarginToOverflowM float64 `json:"margin_to_overflow_m"`
	Status            string  `json:"status"`
}

type EngineRadarResponse struct {
	MaxReflectivityDbz float64 `json:"max_reflectivity_dbz"`
	StormCellCount     int     `json:"storm_cell_count"`
	PrimaryStormVector struct {
		MovementDirectionDeg    float64        `json:"movement_direction_deg"`
		SpeedKmh                float64        `json:"speed_kmh"`
		EstimatedArrivalMinutes map[string]int `json:"estimated_arrival_minutes"`
	} `json:"primary_storm_vector"`
	Timestamp string `json:"timestamp"`
}

type EngineCalendarSyncRequest struct {
	UserID        string `json:"user_id"`
	Name          string `json:"name"`
	TransportMode string `json:"transport_mode"`
}

type EngineCalendarSyncResponse struct {
	UserID                   string                    `json:"user_id"`
	TotalEventsChecked       int                       `json:"total_events_checked"`
	EventsWithWeatherHazards int                       `json:"events_with_weather_hazards"`
	ProactiveAdvisories      []EngineProactiveAdvisory `json:"proactive_advisories"`
}

type EngineProactiveAdvisory struct {
	EventID     string `json:"event_id"`
	EventTitle  string `json:"event_title"`
	Urgency     string `json:"urgency"`
	ConcernType string `json:"concern_type"`
	Advisory    struct {
		Headline                string `json:"headline"`
		Reasoning               string `json:"reasoning"`
		ProactiveRecommendation string `json:"proactive_recommendation"`
		DepartureAdjustmentMins int    `json:"departure_adjustment_mins"`
		RecommendedActionType   string `json:"recommended_action_type"`
	} `json:"advisory"`
}

// executeRequest performs an HTTP call wrapped in CircuitBreaker protection.
func (ec *EngineClient) executeRequest(ctx context.Context, method, endpoint string, reqBody interface{}, target interface{}) error {
	if !ec.cb.AllowRequest() {
		return ErrCircuitOpen
	}

	reqURL := fmt.Sprintf("%s%s", ec.baseURL, endpoint)
	var bodyReader io.Reader
	if reqBody != nil {
		data, err := json.Marshal(reqBody)
		if err != nil {
			return err
		}
		bodyReader = bytes.NewReader(data)
	}

	reqCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()

	httpReq, err := http.NewRequestWithContext(reqCtx, method, reqURL, bodyReader)
	if err != nil {
		return err
	}
	if reqBody != nil {
		httpReq.Header.Set("Content-Type", "application/json")
	}

	resp, err := ec.httpClient.Do(httpReq)
	if err != nil {
		ec.cb.RecordFailure()
		return fmt.Errorf("engine request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		ec.cb.RecordFailure()
		return fmt.Errorf("engine returned HTTP %d", resp.StatusCode)
	}

	if err := json.NewDecoder(resp.Body).Decode(target); err != nil {
		ec.cb.RecordFailure()
		return fmt.Errorf("decoding engine response: %w", err)
	}

	ec.cb.RecordSuccess()
	return nil
}

// ResolveWeatherAdvisory fetches live WeatherNext 3 telemetry or transparently falls back.
func (ec *EngineClient) ResolveWeatherAdvisory(ctx context.Context, user model.UserProfile) model.AdvisoryPayload {
	lat := user.HomeLocation.Latitude
	lng := user.HomeLocation.Longitude
	if lat == 0 && lng == 0 {
		lat, lng = 13.7563, 100.5018 // Default Bangkok Center
	}

	endpoint := fmt.Sprintf("/api/v1/forecast?lat=%.4f&lng=%.4f&hours=12", lat, lng)
	var resp EngineForecastResponse

	if err := ec.executeRequest(ctx, http.MethodGet, endpoint, nil, &resp); err != nil {
		log.Printf("[EngineClient] Weather forecast failed (%v). Serving baseline fallback.", err)
		return FallbackWeatherAdvisory(user)
	}

	if len(resp.Forecasts) == 0 {
		return FallbackWeatherAdvisory(user)
	}

	fc := resp.Forecasts[0]
	urgency := "INFO"
	if fc.PrecipitationRateMmHr >= 35.0 || fc.WindGustKmh >= 55.0 {
		urgency = "CRITICAL"
	} else if fc.PrecipitationRateMmHr >= 15.0 || fc.WindGustKmh >= 35.0 {
		urgency = "WARNING"
	} else if fc.PrecipitationRateMmHr > 2.0 {
		urgency = "ADVISORY"
	}

	locName := user.HomeLocation.Name
	if locName == "" {
		locName = "กรุงเทพมหานคร"
	}

	summary := fmt.Sprintf("ตรวจพบกลุ่มฝนฟ้าคะนองในพื้นที่ อัตราฝนตก %.1f มม./ชม. ความเร็วลมกระโชก %.1f กม./ชม.", fc.PrecipitationRateMmHr, fc.WindGustKmh)
	if fc.PrecipitationRateMmHr < 2.0 {
		summary = fmt.Sprintf("สภาพอากาศปกติ ท้องฟ้าโปร่งถึงมีเมฆบางส่วน อุณหภูมิ %.1f°C", fc.TemperatureC)
	}

	return model.AdvisoryPayload{
		Title:          "พยากรณ์อากาศ WeatherNext 3 (5km Grid)",
		UrgencyLevel:   urgency,
		SummaryText:    summary,
		CriticalWindow: "17:00 - 19:30 น.",
		LocationName:   locName,
		Temperature:    fc.TemperatureC,
		Condition:      fc.Condition,
		RainRate:       fc.PrecipitationRateMmHr,
		HeatIndex:      fc.HeatIndexC,
		WindGust:       fc.WindGustKmh,
		VehicleType:    user.TransportMode,
		ActionChecklist: []string{
			"ตรวจสอบระบบที่ปัดน้ำฝนและไฟส่องสว่าง",
			"ชะลอความเร็วขณะขับขี่และเว้นระยะห่างปลอดภัย",
			"หลีกเลี่ยงจุดเสี่ยงน้ำท่วมขังบนผิวจราจร",
		},
		AlternativeRoutesOrActions: "แนะนำใช้ทางด่วนศรีรัช หรือพักคอยในอาคาร 30 นาที",
		TabDestination:             "dashboard",
	}
}

// ResolveFloodAdvisory fetches live canal & radar telemetry or transparently falls back.
func (ec *EngineClient) ResolveFloodAdvisory(ctx context.Context, user model.UserProfile) model.AdvisoryPayload {
	var canalsResp EngineCanalsResponse
	var radarResp EngineRadarResponse

	err1 := ec.executeRequest(ctx, http.MethodGet, "/api/v1/canals", nil, &canalsResp)
	err2 := ec.executeRequest(ctx, http.MethodGet, "/api/v1/radar", nil, &radarResp)

	if err1 != nil || err2 != nil {
		log.Printf("[EngineClient] Flood telemetry failed (canals: %v, radar: %v). Serving baseline fallback.", err1, err2)
		return FallbackFloodAdvisory(user)
	}

	primaryCanal := EngineCanal{
		CanalName:         "คลองแสนแสบ",
		Location:          "ประตูระบายน้ำวิทยุ-อโศก",
		WaterLevelM:       0.85,
		BankHeightM:       1.10,
		MarginToOverflowM: 0.25,
		Status:            "WARNING",
	}
	if len(canalsResp.Canals) > 0 {
		primaryCanal = canalsResp.Canals[0]
	}

	rainRate := 18.0
	if radarResp.MaxReflectivityDbz >= 50 {
		rainRate = 35.0
	} else if radarResp.MaxReflectivityDbz >= 40 {
		rainRate = 20.0
	}

	urgency := "ADVISORY"
	remainingCm := primaryCanal.MarginToOverflowM * 100
	if primaryCanal.Status == "CRITICAL" || remainingCm < 15 {
		urgency = "CRITICAL"
	} else if primaryCanal.Status == "WARNING" || remainingCm < 30 {
		urgency = "WARNING"
	}

	return model.AdvisoryPayload{
		Title:            "รายงานระดับน้ำคลองและจุดเสี่ยงน้ำท่วม กทม.",
		UrgencyLevel:     urgency,
		SummaryText:      fmt.Sprintf("%s ระดับน้ำ %.2f ม.รทก. เหลือระยะปลอดภัย %.0f ซม. เรดาร์ตรวจพบฝนสะท้อน %.1f dBZ", primaryCanal.CanalName, primaryCanal.WaterLevelM, remainingCm, radarResp.MaxReflectivityDbz),
		CriticalWindow:   "17:30 - 20:00 น.",
		LocationName:     primaryCanal.Location,
		CanalName:        primaryCanal.CanalName,
		CanalStage:       primaryCanal.WaterLevelM,
		CanalRemainingCm: remainingCm,
		RainRate:         rainRate,
		WindGust:         38.0,
		HeatIndex:        32.5,
		FloodDepthCm:     15.0,
		VehicleType:      user.TransportMode,
		ActionChecklist: []string{
			"หลีกเลี่ยงถนนอโศกมนตรี, รัชดาภิเษก, ลาดพร้าว",
			"ยกสิ่งของขึ้นที่สูงบริเวณชุมชนริมคลอง",
			"เฝ้าระวังการระบายน้ำของสถานีสูบน้ำ",
		},
		AlternativeRoutesOrActions: "แนะนำใช้รถไฟฟ้า BTS/MRT หรือเลี่ยงไปใช้ถนนพระราม 9",
		TabDestination:             "dashboard",
		ExtraParams:                "focus=hazard",
	}
}

// ResolveCalendarAdvisory queries calendar hazard evaluations or transparently falls back.
func (ec *EngineClient) ResolveCalendarAdvisory(ctx context.Context, user model.UserProfile) model.AdvisoryPayload {
	req := EngineCalendarSyncRequest{
		UserID:        user.UserID,
		Name:          user.DisplayName,
		TransportMode: user.TransportMode,
	}
	var resp EngineCalendarSyncResponse

	if err := ec.executeRequest(ctx, http.MethodPost, "/api/v1/calendar/sync_and_evaluate", req, &resp); err != nil {
		log.Printf("[EngineClient] Calendar sync failed (%v). Serving baseline fallback.", err)
		return FallbackCalendarAdvisory(user)
	}

	if resp.EventsWithWeatherHazards > 0 && len(resp.ProactiveAdvisories) > 0 {
		adv := resp.ProactiveAdvisories[0]
		return model.AdvisoryPayload{
			Title:          "การประเมินสภาพอากาศตารางนัดหมาย (Google Calendar)",
			UrgencyLevel:   adv.Urgency,
			SummaryText:    fmt.Sprintf("นัดหมาย '%s': %s (%s)", adv.EventTitle, adv.Advisory.Headline, adv.Advisory.Reasoning),
			CriticalWindow: fmt.Sprintf("แนะนำปรับเวลาเดินทางเร็วขึ้น %d นาที", adv.Advisory.DepartureAdjustmentMins),
			LocationName:   adv.EventTitle,
			RainRate:       25.0,
			WindGust:       35.0,
			HeatIndex:      32.0,
			VehicleType:    user.TransportMode,
			ActionChecklist: []string{
				adv.Advisory.ProactiveRecommendation,
				"ตรวจสอบจุดจอดรถในร่ม ณ สถานที่นัดหมาย",
				"พิจารณาใช้ระบบขนส่งมวลชน (BTS/MRT) เพื่อหลีกเลี่ยงน้ำท่วมขัง",
			},
			AlternativeRoutesOrActions: "แนะนำปรับเวลาเดินทางเร็วขึ้น หรือสลับเป็นการประชุมออนไลน์ผ่าน Google Meet",
			TabDestination:             "calendar",
			ExtraParams:                "tab=calendar",
		}
	}

	return model.AdvisoryPayload{
		Title:        "ตารางนัดหมายปลอดภัย (Google Calendar)",
		UrgencyLevel: "INFO",
		SummaryText:  "ตรวจสอบแล้ว ตารางนัดหมายของคุณวันนี้ไม่พบความเสี่ยงสภาพอากาศรุนแรงหรือน้ำท่วมขัง",
		VehicleType:  user.TransportMode,
		ActionChecklist: []string{
			"เดินทางตามกำหนดการปกติ",
			"เปิดการแจ้งเตือนพยากรณ์อากาศแบบเรียลไทม์",
		},
		TabDestination: "calendar",
		ExtraParams:    "tab=calendar",
	}
}

// --- Fallback Baseline Bangkok Telemetry ---

func FallbackWeatherAdvisory(user model.UserProfile) model.AdvisoryPayload {
	return model.AdvisoryPayload{
		Title:          "พยากรณ์อากาศและเรดาร์ฝน กทม. (ระบบสำรอง)",
		UrgencyLevel:   "WARNING",
		SummaryText:    "เรดาร์ตรวจพบกลุ่มฝนฟ้าคะนองกำลังเคลื่อนตัวเข้าสู่กรุงเทพฯ ชั้นใน อัตราฝน 18.5 มม./ชม. (ข้อมูลสำรองอัตโนมัติ)",
		CriticalWindow: "17:00 - 19:30 น.",
		LocationName:   "กรุงเทพมหานคร (สุขุมวิท / อโศก)",
		Temperature:    28.5,
		Condition:      "พายุฝนฟ้าคะนองกระจายตัว",
		RainRate:       18.5,
		HeatIndex:      33.2,
		WindGust:       42.0,
		VehicleType:    user.TransportMode,
		VehicleImpact:  "ถนนเปียกลื่น ทัศนวิสัยลดลง ตรวจสอบแรงดันลมยางและที่ปัดน้ำฝน",
		ActionChecklist: []string{
			"ตรวจสอบระบบที่ปัดน้ำฝนและไฟส่องสว่าง",
			"หลีกเลี่ยงเส้นทางจุดเสี่ยงน้ำท่วมขังผิวจราจร",
			"ชะลอความเร็วขณะขับขี่และเว้นระยะห่างปลอดภัย",
		},
		AlternativeRoutesOrActions: "แนะนำใช้ทางด่วนศรีรัช หรือพักคอยในอาคาร 30-45 นาที",
		TabDestination:             "dashboard",
	}
}

func FallbackFloodAdvisory(user model.UserProfile) model.AdvisoryPayload {
	return model.AdvisoryPayload{
		Title:            "รายงานระดับน้ำคลองและจุดเสี่ยงน้ำท่วม (ระบบสำรอง)",
		UrgencyLevel:     "WARNING",
		SummaryText:      "คลองแสนแสบระดับน้ำ 0.85 ม.รทก. เหลือระยะปลอดภัย 25 ซม. จุดเสี่ยงอโศก-รัชดา เฝ้าระวังน้ำท่วมขัง (ข้อมูลสำรองอัตโนมัติ)",
		CriticalWindow:   "17:30 - 20:00 น.",
		LocationName:     "คลองแสนแสบ / อโศกมนตรี",
		CanalName:        "คลองแสนแสบ",
		CanalStage:       0.85,
		CanalRemainingCm: 25.0,
		RainRate:         22.0,
		WindGust:         38.0,
		HeatIndex:        32.5,
		FloodDepthCm:     15.0,
		VehicleType:      user.TransportMode,
		VehicleImpact:    "ระดับน้ำรอระบาย 10-15 ซม. สุ่มเสี่ยงสำหรับรถเก๋งเตี้ยและมอเตอร์ไซค์",
		ActionChecklist: []string{
			"หลีกเลี่ยงถนนอโศกมนตรี, รัชดาภิเษก, ลาดพร้าว",
			"ยกสิ่งของขึ้นที่สูงบริเวณชุมชนริมคลอง",
			"เฝ้าระวังระดับน้ำหนุนในคลองสายหลัก",
		},
		AlternativeRoutesOrActions: "แนะนำใช้รถไฟฟ้า BTS/MRT หรือเลี่ยงไปใช้ถนนพระราม 9",
		TabDestination:             "dashboard",
		ExtraParams:                "focus=hazard",
	}
}

func FallbackCalendarAdvisory(user model.UserProfile) model.AdvisoryPayload {
	return model.AdvisoryPayload{
		Title:          "การประเมินสภาพอากาศตารางนัดหมาย (ระบบสำรอง)",
		UrgencyLevel:   "ADVISORY",
		SummaryText:    "ตรวจพบความเสี่ยงฝนตกหนักในช่วงเวลานัดหมายช่วงเย็น แนะนำออกเดินทางล่วงหน้า 30 นาที (ข้อมูลสำรองอัตโนมัติ)",
		CriticalWindow: "16:30 - 18:30 น.",
		LocationName:   "พื้นที่นัดหมาย กรุงเทพฯ",
		RainRate:       15.0,
		WindGust:       30.0,
		HeatIndex:      32.0,
		VehicleType:    user.TransportMode,
		VehicleImpact:  "การจราจรติดขัดสะสมและฝนตกหนัก แนะนำเผื่อเวลาเดินทางอย่างน้อย 30-45 นาที",
		ActionChecklist: []string{
			"ออกเดินทางล่วงหน้าอย่างน้อย 30 นาที",
			"พกพาอุปกรณ์กันฝนและตรวจสอบที่จอดรถในร่ม",
			"พิจารณาเปลี่ยนเป็นประชุมออนไลน์ผ่าน Google Meet",
		},
		AlternativeRoutesOrActions: "สลับเป็นประชุมออนไลน์ หรือใช้เส้นทางระบบราง (BTS/MRT)",
		TabDestination:             "calendar",
		ExtraParams:                "tab=calendar",
	}
}
