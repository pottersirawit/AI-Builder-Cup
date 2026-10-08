package geo

import (
	"math"
	"testing"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

func TestHaversineM(t *testing.T) {
	tests := []struct {
		name    string
		a, b    domain.LatLng
		want    float64
		epsilon float64
	}{
		{"same point", domain.LatLng{Lat: 13.7263, Lng: 100.534}, domain.LatLng{Lat: 13.7263, Lng: 100.534}, 0, 0.01},
		{"one degree latitude", domain.LatLng{Lat: 13, Lng: 100}, domain.LatLng{Lat: 14, Lng: 100}, 111195, 50},
		{"silom to lat phrao", domain.LatLng{Lat: 13.7263, Lng: 100.5340}, domain.LatLng{Lat: 13.8160, Lng: 100.5900}, 11643, 150},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := HaversineM(tt.a, tt.b); math.Abs(got-tt.want) > tt.epsilon {
				t.Fatalf("HaversineM = %.0f, want %.0f", got, tt.want)
			}
		})
	}
}

func TestDistanceToPolylineM(t *testing.T) {
	line := []domain.LatLng{{Lat: 13.80, Lng: 100.50}, {Lat: 13.80, Lng: 100.60}}
	tests := []struct {
		name    string
		p       domain.LatLng
		want    float64
		epsilon float64
	}{
		{"on the line", domain.LatLng{Lat: 13.80, Lng: 100.55}, 0, 1},
		{"north of the middle", domain.LatLng{Lat: 13.801, Lng: 100.55}, 111, 2},
		{"beyond the end uses the endpoint", domain.LatLng{Lat: 13.80, Lng: 100.601}, 108, 2},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := DistanceToPolylineM(tt.p, line); math.Abs(got-tt.want) > tt.epsilon {
				t.Fatalf("got %.1f, want %.1f", got, tt.want)
			}
		})
	}
	if !math.IsInf(DistanceToPolylineM(domain.LatLng{}, nil), 1) {
		t.Fatal("empty polyline should be infinitely far")
	}
}

func TestDecodePolyline(t *testing.T) {
	// Example from Google's polyline algorithm documentation.
	got := DecodePolyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
	want := []domain.LatLng{{Lat: 38.5, Lng: -120.2}, {Lat: 40.7, Lng: -120.95}, {Lat: 43.252, Lng: -126.453}}
	if len(got) != len(want) {
		t.Fatalf("len = %d, want %d", len(got), len(want))
	}
	for i := range want {
		if math.Abs(got[i].Lat-want[i].Lat) > 1e-6 || math.Abs(got[i].Lng-want[i].Lng) > 1e-6 {
			t.Fatalf("point %d = %v, want %v", i, got[i], want[i])
		}
	}
}

func TestInServiceArea(t *testing.T) {
	tests := []struct {
		name string
		p    domain.LatLng
		want bool
	}{
		{"Silom", domain.LatLng{Lat: 13.7263, Lng: 100.5340}, true},
		{"Suvarnabhumi on the eastern edge", domain.LatLng{Lat: 13.69, Lng: 100.75}, true},
		{"south-west corner", domain.LatLng{Lat: 13.49, Lng: 100.30}, true},
		{"Chiang Mai", domain.LatLng{Lat: 18.79, Lng: 98.98}, false},
		{"Chachoengsao, just east", domain.LatLng{Lat: 13.69, Lng: 101.07}, false},
		{"zero point", domain.LatLng{}, false},
	}
	for _, tt := range tests {
		if got := InServiceArea(tt.p); got != tt.want {
			t.Errorf("%s: got %v, want %v", tt.name, got, tt.want)
		}
	}
}
