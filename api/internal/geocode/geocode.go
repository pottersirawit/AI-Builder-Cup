// Package geocode turns what a user types into a place (search) and a GPS fix
// into a name (reverse). Google Places / Geocoding answer when a key is set;
// the bundled Bangkok landmark list (data/bkk_landmarks.json) answers otherwise.
package geocode

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"os"
	"sort"
	"strings"
	"unicode/utf8"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
)

// Place is one search result.
type Place struct {
	NameTH    string  `json:"name_th"`
	NameEN    string  `json:"name_en,omitempty"` // local results only
	AddressTH string  `json:"address_th"`
	Lat       float64 `json:"lat"`
	Lng       float64 `json:"lng"`
	Source    string  `json:"source"` // google or local
}

// Address names a point. Lat and Lng echo the queried point, which is what the
// app should save; DistanceM is how far the named landmark is (local only).
type Address struct {
	NameTH        string  `json:"name_th"`
	AddressTH     string  `json:"address_th"`
	Lat           float64 `json:"lat"`
	Lng           float64 `json:"lng"`
	InServiceArea bool    `json:"in_service_area"`
	Source        string  `json:"source"`
	DistanceM     *int    `json:"distance_m,omitempty"`
}

type Geocoder interface {
	Search(ctx context.Context, q string) ([]Place, error)
	Reverse(ctx context.Context, at domain.LatLng) (Address, error)
}

var ErrNotFound = errors.New("no place found")

// maxResults caps a search; the app shows one screen of choices.
const maxResults = 8

// Landmark is one entry of data/bkk_landmarks.json.
type Landmark struct {
	ID        string   `json:"id"`
	NameTH    string   `json:"name_th"`
	NameEN    string   `json:"name_en"`
	AddressTH string   `json:"address_th"`
	Category  string   `json:"category"` // landmark, mall, transit, university, hospital, area, district, demo
	Lat       float64  `json:"latitude"`
	Lng       float64  `json:"longitude"`
	Keywords  []string `json:"keywords"`
}

func (l Landmark) Point() domain.LatLng { return domain.LatLng{Lat: l.Lat, Lng: l.Lng} }

func LoadLandmarks(path string) ([]Landmark, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read landmarks: %w", err)
	}
	var ls []Landmark
	if err := json.Unmarshal(b, &ls); err != nil {
		return nil, fmt.Errorf("parse landmarks %s: %w", path, err)
	}
	return ls, nil
}

// Local searches the bundled landmark list. It never fails.
type Local struct{ Landmarks []Landmark }

// norm folds case and drops spaces and punctuation, so "Central World",
// "centralworld" and "เซ็นทรัล เวิลด์" compare equal.
func norm(s string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(s) {
		switch r {
		case ' ', '\t', '.', '-', '(', ')', '/', ',', '\'', '"':
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}

// score ranks how well a landmark matches the normalised query: exact name or
// keyword, then prefix, then substring, then a known name inside a longer
// query ("ไปเซ็นทรัลลาดพร้าว"), then every word of the query somewhere.
func score(l Landmark, q string, words []string) int {
	best := 0
	for _, name := range append([]string{l.NameTH, l.NameEN}, l.Keywords...) {
		n := norm(name)
		if n == "" {
			continue
		}
		s := 0
		switch {
		case n == q:
			s = 100
		case strings.HasPrefix(n, q):
			s = 80
		case strings.Contains(n, q):
			s = 60
		case utf8.RuneCountInString(n) >= 3 && strings.Contains(q, n):
			s = 20 + min(utf8.RuneCountInString(n), 19)
		}
		best = max(best, s)
	}
	if best > 0 {
		return best
	}
	all := norm(strings.Join(append([]string{l.NameTH, l.NameEN, l.AddressTH}, l.Keywords...), "|"))
	if len(words) > 1 {
		for _, w := range words {
			if !strings.Contains(all, w) {
				return 0
			}
		}
		return 50
	}
	if strings.Contains(norm(l.AddressTH), q) {
		return 30
	}
	return 0
}

func (l Local) Search(_ context.Context, q string) ([]Place, error) {
	nq := norm(q)
	if nq == "" {
		return []Place{}, nil
	}
	var words []string
	for _, w := range strings.Fields(q) {
		if w = norm(w); utf8.RuneCountInString(w) >= 2 {
			words = append(words, w)
		}
	}
	type hit struct {
		l     Landmark
		score int
	}
	var hits []hit
	for _, lm := range l.Landmarks {
		if s := score(lm, nq, words); s > 0 {
			hits = append(hits, hit{lm, s})
		}
	}
	sort.SliceStable(hits, func(i, j int) bool {
		if hits[i].score != hits[j].score {
			return hits[i].score > hits[j].score
		}
		return utf8.RuneCountInString(hits[i].l.NameTH) < utf8.RuneCountInString(hits[j].l.NameTH)
	})
	out := []Place{}
	seen := map[string]bool{}
	for _, h := range hits {
		if seen[h.l.NameTH] {
			continue
		}
		seen[h.l.NameTH] = true
		out = append(out, Place{NameTH: h.l.NameTH, NameEN: h.l.NameEN, AddressTH: h.l.AddressTH, Lat: h.l.Lat, Lng: h.l.Lng, Source: "local"})
		if len(out) == maxResults {
			break
		}
	}
	return out, nil
}

// nearM is how close a point must be to a landmark to carry its bare name;
// farther points are "ใกล้<landmark>".
const nearM = 150

// Reverse names a point after the nearest landmark (districts are too coarse
// to name a doorstep) and gives that landmark's address.
func (l Local) Reverse(_ context.Context, at domain.LatLng) (Address, error) {
	best, bestD := -1, math.Inf(1)
	for i, lm := range l.Landmarks {
		if lm.Category == "district" {
			continue
		}
		if d := geo.HaversineM(at, lm.Point()); d < bestD {
			best, bestD = i, d
		}
	}
	if best < 0 {
		return Address{}, ErrNotFound
	}
	lm, dist := l.Landmarks[best], int(math.Round(bestD))
	name := lm.NameTH
	if dist > nearM {
		name = "ใกล้" + lm.NameTH
	}
	return Address{NameTH: name, AddressTH: lm.AddressTH, Lat: at.Lat, Lng: at.Lng,
		InServiceArea: geo.InServiceArea(at), Source: "local", DistanceM: &dist}, nil
}

// Fallback asks Primary (Google) and answers from Fallback (local) when it
// fails or finds nothing.
type Fallback struct{ Primary, Fallback Geocoder }

func (f Fallback) Search(ctx context.Context, q string) ([]Place, error) {
	out, err := f.Primary.Search(ctx, q)
	if err == nil && len(out) > 0 {
		return out, nil
	}
	if err != nil {
		slog.Warn("place search failed, using local landmarks", "err", err)
	}
	return f.Fallback.Search(ctx, q)
}

func (f Fallback) Reverse(ctx context.Context, at domain.LatLng) (Address, error) {
	out, err := f.Primary.Reverse(ctx, at)
	if err == nil {
		return out, nil
	}
	if !errors.Is(err, ErrNotFound) {
		slog.Warn("reverse geocoding failed, using local landmarks", "err", err)
	}
	return f.Fallback.Reverse(ctx, at)
}
