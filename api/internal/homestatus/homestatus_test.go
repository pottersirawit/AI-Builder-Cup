package homestatus

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
)

func at(hh, mm int) time.Time { return time.Date(2026, 9, 29, hh, mm, 0, 0, domain.Bangkok) }

func scenarioInput(now time.Time, reports int) Input {
	ctx := context.Background()
	canals, _ := scenario.Canals{}.Canals(ctx, scenario.Home.Point(), now)
	day := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, domain.Bangkok)
	rain, _ := scenario.Weather{}.Rain(ctx, scenario.Home.Point(), day, now)
	return Input{Now: now, Home: Home(scenario.HomeProfile), Canal: canals[0], Rain: rain, NearbyReports: reports}
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
		st := Evaluate(Input{Home: Home{FloodLevelM: 1.93}, Canal: domain.CanalReading{NameTH: "คลอง", LevelM: tt.level, BankM: tt.bank, RiseCM2h: tt.rise}})
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
