package advise

import (
	"context"
	"fmt"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/agent"
	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/notify"
	"github.com/pottersirawit/fontokmai/api/internal/planner"
	"github.com/pottersirawit/fontokmai/api/internal/users"
)

// Evaluator evaluates scheduled trips, detects risk changes, and sends alerts.
type Evaluator struct {
	Planner  *planner.Planner
	Users    users.UserStore
	Notifier notify.Notifier
	Gemini   *agent.Gemini
}

// Result is the outcome of a proactive advisory check.
type Result struct {
	Notified     bool             `json:"notified"`
	Verdict      decision.Verdict `json:"verdict"`
	Risk         decision.Risk    `json:"risk"`
	HeadlineTH   string           `json:"headline_th"`
	SummaryTH    string           `json:"summary_th"`
	LeaveBy      *time.Time       `json:"leave_by,omitempty"`
	Reasoning    []planner.Call   `json:"reasoning,omitempty"`
}

// EvaluateTrip evaluates a trip at now, compares with cached state, and notifies if needed.
func (e *Evaluator) EvaluateTrip(ctx context.Context, prov planner.Providers, now time.Time, uid, tripID string, forceNotify bool) (Result, error) {
	ut, err := e.Users.GetTrip(ctx, uid, tripID)
	if err != nil {
		return Result{}, fmt.Errorf("evaluate: %w", err)
	}

	tr := planner.TripRequest{
		TripID:      ut.Trip.ID,
		Origin:      &ut.Trip.Origin,
		Destination: &ut.Trip.Destination,
		Places:      ut.Places,
	}

	sess, err := e.Planner.Open(ctx, prov, now, tr)
	if err != nil {
		return Result{}, fmt.Errorf("planner open: %w", err)
	}

	depart := now

	req := agent.Request{
		TripID:   ut.Trip.ID,
		DepartAt: depart.Format(time.RFC3339),
		Mode:     string(ut.Trip.Mode),
	}
	sources := []string{prov.Weather.Name(), prov.Routes.Name(), prov.Canals.Name(), "BMA flood spots"}

	resp, err := agent.Decide(ctx, e.Gemini, sess, req, sources)
	if err != nil {
		return Result{}, fmt.Errorf("decide: %w", err)
	}

	currentRisk := decision.RiskLow
	for _, opt := range resp.ModeOptions {
		if opt.Mode == resp.Mode {
			currentRisk = opt.Risk
			break
		}
	}

	// Check if notification condition is met:
	// 1. Force notify (e.g. first T-45 min check)
	// 2. Verdict or risk level has changed
	// 3. Risk is High or Medium and never notified
	changed := ut.CachedVerd == nil || *ut.CachedVerd != resp.Verdict ||
		ut.CachedRisk == nil || *ut.CachedRisk != currentRisk

	shouldNotify := forceNotify || changed || (currentRisk != decision.RiskLow && ut.LastNotified == nil)

	if shouldNotify && e.Notifier != nil {
		etaMin := 0
		for _, opt := range resp.ModeOptions {
			if opt.Mode == resp.Mode {
				etaMin = opt.EtaMin
				break
			}
		}

		msg := notify.Message{
			UID:         uid,
			TripID:      ut.Trip.ID,
			TripTitleTH: ut.Trip.TitleTH,
			Verdict:     resp.Verdict,
			Risk:        currentRisk,
			HeadlineTH:  resp.HeadlineTH,
			SummaryTH:   resp.SummaryTH,
			LeaveBy:     resp.LeaveBy,
			Mode:        resp.Mode,
			EtaMin:      etaMin,
			SentAt:      now,
		}
		if err := e.Notifier.Notify(ctx, msg); err != nil {
			return Result{}, fmt.Errorf("notify: %w", err)
		}
		_ = e.Users.UpdateCachedAdvisory(ctx, uid, ut.Trip.ID, resp.Verdict, currentRisk, now)
	}

	return Result{
		Notified:   shouldNotify,
		Verdict:    resp.Verdict,
		Risk:       currentRisk,
		HeadlineTH: resp.HeadlineTH,
		SummaryTH:  resp.SummaryTH,
		LeaveBy:    resp.LeaveBy,
		Reasoning:  resp.Reasoning,
	}, nil
}
