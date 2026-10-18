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
func heroInput(t *testing.T, now, depart time.Time, mode domain.Mode) Input {
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
		Rain: rain, Spots: floodspot.OnRoute(spots, road.Polyline),
		Travel: func(m domain.Mode, t time.Time) int {
			return scenario.Routes{}.TravelMinutes(scenario.Silom.Point(), scenario.Home.Point(), m, t)
		},
	}
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
	tests := []struct {
		name         string
		now, depart  time.Time
		mode         domain.Mode
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
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			res := Decide(heroInput(t, tt.now, tt.depart, tt.mode))
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
			if len(res.ModeOptions) != len(domain.AllModes) {
				t.Errorf("want %d mode options, got %d", len(domain.AllModes), len(res.ModeOptions))
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
}

func TestRiskFor(t *testing.T) {
	tests := []struct {
		mode        domain.Mode
		rain, depth float64
		prob        int
		want        Risk
	}{
		{domain.ModeCar, 0, 0, 0, RiskLow},
		{domain.ModeCar, 5, 4, 0, RiskLow},
		{domain.ModeCar, 0, 0, 70, RiskLow},
		{domain.ModeCar, 12, 0, 0, RiskMedium},
		{domain.ModeCar, 0, 5, 0, RiskMedium},
		{domain.ModeCar, 0, 15, 0, RiskHigh},
		{domain.ModeMoto, 0.5, 0, 0, RiskLow},
		{domain.ModeMoto, 0, 0, 20, RiskLow},
		{domain.ModeMoto, 0, 0, 60, RiskMedium},
		{domain.ModeMoto, 0, 0, 75, RiskMedium},
		{domain.ModeMoto, 2, 0, 0, RiskMedium},
		{domain.ModeMoto, 0, 2, 0, RiskMedium},
		{domain.ModeMoto, 12, 0, 0, RiskHigh},
		{domain.ModeMoto, 0, 10, 0, RiskHigh},
		{domain.ModeTransit, 50, 40, 0, RiskMedium},
		{domain.ModeTransit, 5, 40, 0, RiskLow},
		{domain.ModeTransit, 0, 0, 70, RiskLow},
	}
	for _, tt := range tests {
		if got := riskFor(tt.mode, tt.rain, tt.depth, 0, tt.prob); got != tt.want {
			t.Errorf("%s rain=%v depth=%v prob=%v: got %s, want %s", tt.mode, tt.rain, tt.depth, tt.prob, got, tt.want)
		}
	}
}

func TestDecideRainProbability(t *testing.T) {
	rain := []domain.RainSample{
		{Time: at(16, 0), MMPerHr: 0, ProbPct: 70},
		{Time: at(17, 0), MMPerHr: 0, ProbPct: 70},
		{Time: at(18, 0), MMPerHr: 0, ProbPct: 70},
	}
	in := Input{
		Now:           at(16, 0),
		DepartAt:      at(16, 0),
		Mode:          domain.ModeCar,
		DestinationTH: "ออฟฟิศ",
		Travel: func(m domain.Mode, _ time.Time) int {
			return 30
		},
		Rain: rain,
	}
	res := Decide(in)
	byMode := map[domain.Mode]ModeOption{}
	for _, opt := range res.ModeOptions {
		byMode[opt.Mode] = opt
	}
	if byMode[domain.ModeCar].Risk != RiskLow || byMode[domain.ModeCar].RainProbPct != 70 {
		t.Errorf("car = %+v, want RiskLow and RainProbPct=70", byMode[domain.ModeCar])
	}
	if byMode[domain.ModeTransit].Risk != RiskLow || byMode[domain.ModeTransit].RainProbPct != 70 {
		t.Errorf("transit = %+v, want RiskLow and RainProbPct=70", byMode[domain.ModeTransit])
	}
	if byMode[domain.ModeMoto].Risk != RiskMedium || byMode[domain.ModeMoto].RainProbPct != 70 {
		t.Errorf("moto = %+v, want RiskMedium (elevated by 70%% prob) and RainProbPct=70", byMode[domain.ModeMoto])
	}
	if !strings.Contains(byMode[domain.ModeMoto].NoteTH, "เสื้อกันฝน") {
		t.Errorf("moto note %q should advise rain gear", byMode[domain.ModeMoto].NoteTH)
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

	// 2. High flood depth scenario on Ratchada during storm: should advise switching mode and avoiding Ratchada
	resFlooded := Decide(heroInput(t, at(18, 0), at(18, 0), domain.ModeCar))
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


func TestRainFactorSaysRainingNowMidStorm(t *testing.T) {
	for _, tt := range []struct {
		lang        domain.Lang
		now, starts string
	}{{domain.LangTH, "กำลังตก", "เริ่มตก"}, {domain.LangEN, "raining on your route now", "starts on your route"}} {
		in := heroInput(t, at(18, 52), at(18, 52), domain.ModeCar)
		in.Lang = tt.lang
		f := Decide(in).Explanation.FactorsTH[0]
		if !strings.Contains(f, tt.now) || strings.Contains(f, tt.starts) {
			t.Errorf("%s mid-storm rain factor = %q, want it raining now", tt.lang, f)
		}
		in = heroInput(t, at(16, 10), at(16, 10), domain.ModeCar)
		in.Lang = tt.lang
		if f := Decide(in).Explanation.FactorsTH[0]; !strings.Contains(f, tt.starts) {
			t.Errorf("%s before the rain, factor = %q, want when it starts", tt.lang, f)
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

// The app shows the train when the asked mode must wait but the train can go;
// the summary says so instead of only the wait.
func TestWaitSummaryOffersTheTrainWhenItCanGo(t *testing.T) {
	for _, tt := range []struct {
		lang  domain.Lang
		train string
	}{{domain.LangTH, "รถไฟฟ้า"}, {domain.LangEN, "BTS / MRT"}} {
		in := dryInput(tt.lang, time.Time{})
		in.Mode, in.Rain = domain.ModeMoto, []domain.RainSample{{Time: at(8, 0), MMPerHr: 2}}
		res := Decide(in)
		transit := res.ModeOptions[slices.IndexFunc(res.ModeOptions, func(o ModeOption) bool { return o.Mode == domain.ModeTransit })]
		if res.Verdict != Wait || transit.Verdict != LeaveNow {
			t.Fatalf("%s: setup got %s with transit %s, want wait and transit leave_now", tt.lang, res.Verdict, transit.Verdict)
		}
		if !strings.Contains(res.SummaryTH, tt.train) {
			t.Errorf("%s: wait summary should offer the train: %q", tt.lang, res.SummaryTH)
		}
	}
}

// A wait that turns an on-time trip into a late one is no answer: the train
// is, and a rider is not sent to wait an hour past the appointment.
func TestWaitNeverMakesAnOnTimeTripLate(t *testing.T) {
	in := dryInput(domain.LangEN, at(9, 0))
	in.Mode, in.Rain = domain.ModeMoto, []domain.RainSample{{Time: at(8, 0), MMPerHr: 2}}
	res := Decide(in)
	if res.Verdict == Wait && EvaluateMode(in, in.Mode, *res.WaitUntil).Late() {
		t.Fatalf("got wait until %s, arriving late; leaving now is on time", hhmm(*res.WaitUntil))
	}
	if res.Verdict != SwitchMode {
		t.Errorf("got %s, want switch_mode to the on-time train", res.Verdict)
	}
}

// Already late with the road clearing only later still and the train slower,
// the answer is the first clearing wait, not "every option is high risk".
func TestLateWithASlowerTrainStillWaits(t *testing.T) {
	in := dryInput(domain.LangEN, at(8, 0))
	in.Rain = []domain.RainSample{{Time: at(8, 0), MMPerHr: 12}, {Time: at(9, 0), MMPerHr: 0}}
	in.Travel = func(m domain.Mode, _ time.Time) int {
		if m == domain.ModeTransit {
			return 50
		}
		return 30
	}
	res := Decide(in)
	if res.Verdict == DontGo {
		t.Fatalf("got dont_go; the road clears at 09:00 (%q)", res.SummaryTH)
	}
}

// Water under a mode's clearance is not why it should switch; the rain is.
func TestSwitchReasonBlamesWaterOnlyPastItsLimit(t *testing.T) {
	for _, tt := range []struct {
		mode  domain.Mode
		depth float64
	}{{domain.ModeMoto, 9}, {domain.ModeCar, 4}} {
		in := dryInput(domain.LangEN, time.Time{})
		in.Mode = tt.mode
		res := Result{Verdict: SwitchMode, Evals: map[domain.Mode]Eval{
			tt.mode:            {MaxDepthCM: tt.depth, MaxRainMM: 30, Risk: RiskHigh},
			domain.ModeTransit: {Minutes: 40},
		}}
		_, _, en := narrateEN(in, res)
		in.Lang = domain.LangTH
		_, _, th := narrate(in, res)
		if strings.Contains(en.ReasonWhyTH, "standing water") || strings.Contains(th.ReasonWhyTH, "น้ำท่วมขัง") {
			t.Errorf("%s at %.0f cm blames the water:\n%s\n%s", tt.mode, tt.depth, en.ReasonWhyTH, th.ReasonWhyTH)
		}
		if !strings.Contains(en.ReasonWhyTH, "30 mm/h") || !strings.Contains(th.ReasonWhyTH, "30 มม./ชม.") {
			t.Errorf("%s: the reason should name the rain:\n%s\n%s", tt.mode, en.ReasonWhyTH, th.ReasonWhyTH)
		}
	}
}

// Lines under the answer never contradict the rain they sit next to.
func TestRainLinesMatchTheRain(t *testing.T) {
	for _, lang := range []domain.Lang{domain.LangTH, domain.LangEN} {
		later := dryInput(lang, time.Time{})
		later.Rain = []domain.RainSample{{Time: at(10, 0), MMPerHr: 20}}
		for _, f := range Decide(later).Explanation.FactorsTH {
			if strings.Contains(f, " 0 ") {
				t.Errorf("%s: rain after arrival quotes a 0 peak: %q", lang, f)
			}
		}
		train := dryInput(lang, time.Time{})
		train.Mode, train.Rain = domain.ModeTransit, []domain.RainSample{{Time: at(8, 0), MMPerHr: 40}}
		res := Decide(train)
		if r := res.Explanation.ReasonWhyTH; res.Verdict != LeaveNow || strings.Contains(r, "no heavy rain") || strings.Contains(r, "ฝนไม่หนัก") {
			t.Errorf("%s: train in 40 mm/h: %s %q", lang, res.Verdict, r)
		}
	}
}

func TestDepthRiskModeAwareness(t *testing.T) {
	// 12 cm water:
	// - Moto stall is 10cm: 12cm >= 10cm -> RiskHigh
	// - Car stall is 15cm, slow is 5cm: 12cm is between 5 and 15 -> RiskMedium
	// - Pickup stall is 35cm, slow is 20cm: 12cm < 20cm -> RiskLow
	if got := depthRisk(12.0, domain.ModeMoto); got != RiskHigh {
		t.Errorf("depthRisk(12, moto) = %v, want RiskHigh", got)
	}
	if got := depthRisk(12.0, domain.ModeCar); got != RiskMedium {
		t.Errorf("depthRisk(12, car) = %v, want RiskMedium", got)
	}
	if got := depthRisk(12.0, domain.ModePickup); got != RiskLow {
		t.Errorf("depthRisk(12, pickup) = %v, want RiskLow", got)
	}

	// Pickup clearance thresholds:
	if stallDepthCM(domain.ModePickup) != 35.0 {
		t.Errorf("stallDepthCM(ModePickup) = %v, want 35.0", stallDepthCM(domain.ModePickup))
	}
	if slowDepthCM(domain.ModePickup) != 20.0 {
		t.Errorf("slowDepthCM(ModePickup) = %v, want 20.0", slowDepthCM(domain.ModePickup))
	}
	if got := depthRisk(25.0, domain.ModePickup); got != RiskMedium {
		t.Errorf("depthRisk(25, pickup) = %v, want RiskMedium", got)
	}
	if got := depthRisk(36.0, domain.ModePickup); got != RiskHigh {
		t.Errorf("depthRisk(36, pickup) = %v, want RiskHigh", got)
	}
}

func TestVerdictFor_DoesNotSuggestPastDeparture(t *testing.T) {
	now := at(18, 0)
	in := dryInput(domain.LangTH, now)
	in.Now = now
	in.DepartAt = at(17, 0) // departAt is 1 hour in the past
	in.Mode = domain.ModeCar
	// Rain between 17:00 and 18:30, clearing at 18:45
	in.Rain = []domain.RainSample{
		{Time: at(17, 30), MMPerHr: 30},
		{Time: at(18, 0), MMPerHr: 25},
		{Time: at(18, 15), MMPerHr: 20},
	}
	res := Decide(in)
	if res.WaitUntil != nil && res.WaitUntil.Before(now) {
		t.Fatalf("WaitUntil %v must not be before Now %v", res.WaitUntil, now)
	}
}

