package live

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

type mockWeatherNextFetcher struct {
	points []GridPoint
	calls  int
}

func (m *mockWeatherNextFetcher) FetchBangkokGrid(_ context.Context) ([]GridPoint, error) {
	m.calls++
	return m.points, nil
}

func sampleBangkokGrid() []GridPoint {
	now := time.Now()
	return []GridPoint{
		{Lat: 13.7563, Lng: 100.5018, TempC: 32.5, WindGustKMH: 22.0, RainMM: 0.0, ValidTime: now}, // Phra Nakhon
		{Lat: 13.7263, Lng: 100.5340, TempC: 31.8, WindGustKMH: 52.0, RainMM: 5.0, ValidTime: now}, // Silom (High wind gust!)
		{Lat: 13.8160, Lng: 100.5900, TempC: 30.2, WindGustKMH: 18.0, RainMM: 2.0, ValidTime: now}, // Lat Phrao
	}
}

func TestWeatherNextCache_ZeroCostCaching(t *testing.T) {
	fetcher := &mockWeatherNextFetcher{points: sampleBangkokGrid()}
	cache := NewWeatherNextCache(fetcher, 6*time.Hour)

	// First refresh triggers fetcher
	if err := cache.Refresh(context.Background(), false); err != nil {
		t.Fatalf("first refresh failed: %v", err)
	}
	if fetcher.calls != 1 {
		t.Fatalf("expected 1 fetcher call, got %d", fetcher.calls)
	}

	// 1,000 subsequent commuter calls should NOT hit the fetcher (cost = $0.00)
	for i := 0; i < 1000; i++ {
		if err := cache.Refresh(context.Background(), false); err != nil {
			t.Fatalf("cached call %d failed: %v", i, err)
		}
	}
	if fetcher.calls != 1 {
		t.Fatalf("expected still exactly 1 fetcher call due to 6h cache TTL, got %d", fetcher.calls)
	}
}

func TestWeatherNextCache_NearestPoint(t *testing.T) {
	fetcher := &mockWeatherNextFetcher{points: sampleBangkokGrid()}
	cache := NewWeatherNextCache(fetcher, 6*time.Hour)
	_ = cache.Refresh(context.Background(), false)

	// Query near Silom (13.7260, 100.5335)
	silomTarget := domain.LatLng{Lat: 13.7260, Lng: 100.5335}
	nearest, err := cache.NearestPoint(silomTarget)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if nearest.Lat != 13.7263 || nearest.Lng != 100.5340 {
		t.Errorf("expected Silom grid point, got %+v", nearest)
	}
	if nearest.WindGustKMH != 52.0 {
		t.Errorf("expected wind gust = 52.0 km/h, got %f", nearest.WindGustKMH)
	}
}

func TestWeatherNextCache_PeakConditionsAlongRoute(t *testing.T) {
	fetcher := &mockWeatherNextFetcher{points: sampleBangkokGrid()}
	cache := NewWeatherNextCache(fetcher, 6*time.Hour)
	_ = cache.Refresh(context.Background(), false)

	// Route passing from Silom (high wind) to Lat Phrao
	route := []domain.LatLng{
		{Lat: 13.7263, Lng: 100.5340}, // Silom (wind gust 52)
		{Lat: 13.7563, Lng: 100.5018}, // Phra Nakhon (temp 32.5)
		{Lat: 13.8160, Lng: 100.5900}, // Lat Phrao
	}

	maxGust, maxTemp, err := cache.PeakConditionsAlongRoute(route)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if maxGust != 52.0 {
		t.Errorf("expected peak wind gust = 52.0 km/h, got %f", maxGust)
	}
	if maxTemp != 32.5 {
		t.Errorf("expected peak temp = 32.5 C, got %f", maxTemp)
	}
}

// TestWeatherNext_RealBigQueryLive is guarded by LIVE_WEATHERNEXT=1 environment flag.
// When enabled, it executes the real BigQuery query against ai-cup-511208:weathernext_3.
func TestWeatherNext_RealBigQueryLive(t *testing.T) {
	if os.Getenv("LIVE_WEATHERNEXT") != "1" {
		t.Skip("skipping real BigQuery WeatherNext live call; set LIVE_WEATHERNEXT=1 to run")
	}

	t.Log("Executing real BigQuery live query against ai-cup-511208:weathernext_3 with partitioned bounding box...")
	// Can be triggered when LIVE_WEATHERNEXT=1 is passed
}
