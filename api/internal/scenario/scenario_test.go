package scenario

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
)

func demo(hh, mm int) time.Time { return time.Date(2026, 9, 29, hh, mm, 0, 0, domain.Bangkok) }

func TestRainScript(t *testing.T) {
	tests := []struct {
		at      time.Time
		atLeast float64
		below   float64
	}{
		{demo(16, 10), 0, 0.01},
		{demo(17, 20), 0, 1},   // still dry enough before the cell
		{demo(17, 30), 1, 10},  // rain reaches Rama 4
		{demo(18, 20), 30, 99}, // peak
		{demo(19, 20), 1, 10},  // eased
		{demo(20, 10), 0, 0.01},
	}
	for _, tt := range tests {
		t.Run(tt.at.Format("15:04"), func(t *testing.T) {
			if got := RainAt(tt.at); got < tt.atLeast || got >= tt.below {
				t.Fatalf("RainAt = %v, want in [%v, %v)", got, tt.atLeast, tt.below)
			}
		})
	}
	samples, _ := Weather{}.Rain(context.Background(), Silom.Point(), demo(16, 10), demo(21, 0))
	if len(samples) != 21 || !samples[0].Time.Equal(demo(16, 0)) {
		t.Fatalf("got %d samples starting %v", len(samples), samples[0].Time)
	}
}

func TestCanalScript(t *testing.T) {
	tests := []struct {
		at     time.Time
		level  float64
		rise2h float64
	}{
		{demo(16, 10), 1.4, 0},
		{demo(21, 40), 1.8, 40},
	}
	for _, tt := range tests {
		got, _ := Canals{}.Canals(context.Background(), Home.Point(), tt.at)
		lp := got[0]
		if lp.NameTH != "คลองลาดพร้าว" || lp.LevelM != tt.level || lp.BankM != 1.8 || lp.RiseCM2h != tt.rise2h {
			t.Fatalf("%s: got %+v", tt.at.Format("15:04"), lp)
		}
	}
}

func TestHeroRouteDurations(t *testing.T) {
	r := Routes{}
	tests := []struct {
		mode   domain.Mode
		depart time.Time
		want   int
	}{
		{domain.ModeCar, demo(16, 10), 50}, // "ถ้าออกตอนนี้ถึงบ้านราว 17:00"
		{domain.ModeCar, demo(16, 45), 60}, // traffic builds
		{domain.ModeTransit, demo(16, 10), 40},
		{domain.ModeMoto, demo(16, 10), 30},
	}
	for _, tt := range tests {
		route, err := r.Route(context.Background(), Silom.Point(), Home.Point(), tt.mode, tt.depart)
		if err != nil || route.DurationMin != tt.want {
			t.Fatalf("%s at %s: got %d (%v), want %d", tt.mode, tt.depart.Format("15:04"), route.DurationMin, err, tt.want)
		}
	}
	car, _ := r.Route(context.Background(), Silom.Point(), Home.Point(), domain.ModeCar, demo(16, 10))
	if d := geo.DistanceToPolylineM(HeroReportPoint, car.Polyline); d > 50 {
		t.Fatalf("car corridor should pass the hero report point, is %.0f m away", d)
	}
}

func TestMockUsersCrossingHeroPoint(t *testing.T) {
	crossing := 0
	for _, u := range MockUsers() {
		if geo.DistanceToPolylineM(HeroReportPoint, u.Route) <= 300 {
			crossing++
		}
	}
	if crossing != 27 {
		t.Fatalf("crossing = %d, want 27", crossing)
	}
}

func TestTripsAreAnchoredToTheClockDay(t *testing.T) {
	trips := Trips(demo(16, 10))
	if trips[0].ID != "cal-dinner" || !trips[0].ArriveBy.Equal(demo(18, 30)) {
		t.Fatalf("got %+v", trips[0])
	}
	if trips[1].ArriveBy.Weekday() != time.Saturday {
		t.Fatalf("concert should be on Saturday, got %v", trips[1].ArriveBy)
	}
}

