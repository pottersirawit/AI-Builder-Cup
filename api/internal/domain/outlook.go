package domain

import (
	"context"
	"time"
)

// OutlookHour is the weather for one hour (or, for Outlook.Now, the current
// moment): what to carry today, not whether a trip is safe.
type OutlookHour struct {
	Time        time.Time `json:"time"`
	TempC       float64   `json:"temp_c"`
	FeelsLikeC  float64   `json:"feels_like_c"`
	UVIndex     int       `json:"uv_index"`
	RainProbPct int       `json:"rain_prob_pct"`
	RainMMPerHr float64   `json:"rain_mm_per_hr"`
	HumidityPct int       `json:"humidity_pct"`
	WindKPH     float64   `json:"wind_kph"`
	// Condition is a Google Weather weatherCondition.type such as PARTLY_CLOUDY.
	Condition string `json:"condition"`
	// ConditionText is the short description in the request language; the
	// JSON key stays condition_th in English too.
	ConditionText string `json:"condition_th"`
}

// Outlook is the hourly weather from the current hour on, for /v1/outlook.
type Outlook struct {
	Now     OutlookHour   `json:"now"`
	Hours   []OutlookHour `json:"hours"`
	Sunset  time.Time     `json:"sunset,omitzero"`
	Sources []string      `json:"sources"`
}

// OutlookHours is how many hours an outlook covers.
const OutlookHours = 12

// OutlookProvider forecasts the next OutlookHours hours at a point from the
// hour containing from, with condition text in l.
type OutlookProvider interface {
	Outlook(ctx context.Context, at LatLng, from time.Time, l Lang) (Outlook, error)
	Name() string
}

var conditionText = map[string][2]string{
	"CLEAR":              {"ท้องฟ้าแจ่มใส", "Clear"},
	"MOSTLY_CLEAR":       {"ท้องฟ้าโปร่งเป็นส่วนใหญ่", "Mostly clear"},
	"PARTLY_CLOUDY":      {"มีเมฆบางส่วน", "Partly cloudy"},
	"MOSTLY_CLOUDY":      {"มีเมฆเป็นส่วนมาก", "Mostly cloudy"},
	"CLOUDY":             {"เมฆมาก", "Cloudy"},
	"LIGHT_RAIN":         {"ฝนตกเล็กน้อย", "Light rain"},
	"RAIN":               {"ฝนตก", "Rain"},
	"HEAVY_RAIN":         {"ฝนตกหนัก", "Heavy rain"},
	"RAIN_SHOWERS":       {"ฝนตกเป็นช่วง", "Rain showers"},
	"SCATTERED_SHOWERS":  {"ฝนตกกระจาย", "Scattered showers"},
	"THUNDERSTORM":       {"พายุฝนฟ้าคะนอง", "Thunderstorm"},
	"HEAVY_THUNDERSTORM": {"พายุฝนฟ้าคะนองรุนแรง", "Heavy thunderstorm"},
}

// ConditionText is a short description of a weatherCondition.type in l, or
// "" for a type it does not know.
func ConditionText(condition string, l Lang) string {
	t, ok := conditionText[condition]
	if !ok {
		return ""
	}
	return l.Pick(t[0], t[1])
}
