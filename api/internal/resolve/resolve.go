// Package resolve transforms an extracted Event Payload into a fully geocoded domain.Trip,
// resolving destination references against saved places and geocoders.
package resolve

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/extract"
	"github.com/pottersirawit/fontokmai/api/internal/geocode"
)

var (
	ErrNotATrip      = errors.New("payload is not a trip")
	ErrMissingOrigin = errors.New("origin location required to plan trip")
)

// NeedsPlace signals that the destination could not be matched or geocoded automatically.
type NeedsPlace struct {
	QueryTH    string          `json:"query_th"`
	Kind       string          `json:"kind,omitempty"`
	Candidates []geocode.Place `json:"candidates"`
}

func (n *NeedsPlace) Error() string {
	return fmt.Sprintf("needs place: %s", n.QueryTH)
}

// defaultBangkokCenter is fallback origin (Siam area) if no user origin is known.
var defaultBangkokOrigin = domain.Place{
	NameTH: "ตำแหน่งปัจจุบัน",
	Lat:    13.7456,
	Lng:    100.5341,
}

// Trip is TripFor in Thai.
func Trip(
	ctx context.Context,
	p extract.Payload,
	currentOrigin *domain.Place,
	savedPlaces []domain.SavedPlace,
	geo geocode.Geocoder,
) (domain.Trip, *NeedsPlace, error) {
	return TripFor(ctx, domain.LangTH, p, currentOrigin, savedPlaces, geo)
}

// TripFor resolves an extracted payload into a runnable domain.Trip, writing
// the titles and prompts it makes up in lang.
func TripFor(
	ctx context.Context,
	lang domain.Lang,
	p extract.Payload,
	currentOrigin *domain.Place,
	savedPlaces []domain.SavedPlace,
	geo geocode.Geocoder,
) (domain.Trip, *NeedsPlace, error) {
	if !p.IsTrip {
		return domain.Trip{}, nil, ErrNotATrip
	}

	destText := strings.TrimSpace(p.DestinationText)
	if destText == "" {
		destText = strings.TrimSpace(p.TitleTH)
	}
	if destText == "" {
		return domain.Trip{}, &NeedsPlace{QueryTH: lang.Pick("ระบุสถานที่", "Choose a place")}, nil
	}

	// 1. Try matching against user's saved places
	var destPlace *domain.Place
	for _, sp := range savedPlaces {
		nameClean := strings.TrimSpace(strings.Split(sp.NameTH, "(")[0])
		labelClean := strings.TrimSpace(sp.LabelTH)

		if strings.EqualFold(destText, labelClean) || strings.EqualFold(destText, sp.NameTH) || strings.EqualFold(destText, nameClean) {
			destPlace = &sp.Place
			break
		}
		for _, kw := range sp.Keywords {
			if strings.EqualFold(destText, kw) {
				destPlace = &sp.Place
				break
			}
		}
		if destPlace != nil {
			break
		}
	}

	// 2. If not matched in saved places, search via geocoder
	if destPlace == nil && geo != nil {
		candidates, err := geo.Search(ctx, destText)
		if err == nil && len(candidates) > 0 {
			top := candidates[0]
			destPlace = &domain.Place{
				NameTH: top.NameTH,
				Lat:    top.Lat,
				Lng:    top.Lng,
			}
		} else {
			return domain.Trip{}, &NeedsPlace{
				QueryTH:    destText,
				Candidates: candidates,
			}, nil
		}
	}

	if destPlace == nil {
		return domain.Trip{}, &NeedsPlace{QueryTH: destText}, nil
	}

	// 3. Determine Origin
	origin := defaultBangkokOrigin
	origin.NameTH = lang.Pick(origin.NameTH, "Current location")
	if currentOrigin != nil {
		origin = *currentOrigin
	} else {
		// Look for work or home as default commute start
		for _, sp := range savedPlaces {
			if sp.Kind == domain.KindWork {
				origin = sp.Place
				break
			}
		}
	}

	mode := domain.ModeCar
	if p.Mode != nil && p.Mode.Valid() {
		mode = *p.Mode
	}

	tripID := generateTripID(p.Source, p.SourceRef, origin, *destPlace)
	title := p.TitleTH
	if title == "" {
		title = lang.Pick("ไป", "Go to ") + destPlace.NameTH
	}

	trip := domain.Trip{
		ID:          tripID,
		TitleTH:     title,
		Source:      p.Source,
		Origin:      origin,
		Destination: *destPlace,
		Mode:        mode,
	}

	if p.ArriveBy != nil {
		trip.ArriveBy = *p.ArriveBy
	}

	return trip, nil, nil
}

func generateTripID(source, ref string, origin, dest domain.Place) string {
	if ref != "" {
		return fmt.Sprintf("%s-%s", source, ref)
	}
	hashInput := fmt.Sprintf("%s:%.4f,%.4f->%.4f,%.4f", source, origin.Lat, origin.Lng, dest.Lat, dest.Lng)
	sum := sha1.Sum([]byte(hashInput))
	return fmt.Sprintf("%s-%s", source, hex.EncodeToString(sum[:])[:8])
}
