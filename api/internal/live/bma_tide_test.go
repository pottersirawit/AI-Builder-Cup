package live

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

func TestBMATidal_ParseAndHighSurgeEvaluation(t *testing.T) {
	mockResponse := map[string]any{
		"dailyheightwater": map[string]any{
			"hight_water":    1.15,
			"low_water":      -0.35,
			"hight_water_pm": 1.20,
			"low_water_pm":   0.45,
		},
	}

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(mockResponse)
	}))
	defer ts.Close()

	fetcher := NewBMATidalFetcher(ts.URL, ts.Client(), 15*time.Minute)

	reading, err := fetcher.TidalStatus(context.Background(), time.Date(2026, 10, 15, 18, 0, 0, 0, domain.Bangkok))
	if err != nil {
		t.Fatalf("TidalStatus error: %v", err)
	}

	if reading.HighTideM != 1.20 {
		t.Errorf("expected HighTideM = 1.20, got %v", reading.HighTideM)
	}
	if reading.SurgeRisk != "high" {
		t.Errorf("expected high surge risk for tide > 1.0m, got %v", reading.SurgeRisk)
	}
}

func TestBMATidal_Caching(t *testing.T) {
	calls := 0
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"dailyheightwater": map[string]any{"hight_water": 0.8},
		})
	}))
	defer ts.Close()

	fetcher := NewBMATidalFetcher(ts.URL, ts.Client(), 10*time.Minute)

	for i := 0; i < 5; i++ {
		_, _ = fetcher.TidalStatus(context.Background(), time.Now())
	}

	if calls != 1 {
		t.Fatalf("expected 1 HTTP call due to cache, got %d", calls)
	}
}
