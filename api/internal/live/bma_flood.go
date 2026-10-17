package live

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"sync"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
)

const defaultBMAFloodURL = "https://weather.bangkok.go.th/Flood/PageMap/GetData?id=0"

// BMARoadFloodFetcher fetches real-time road flood sensor telemetry from the BMA Flood portal
// and caches the response in-memory with a short TTL (e.g. 3 minutes).
type BMARoadFloodFetcher struct {
	URL    string
	Client *http.Client
	TTL    time.Duration

	mu       sync.RWMutex
	cachedAt time.Time
	cached   []domain.RoadFloodSensor
}

func NewBMARoadFloodFetcher(url string, client *http.Client, ttl time.Duration) *BMARoadFloodFetcher {
	if url == "" {
		url = defaultBMAFloodURL
	}
	if client == nil {
		client = &http.Client{Timeout: 8 * time.Second}
	}
	if ttl <= 0 {
		ttl = 3 * time.Minute
	}
	return &BMARoadFloodFetcher{
		URL:    url,
		Client: client,
		TTL:    ttl,
	}
}

func (f *BMARoadFloodFetcher) Name() string {
	return "BMA Road Flood Sensors (live)"
}

type bmaFloodPayload struct {
	FloodTbl []struct {
		FloodCode       string  `json:"flood_code"`
		FloodShortName   string  `json:"flood_short_name"`
		FloodShortNameEN string  `json:"flood_short_name_en"`
		Latitude        float64 `json:"latitude"`
		Longitude       float64 `json:"longitude"`
		FloodDepthCM    float64 `json:"flood"`
		SiteTimestampTH string  `json:"site_timestatmpTH"`
	} `json:"floodTbl"`
}

func (f *BMARoadFloodFetcher) fetchAll() ([]domain.RoadFloodSensor, error) {
	f.mu.RLock()
	if !f.cachedAt.IsZero() && time.Since(f.cachedAt) < f.TTL {
		cached := f.cached
		f.mu.RUnlock()
		return cached, nil
	}
	f.mu.RUnlock()

	req, err := http.NewRequest(http.MethodGet, f.URL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "Fontokmai/1.0 (Bangkok Weather Resilience)")

	resp, err := f.Client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("bma flood fetch failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("bma flood unexpected status: %d", resp.StatusCode)
	}

	var payload bmaFloodPayload
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return nil, fmt.Errorf("bma flood decode error: %w", err)
	}

	var sensors []domain.RoadFloodSensor
	now := time.Now().In(domain.Bangkok)
	for _, raw := range payload.FloodTbl {
		if raw.Latitude == 0 && raw.Longitude == 0 {
			continue
		}
		updatedAt := now
		if raw.SiteTimestampTH != "" {
			for _, layout := range []string{"2006-01-02 15:04:05", "2006-01-02T15:04:05", "02/01/2006 15:04:05", "02/01/2006 15:04"} {
				if t, err := time.ParseInLocation(layout, raw.SiteTimestampTH, domain.Bangkok); err == nil {
					updatedAt = t
					break
				}
			}
		}
		sensors = append(sensors, domain.RoadFloodSensor{
			Code:      raw.FloodCode,
			NameTH:    raw.FloodShortName,
			NameEN:    raw.FloodShortNameEN,
			Lat:       raw.Latitude,
			Lng:       raw.Longitude,
			DepthCM:   raw.FloodDepthCM,
			UpdatedAt: updatedAt,
		})
	}

	f.mu.Lock()
	f.cached = sensors
	f.cachedAt = time.Now()
	f.mu.Unlock()

	return sensors, nil
}

// SensorsNearRoute filters all cached BMA road sensors down to those within radiusM of the polyline.
func (f *BMARoadFloodFetcher) SensorsNearRoute(polyline []domain.LatLng, radiusM float64) ([]domain.RoadFloodSensor, error) {
	if len(polyline) == 0 {
		return nil, nil
	}
	all, err := f.fetchAll()
	if err != nil {
		return nil, err
	}

	var near []domain.RoadFloodSensor
	for _, s := range all {
		if geo.DistanceToPolylineM(s.Point(), polyline) <= radiusM {
			near = append(near, s)
		}
	}
	return near, nil
}

// RoadFloodFallback wraps a primary provider with a scenario fallback.
type RoadFloodFallback struct {
	Primary  domain.RoadFloodProvider
	Fallback domain.RoadFloodProvider
}

func (r RoadFloodFallback) Name() string { return r.Primary.Name() }

func (r RoadFloodFallback) SensorsNearRoute(polyline []domain.LatLng, radiusM float64) ([]domain.RoadFloodSensor, error) {
	sensors, err := r.Primary.SensorsNearRoute(polyline, radiusM)
	if err == nil {
		return sensors, nil
	}
	slog.Warn("live bma road flood failed, using fallback", "err", err)
	return r.Fallback.SensorsNearRoute(polyline, radiusM)
}
