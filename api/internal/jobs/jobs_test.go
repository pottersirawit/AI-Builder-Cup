package jobs

import (
	"context"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/advise"
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

func setupScheduler(t *testing.T) (*InlineScheduler, *notify.MemoryNotifier, *users.MemoryUserStore) {
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

	eval := &advise.Evaluator{
		Planner:  p,
		Users:    userStore,
		Notifier: memNotifier,
	}

	scheduler := NewInlineScheduler(eval, prov)
	return scheduler, memNotifier, userStore
}

func TestInlineScheduler_ScheduleAndRunDue(t *testing.T) {
	scheduler, notifier, userStore := setupScheduler(t)
	ctx := context.Background()

	trip := scenario.Trips(at(16, 10))[0] // cal-dinner
	ut := users.UserTrip{
		UID:    "user-demo",
		Trip:   trip,
		Places: scenario.Places,
	}
	if err := userStore.UpsertTrip(ctx, ut); err != nil {
		t.Fatal(err)
	}

	// Schedule check for 16:10
	t1610 := at(16, 10)
	if err := scheduler.ScheduleCheck(ctx, "user-demo", trip.ID, t1610); err != nil {
		t.Fatalf("schedule: %v", err)
	}

	// Duplicate schedule check should deduplicate cleanly
	if err := scheduler.ScheduleCheck(ctx, "user-demo", trip.ID, t1610); err != nil {
		t.Fatalf("duplicate schedule: %v", err)
	}
	if len(scheduler.Tasks) != 1 {
		t.Fatalf("task count = %d, want 1 (deduped)", len(scheduler.Tasks))
	}

	// Run due at 16:00 (task is scheduled for 16:10, so not due yet)
	res, err := scheduler.RunDue(ctx, at(16, 0))
	if err != nil {
		t.Fatal(err)
	}
	if len(res) != 0 || len(notifier.Messages) != 0 {
		t.Fatalf("expected 0 executions before scheduled time")
	}

	// Run due at 16:10 -> should execute and trigger notification
	res, err = scheduler.RunDue(ctx, at(16, 10))
	if err != nil {
		t.Fatal(err)
	}
	if len(res) != 1 {
		t.Fatalf("expected 1 result executed, got %d", len(res))
	}
	if len(notifier.Messages) != 1 {
		t.Fatalf("expected 1 message sent, got %d", len(notifier.Messages))
	}
	if notifier.Messages[0].Verdict != decision.LeaveNow {
		t.Fatalf("got verdict %s, want %s", notifier.Messages[0].Verdict, decision.LeaveNow)
	}

	// Task list should now be empty
	if len(scheduler.Tasks) != 0 {
		t.Fatalf("remaining tasks = %d, want 0", len(scheduler.Tasks))
	}
}
