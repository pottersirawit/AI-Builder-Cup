package homestatus

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func at(hh, mm int) time.Time { return time.Date(2026, 9, 29, hh, mm, 0, 0, domain.Bangkok) }

func scenarioInput(now time.Time, reports int) Input {
	ctx := context.Background()
	canals, _ := scenario.Canals{}.Canals(ctx, scenario.Home.Point(), now)
	day := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, domain.Bangkok)
	rain, _ := scenario.Weather{}.Rain(ctx, scenario.Home.Point(), day, now)
	return Input{Now: now, Home: Home(scenario.HomeProfile), Canals: canals, Rain: rain, NearbyReports: reports}
}

func TestEvaluateScenario(t *testing.T) {
	tests := []struct {
		name         string
		now          time.Time
		reports      int
		wantLevel    Level
		wantHeadline string
		wantSummary  []string
		wantFirst    string
	}{
		{"16:10 home card says watch", at(16, 10), 0, Watch, "คืนนี้เสี่ยงน้ำท่วม: ปานกลาง", []string{"คลองลาดพร้าว 1.4 ม. ต่ำกว่าตลิ่ง 0.4 ม."}, "ชาร์จ"},
		{"21:40 flood mode", at(21, 40), 11, Danger, "น้ำจะถึงหน้าบ้านใน 40 นาที",
			[]string{"(1.8 / 1.8 ม.)", "ขึ้น 40 ซม. ใน 2 ชั่วโมง", "ฝนสะสมวันนี้ 68 มม.", "รายงานผู้ใช้ 11 คน"}, "ย้ายรถไปจอดที่ลานจอดเซ็นทรัลลาดพร้าว 1.2 กม. ถนนยังแห้งอีก 25 นาที"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			st := Evaluate(scenarioInput(tt.now, tt.reports))
			if st.Level != tt.wantLevel || st.HeadlineTH != tt.wantHeadline {
				t.Fatalf("got %s %q", st.Level, st.HeadlineTH)
			}
			for _, s := range tt.wantSummary {
				if !strings.Contains(st.SummaryTH, s) {
					t.Errorf("summary %q should contain %q", st.SummaryTH, s)
				}
			}
			if !strings.HasPrefix(st.Actions[0].TextTH, tt.wantFirst) {
				t.Errorf("first action = %q", st.Actions[0].TextTH)
			}
		})
	}
}

func TestEvaluateLevels(t *testing.T) {
	tests := []struct {
		level, bank, rise float64
		want              Level
	}{
		{0.5, 1.8, 0, Normal},
		{1.4, 1.8, 0, Watch},
		{1.0, 1.8, 25, Watch},
		{1.65, 1.8, 35, Danger},
		{1.75, 1.8, 0, Danger},
	}
	for _, tt := range tests {
		st := Evaluate(Input{Home: Home{FloodLevelM: 1.93}, Canals: []domain.CanalReading{{NameTH: "คลอง", LevelM: tt.level, BankM: tt.bank, RiseCM2h: tt.rise}}})
		if st.Level != tt.want {
			t.Errorf("%v/%v rise %v: got %s, want %s", tt.level, tt.bank, tt.rise, st.Level, tt.want)
		}
	}
}

func TestRainTotalMM(t *testing.T) {
	samples := []domain.RainSample{{Time: at(18, 0), MMPerHr: 40}, {Time: at(18, 15), MMPerHr: 20}, {Time: at(19, 0), MMPerHr: 10}}
	tests := []struct {
		now  time.Time
		want float64
	}{
		{at(18, 0), 0},
		{at(18, 15), 10},
		{at(19, 0), 25},
		{at(19, 30), 30},
		{at(23, 0), 35},
	}
	for _, tt := range tests {
		if got := rainTotalMM(samples, tt.now); got != tt.want {
			t.Errorf("%s: got %v, want %v", tt.now.Format("15:04"), got, tt.want)
		}
	}
}

// bangNa is far from every scenario canal station (the nearest is 4 km away).
var bangNa = domain.Place{NameTH: "คอนโดบางนา", Lat: 13.6681, Lng: 100.6046}

var udomSuk = floodspot.Spot{ID: "S-UDOMSUK", NameTH: "ถนนสุขุมวิท ช่วงอุดมสุข", Lat: 13.6799, Lng: 100.6094,
	RiskRadiusM: 800, ThresholdMMPerHr: 35, MaxDepthCM: 30}

func rainAt(now time.Time, mm float64) []domain.RainSample {
	return []domain.RainSample{{Time: now.Add(-2 * time.Hour), MMPerHr: 0}, {Time: now.Add(-15 * time.Minute), MMPerHr: mm}, {Time: now.Add(time.Hour), MMPerHr: 0}}
}

