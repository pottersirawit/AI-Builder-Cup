package decision

import (
	"testing"
	"time"
	"unicode/utf8"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func noThai(t *testing.T, what, s string) {
	t.Helper()
	if s == "" {
		t.Errorf("%s is empty", what)
	}
	if domain.HasThai(s) {
		t.Errorf("%s has Thai characters: %q", what, s)
	}
}

func TestEnglishNarrationPerVerdict(t *testing.T) {
	ratchadaReport := domain.Report{ID: "r1", Lat: scenario.HeroReportPoint.Lat, Lng: scenario.HeroReportPoint.Lng, CreatedAt: at(18, 52), DepthCMMin: 20, DepthCMMax: 25, Confidence: 0.84}
	var rain []domain.RainSample
	for h := 12; h < 23; h++ {
		rain = append(rain, domain.RainSample{Time: at(h, 0), MMPerHr: 12})
	}
	dontGo := Input{
		Now: at(16, 0), DepartAt: at(16, 0), ArriveBy: at(16, 30), Mode: domain.ModeCar, DestinationTH: "ที่ทำงาน",
		Rain: rain, Travel: func(domain.Mode, time.Time) int { return 60 },
	}
	hero := func(now, depart time.Time, mode domain.Mode, reps ...domain.Report) Input {
		return heroInput(t, now, depart, mode, reps...)
	}
	tests := []struct {
		name         string
		in           Input
		wantVerdict  Verdict
		wantHeadline string
		wantInText   []string
	}{
		{"leave_now with a leave-by", hero(at(16, 10), at(16, 10), domain.ModeCar), LeaveNow, "Leave by 16:45",
			[]string{"Rain starts on your route around 17:30", "around 17:00", "in time for 18:30"}},
		{"leave_now but late", hero(at(16, 10), at(20, 0), domain.ModeCar), LeaveNow, "Leave 20:00, late for 18:30",
			[]string{"150 min past 18:30"}},
		{"switch_mode on a motorbike", hero(at(16, 10), at(17, 15), domain.ModeMoto), SwitchMode, "Take BTS / MRT instead",
			[]string{"by motorbike", "BTS / MRT stays clear of the water"}},
		{"switch_mode for a flood report", hero(at(18, 52), at(18, 52), domain.ModeCar, withRatchadaSeeds(ratchadaReport)...), SwitchMode, "Take BTS / MRT instead",
			[]string{"flooding of about"}},
		{"wait", hero(at(19, 30), at(19, 30), domain.ModeCar), Wait, "Wait until 20:00", []string{"Leaving at 20:00"}},
		{"dont_go", dontGo, DontGo, "Don't leave yet", []string{"Every option is still risky"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.in.Lang = domain.LangEN
			res := Decide(tt.in)
			if res.Verdict != tt.wantVerdict {
				t.Fatalf("verdict = %s, want %s", res.Verdict, tt.wantVerdict)
			}
			if res.HeadlineTH != tt.wantHeadline {
				t.Errorf("headline = %q, want %q", res.HeadlineTH, tt.wantHeadline)
			}
			if n := utf8.RuneCountInString(res.HeadlineTH); n > 30 {
				t.Errorf("headline %q is %d characters, want at most 30", res.HeadlineTH, n)
			}
			noThai(t, "headline", res.HeadlineTH)
			noThai(t, "summary", res.SummaryTH)
			for _, s := range tt.wantInText {
				if !contains(res.SummaryTH, s) {
					t.Errorf("summary %q should contain %q", res.SummaryTH, s)
				}
			}
			e := res.Explanation
			noThai(t, "reason_why", e.ReasonWhyTH)
			noThai(t, "route_advice", e.RouteAdviceTH)
			if len(e.FactorsTH) == 0 {
				t.Error("no factors")
			}
			for _, f := range e.FactorsTH {
				noThai(t, "factor", f)
			}
			for _, o := range res.ModeOptions {
				noThai(t, "mode note", o.NoteTH)
			}
		})
	}
}

func TestEnglishReportLabel(t *testing.T) {
	in := heroInput(t, at(18, 52), at(18, 52), domain.ModeCar,
		domain.Report{ID: "r1", Lat: scenario.HeroReportPoint.Lat, Lng: scenario.HeroReportPoint.Lng, CreatedAt: at(18, 52), DepthCMMin: 20, DepthCMMax: 25, Confidence: 0.84})
	in.Lang = domain.LangEN
	found := false
	for _, s := range Decide(in).FloodSpots {
		if len(s.ID) > 7 && s.ID[:7] == "report-" {
			found = true
			if !contains(s.NameTH, "User report 18:52 near ") {
				t.Errorf("report label = %q", s.NameTH)
			}
		}
	}
	if !found {
		t.Fatal("no report flood spot")
	}
}

func TestModeNameFor(t *testing.T) {
	for _, m := range domain.AllModes {
		if got := m.NameFor(domain.LangTH); got != m.NameTH() {
			t.Errorf("%s: Thai NameFor = %q, want %q", m, got, m.NameTH())
		}
		noThai(t, string(m), m.NameFor(domain.LangEN))
	}
}

func contains(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
