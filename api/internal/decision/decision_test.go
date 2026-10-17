package decision

import (
	"context"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func at(hh, mm int) time.Time { return time.Date(2026, 9, 29, hh, mm, 0, 0, domain.Bangkok) }

// heroInput builds the มิว trip (Silom to Lat Phrao, dinner at 18:30) from the
// scenario providers and the real BMA flood spot dataset.
func heroInput(t *testing.T, now, depart time.Time, mode domain.Mode, reports ...domain.Report) Input {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	spots, err := floodspot.Load(filepath.Join(filepath.Dir(file), "..", "..", "..", "data", "bkk_flood_risk_points.json"))
	if err != nil {
		t.Fatal(err)
	}
	ctx := context.Background()
	road, _ := scenario.Routes{}.Route(ctx, scenario.Silom.Point(), scenario.Home.Point(), domain.ModeCar, depart)
	rain, _ := scenario.Weather{}.Rain(ctx, scenario.Silom.Point(), now.Add(-2*time.Hour), now.Add(8*time.Hour))
	return Input{
		Now: now, DepartAt: depart, ArriveBy: at(18, 30), Mode: mode,
		DestinationTH: "บ้านลาดพร้าว", RoadViaTH: road.ViaTH,
		Rain: rain, Spots: floodspot.OnRoute(spots, road.Polyline), Reports: reports,
		Travel: func(m domain.Mode, t time.Time) int {
			return scenario.Routes{}.TravelMinutes(scenario.Silom.Point(), scenario.Home.Point(), m, t)
		},
	}
}

// withRatchadaSeeds backs r with the two scenario reports on Ratchada, which is
// what makes a photo count at its full depth.
func withRatchadaSeeds(r domain.Report) []domain.Report {
	return append(scenario.SeedReports()[:2:2], r)
}

func TestHeroRouteCrossesTheExpectedFloodSpots(t *testing.T) {
	in := heroInput(t, at(16, 10), at(16, 10), domain.ModeCar)
	got := map[string]bool{}
	for _, s := range in.Spots {
		got[s.ID] = true
	}
	for _, id := range []string{"BKK-FL-001", "BKK-FL-002", "BKK-FL-008"} {
		if !got[id] {
			t.Errorf("route should cross %s, got %v", id, got)
		}
	}
}

func TestDecideHeroBeats(t *testing.T) {
	ratchadaReport := domain.Report{ID: "r1", Lat: scenario.HeroReportPoint.Lat, Lng: scenario.HeroReportPoint.Lng, CreatedAt: at(18, 52), DepthCMMin: 20, DepthCMMax: 25, Confidence: 0.84}
	tests := []struct {
		name         string
		now, depart  time.Time
		mode         domain.Mode
		reports      []domain.Report
		wantVerdict  Verdict
		wantHeadline string
		wantLeaveBy  string
		wantInText   []string
	}{
		{
			name: "16:10 push: car should leave before 16:45", now: at(16, 10), depart: at(16, 10), mode: domain.ModeCar,
			wantVerdict: LeaveNow, wantHeadline: "ออกก่อน 16:45", wantLeaveBy: "16:45",
			wantInText: []string{"ฝนถึงพระราม 4 ประมาณ 17:30", "ราว 17:00", "ทันนัด 18:30"},
		},
		{
			name: "16:10 motorbike still makes it before the rain", now: at(16, 10), depart: at(16, 10), mode: domain.ModeMoto,
			wantVerdict: LeaveNow, wantHeadline: "ออกก่อน 16:55", wantLeaveBy: "16:55",
		},
		{
			name: "16:10 transit is fine", now: at(16, 10), depart: at(16, 10), mode: domain.ModeTransit,
			wantVerdict: LeaveNow, wantInText: []string{"ทันนัด 18:30"},
		},
		{
			name: "slider to 17:15 on a motorbike: switch to BTS", now: at(16, 10), depart: at(17, 15), mode: domain.ModeMoto,
			wantVerdict: SwitchMode, wantHeadline: "เปลี่ยนไปนั่งรถไฟฟ้าดีกว่า", wantLeaveBy: "16:55",
		},
		{
			name: "slider to 17:50 by car: water on Ratchada, switch to BTS", now: at(16, 10), depart: at(17, 50), mode: domain.ModeCar,
			wantVerdict: SwitchMode, wantInText: []string{"น้ำท่วม"},
		},
		{
			name: "after the rain at 19:30 the road still drains: wait until 20:00", now: at(19, 30), depart: at(19, 30), mode: domain.ModeCar,
			wantVerdict: Wait, wantHeadline: "รอถึง 20:00 ค่อยออก",
		},
		{
			name: "asked at 16:10 about leaving at 20:00: fine but late for dinner", now: at(16, 10), depart: at(20, 0), mode: domain.ModeCar,
			wantVerdict: LeaveNow, wantHeadline: "ออก 20:00 ได้ แต่เลยนัด 18:30", wantLeaveBy: "16:45",
			wantInText: []string{"เลยนัด 18:30 ไป 150 นาที"},
		},
		{
			name: "18:52 photo report confirms 25 cm on Ratchada", now: at(18, 52), depart: at(18, 52), mode: domain.ModeCar, reports: withRatchadaSeeds(ratchadaReport),
			wantVerdict: SwitchMode, wantInText: []string{"รัชดาภิเษก"},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			res := Decide(heroInput(t, tt.now, tt.depart, tt.mode, tt.reports...))
			if res.Verdict != tt.wantVerdict {
				t.Fatalf("verdict = %s, want %s (evals %+v)", res.Verdict, tt.wantVerdict, res.Evals)
			}
			if tt.wantHeadline != "" && res.HeadlineTH != tt.wantHeadline {
				t.Errorf("headline = %q, want %q", res.HeadlineTH, tt.wantHeadline)
			}
			gotLeaveBy := ""
			if res.LeaveBy != nil {
				gotLeaveBy = res.LeaveBy.Format("15:04")
			}
			if tt.wantLeaveBy != "" && gotLeaveBy != tt.wantLeaveBy {
				t.Errorf("leave_by = %q, want %q", gotLeaveBy, tt.wantLeaveBy)
			}
			for _, s := range tt.wantInText {
				if !strings.Contains(res.SummaryTH, s) {
					t.Errorf("summary %q should contain %q", res.SummaryTH, s)
				}
			}
			if res.Confidence < 0.4 || res.Confidence > 0.95 {
				t.Errorf("confidence %v out of range", res.Confidence)
			}
			if len(res.ModeOptions) != 3 {
				t.Errorf("want 3 mode options, got %d", len(res.ModeOptions))
			}
		})
	}
}