func TestEvaluateWithoutCanalUsesRainAndFloodSpots(t *testing.T) {
	canals, _ := scenario.Canals{}.Canals(context.Background(), bangNa.Point(), at(18, 30))
	far := floodspot.Spot{ID: "S-FAR", NameTH: "ถนนรัชดาภิเษก", Lat: 13.8219, Lng: 100.5752, ThresholdMMPerHr: 35, MaxDepthCM: 25}
	tests := []struct {
		name         string
		rain         float64
		reports      int
		want         Level
		wantHeadline string
		wantSummary  []string
	}{
		{"dry", 0, 0, Normal, "แถวบ้านยังไม่มีน้ำท่วม", []string{"ไม่มีสถานีวัดระดับคลองใกล้บ้าน", "จุดน้ำท่วม กทม. 1 จุดในรัศมี 2 กม."}},
		{"heavy rain floods Udom Suk", 52, 0, Danger, "น้ำท่วมถนนแถวบ้านได้ถึง 22 ซม.", []string{"สุขุมวิท อาจมีน้ำขัง 22 ซม.", "ฝนหนักสุด 52 มม./ชม."}},
		{"moderate rain", 20, 0, Watch, "เฝ้าระวังน้ำขังแถวบ้าน", []string{"ไม่มีสถานีวัดระดับคลองใกล้บ้าน"}},
		{"neighbours report water", 0, 3, Danger, "ถนนแถวบ้านน้ำท่วม", []string{"รายงานผู้ใช้ 3 คน"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			now := at(18, 30)
			st := Evaluate(Input{Now: now, Home: Home{Place: bangNa}, Canals: canals, Rain: rainAt(now, tt.rain),
				Spots: []floodspot.Spot{udomSuk, far}, NearbyReports: tt.reports, CanalSource: "ThaiWater", WeatherSource: "Weather"})
			if st.Canal != nil || st.MinutesToDoorstep != nil {
				t.Fatalf("no canal within 3 km, got %+v", st.Canal)
			}
			if st.Level != tt.want || st.HeadlineTH != tt.wantHeadline {
				t.Fatalf("got %s %q (%s)", st.Level, st.HeadlineTH, st.SummaryTH)
			}
			for _, s := range tt.wantSummary {
				if !strings.Contains(st.SummaryTH, s) {
					t.Errorf("summary %q should contain %q", st.SummaryTH, s)
				}
			}
			if len(st.FloodSpots) != 1 || st.FloodSpots[0].ID != "S-UDOMSUK" || st.FloodSpots[0].DistanceM < 1300 || st.FloodSpots[0].DistanceM > 1500 {
				t.Fatalf("flood spots %+v", st.FloodSpots)
			}
			if !st.InServiceArea || st.Place != bangNa || len(st.Actions) == 0 {
				t.Fatalf("got %+v", st)
			}
			if strings.Join(st.Sources, ",") != "Weather,BMA flood spots,รายงานผู้ใช้" {
				t.Fatalf("sources %v", st.Sources)
			}
		})
	}
}

func TestEvaluateUsesTheNearestCanalWithin3km(t *testing.T) {
	home := domain.Place{NameTH: "บ้าน", Lat: 13.80, Lng: 100.60}
	near := domain.CanalReading{NameTH: "คลองใกล้", Lat: 13.82, Lng: 100.60, LevelM: 1.75, BankM: 1.8, Source: "ThaiWater (HII)"} // 2.2 km
	far := domain.CanalReading{NameTH: "คลองไกล", Lat: 13.84, Lng: 100.60, LevelM: 0.5, BankM: 1.8}                               // 4.4 km
	st := Evaluate(Input{Home: Home{Place: home}, Canals: []domain.CanalReading{far, near}, CanalSource: "ThaiWater (HII)", WeatherSource: "W"})
	if st.Canal == nil || st.Canal.NameTH != "คลองใกล้" || st.Level != Danger || st.MinutesToDoorstep != nil {
		t.Fatalf("got %+v %+v", st, st.Canal)
	}
	if st.Sources[0] != "ThaiWater (HII)" {
		t.Fatalf("sources %v", st.Sources)
	}
	for _, a := range st.Actions {
		if strings.Contains(a.TextTH, "ที่ ถนน") || strings.HasSuffix(a.TextTH, ": ") {
			t.Errorf("action %q leaks an empty demo profile field", a.TextTH)
		}
	}
	if st := Evaluate(Input{Home: Home{Place: home}, Canals: []domain.CanalReading{far}}); st.Canal != nil {
		t.Fatalf("4.4 km station should not count, got %+v", st.Canal)
	}
}

