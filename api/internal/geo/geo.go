// Package geo has the small amount of spherical geometry the API needs.
package geo

import (
	"math"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

const earthRadiusM = 6371000.0

// CommuterNotifyRadiusM is how close a route corridor or point must be to a sensor/hazard (300m).
const CommuterNotifyRadiusM = 300.0

// HaversineM is the great-circle distance in metres.
func HaversineM(a, b domain.LatLng) float64 {
	phi1, phi2 := rad(a.Lat), rad(b.Lat)
	dPhi, dLambda := rad(b.Lat-a.Lat), rad(b.Lng-a.Lng)
	h := math.Sin(dPhi/2)*math.Sin(dPhi/2) + math.Cos(phi1)*math.Cos(phi2)*math.Sin(dLambda/2)*math.Sin(dLambda/2)
	return earthRadiusM * 2 * math.Atan2(math.Sqrt(h), math.Sqrt(1-h))
}

// InServiceArea reports whether p is inside the Bangkok bounding box the app
// has flood spot and canal data for (13.49-14.10 N, 100.30-100.95 E).
func InServiceArea(p domain.LatLng) bool {
	return p.Lat >= 13.49 && p.Lat <= 14.10 && p.Lng >= 100.30 && p.Lng <= 100.95
}

// DistanceToPolylineM is the shortest distance from p to any segment of line.
// Segments are projected onto a local plane, which is accurate at city scale.
func DistanceToPolylineM(p domain.LatLng, line []domain.LatLng) float64 {
	switch len(line) {
	case 0:
		return math.Inf(1)
	case 1:
		return HaversineM(p, line[0])
	}
	best := math.Inf(1)
	for i := 0; i+1 < len(line); i++ {
		if d := distanceToSegmentM(p, line[i], line[i+1]); d < best {
			best = d
		}
	}
	return best
}

func distanceToSegmentM(p, a, b domain.LatLng) float64 {
	kx := earthRadiusM * math.Cos(rad(p.Lat)) * math.Pi / 180
	ky := earthRadiusM * math.Pi / 180
	ax, ay := (a.Lng-p.Lng)*kx, (a.Lat-p.Lat)*ky
	bx, by := (b.Lng-p.Lng)*kx, (b.Lat-p.Lat)*ky
	dx, dy := bx-ax, by-ay
	t := 0.0
	if l2 := dx*dx + dy*dy; l2 > 0 {
		t = math.Max(0, math.Min(1, -(ax*dx+ay*dy)/l2))
	}
	cx, cy := ax+t*dx, ay+t*dy
	return math.Hypot(cx, cy)
}

// DecodePolyline decodes a Google encoded polyline (precision 5).
func DecodePolyline(s string) []domain.LatLng {
	var out []domain.LatLng
	lat, lng, i := 0, 0, 0
	next := func() (int, bool) {
		result, shift := 0, 0
		for i < len(s) {
			b := int(s[i]) - 63
			i++
			result |= (b & 0x1f) << shift
			shift += 5
			if b < 0x20 {
				if result&1 != 0 {
					return ^(result >> 1), true
				}
				return result >> 1, true
			}
		}
		return 0, false
	}
	for i < len(s) {
		dLat, ok1 := next()
		dLng, ok2 := next()
		if !ok1 || !ok2 {
			break
		}
		lat += dLat
		lng += dLng
		out = append(out, domain.LatLng{Lat: float64(lat) / 1e5, Lng: float64(lng) / 1e5})
	}
	return out
}

func rad(d float64) float64 { return d * math.Pi / 180 }