func TestDecideHeroDetails(t *testing.T) {
	res := Decide(heroInput(t, at(16, 10), at(16, 10), domain.ModeCar))
	if len(res.RainTimeline) != 21 || !res.RainTimeline[0].Time.Equal(at(16, 0)) || !res.RainTimeline[20].Time.Equal(at(21, 0)) {
		t.Fatalf("timeline should be 16:00..21:00 every 15 min, got %d samples", len(res.RainTimeline))
	}
	if res.ModeOptions[0].EtaMin != 50 || res.ModeOptions[0].Risk != RiskLow {
		t.Errorf("car option = %+v", res.ModeOptions[0])
	}
	for _, s := range res.FloodSpots {
		if s.ExpectedDepthCM != 0 {
			t.Errorf("no water expected before the rain, got %+v", s)
		}
	}

	report := domain.Report{ID: "r1", Lat: scenario.HeroReportPoint.Lat, Lng: scenario.HeroReportPoint.Lng, CreatedAt: at(18, 52), DepthCMMax: 25, Confidence: 0.84}
	res = Decide(heroInput(t, at(18, 52), at(18, 52), domain.ModeCar, withRatchadaSeeds(report)...))
	if res.FloodSpots[0].ID != "report-r1" || res.FloodSpots[0].ExpectedDepthCM != 25 || res.FloodSpots[0].Risk != RiskHigh {
		t.Errorf("deepest spot should be the photo report, got %+v", res.FloodSpots[0])
	}
}

func TestRiskFor(t *testing.T) {
	tests := []struct {
		mode        domain.Mode
		rain, depth float64
		want        Risk
	}{
		{domain.ModeCar, 0, 0, RiskLow},
		{domain.ModeCar, 5, 4, RiskLow},
		{domain.ModeCar, 12, 0, RiskMedium},
		{domain.ModeCar, 0, 5, RiskMedium},
		{domain.ModeCar, 0, 15, RiskHigh},
		{domain.ModeMoto, 0.5, 0, RiskLow},
		{domain.ModeMoto, 2, 0, RiskMedium},
		{domain.ModeMoto, 0, 2, RiskMedium},
		{domain.ModeMoto, 12, 0, RiskHigh},
		{domain.ModeMoto, 0, 10, RiskHigh},
		{domain.ModeTransit, 50, 40, RiskMedium},
		{domain.ModeTransit, 5, 40, RiskLow},
	}
	for _, tt := range tests {
		if got := riskFor(tt.mode, tt.rain, tt.depth, 0); got != tt.want {
			t.Errorf("%s rain=%v depth=%v: got %s, want %s", tt.mode, tt.rain, tt.depth, got, tt.want)
		}
	}
}

