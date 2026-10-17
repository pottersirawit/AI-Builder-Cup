package httpapi

import (
	"strings"
	"time"
	"unicode"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
)

// areDuplicateTrips reports whether a and b represent the same real-world event
// (e.g. one synced from Calendar and another extracted from a Gmail confirmation).
func areDuplicateTrips(a, b domain.Trip) bool {
	isAEvent := a.Source == "calendar" || a.Source == "gmail"
	isBEvent := b.Source == "calendar" || b.Source == "gmail"
	if !isAEvent || !isBEvent {
		return false
	}

	// Must occur on the same calendar day in Bangkok
	if !sameDay(a.ArriveBy, b.ArriveBy) {
		return false
	}

	// If either is an all-day (date-only) event on the same day, match by destination or title
	if a.AllDay || b.AllDay {
		return destinationsOrTitlesMatch(a, b)
	}

	// If arrival times are present, check closeness (within 90 mins)
	if !a.ArriveBy.IsZero() && !b.ArriveBy.IsZero() {
		diff := a.ArriveBy.Sub(b.ArriveBy)
		if diff < 0 {
			diff = -diff
		}
		if diff > 90*time.Minute {
			return false
		}
	}

	return destinationsOrTitlesMatch(a, b)
}

func destinationsOrTitlesMatch(a, b domain.Trip) bool {
	// 1. Coordinates match within 1000m
	if a.Destination.Resolved() && b.Destination.Resolved() {
		if geo.HaversineM(a.Destination.Point(), b.Destination.Point()) <= 1000 {
			return true
		}
	}

	// 2. Destination names or location texts match
	namesA := []string{a.Destination.NameTH, a.LocationTextTH}
	namesB := []string{b.Destination.NameTH, b.LocationTextTH}
	for _, na := range namesA {
		if na = cleanText(na); na == "" {
			continue
		}
		for _, nb := range namesB {
			if nb = cleanText(nb); nb == "" {
				continue
			}
			if strings.Contains(na, nb) || strings.Contains(nb, na) {
				return true
			}
		}
	}

	// 3. Titles match or have significant keyword overlap
	ta := cleanText(a.TitleTH)
	tb := cleanText(b.TitleTH)
	if ta != "" && tb != "" {
		if strings.Contains(ta, tb) || strings.Contains(tb, ta) {
			return true
		}
		// Token overlap (e.g. flight numbers, artist names, event names)
		tokensA := tokenize(a.TitleTH)
		tokensB := tokenize(b.TitleTH)
		for _, t1 := range tokensA {
			if len(t1) < 3 {
				continue
			}
			for _, t2 := range tokensB {
				if t1 == t2 {
					return true
				}
			}
		}
	}

	return false
}

func cleanText(s string) string {
	var sb strings.Builder
	for _, r := range strings.ToLower(s) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			sb.WriteRune(r)
		}
	}
	return sb.String()
}

func tokenize(s string) []string {
	var words []string
	var current strings.Builder
	for _, r := range strings.ToLower(s) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			current.WriteRune(r)
		} else {
			if current.Len() > 0 {
				words = append(words, current.String())
				current.Reset()
			}
		}
	}
	if current.Len() > 0 {
		words = append(words, current.String())
	}
	return words
}

// DeduplicateTrips merges Calendar and Gmail trips representing the same event.
// Calendar entries take primary precedence; resolved destinations from Gmail
// enrich an unresolved Calendar entry.
func DeduplicateTrips(trips []domain.Trip) []domain.Trip {
	if len(trips) <= 1 {
		return trips
	}
	result := make([]domain.Trip, 0, len(trips))
	dropped := make(map[int]bool)

	for i := 0; i < len(trips); i++ {
		if dropped[i] {
			continue
		}
		current := trips[i]
		for j := i + 1; j < len(trips); j++ {
			if dropped[j] {
				continue
			}
			if areDuplicateTrips(current, trips[j]) {
				// If current is gmail and trips[j] is calendar, prefer calendar
				if current.Source == "gmail" && trips[j].Source == "calendar" {
					cal := trips[j]
					if !cal.Destination.Resolved() && current.Destination.Resolved() {
						cal.Destination = current.Destination
						cal.LocationTextTH = current.LocationTextTH
					}
					current = cal
					dropped[j] = true
				} else {
					// current is calendar (or first), trips[j] is gmail (or duplicate)
					if !current.Destination.Resolved() && trips[j].Destination.Resolved() {
						current.Destination = trips[j].Destination
						current.LocationTextTH = trips[j].LocationTextTH
					}
					dropped[j] = true
				}
			}
		}
		result = append(result, current)
	}
	return result
}
