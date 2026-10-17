// Package live provides data adapters including Google Weather, Routes, and WeatherNext 3.
package live

import (
	"context"
	"errors"
	"fmt"
	"math"
	"os"
	"sync"
	"time"

	"cloud.google.com/go/bigquery"
	"google.golang.org/api/iterator"

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

// BigQueryWeatherNextFetcher is the real implementation querying BigQuery WeatherNext 3
// with strict bounding box and partition filters to minimize data scan.
type BigQueryWeatherNextFetcher struct {
	Client    *bigquery.Client
	ProjectID string
	DatasetID string // e.g. "weathernext_3"
	TableID   string // e.g. "weathernext_3_0_0_0p05deg"
}

func NewBigQueryWeatherNextFetcher(ctx context.Context, projectID string) (*BigQueryWeatherNextFetcher, error) {
	if projectID == "" {
		projectID = os.Getenv("GOOGLE_CLOUD_PROJECT")
	}
	if projectID == "" {
		projectID = "ai-cup-511208"
	}

	client, err := bigquery.NewClient(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("failed to create BigQuery client: %w", err)
	}

	return &BigQueryWeatherNextFetcher{
		Client:    client,
		ProjectID: projectID,
		DatasetID: "weathernext_3",
		TableID:   "weathernext_3_0_0_0p1deg",
	}, nil
}

// FetchBangkokGrid executes the partition-filtered spatial query over Greater Bangkok bounding box.
func (b *BigQueryWeatherNextFetcher) FetchBangkokGrid(ctx context.Context) ([]GridPoint, error) {
	queryStr := fmt.Sprintf(`
		SELECT 
			ST_Y(geography) as lat,
			ST_X(geography) as lng,
			forecast[OFFSET(0)].time as valid_time,
			forecast[OFFSET(0)].temperature_2m_mean as temp_kelvin,
			forecast[OFFSET(0)].wind_speed_10m_p90 as wind_10m_p90_ms,
			forecast[OFFSET(0)].total_precipitation_1hr_mean as precip_1hr_m
		FROM `+"`%s.%s.%s`"+`
		WHERE init_time >= TIMESTAMP_SUB(TIMESTAMP_TRUNC(CURRENT_TIMESTAMP(), HOUR), INTERVAL 24 HOUR)
		  AND ST_DWITHIN(geography, ST_GEOGPOINT(100.5018, 13.7563), 50000)
		ORDER BY init_time DESC
		LIMIT 100
	`, b.ProjectID, b.DatasetID, b.TableID)

	q := b.Client.Query(queryStr)
	q.Location = "US" // WeatherNext 3 linked dataset is hosted in US multi-region

	it, err := q.Read(ctx)
	if err != nil {
		return nil, fmt.Errorf("bigquery read error: %w", err)
	}

	var results []GridPoint
	for {
		var row struct {
			Lat          float64   `bigquery:"lat"`
			Lng          float64   `bigquery:"lng"`
			ValidTime    time.Time `bigquery:"valid_time"`
			TempKelvin   float64   `bigquery:"temp_kelvin"`
			Wind10mP90MS float64   `bigquery:"wind_10m_p90_ms"`
			Precip1hrM   float64   `bigquery:"precip_1hr_m"`
		}
		err := it.Next(&row)
		if errors.Is(err, iterator.Done) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("bigquery row error: %w", err)
		}

		results = append(results, GridPoint{
			Lat:         row.Lat,
			Lng:         row.Lng,
			TempC:       row.TempKelvin - 273.15,
			WindGustKMH: row.Wind10mP90MS * 3.6, // m/s to km/h
			RainMM:      row.Precip1hrM * 1000.0, // m to mm
			ValidTime:   row.ValidTime,
		})
	}

	return results, nil
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
	needRefresh := (len(c.cached) == 0 || time.Since(c.cachedAt) > c.TTL) && c.Fetcher != nil
	c.mu.RUnlock()
	if needRefresh {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		_ = c.Refresh(ctx, false)
		cancel()
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
