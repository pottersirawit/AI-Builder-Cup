// Package reports stores community flood reports and fans them out to commuters.
package reports

import (
	"context"
	"fmt"
	"sort"
	"sync"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
)

// NotifyRadiusM is how close a commuter's route must pass to be warned.
const NotifyRadiusM = 300

// MemoryStore is the in-memory ReportStore used in dev and on a single Cloud Run
// instance. Reports are only visible once the request clock reaches CreatedAt,
// which lets seeded reports replay with the demo clock.
type MemoryStore struct {
	mu      sync.RWMutex
	reports []domain.Report
	nextID  int
}

func NewMemoryStore(seed ...domain.Report) *MemoryStore {
	return &MemoryStore{reports: append([]domain.Report(nil), seed...), nextID: 1}
}

func (s *MemoryStore) Add(_ context.Context, r domain.Report) (domain.Report, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if r.ID == "" {
		r.ID = fmt.Sprintf("r%d", s.nextID)
		s.nextID++
	}
	s.reports = append(s.reports, r)
	return r, nil
}

func (s *MemoryStore) Near(_ context.Context, center domain.LatLng, radiusM float64, since, until time.Time) ([]domain.Report, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	var out []domain.Report
	for _, r := range s.reports {
		if r.CreatedAt.Before(since) || r.CreatedAt.After(until) {
			continue
		}
		if geo.HaversineM(center, r.Point()) <= radiusM {
			out = append(out, r)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.Before(out[j].CreatedAt) })
	return out, nil
}

// NotifiedUsers counts commuters whose usual route passes within NotifyRadiusM of p.
func NotifiedUsers(users []domain.MockUser, p domain.LatLng) int {
	n := 0
	for _, u := range users {
		if geo.DistanceToPolylineM(p, u.Route) <= NotifyRadiusM {
			n++
		}
	}
	return n
}
