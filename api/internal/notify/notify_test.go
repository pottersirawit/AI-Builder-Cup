package notify

import (
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

func TestBuildLineFlexJSON(t *testing.T) {
	leaveBy := time.Date(2026, 9, 29, 16, 45, 0, 0, domain.Bangkok)
	msg := Message{
		UID:         "mew-1",
		TripID:      "cal-dinner",
		TripTitleTH: "กลับบ้านลาดพร้าว",
		Verdict:     decision.LeaveNow,
		Risk:        decision.RiskLow,
		HeadlineTH:  "ออกก่อน 16:45",
		SummaryTH:   "ฝนก้อนใหญ่ถึงพระราม 4 ราว 17:30",
		LeaveBy:     &leaveBy,
		Mode:        domain.ModeCar,
		EtaMin:      45,
		SentAt:      leaveBy.Add(-35 * time.Minute),
	}

	flex := BuildLineFlexJSON(msg)
	if flex["type"] != "bubble" || flex["size"] != "mega" {
		t.Fatalf("invalid flex root: %+v", flex)
	}

	header, ok := flex["header"].(map[string]any)
	if !ok {
		t.Fatalf("missing header: %+v", flex)
	}
	contents := header["contents"].([]any)
	badge := contents[0].(map[string]any)
	if badge["text"] != "✅ ควรออกเดินทางทันที" {
		t.Fatalf("badge text = %v", badge["text"])
	}
	headline := contents[1].(map[string]any)
	if headline["text"] != "ออกก่อน 16:45" {
		t.Fatalf("headline text = %v", headline["text"])
	}
}

func TestBuildLineFlexJSONEnglish(t *testing.T) {
	leaveBy := time.Date(2026, 9, 29, 16, 45, 0, 0, domain.Bangkok)
	tests := []struct {
		verdict decision.Verdict
		badge   string
	}{
		{decision.LeaveNow, "✅ Leave now"},
		{decision.Wait, "⏳ Wait for the rain to ease"},
		{decision.SwitchMode, "⚠️ Switch how you travel"},
		{decision.DontGo, "🚨 Very high risk, do not go out"},
	}
	for _, tt := range tests {
		msg := Message{Lang: domain.LangEN, TripTitleTH: "Dinner with family", Verdict: tt.verdict, HeadlineTH: "Leave by 16:45",
			SummaryTH: "Heavy rain reaches Rama IV around 17:30", LeaveBy: &leaveBy, Mode: domain.ModeMoto, EtaMin: 45}
		flex := BuildLineFlexJSON(msg)
		header := flex["header"].(map[string]any)["contents"].([]any)
		if got := header[0].(map[string]any)["text"]; got != tt.badge {
			t.Errorf("%s badge = %v, want %q", tt.verdict, got, tt.badge)
		}
		body := flex["body"].(map[string]any)["contents"].([]any)[1].(map[string]any)["contents"].([]any)
		trip, eta := body[0].(map[string]any)["text"], body[1].(map[string]any)["text"]
		if trip != "Trip: Dinner with family (Motorbike)" || eta != "Leave by: 16:45 (about 45 min)" {
			t.Errorf("trip = %v, eta = %v", trip, eta)
		}
	}
	msg := Message{Lang: domain.LangEN, Verdict: decision.LeaveNow, Mode: domain.ModeCar}
	body := BuildLineFlexJSON(msg)["body"].(map[string]any)["contents"].([]any)[1].(map[string]any)["contents"].([]any)
	if got := body[1].(map[string]any)["text"]; got != "Leave by: now (about 0 min)" {
		t.Errorf("no leave-by = %v", got)
	}
}
