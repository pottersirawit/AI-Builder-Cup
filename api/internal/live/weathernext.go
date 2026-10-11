// Package live provides data adapters including Google Weather, Routes, and WeatherNext 3.
package live

import (
	"context"
	"fmt"
	"math"
	"sync"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
)

// GridPoint represents an interpolated WeatherNext 3 ~5km forecast cell.
type GridPoint struct {
	Lat         float64
	Lng         float64
	TempC       float64
	WindGustKMH float64
	RainMM      float64
	ValidTime   time.Time
}

// Bounding box for Greater Bangkok & perimeter.
const (
	MinLat = 13.40
	MaxLat = 14.20
	MinLng = 100.30
	MaxLng = 101.00
)

// WeatherNextFetcher abstracts fetching raw partition data (from real BigQuery or test mock).
type WeatherNextFetcher interface {
	FetchBangkokGrid(ctx context.Context) ([]GridPoint, error)
}

// WeatherNextCache implements an in-memory cached extractor that refreshes on model cadence (6h)
// ensuring $0.00 compute cost per commuter request and < 1ms spatial lookup.
type WeatherNextCache struct {
	Fetcher  WeatherNextFetcher
	TTL      time.Duration
	mu       sync.RWMutex
	cached   []GridPoint
	cachedAt time.Time
}

func NewWeatherNextCache(fetcher WeatherNextFetcher, ttl time.Duration) *WeatherNextCache {
	if ttl <= 0 {
		ttl = 6 * time.Hour
	}
	return &WeatherNextCache{
		Fetcher: fetcher,
		TTL:     ttl,
	}
}

// Name identifies the provider.
func (c *WeatherNextCache) Name() string {
	return "Google DeepMind WeatherNext 3 (Cached Grid)"
}

// Refresh reloads the Bangkok grid from the fetcher if expired.
func (c *WeatherNextCache) Refresh(ctx context.Context, force bool) error {
	c.mu.RLock()
	expired := time.Since(c.cachedAt) > c.TTL || len(c.cached) == 0
	c.mu.RUnlock()

	if !expired && !force {
		return nil
	}

	c.mu.Lock()
	defer c.mu.Unlock()

	// Double-check after acquiring write lock
	if !force && time.Since(c.cachedAt) <= c.TTL && len(c.cached) > 0 {
		return nil
	}

	if c.Fetcher == nil {
		return fmt.Errorf("no fetcher configured for WeatherNext")
	}

	grid, err := c.Fetcher.FetchBangkokGrid(ctx)
	if err != nil {
		return fmt.Errorf("failed to fetch WeatherNext grid: %w", err)
	}

	c.cached = grid
	c.cachedAt = time.Now()
	return nil
}

// NearestPoint performs in-memory spatial nearest-neighbor search (< 1ms).
func (c *WeatherNextCache) NearestPoint(p domain.LatLng) (GridPoint, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	if len(c.cached) == 0 {
		return GridPoint{}, fmt.Errorf("weathernext cache empty")
	}

	var best GridPoint
	minDist := math.Inf(1)
	for _, gp := range c.cached {
		d := geo.HaversineM(p, domain.LatLng{Lat: gp.Lat, Lng: gp.Lng})
		if d < minDist {
			minDist = d
			best = gp
		}
	}
	return best, nil
}

// PeakConditionsAlongRoute computes maximum wind gusts and temperatures along a commuter route polyline.
func (c *WeatherNextCache) PeakConditionsAlongRoute(polyline []domain.LatLng) (maxGust float64, maxTemp float64, err error) {
	if len(polyline) == 0 {
		return 0, 0, nil
	}

	c.mu.RLock()
	defer c.mu.RUnlock()

	if len(c.cached) == 0 {
		return 0, 0, fmt.Errorf("weathernext cache empty")
	}

	// Sample every ~5th point or endpoints to keep lookup < 0.2ms
	step := max(1, len(polyline)/10)
	for i := 0; i < len(polyline); i += step {
		pt := polyline[i]
		var closest GridPoint
		minDist := math.Inf(1)
		for _, gp := range c.cached {
			d := geo.HaversineM(pt, domain.LatLng{Lat: gp.Lat, Lng: gp.Lng})
			if d < minDist {
				minDist = d
				closest = gp
			}
		}
		if closest.WindGustKMH > maxGust {
			maxGust = closest.WindGustKMH
		}
		if closest.TempC > maxTemp {
			maxTemp = closest.TempC
		}
	}
	return maxGust, maxTemp, nil
}
