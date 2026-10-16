package scenario

import (
	"context"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

func TestOutlookFollowsTheStormDay(t *testing.T) {
	now := time.Date(2026, 9, 29, 13, 30, 0, 0, domain.Bangkok)
	o, err := Outlook{}.Outlook(context.Background(), Home.Point(), now, domain.LangTH)
	if err != nil {
		t.Fatal(err)
	}
	if len(o.Hours) != 12 {
		t.Fatalf("got %d hours", len(o.Hours))
	}
	if first := o.Hours[0].Time; !first.Equal(time.Date(2026, 9, 29, 13, 0, 0, 0, domain.Bangkok)) {
		t.Errorf("first hour = %v", first)
	}
	for _, h := range o.Hours[:2] {
		if h.UVIndex < 8 {
			t.Errorf("%s UV = %d, want >= 8", h.Time.Format("15:04"), h.UVIndex)
		}
	}
	byHour := map[int]domain.OutlookHour{}
	for _, h := range o.Hours {
		byHour[h.Time.Hour()] = h
	}
	storm := byHour[18]
	if storm.RainProbPct < 80 || storm.RainMMPerHr < 20 || storm.TempC > 29 || storm.UVIndex != 0 {
		t.Errorf("18:00 = %+v, want the storm", storm)
	}
	if byHour[16].RainMMPerHr != 0 || byHour[16].UVIndex >= byHour[14].UVIndex {
		t.Errorf("16:00 = %+v, want dry with UV falling", byHour[16])
	}
	if o.Sunset.IsZero() || o.Sunset.Hour() != 18 {
		t.Errorf("sunset = %v", o.Sunset)
	}
	if o.Now.Condition == "" || o.Now.ConditionText == "" || !domain.HasThai(o.Now.ConditionText) {
		t.Errorf("now = %+v, want Thai condition text", o.Now)
	}
	en, _ := Outlook{}.Outlook(context.Background(), Home.Point(), now, domain.LangEN)
	if domain.HasThai(en.Hours[5].ConditionText) || en.Hours[5].ConditionText == "" {
		t.Errorf("English condition = %q", en.Hours[5].ConditionText)
	}
}
