package jobs

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/advise"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
)

// Task represents a scheduled check for a user trip.
type Task struct {
	Name        string    `json:"name"` // unique task name for deduplication
	UID         string    `json:"uid"`
	TripID      string    `json:"trip_id"`
	ScheduledAt time.Time `json:"scheduled_at"`
}

// Scheduler schedules future proactive advisory checks.
type Scheduler interface {
	ScheduleCheck(ctx context.Context, uid, tripID string, runAt time.Time) error
}

// InlineScheduler triggers evaluation immediately or stores it for inspection/execution.
type InlineScheduler struct {
	mu        sync.Mutex
	Tasks     []Task
	Evaluator *advise.Evaluator
	Prov      planner.Providers
}

func NewInlineScheduler(eval *advise.Evaluator, prov planner.Providers) *InlineScheduler {
	return &InlineScheduler{
		Evaluator: eval,
		Prov:      prov,
	}
}

// TaskName generates a deduplication name for a trip check.
func TaskName(uid, tripID string, runAt time.Time) string {
	return fmt.Sprintf("check-%s-%s-%d", uid, tripID, runAt.Unix())
}

func (s *InlineScheduler) ScheduleCheck(ctx context.Context, uid, tripID string, runAt time.Time) error {
	s.mu.Lock()
	name := TaskName(uid, tripID, runAt)
	for _, t := range s.Tasks {
		if t.Name == name {
			s.mu.Unlock()
			return nil // already scheduled
		}
	}
	task := Task{
		Name:        name,
		UID:         uid,
		TripID:      tripID,
		ScheduledAt: runAt,
	}
	s.Tasks = append(s.Tasks, task)
	s.mu.Unlock()

	return nil
}

// RunDue executes all tasks that are scheduled at or before now.
func (s *InlineScheduler) RunDue(ctx context.Context, now time.Time) ([]advise.Result, error) {
	s.mu.Lock()
	var due []Task
	var remaining []Task
	for _, t := range s.Tasks {
		if !t.ScheduledAt.After(now) {
			due = append(due, t)
		} else {
			remaining = append(remaining, t)
		}
	}
	s.Tasks = remaining
	s.mu.Unlock()

	var results []advise.Result
	for _, t := range due {
		res, err := s.Evaluator.EvaluateTrip(ctx, s.Prov, now, t.UID, t.TripID, false)
		if err != nil {
			return results, fmt.Errorf("task %s failed: %w", t.Name, err)
		}
		results = append(results, res)
	}
	return results, nil
}
