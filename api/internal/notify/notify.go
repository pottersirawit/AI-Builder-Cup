package notify

import (
	"context"
	"fmt"
	"log/slog"
	"sync"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

// Message is an advisory message delivered to a user via LINE or FCM.
type Message struct {
	Lang        domain.Lang      `json:"lang,omitempty"` // language of the fixed text around the headline and summary
	UID         string           `json:"uid"`
	TripID      string           `json:"trip_id"`
	TripTitleTH string           `json:"trip_title_th"`
	Verdict     decision.Verdict `json:"verdict"`
	Risk        decision.Risk    `json:"risk"`
	HeadlineTH  string           `json:"headline_th"`
	SummaryTH   string           `json:"summary_th"`
	LeaveBy     *time.Time       `json:"leave_by,omitempty"`
	Mode        domain.Mode      `json:"mode"`
	EtaMin      int              `json:"eta_min"`
	SentAt      time.Time        `json:"sent_at"`
}

// Notifier sends advisory alerts across communication channels.
type Notifier interface {
	Notify(ctx context.Context, msg Message) error
}

// MemoryNotifier captures sent messages for tests and inspections.
type MemoryNotifier struct {
	mu       sync.Mutex
	Messages []Message
}

func NewMemoryNotifier() *MemoryNotifier {
	return &MemoryNotifier{}
}

func (m *MemoryNotifier) Notify(_ context.Context, msg Message) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.Messages = append(m.Messages, msg)
	return nil
}

// LogNotifier writes advisories to structured slog.
type LogNotifier struct{}

func (l *LogNotifier) Notify(_ context.Context, msg Message) error {
	slog.Info("PROACTIVE ADVISORY NOTIFY",
		"uid", msg.UID,
		"trip", msg.TripTitleTH,
		"verdict", msg.Verdict,
		"headline", msg.HeadlineTH,
		"summary", msg.SummaryTH,
	)
	return nil
}

// BuildLineFlexJSON creates a standard LINE Flex Message bubble JSON representation.
func BuildLineFlexJSON(msg Message) map[string]any {
	colorBadge := "#34D399" // emerald
	l := msg.Lang
	badgeText := l.Pick("เดินทางปลอดภัย", "Safe to travel")
	switch msg.Verdict {
	case decision.DontGo:
		colorBadge = "#F43F5E" // rose
		badgeText = l.Pick("🚨 เสี่ยงสูงมาก ไม่ควรออก", "🚨 Very high risk, do not go out")
	case decision.SwitchMode:
		colorBadge = "#F59E0B" // amber
		badgeText = l.Pick("⚠️ แนะนำเปลี่ยนวิธีเดินทาง", "⚠️ Switch how you travel")
	case decision.Wait:
		colorBadge = "#F59E0B"
		badgeText = l.Pick("⏳ ควรรอฝนซา", "⏳ Wait for the rain to ease")
	case decision.LeaveNow:
		badgeText = l.Pick("✅ ควรออกเดินทางทันที", "✅ Leave now")
	}

	leaveByStr := l.Pick("ตอนนี้", "now")
	if msg.LeaveBy != nil {
		leaveByStr = msg.LeaveBy.Format(l.Pick("15:04 น.", "15:04"))
	}

	return map[string]any{
		"type": "bubble",
		"size": "mega",
		"header": map[string]any{
			"type":            "box",
			"layout":          "vertical",
			"backgroundColor": "#091122",
			"contents": []any{
				map[string]any{
					"type":   "text",
					"text":   badgeText,
					"color":  colorBadge,
					"size":   "sm",
					"weight": "bold",
				},
				map[string]any{
					"type":   "text",
					"text":   msg.HeadlineTH,
					"color":  "#FFFFFF",
					"size":   "xl",
					"weight": "bold",
					"margin": "md",
					"wrap":   true,
				},
			},
		},
		"body": map[string]any{
			"type":            "box",
			"layout":          "vertical",
			"backgroundColor": "#0B132B",
			"contents": []any{
				map[string]any{
					"type":  "text",
					"text":  msg.SummaryTH,
					"color": "#E2E8F0",
					"size":  "md",
					"wrap":  true,
				},
				map[string]any{
					"type":    "box",
					"layout":  "vertical",
					"margin":  "lg",
					"spacing": "sm",
					"contents": []any{
						map[string]any{
							"type":  "text",
							"text":  l.Pick(fmt.Sprintf("ทริป: %s (%s)", msg.TripTitleTH, msg.Mode.NameTH()), fmt.Sprintf("Trip: %s (%s)", msg.TripTitleTH, msg.Mode.Label(l))),
							"color": "#94A3B8",
							"size":  "sm",
						},
						map[string]any{
							"type":  "text",
							"text":  l.Pick(fmt.Sprintf("เวลาควรออก: %s (ใช้เวลาราว %d นาที)", leaveByStr, msg.EtaMin), fmt.Sprintf("Leave by: %s (about %d min)", leaveByStr, msg.EtaMin)),
							"color": "#94A3B8",
							"size":  "sm",
						},
					},
				},
			},
		},
	}
}
