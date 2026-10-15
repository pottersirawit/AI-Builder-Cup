package advise

import (
	"context"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/floodspot"
	"github.com/pottersirawit/fontokmai/api/internal/notify"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
	"github.com/pottersirawit/fontokmai/api/internal/reports"
	"github.com/pottersirawit/fontokmai/api/internal/scenario"
	"github.com/pottersirawit/fontokmai/api/internal/users"
)

func at(hh, mm int) time.Time {
	return time.Date(2026, 9, 29, hh, mm, 0, 0, domain.Bangkok)
}

func setupTest(t *testing.T) (*Evaluator, *users.MemoryUserStore, *notify.MemoryNotifier, planner.Providers) {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	spots, err := floodspot.Load(filepath.Join(filepath.Dir(file), "..", "..", "..", "data", "bkk_flood_risk_points.json"))
	if err != nil {
		t.Fatal(err)
	}
	p := &planner.Planner{
		Spots:       spots,
		Trips:       scenario.Trips,
		Places:      scenario.Places,
		Whereabouts: scenario.Whereabouts,
	}
	prov := planner.Providers{
		Weather: scenario.Weather{},
		Routes:  scenario.Routes{},
		Canals:  scenario.Canals{},
		Reports: reports.NewMemoryStore(scenario.SeedReports()...),
	}

	userStore := users.NewMemoryUserStore()
	memNotifier := notify.NewMemoryNotifier()

	eval := &Evaluator{
		Planner:  p,
		Users:    userStore,
		Notifier: memNotifier,
	}

	return eval, userStore, memNotifier, prov
}

func TestEvaluator_ProactiveAlertOnWeatherChange(t *testing.T) {
	eval, userStore, notifier, prov := setupTest(t)
	ctx := context.Background()

	// Seed user trip at 16:10 for arrival at 18:30 (dinner commute)
	trip := scenario.Trips(at(16, 10))[0] // cal-dinner
	ut := users.UserTrip{
		UID:    "mew-1",
		Trip:   trip,
		Places: scenario.Places,
	}
	if err := userStore.UpsertTrip(ctx, ut); err != nil {
		t.Fatal(err)
	}

	// 1. Evaluate at 16:10 (Initial check at T-45 before rain)
	res1, err := eval.EvaluateTrip(ctx, prov, at(16, 10), "mew-1", trip.ID, true)
	if err != nil {
		t.Fatalf("eval 16:10: %v", err)
	}
	if !res1.Notified {
		t.Fatalf("expected initial check to notify user")
	}
	if res1.Verdict != decision.LeaveNow {
		t.Fatalf("got verdict %s, want %s", res1.Verdict, decision.LeaveNow)
	}
	if len(notifier.Messages) != 1 {
		t.Fatalf("messages sent = %d, want 1", len(notifier.Messages))
	}

	// 2. Evaluate again at 16:20 with NO condition change -> should NOT duplicate notify
	res2, err := eval.EvaluateTrip(ctx, prov, at(16, 20), "mew-1", trip.ID, false)
	if err != nil {
		t.Fatalf("eval 16:20: %v", err)
	}
	if res2.Notified {
		t.Fatalf("should not duplicate notify when verdict and risk haven't changed")
	}
	if len(notifier.Messages) != 1 {
		t.Fatalf("messages sent = %d, want still 1", len(notifier.Messages))
	}

	// 3. Evaluate at 17:15 when rain has reached corridor and risk rises / switch mode
	res3, err := eval.EvaluateTrip(ctx, prov, at(17, 15), "mew-1", trip.ID, false)
	if err != nil {
		t.Fatalf("eval 17:15: %v", err)
	}
	// At 17:15, rain makes car risky (deep water on Ratchada), so verdict changes
	if !res3.Notified {
		t.Fatalf("expected state change to trigger notification at 17:15")
	}
	if len(notifier.Messages) != 2 {
		t.Fatalf("messages sent = %d, want 2", len(notifier.Messages))
	}

	lastMsg := notifier.Messages[1]
	if lastMsg.Verdict == decision.LeaveNow && lastMsg.Risk == decision.RiskLow {
		t.Fatalf("expected worse verdict or higher risk than leave_now / low at 17:15, got %v %v", lastMsg.Verdict, lastMsg.Risk)
	}
}
