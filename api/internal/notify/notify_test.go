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
