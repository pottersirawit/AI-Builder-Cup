package users

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/decision"
	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

// UserTrip stores a trip associated with a user and its cached risk state.
type UserTrip struct {
	UID          string               `json:"uid"`
	Trip         domain.Trip          `json:"trip"`
	CachedRisk   *decision.Risk       `json:"cached_risk,omitempty"`
	CachedVerd   *decision.Verdict    `json:"cached_verdict,omitempty"`
	LastNotified *time.Time           `json:"last_notified,omitempty"`
	Places       []domain.SavedPlace  `json:"places,omitempty"`
	UpdatedAt    time.Time            `json:"updated_at"`
}

// UserStore manages user profiles, trips, and cached risk states.
type UserStore interface {
	GetTrip(ctx context.Context, uid, tripID string) (UserTrip, error)
	FindTripByID(ctx context.Context, tripID string) (UserTrip, error)
	UpsertTrip(ctx context.Context, ut UserTrip) error
	ListTrips(ctx context.Context, uid string) ([]UserTrip, error)
	UpdateCachedAdvisory(ctx context.Context, uid, tripID string, verdict decision.Verdict, risk decision.Risk, notifiedAt time.Time) error
}

// MemoryUserStore implements UserStore in memory for dev and tests.
type MemoryUserStore struct {
	mu    sync.RWMutex
	trips map[string]UserTrip // key: uid + ":" + tripID
}

func NewMemoryUserStore() *MemoryUserStore {
	return &MemoryUserStore{trips: make(map[string]UserTrip)}
}

func key(uid, tripID string) string {
	return fmt.Sprintf("%s:%s", uid, tripID)
}

func (m *MemoryUserStore) GetTrip(_ context.Context, uid, tripID string) (UserTrip, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	ut, ok := m.trips[key(uid, tripID)]
	if !ok {
		return UserTrip{}, fmt.Errorf("trip %s not found for user %s", tripID, uid)
	}
	return ut, nil
}

func (m *MemoryUserStore) FindTripByID(_ context.Context, tripID string) (UserTrip, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	for _, ut := range m.trips {
		if ut.Trip.ID == tripID {
			return ut, nil
		}
	}
	return UserTrip{}, fmt.Errorf("trip %s not found in store", tripID)
}

func (m *MemoryUserStore) UpsertTrip(_ context.Context, ut UserTrip) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	ut.UpdatedAt = time.Now()
	m.trips[key(ut.UID, ut.Trip.ID)] = ut
	return nil
}

func (m *MemoryUserStore) ListTrips(_ context.Context, uid string) ([]UserTrip, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	var out []UserTrip
	for _, ut := range m.trips {
		if ut.UID == uid {
			out = append(out, ut)
		}
	}
	return out, nil
}

func (m *MemoryUserStore) UpdateCachedAdvisory(_ context.Context, uid, tripID string, verdict decision.Verdict, risk decision.Risk, notifiedAt time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	k := key(uid, tripID)
	ut, ok := m.trips[k]
	if !ok {
		return fmt.Errorf("trip %s not found for user %s", tripID, uid)
	}
	ut.CachedVerd = &verdict
	ut.CachedRisk = &risk
	if !notifiedAt.IsZero() {
		ut.LastNotified = &notifiedAt
	}
	ut.UpdatedAt = time.Now()
	m.trips[k] = ut
	return nil
}
