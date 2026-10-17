package live

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"math"
	"net/http"
	"sync"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

const defaultBMATideURL = "https://weather.bangkok.go.th/Klongmap/GetDataForUpdate"

// BMATidalFetcher fetches the daily astronomical high/low tide predictions from BMA KlongMap
// to assess sea surge backwater risk in the Chao Phraya river and connected drainage canals.
type BMATidalFetcher struct {
	URL    string
	Client *http.Client
	TTL    time.Duration

	mu       sync.RWMutex
	cachedAt time.Time
	cached   domain.TidalReading
}

func NewBMATidalFetcher(url string, client *http.Client, ttl time.Duration) *BMATidalFetcher {
	if url == "" {
		url = defaultBMATideURL
	}
	if client == nil {
		client = &http.Client{Timeout: 8 * time.Second}
	}
	if ttl <= 0 {
		ttl = 15 * time.Minute
	}
	return &BMATidalFetcher{
		URL:    url,
		Client: client,
		TTL:    ttl,
	}
}

func (f *BMATidalFetcher) Name() string {
	return "BMA Canal Flow & Tidal Map (live)"
}

type bmaTidePayload struct {
	DailyHeightWater struct {
		HighWater   float64 `json:"hight_water"`
		LowWater    float64 `json:"low_water"`
		HighWaterPM float64 `json:"hight_water_pm"`
		LowWaterPM  float64 `json:"low_water_pm"`
	} `json:"dailyheightwater"`
}

func (f *BMATidalFetcher) TidalStatus(ctx context.Context, at time.Time) (domain.TidalReading, error) {
	f.mu.RLock()
	if !f.cachedAt.IsZero() && time.Since(f.cachedAt) < f.TTL {
		cached := f.cached
		f.mu.RUnlock()
		return cached, nil
	}
	f.mu.RUnlock()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, f.URL, nil)
	if err != nil {
		return domain.TidalReading{}, err
	}
	req.Header.Set("User-Agent", "Fontokmai/1.0 (Bangkok Weather Resilience)")

	resp, err := f.Client.Do(req)
	if err != nil {
		return domain.TidalReading{}, fmt.Errorf("bma tide fetch failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return domain.TidalReading{}, fmt.Errorf("bma tide unexpected status: %d", resp.StatusCode)
	}

	var payload bmaTidePayload
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return domain.TidalReading{}, fmt.Errorf("bma tide decode error: %w", err)
	}

	dhw := payload.DailyHeightWater
	maxHigh := math.Max(dhw.HighWater, dhw.HighWaterPM)
	minLow := math.Min(dhw.LowWater, dhw.LowWaterPM)

	surgeRisk := "low"
	if maxHigh >= 1.0 {
		surgeRisk = "high"
	} else if maxHigh >= 0.7 {
		surgeRisk = "medium"
	}

	reading := domain.TidalReading{
		HighTideM:    maxHigh,
		HighTideTime: at,
		LowTideM:     minLow,
		SurgeRisk:    surgeRisk,
	}

	f.mu.Lock()
	f.cached = reading
	f.cachedAt = time.Now()
	f.mu.Unlock()

	return reading, nil
}

// TidalFallback wraps a primary tidal provider with a scenario fallback.
type TidalFallback struct {
	Primary  domain.TidalProvider
	Fallback domain.TidalProvider
}

func (t TidalFallback) Name() string { return t.Primary.Name() }

func (t TidalFallback) TidalStatus(ctx context.Context, at time.Time) (domain.TidalReading, error) {
	status, err := t.Primary.TidalStatus(ctx, at)
	if err == nil {
		return status, nil
	}
	slog.Warn("live bma tide failed, using fallback", "err", err)
	return t.Fallback.TidalStatus(ctx, at)
}
