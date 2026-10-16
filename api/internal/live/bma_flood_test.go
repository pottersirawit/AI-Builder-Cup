package live

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

func TestBMARoadFlood_ParseAndDistanceFilter(t *testing.T) {
	mockResponse := map[string]any{
		"floodTbl": []map[string]any{
			{
				"flood_code":          "TN.DDG.01",
				"flood_short_name":    "อุโมงค์ทางลอดดินแดง",
				"flood_short_name_en": "Din Daeng Underpass Tunnel",
				"latitude":            13.76391,
				"longitude":           100.54820,
				"flood":               12.5,
				"site_timestatmpTH":   "15/10/2569 22:55",
			},
			{
				"flood_code":          "FL.BBN.01",
				"flood_short_name":    "ถนนเอกชัย หน้าบิ๊กซี",
				"flood_short_name_en": "Thanon Ekkachai, Big C",
				"latitude":            13.67942,
				"longitude":           100.43563,
				"flood":               0.0,
				"site_timestatmpTH":   "15/10/2569 22:55",
			},
		},
	}

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(mockResponse)
	}))
	defer ts.Close()

	fetcher := NewBMARoadFloodFetcher(ts.URL, ts.Client(), 3*time.Minute)

	// Route passing right next to Din Daeng underpass (within 100 meters)
	polyline := []domain.LatLng{
		{Lat: 13.7635, Lng: 100.5480},
		{Lat: 13.7645, Lng: 100.5485},
	}

	sensors, err := fetcher.SensorsNearRoute(polyline, 250)
	if err != nil {
		t.Fatalf("SensorsNearRoute error: %v", err)
	}

	if len(sensors) != 1 {
		t.Fatalf("expected 1 sensor near Din Daeng route, got %d", len(sensors))
	}

	if sensors[0].Code != "TN.DDG.01" || sensors[0].DepthCM != 12.5 {
		t.Errorf("unexpected sensor: %+v", sensors[0])
	}
}

func TestBMARoadFlood_Caching(t *testing.T) {
	calls := 0
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{"floodTbl": []map[string]any{}})
	}))
	defer ts.Close()

	fetcher := NewBMARoadFloodFetcher(ts.URL, ts.Client(), 5*time.Minute)

	polyline := []domain.LatLng{{Lat: 13.76, Lng: 100.54}}
	for i := 0; i < 5; i++ {
		_, _ = fetcher.SensorsNearRoute(polyline, 500)
	}

	if calls != 1 {
		t.Fatalf("expected 1 HTTP call due to cache, got %d", calls)
	}
}