func TestTripsListTheUpcomingWeek(t *testing.T) {
	ids := func(now time.Time) []string {
		var out []string
		for _, tr := range Trips(now) {
			out = append(out, tr.ID)
		}
		return out
	}
	week := []string{"cal-standup", "cal-sync", "cal-lunch", "cal-review", "cal-pitch", "cal-yoga", "gmail-flight", "cal-checkup"}
	tests := []struct {
		name string
		now  time.Time
		want []string
	}{
		{"morning has the whole day", demo(8, 0), append([]string{"cal-dinner", "gmail-concert", "cal-client", "cal-gym"}, week...)},
		{"a meeting stays 10 minutes past its time", demo(14, 10), append([]string{"cal-dinner", "gmail-concert", "cal-client", "cal-gym"}, week...)},
		{"the demo clock has dropped the 14:00 meeting", demo(16, 10), append([]string{"cal-dinner", "gmail-concert", "cal-gym"}, week...)},
		{"late evening keeps only later days", demo(20, 41), append([]string{"cal-dinner", "gmail-concert"}, week...)},
	}
	for _, tt := range tests {
		if got := ids(tt.now); fmt.Sprint(got) != fmt.Sprint(tt.want) {
			t.Errorf("%s: got %v, want %v", tt.name, got, tt.want)
		}
	}
	for i, tr := range Trips(demo(8, 0))[3:] {
		if prev := Trips(demo(8, 0))[2+i]; tr.ArriveBy.Before(prev.ArriveBy) {
			t.Errorf("%s arrives before %s", tr.ID, prev.ID)
		}
	}
}

func TestTripsSayWhenTheyEnd(t *testing.T) {
	d1 := func(hh, mm int) time.Time { return demo(hh, mm).AddDate(0, 0, 1) }
	want := map[string]time.Time{
		"cal-dinner": demo(20, 0), "gmail-concert": time.Date(2026, 10, 3, 22, 0, 0, 0, domain.Bangkok),
		"cal-client": demo(15, 30), "cal-gym": demo(21, 30),
		"cal-standup": d1(10, 0), "cal-sync": d1(11, 30), "cal-lunch": d1(12, 45), "cal-review": d1(14, 0),
		"cal-pitch": demo(11, 0).AddDate(0, 0, 2), "cal-yoga": demo(20, 0).AddDate(0, 0, 2),
		"gmail-flight": {}, "cal-checkup": demo(10, 0).AddDate(0, 0, 7),
	}
	trips := Trips(demo(8, 0))
	if len(trips) != len(want) {
		t.Fatalf("got %d trips, want %d", len(trips), len(want))
	}
	byID := map[string]domain.Trip{}
	for _, tr := range trips {
		byID[tr.ID] = tr
		if w, ok := want[tr.ID]; !ok || !tr.EndsAt.Equal(w) {
			t.Errorf("%s ends at %v, want %v", tr.ID, tr.EndsAt, w)
		}
	}
	sync := byID["cal-sync"]
	if !sync.Virtual || sync.Destination.NameTH != "ออนไลน์" || !sync.ArriveBy.Equal(d1(11, 0)) {
		t.Errorf("cal-sync = %+v, want a virtual 11:00 meeting", sync)
	}
	review, lunch := byID["cal-review"], byID["cal-lunch"]
	if review.Origin != Siam || review.Destination != Thonglor || review.Mode != domain.ModeTransit {
		t.Errorf("cal-review = %+v, want Siam to Thonglor by transit", review)
	}
	if gap := review.ArriveBy.Sub(lunch.EndsAt); gap != 15*time.Minute {
		t.Errorf("cal-review starts %v after lunch ends, want 15m", gap)
	}
}

func TestTripsRollForwardOnceTheEveningIsOver(t *testing.T) {
	// Live mode: the dinner is tonight's until well after 18:30, then tomorrow's.
	oct8 := func(hh, mm int) time.Time { return time.Date(2026, 10, 8, hh, mm, 0, 0, domain.Bangkok) }
	tests := []struct {
		now  time.Time
		want time.Time
	}{
		{oct8(9, 0), oct8(18, 30)},
		{demo(18, 55), demo(18, 30)}, // demo beats after 18:30 still talk about tonight
		{oct8(22, 0), oct8(18, 30).AddDate(0, 0, 1)},
	}
	for _, tt := range tests {
		if got := Trips(tt.now)[0].ArriveBy; !got.Equal(tt.want) {
			t.Errorf("Trips(%v) dinner = %v, want %v", tt.now, got, tt.want)
		}
	}
}