func TestRainAt(t *testing.T) {
	samples := []domain.RainSample{{Time: at(17, 0), MMPerHr: 5}, {Time: at(18, 0), MMPerHr: 20}}
	tests := []struct {
		t    time.Time
		want float64
	}{
		{at(16, 59), 0},
		{at(17, 0), 5},
		{at(17, 59), 5},
		{at(18, 30), 20},
		{at(19, 0), 0}, // the last sample only holds for an hour
	}
	for _, tt := range tests {
		if got := RainAt(samples, tt.t); got != tt.want {
			t.Errorf("%s: got %v, want %v", tt.t.Format("15:04"), got, tt.want)
		}
	}
}

func TestSpotDepthDrains(t *testing.T) {
	spot := floodspot.Spot{ThresholdMMPerHr: 35, MaxDepthCM: 25}
	rain := []domain.RainSample{{Time: at(18, 0), MMPerHr: 52}}
	full := floodspot.InstantDepthCM(spot, 52)
	tests := []struct {
		t    time.Time
		want float64
	}{
		{at(17, 59), 0},
		{at(18, 0), full},
		{at(19, 0), full / 2},
		{at(20, 0), 0},
	}
	for _, tt := range tests {
		if got := SpotDepthCM(spot, rain, tt.t); got < tt.want-0.01 || got > tt.want+0.01 {
			t.Errorf("%s: got %.2f, want %.2f", tt.t.Format("15:04"), got, tt.want)
		}
	}
}

func TestDontGoWhenEveryOptionStaysRisky(t *testing.T) {
	var rain []domain.RainSample
	for h := 12; h < 23; h++ {
		rain = append(rain, domain.RainSample{Time: at(h, 0), MMPerHr: 12})
	}
	in := Input{
		Now: at(16, 0), DepartAt: at(16, 0), ArriveBy: at(16, 30), Mode: domain.ModeCar, DestinationTH: "ที่ทำงาน",
		Rain:   rain,
		Travel: func(domain.Mode, time.Time) int { return 60 },
	}
	res := Decide(in)
	if res.Verdict != DontGo || res.HeadlineTH != "อย่าเพิ่งออก" || res.LeaveBy != nil {
		t.Fatalf("got %s %q leave_by=%v", res.Verdict, res.HeadlineTH, res.LeaveBy)
	}
}

func TestMotoHighRiskOnWindGust(t *testing.T) {
	// No rain, no flood spots, but wind gusts exceed 45 km/h
	in := Input{
		Now: at(16, 0), DepartAt: at(16, 0), Mode: domain.ModeMoto, DestinationTH: "สยาม",
		WindGustKMH: 48.0,
		Travel:      func(domain.Mode, time.Time) int { return 25 },
	}
	ev := EvaluateMode(in, domain.ModeMoto, in.DepartAt)
	if ev.Risk != RiskHigh {
		t.Fatalf("expected RiskHigh for moto under 48 km/h wind gusts, got %v", ev.Risk)
	}

	res := Decide(in)
	if res.Verdict != SwitchMode {
		t.Errorf("expected SwitchMode away from dangerous motorcycle wind, got %v", res.Verdict)
	}
}

