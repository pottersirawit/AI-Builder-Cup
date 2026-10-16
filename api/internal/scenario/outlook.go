package scenario

import (
	"context"
	"math"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

// hourProfile is the storm day by hour of day: a hot, sunny afternoon, clouds
// building after 15:00, then the rain in rainBySlot. Rain, and the condition
// it implies, come from rainBySlot so the outlook agrees with /v1/decide.
type hourProfile struct {
	temp, feels float64
	uv, prob    int
	humidity    int
	wind        float64
	dry         string // condition when no rain falls in the hour
}

var dayProfile = [24]hourProfile{
	{27.0, 30.5, 0, 15, 86, 6, "MOSTLY_CLEAR"}, {26.8, 30.2, 0, 10, 87, 5, "CLEAR"}, {26.6, 29.8, 0, 10, 88, 5, "CLEAR"},
	{26.5, 29.6, 0, 10, 88, 5, "CLEAR"}, {26.4, 29.5, 0, 10, 89, 5, "CLEAR"}, {26.4, 29.5, 0, 10, 89, 5, "MOSTLY_CLEAR"},
	{26.7, 30.0, 0, 10, 87, 5, "MOSTLY_CLEAR"}, {27.8, 31.8, 1, 10, 82, 6, "MOSTLY_CLEAR"}, {29.4, 34.0, 3, 10, 75, 7, "MOSTLY_CLEAR"},
	{30.9, 36.2, 5, 10, 69, 8, "MOSTLY_CLEAR"}, {32.2, 38.0, 7, 10, 64, 9, "MOSTLY_CLEAR"}, {33.3, 39.4, 9, 10, 60, 10, "MOSTLY_CLEAR"},
	{34.1, 40.5, 10, 15, 58, 10, "MOSTLY_CLEAR"}, {34.6, 41.0, 10, 15, 57, 11, "PARTLY_CLOUDY"}, {34.4, 40.6, 9, 20, 58, 11, "PARTLY_CLOUDY"},
	{33.9, 39.8, 8, 30, 61, 12, "PARTLY_CLOUDY"}, {33.4, 39.1, 5, 45, 66, 14, "MOSTLY_CLOUDY"}, {30.6, 36.0, 2, 85, 76, 20, "CLOUDY"},
	{27.8, 31.5, 0, 100, 94, 26, "CLOUDY"}, {27.4, 30.8, 0, 90, 93, 18, "CLOUDY"}, {27.3, 30.6, 0, 60, 91, 12, "CLOUDY"},
	{27.0, 30.2, 0, 95, 95, 22, "CLOUDY"}, {26.9, 30.0, 0, 80, 94, 15, "CLOUDY"}, {26.9, 30.0, 0, 40, 90, 10, "MOSTLY_CLOUDY"},
}

// sunset is when the sun sets over Bangkok at the end of September.
func sunset(day time.Time) time.Time { return at(day, 18, 10) }

// Outlook replays the storm day's hourly weather. Like Weather it is the same
// at every point and keyed by time of day.
type Outlook struct{}

func (Outlook) Name() string { return "Google Weather API (scenario)" }

func (o Outlook) Outlook(_ context.Context, _ domain.LatLng, from time.Time, l domain.Lang) (domain.Outlook, error) {
	from = from.In(domain.Bangkok)
	start := from.Truncate(time.Hour)
	out := domain.Outlook{Sunset: sunset(dayOf(from)), Sources: []string{o.Name()}}
	for i := range domain.OutlookHours {
		t := start.Add(time.Duration(i) * time.Hour)
		var sum float64
		for m := 0; m < 60; m += 15 {
			sum += RainAt(t.Add(time.Duration(m) * time.Minute))
		}
		out.Hours = append(out.Hours, outlookHour(t, sum/4, l))
	}
	// Now is this minute: the hour's profile with the rain falling right now.
	out.Now = outlookHour(from.Truncate(time.Minute), RainAt(from), l)
	return out, nil
}

func outlookHour(t time.Time, rain float64, l domain.Lang) domain.OutlookHour {
	p := dayProfile[t.Hour()]
	cond := p.dry
	switch {
	case rain >= 10:
		cond = "THUNDERSTORM"
	case rain >= 2.5:
		cond = "RAIN"
	case rain > 0:
		cond = "LIGHT_RAIN"
	}
	return domain.OutlookHour{
		Time: t, TempC: p.temp, FeelsLikeC: p.feels, UVIndex: p.uv, RainProbPct: p.prob, RainMMPerHr: math.Round(rain*10) / 10,
		HumidityPct: p.humidity, WindKPH: p.wind, Condition: cond, ConditionText: domain.ConditionText(cond, l),
	}
}