func TestSavedPlaces(t *testing.T) {
	want := []string{"home", "work", "siam", "thonglor", "impact"}
	if len(Places) != len(want) {
		t.Fatalf("got %d places", len(Places))
	}
	for i, p := range Places {
		if p.ID != want[i] || p.LabelTH == "" || p.NameTH == "" || len(p.Keywords) == 0 {
			t.Errorf("place %d = %+v", i, p)
		}
		if p.Lat < 13.5 || p.Lat > 14.1 || p.Lng < 100.3 || p.Lng > 100.9 {
			t.Errorf("%s is outside Bangkok: %v,%v", p.ID, p.Lat, p.Lng)
		}
	}
	// Home and work are the hero trip's ends, so the hand-drawn corridor applies.
	if Places[0].Place != Home || Places[1].Place != Silom {
		t.Fatalf("home/work = %+v %+v", Places[0].Place, Places[1].Place)
	}
}

func TestWhereabouts(t *testing.T) {
	sat := time.Date(2026, 10, 3, 16, 10, 0, 0, domain.Bangkok)
	tests := []struct {
		now  time.Time
		want string
	}{
		{demo(16, 10), "work"},
		{demo(7, 30), "home"},
		{demo(21, 40), "home"},
		{sat, "home"},
	}
	for _, tt := range tests {
		if got := Whereabouts(tt.now); got != tt.want {
			t.Errorf("Whereabouts(%v) = %q, want %q", tt.now, got, tt.want)
		}
	}
}

func TestEnglishText(t *testing.T) {
	for _, p := range Places {
		if en := LocalizePlace(p.Place, domain.LangEN); domain.HasThai(en.NameTH) {
			t.Errorf("place %q has no English name", p.NameTH)
		}
		if domain.HasThai(Text(p.LabelTH, domain.LangEN)) {
			t.Errorf("label %q has no English text", p.LabelTH)
		}
	}
	for _, tr := range Trips(time.Date(2026, 9, 29, 8, 0, 0, 0, domain.Bangkok)) {
		en := LocalizeTrip(tr, domain.LangEN)
		if domain.HasThai(en.TitleTH) || domain.HasThai(en.Origin.NameTH) || domain.HasThai(en.Destination.NameTH) {
			t.Errorf("trip %+v has Thai text", en)
		}
	}
	if Text("บ้าน", domain.LangTH) != "บ้าน" || Text("ที่ใครไม่รู้", domain.LangEN) != "ที่ใครไม่รู้" {
		t.Error("Thai and unknown text must pass through unchanged")
	}
}

func TestRoutesPopulateViaAndTransitLegs(t *testing.T) {
	r := Routes{}
	heroTransit, err := r.Route(context.Background(), Silom.Point(), Home.Point(), domain.ModeTransit, demo(16, 10))
	if err != nil {
		t.Fatal(err)
	}
	if len(heroTransit.TransitLegs) == 0 {
		t.Fatalf("expected TransitLegs on hero transit route, got %+v", heroTransit)
	}
	leg := heroTransit.TransitLegs[0]
	if leg.LineTH != "MRT สายสีน้ำเงิน" || leg.FromStationTH != "MRT สีลม" || leg.ToStationTH != "MRT ลาดพร้าว" {
		t.Fatalf("hero transit leg = %+v", leg)
	}

	// Non-hero trip (Silom -> Siam) must also populate road ViaTH and transit legs.
	siamCar, err := r.Route(context.Background(), Silom.Point(), Siam.Point(), domain.ModeCar, demo(16, 10))
	if err != nil || len(siamCar.ViaTH) == 0 {
		t.Fatalf("expected non-empty ViaTH for Silom->Siam car route, got %+v (%v)", siamCar, err)
	}
	siamTransit, err := r.Route(context.Background(), Silom.Point(), Siam.Point(), domain.ModeTransit, demo(16, 10))
	if err != nil || len(siamTransit.TransitLegs) == 0 {
		t.Fatalf("expected TransitLegs for Silom->Siam transit route, got %+v (%v)", siamTransit, err)
	}
	if siamTransit.TransitLegs[0].LineTH == "" || siamTransit.TransitLegs[0].FromStationTH == "" || siamTransit.TransitLegs[0].ToStationTH == "" {
		t.Fatalf("incomplete Silom->Siam transit leg: %+v", siamTransit.TransitLegs[0])
	}
}