func TestDecideExplanation(t *testing.T) {
	// 1. LeaveNow hero scenario
	res := Decide(heroInput(t, at(16, 10), at(16, 10), domain.ModeCar))
	if res.Explanation.ReasonWhyTH == "" {
		t.Errorf("expected non-empty ReasonWhyTH, got empty")
	}
	if len(res.Explanation.FactorsTH) == 0 {
		t.Errorf("expected factors listed in FactorsTH, got 0")
	}
	if res.Explanation.RouteAdviceTH == "" {
		t.Errorf("expected non-empty RouteAdviceTH, got empty")
	}

	// 2. High flood depth scenario on Ratchada: should advise switching mode and avoiding Ratchada
	ratchadaReport := domain.Report{
		ID: "r1", Lat: scenario.HeroReportPoint.Lat, Lng: scenario.HeroReportPoint.Lng,
		CreatedAt: at(18, 52), DepthCMMax: 25, Confidence: 0.84,
	}
	resFlooded := Decide(heroInput(t, at(18, 52), at(18, 52), domain.ModeCar, withRatchadaSeeds(ratchadaReport)...))
	if !strings.Contains(resFlooded.Explanation.ReasonWhyTH, "รถไฟฟ้า") && !strings.Contains(resFlooded.Explanation.ReasonWhyTH, "น้ำท่วม") {
		t.Errorf("ReasonWhyTH should mention transit or flood, got %q", resFlooded.Explanation.ReasonWhyTH)
	}
	if len(resFlooded.Explanation.AvoidSpotsTH) == 0 {
		t.Errorf("expected at least 1 avoid spot, got %v", resFlooded.Explanation.AvoidSpotsTH)
	}
	if !strings.Contains(resFlooded.Explanation.RouteAdviceTH, "รัชดา") {
		t.Errorf("RouteAdviceTH should mention avoiding Ratchada, got %q", resFlooded.Explanation.RouteAdviceTH)
	}
}

func TestReportDepthWeighting(t *testing.T) {
	p := scenario.HeroReportPoint
	mk := func(id string, mm int, by string, conf float64, depthMax int) domain.Report {
		return domain.Report{ID: id, Lat: p.Lat, Lng: p.Lng, CreatedAt: at(18, mm), DepthCMMin: depthMax - 5, DepthCMMax: depthMax, Confidence: conf, GeneratedBy: by}
	}
	now := at(19, 0)
	tests := []struct {
		name string
		r    domain.Report
		all  []domain.Report
		want float64
	}{
		{"fallback hero assessment is ignored", mk("a", 50, "fallback", 0.84, 25), nil, 0},
		{"fallback never corroborates", mk("a", 50, "gemini", 0.9, 40), []domain.Report{mk("a", 50, "gemini", 0.9, 40), mk("b", 51, "fallback", 0.9, 40)}, 15},
		{"low confidence is ignored", mk("a", 50, "gemini", 0.4, 40), nil, 0},
		{"solo report is confidence weighted", mk("a", 50, "gemini", 0.5, 20), nil, 10},
		{"solo report is capped at 15 cm", mk("a", 50, "gemini", 0.9, 100), nil, 15},
		{"low confidence report does not corroborate", mk("a", 50, "gemini", 0.9, 40), []domain.Report{mk("a", 50, "gemini", 0.9, 40), mk("b", 51, "gemini", 0.3, 40)}, 15},
		{"two usable reports give the full depth", mk("a", 50, "gemini", 0.6, 40), []domain.Report{mk("a", 50, "gemini", 0.6, 40), mk("b", 51, "", 0.7, 30)}, 40},
		{"corroborator outside the window does not count", mk("a", 50, "gemini", 0.9, 40), []domain.Report{mk("a", 50, "gemini", 0.9, 40), {ID: "b", Lat: p.Lat, Lng: p.Lng, CreatedAt: at(17, 0), Confidence: 0.9}}, 15},
		{"corroborator too far away does not count", mk("a", 50, "gemini", 0.9, 40), []domain.Report{mk("a", 50, "gemini", 0.9, 40), {ID: "b", Lat: p.Lat + 0.01, Lng: p.Lng, CreatedAt: at(18, 51), Confidence: 0.9}}, 15},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := reportDepthCM(tt.r, tt.all, now); got != tt.want {
				t.Fatalf("got %v, want %v", got, tt.want)
			}
		})
	}
}

func dryInput(lang domain.Lang, arriveBy time.Time) Input {
	return Input{
		Lang: lang, Now: at(8, 0), DepartAt: at(8, 0), ArriveBy: arriveBy, Mode: domain.ModeCar, DestinationTH: "Siam",
		Travel: func(domain.Mode, time.Time) int { return 30 },
	}
}

func TestDryDayWithoutDeadlineHasNoLeaveBy(t *testing.T) {
	for _, tt := range []struct {
		lang         domain.Lang
		wantHeadline string
	}{{domain.LangTH, "ออกได้เลย"}, {domain.LangEN, "Good to go now"}} {
		res := Decide(dryInput(tt.lang, time.Time{}))
		if res.Verdict != LeaveNow || res.LeaveBy != nil || res.HeadlineTH != tt.wantHeadline {
			t.Errorf("%s: got %s %q leave_by=%v, want leave_now %q and no leave_by", tt.lang, res.Verdict, res.HeadlineTH, res.LeaveBy, tt.wantHeadline)
		}
	}
}

