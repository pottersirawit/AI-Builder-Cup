package model

import "time"

// UserProfile represents a registered citizen on LINE OA / LIFF
type UserProfile struct {
	UserID             string           `json:"user_id"`
	DisplayName        string           `json:"display_name"`
	TransportMode      string           `json:"transport_mode"` // compact_sedan, motorcycle, pickup, pedestrian
	HomeLocation       Location         `json:"home_location"`
	WorkLocation       Location         `json:"work_location"`
	CurrentLocation    Location         `json:"current_location"`
	CommuteMorningTime string           `json:"commute_morning_time"` // e.g. "07:30"
	CommuteEveningTime string           `json:"commute_evening_time"` // e.g. "17:30"
	AlertPreferences   AlertPreferences `json:"alert_preferences"`
	CreatedAt          time.Time        `json:"created_at"`
	UpdatedAt          time.Time        `json:"updated_at"`
}

type Location struct {
	Name      string  `json:"name"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type AlertPreferences struct {
	EnableDailyBriefing bool   `json:"enable_daily_briefing"`
	EnableUrgentNowcast bool   `json:"enable_urgent_nowcast"`
	MinUrgencyLevel     string `json:"min_urgency_level"` // INFO, ADVISORY, WARNING, CRITICAL
}

// AdvisoryPayload is received from Python Engine and rendered into Apple Spatial Flex messages
type AdvisoryPayload struct {
	Title                      string   `json:"title"`
	UrgencyLevel               string   `json:"urgency_level"` // CRITICAL, WARNING, ADVISORY, INFO
	SummaryText                string   `json:"summary_text"`
	CriticalWindow             string   `json:"critical_window,omitempty"`
	VehicleImpact              string   `json:"vehicle_impact,omitempty"`
	ActionChecklist            []string `json:"action_checklist,omitempty"`
	AlternativeRoutesOrActions string   `json:"alternative_routes_or_actions,omitempty"`

	// Enriched Telemetry & Context (Theme 1: Apple Spatial Weather)
	LocationName     string  `json:"location_name,omitempty"`      // e.g. "สุขุมวิท 21 (อโศกมนตรี)"
	Temperature      float64 `json:"temperature,omitempty"`        // °C, e.g. 28.0
	Condition        string  `json:"condition,omitempty"`          // e.g. "พายุฝนฟ้าคะนองรุนแรง"
	WeatherCondition string  `json:"weather_condition,omitempty"`  // alias for Condition
	RainRate         float64 `json:"rain_rate,omitempty"`          // mm/h
	RainRateMmHr     float64 `json:"rain_rate_mm_hr,omitempty"`    // alias for RainRate
	CanalName        string  `json:"canal_name,omitempty"`         // e.g. "คลองแสนแสบ"
	CanalStage       float64 `json:"canal_stage,omitempty"`        // m MSL
	CanalStageMMSL   float64 `json:"canal_stage_m_msl,omitempty"`  // alias for CanalStage
	CanalRemainingCm float64 `json:"canal_remaining_cm,omitempty"` // cm, e.g. 25.0
	HeatIndex        float64 `json:"heat_index,omitempty"`         // °C
	HeatIndexC       float64 `json:"heat_index_c,omitempty"`       // alias for HeatIndex
	WindGust         float64 `json:"wind_gust,omitempty"`          // km/h
	WindGustKmh      float64 `json:"wind_gust_kmh,omitempty"`      // alias for WindGust
	VehicleType      string  `json:"vehicle_type,omitempty"`       // sedan, moto, pickup, transit
	VehicleMode      string  `json:"vehicle_mode,omitempty"`       // alias for VehicleType
	FloodDepthCm     float64 `json:"flood_depth_cm,omitempty"`     // cm
	WaterDepthCM     float64 `json:"water_depth_cm,omitempty"`     // alias for FloodDepthCm
	LIFFURL          string  `json:"liff_url,omitempty"`           // Full or base LIFF URL
	LiffBaseURL      string  `json:"liff_base_url,omitempty"`      // alias for LIFFURL
	TabDestination   string  `json:"tab_destination,omitempty"`    // dashboard, calendar, profile
	ExtraParams      string  `json:"extra_params,omitempty"`       // e.g. "focus=hazard", "vehicle=motorcycle"
}

// GetLocationName returns location name with fallback
func (a AdvisoryPayload) GetLocationName() string {
	if a.LocationName != "" {
		return a.LocationName
	}
	return "กรุงเทพมหานคร"
}

// GetTemperature returns temperature with fallback
func (a AdvisoryPayload) GetTemperature() float64 {
	if a.Temperature != 0 {
		return a.Temperature
	}
	return 28.0
}

// GetCondition returns weather condition with fallback
func (a AdvisoryPayload) GetCondition() string {
	if a.Condition != "" {
		return a.Condition
	}
	if a.WeatherCondition != "" {
		return a.WeatherCondition
	}
	return "พายุฝนฟ้าคะนองรุนแรง"
}

// GetRainRate returns rain rate with fallback
func (a AdvisoryPayload) GetRainRate() float64 {
	if a.RainRate != 0 {
		return a.RainRate
	}
	if a.RainRateMmHr != 0 {
		return a.RainRateMmHr
	}
	return 0.0
}

// GetCanalName returns canal name with fallback
func (a AdvisoryPayload) GetCanalName() string {
	if a.CanalName != "" {
		return a.CanalName
	}
	return "คลองแสนแสบ"
}

// GetCanalStage returns canal stage with fallback
func (a AdvisoryPayload) GetCanalStage() float64 {
	if a.CanalStage != 0 {
		return a.CanalStage
	}
	if a.CanalStageMMSL != 0 {
		return a.CanalStageMMSL
	}
	return 0.0
}

// GetCanalRemainingCm returns canal remaining cm with fallback
func (a AdvisoryPayload) GetCanalRemainingCm() float64 {
	if a.CanalRemainingCm != 0 {
		return a.CanalRemainingCm
	}
	stage := a.GetCanalStage()
	if stage > 0 {
		remaining := (1.10 - stage) * 100
		if remaining < 0 {
			remaining = 0
		}
		return remaining
	}
	return 25.0
}

// GetHeatIndex returns heat index with fallback
func (a AdvisoryPayload) GetHeatIndex() float64 {
	if a.HeatIndex != 0 {
		return a.HeatIndex
	}
	if a.HeatIndexC != 0 {
		return a.HeatIndexC
	}
	return 0.0
}

// GetWindGust returns wind gust with fallback
func (a AdvisoryPayload) GetWindGust() float64 {
	if a.WindGust != 0 {
		return a.WindGust
	}
	if a.WindGustKmh != 0 {
		return a.WindGustKmh
	}
	return 0.0
}

// GetVehicleType returns normalized vehicle mode with fallback
func (a AdvisoryPayload) GetVehicleType() string {
	if a.VehicleType != "" {
		return a.VehicleType
	}
	if a.VehicleMode != "" {
		return a.VehicleMode
	}
	return "compact_sedan"
}

// GetFloodDepth returns flood depth in cm with fallback
func (a AdvisoryPayload) GetFloodDepth() float64 {
	if a.FloodDepthCm != 0 {
		return a.FloodDepthCm
	}
	if a.WaterDepthCM != 0 {
		return a.WaterDepthCM
	}
	return 0.0
}

// GetLIFFURL returns base or full LIFF URL
func (a AdvisoryPayload) GetLIFFURL() string {
	if a.LIFFURL != "" {
		return a.LIFFURL
	}
	if a.LiffBaseURL != "" {
		return a.LiffBaseURL
	}
	return ""
}

// AlertDispatchJob represents a task queued for the worker pool
type AlertDispatchJob struct {
	UserID   string          `json:"user_id"`
	Payload  AdvisoryPayload `json:"payload"`
	QueuedAt time.Time       `json:"queued_at"`
}