func TestEvaluateOutsideServiceArea(t *testing.T) {
	chiangMai := domain.Place{NameTH: "เชียงใหม่", Lat: 18.79, Lng: 98.98}
	st := Evaluate(Input{Now: at(18, 0), Home: Home{Place: chiangMai}, Rain: rainAt(at(18, 0), 5)})
	if st.InServiceArea || st.Canal != nil || len(st.FloodSpots) != 0 || !strings.Contains(st.SummaryTH, "นอกพื้นที่ที่แอปรองรับ") {
		t.Fatalf("got %+v", st)
	}
}

func hasThai(s string) bool { return domain.HasThai(s) }

func TestEvaluateEnglishHasNoThai(t *testing.T) {
	udomSukEN := udomSuk
	udomSukEN.NameEN = "Sukhumvit Rd (Udom Suk)"
	bangNaCanals, _ := scenario.Canals{}.Canals(context.Background(), bangNa.Point(), at(18, 30))
	chiangMai := domain.Place{NameTH: "Home", Lat: 18.79, Lng: 98.98}
	tests := []struct {
		name string
		in   Input
		want Level
	}{
		{"canal watch", scenarioInput(at(16, 10), 0), Watch},
		{"canal normal", Input{Now: at(12, 0), Home: Home{Place: scenario.Home}, Canals: []domain.CanalReading{{NameTH: "คลองลาดพร้าว", NameEN: "Lat Phrao Canal", Lat: 13.8185, Lng: 100.5935, LevelM: 0.5, BankM: 1.8}}}, Normal},
		{"canal watch with reports", scenarioInput(at(19, 40), 2), Watch},
		{"canal danger with door ETA", scenarioInput(at(21, 40), 11), Danger},
		{"canal danger past bank", scenarioInput(at(23, 0), 1), Danger},
		{"no canal, out of area", Input{Now: at(18, 0), Home: Home{Place: chiangMai}, Rain: rainAt(at(18, 0), 30)}, Watch},
		{"no canal, dry", Input{Now: at(18, 30), Home: Home{Place: bangNa}, Canals: bangNaCanals, Rain: rainAt(at(18, 30), 0), Spots: []floodspot.Spot{udomSukEN}}, Normal},
		{"no canal, deep water", Input{Now: at(18, 30), Home: Home{Place: bangNa}, Canals: bangNaCanals, Rain: rainAt(at(18, 30), 52), Spots: []floodspot.Spot{udomSukEN}}, Danger},
		{"no canal, spot without English name", Input{Now: at(18, 30), Home: Home{Place: bangNa}, Rain: rainAt(at(18, 30), 20)}, Watch},
		{"no canal, neighbours report", Input{Now: at(18, 30), Home: Home{Place: bangNa}, Rain: rainAt(at(18, 30), 0), NearbyReports: 3}, Danger},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			th := Evaluate(tt.in)
			tt.in.Lang = domain.LangEN
			en := Evaluate(tt.in)
			if en.Level != tt.want || en.Level != th.Level {
				t.Fatalf("level en=%s th=%s want %s", en.Level, th.Level, tt.want)
			}
			fields := []string{en.HeadlineTH, en.SummaryTH, strings.Join(en.Sources, "|")}
			for _, a := range en.Actions {
				fields = append(fields, a.TextTH)
			}
			if en.Canal != nil {
				fields = append(fields, en.Canal.NameTH)
			}
			for _, f := range fields {
				if f == "" || hasThai(f) {
					t.Errorf("English field is empty or has Thai: %q", f)
				}
			}
			if len(en.Actions) != len(th.Actions) {
				t.Errorf("action count differs: en %d th %d", len(en.Actions), len(th.Actions))
			}
		})
	}
}

func TestEvaluateEnglishWording(t *testing.T) {
	st := Evaluate(func() Input { in := scenarioInput(at(21, 40), 11); in.Lang = domain.LangEN; return in }())
	if st.HeadlineTH != "Water will reach your door in 40 minutes" {
		t.Errorf("headline = %q", st.HeadlineTH)
	}
	for _, s := range []string{"Lat Phrao Canal has reached its bank (1.8 / 1.8 m).", "Up 40 cm in 2 hours.", "Rain today: 68 mm.", "11 reports near home"} {
		if !strings.Contains(st.SummaryTH, s) {
			t.Errorf("summary %q should contain %q", st.SummaryTH, s)
		}
	}
	if got := st.Actions[0].TextTH; got != "Move your car to the Central Ladprao car park (1.2 km). The road stays dry for another 25 minutes." {
		t.Errorf("first action = %q", got)
	}
}