func TestAlreadyLateNeverWaitsToArriveLater(t *testing.T) {
	// 18:52 with dinner at 19:00: the car is already 92 min late and waiting
	// for the water to drain would arrive 21:00, later than driving now
	// (20:32). The train arrives 19:47 at the same medium risk.
	in := heroInput(t, at(18, 52), at(18, 52), domain.ModeCar)
	in.ArriveBy = at(19, 0)
	res := Decide(in)
	if res.Verdict != SwitchMode {
		t.Fatalf("verdict = %s wait_until=%v, want switch_mode to the train arriving 19:47", res.Verdict, res.WaitUntil)
	}
}

func TestMotoMediumRiskWaitsOutTheShowerFirst(t *testing.T) {
	drizzle := func(from, to int) []domain.RainSample {
		var rain []domain.RainSample
		for h := from; h < to; h++ {
			rain = append(rain, domain.RainSample{Time: at(h, 0), MMPerHr: 2})
		}
		return rain
	}
	moto := func(lang domain.Lang, rain []domain.RainSample, gust float64) Result {
		in := dryInput(lang, time.Time{})
		in.Mode, in.Rain, in.WindGustKMH = domain.ModeMoto, rain, gust
		return Decide(in)
	}

	if res := moto(domain.LangTH, drizzle(8, 9), 0); res.Verdict != Wait || res.WaitUntil.Format("15:04") != "09:00" {
		t.Errorf("an hour of 2 mm/h drizzle: got %s wait_until=%v, want wait until 09:00", res.Verdict, res.WaitUntil)
	}

	for _, tt := range []struct {
		name      string
		rain      []domain.RainSample
		gust      float64
		wantCause map[domain.Lang]string
	}{
		{"drizzle all day", drizzle(6, 20), 0, map[domain.Lang]string{domain.LangTH: "ฝน", domain.LangEN: "rain"}},
		{"31 km/h gusts", nil, 31, map[domain.Lang]string{domain.LangTH: "31 กม./ชม.", domain.LangEN: "31 km/h"}},
	} {
		for lang, cause := range tt.wantCause {
			res := moto(lang, tt.rain, tt.gust)
			if res.Verdict != SwitchMode {
				t.Errorf("%s %s: verdict = %s, want switch_mode when it does not clear", tt.name, lang, res.Verdict)
				continue
			}
			r := res.Explanation.ReasonWhyTH
			if strings.Contains(r, "ความเสี่ยงสูง") || strings.Contains(r, "high risk") || !strings.Contains(r, cause) {
				t.Errorf("%s %s: medium-risk reason should name %q and not claim high risk: %q", tt.name, lang, cause, r)
			}
			if !strings.Contains(res.SummaryTH, cause) {
				t.Errorf("%s %s: summary should name %q: %q", tt.name, lang, cause, res.SummaryTH)
			}
		}
	}
}

func TestWaitReasonNamesWaterOnlyWhenThereIsSome(t *testing.T) {
	for _, tt := range []struct {
		lang         domain.Lang
		water, eases string
	}{{domain.LangTH, "น้ำท่วมขัง", "ฝนซาลง"}, {domain.LangEN, "standing water", "rain to ease"}} {
		in := dryInput(tt.lang, time.Time{})
		in.Mode, in.Rain = domain.ModeMoto, []domain.RainSample{{Time: at(8, 0), MMPerHr: 2}}
		res := Decide(in)
		if r := res.Explanation.ReasonWhyTH; res.Verdict != Wait || strings.Contains(r, tt.water) || !strings.Contains(r, tt.eases) {
			t.Errorf("%s rain only: got %s, reason should wait for the rain without water: %q", tt.lang, res.Verdict, r)
		}
		drain := heroInput(t, at(19, 30), at(19, 30), domain.ModeCar)
		drain.Lang = tt.lang
		if r := Decide(drain).Explanation.ReasonWhyTH; !strings.Contains(r, tt.water) {
			t.Errorf("%s 19:30 drain: reason should name the standing water: %q", tt.lang, r)
		}
	}
}

func TestOnlyUsableReportsCount(t *testing.T) {
	unusable := []domain.Report{
		{ID: "r1", Lat: 13.7, Lng: 100.5, CreatedAt: at(7, 50), DepthCMMax: 30, Confidence: 0.2},
		{ID: "r2", Lat: 13.7, Lng: 100.5, CreatedAt: at(7, 55), DepthCMMax: 30, Confidence: 0.9, GeneratedBy: "fallback"},
	}
	usable := domain.Report{ID: "r3", Lat: 13.7, Lng: 100.5, CreatedAt: at(7, 55), DepthCMMax: 3, Confidence: 0.9, GeneratedBy: "gemini"}
	for _, tt := range []struct {
		lang   domain.Lang
		factor string
		one    string
	}{{domain.LangTH, "รายงานชุมชน", "พื้นที่ 1 จุด"}, {domain.LangEN, "Community reports", "1 real flood report"}} {
		base := Decide(dryInput(tt.lang, time.Time{}))
		in := dryInput(tt.lang, time.Time{})
		in.Reports = unusable
		res := Decide(in)
		if res.Confidence != base.Confidence {
			t.Errorf("%s: unusable reports raised confidence %v -> %v", tt.lang, base.Confidence, res.Confidence)
		}
		for _, f := range res.Explanation.FactorsTH {
			if strings.Contains(f, tt.factor) {
				t.Errorf("%s: unusable reports listed as a factor: %q", tt.lang, f)
			}
		}
		in.Reports = append(unusable, usable)
		res = Decide(in)
		if !slices.ContainsFunc(res.Explanation.FactorsTH, func(f string) bool { return strings.Contains(f, tt.one) }) || res.Confidence <= base.Confidence {
			t.Errorf("%s: one usable report should count once and raise confidence: %q %v", tt.lang, res.Explanation.FactorsTH, res.Confidence)
		}
	}
}

func TestTransitUmbrellaOnlyWhenItRains(t *testing.T) {
	for _, tt := range []struct {
		lang     domain.Lang
		rain     float64
		umbrella string
		want     bool
	}{
		{domain.LangTH, 0, "ร่ม", false},
		{domain.LangEN, 0, "umbrella", false},
		{domain.LangTH, 3, "ร่ม", true},
		{domain.LangEN, 3, "umbrella", true},
	} {
		in := dryInput(tt.lang, time.Time{})
		in.Mode = domain.ModeTransit
		in.Rain = []domain.RainSample{{Time: at(8, 0), MMPerHr: tt.rain}}
		if got := strings.Contains(Decide(in).Explanation.RouteAdviceTH, tt.umbrella); got != tt.want {
			t.Errorf("%s rain %v mm/h: route advice mentions umbrella = %v, want %v", tt.lang, tt.rain, got, tt.want)
		}
	}
}

func TestLeaveByReasonFollowsWhatEndsTheWindow(t *testing.T) {
	dry := Decide(dryInput(domain.LangTH, at(12, 0)))
	if dry.LeaveBy == nil || dry.LeaveBy.Format("15:04") != "11:30" {
		t.Fatalf("leave_by = %v, want 11:30", dry.LeaveBy)
	}
	if r := dry.Explanation.ReasonWhyTH; strings.Contains(r, "ฝน") || !strings.Contains(r, "ทันนัด 12:00") {
		t.Errorf("dry reason should name the 12:00 appointment, not rain: %q", r)
	}
	dryEN := Decide(dryInput(domain.LangEN, at(12, 0)))
	if r := dryEN.Explanation.ReasonWhyTH; strings.Contains(r, "rain") || !strings.Contains(r, "12:00 appointment") {
		t.Errorf("dry English reason should name the 12:00 appointment, not rain: %q", r)
	}
	laterRain := dryInput(domain.LangEN, at(12, 0))
	laterRain.Rain = []domain.RainSample{{Time: at(14, 0), MMPerHr: 20}}
	if s := Decide(laterRain).SummaryTH; strings.Contains(s, "hit rain") {
		t.Errorf("rain at 14:00 does not end an 11:30 leave-by: %q", s)
	}

	rainy := heroInput(t, at(16, 10), at(16, 10), domain.ModeCar)
	if r := Decide(rainy).Explanation.ReasonWhyTH; !strings.Contains(r, "ฝน") {
		t.Errorf("hero leave-by is set by the 17:30 rain, reason should say so: %q", r)
	}
	rainy.Lang = domain.LangEN
	if r := Decide(rainy).Explanation.ReasonWhyTH; !strings.Contains(r, "rain") {
		t.Errorf("hero leave-by is set by the 17:30 rain, English reason should say so: %q", r)
	}
}
