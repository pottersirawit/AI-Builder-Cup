package geocode

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"slices"
	"strings"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geo"
)

var defaultHTTP = &http.Client{Timeout: 6 * time.Second}

// bangkokCenter and biasRadiusM bias search results toward Bangkok (the Places
// API caps a circle bias at 50 km).
var bangkokCenter = domain.LatLng{Lat: 13.7563, Lng: 100.5018}

const biasRadiusM = 50000

// Google uses Places API Text Search (New) and the Geocoding API, in Thai.
type Google struct {
	APIKey     string
	PlacesURL  string // default https://places.googleapis.com
	GeocodeURL string // default https://maps.googleapis.com
	HTTP       *http.Client
}

func (g Google) do(ctx context.Context, req *http.Request, out any) error {
	client := g.HTTP
	if client == nil {
		client = defaultHTTP
	}
	resp, err := client.Do(req.WithContext(ctx))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s: %s: %.200s", req.URL.Host, resp.Status, body)
	}
	return json.Unmarshal(body, out)
}

func (g Google) Search(ctx context.Context, q string) ([]Place, error) {
	if g.APIKey == "" {
		return nil, errors.New("GOOGLE_MAPS_API_KEY not set")
	}
	base := g.PlacesURL
	if base == "" {
		base = "https://places.googleapis.com"
	}
	b, _ := json.Marshal(map[string]any{
		"textQuery": q, "languageCode": langOf(ctx).Pick("th", "en"), "regionCode": "TH", "pageSize": maxResults,
		"locationBias": map[string]any{"circle": map[string]any{
			"center": map[string]float64{"latitude": bangkokCenter.Lat, "longitude": bangkokCenter.Lng}, "radius": biasRadiusM}},
	})
	req, _ := http.NewRequest(http.MethodPost, base+"/v1/places:searchText", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Goog-Api-Key", g.APIKey)
	req.Header.Set("X-Goog-FieldMask", "places.displayName,places.formattedAddress,places.location")
	var body struct {
		Places []struct {
			DisplayName struct {
				Text string `json:"text"`
			} `json:"displayName"`
			FormattedAddress string `json:"formattedAddress"`
			Location         struct {
				Latitude  float64 `json:"latitude"`
				Longitude float64 `json:"longitude"`
			} `json:"location"`
		} `json:"places"`
	}
	if err := g.do(ctx, req, &body); err != nil {
		return nil, err
	}
	out := []Place{}
	for _, p := range body.Places {
		out = append(out, Place{NameTH: p.DisplayName.Text, AddressTH: p.FormattedAddress,
			Lat: p.Location.Latitude, Lng: p.Location.Longitude, Source: "google"})
	}
	return out, nil
}

// nameTypes are the address component types that make a good short name, best first.
var nameTypes = []string{"point_of_interest", "establishment", "premise", "route", "sublocality_level_2", "sublocality_level_1", "locality"}

func (g Google) Reverse(ctx context.Context, at domain.LatLng) (Address, error) {
	if g.APIKey == "" {
		return Address{}, errors.New("GOOGLE_MAPS_API_KEY not set")
	}
	base := g.GeocodeURL
	if base == "" {
		base = "https://maps.googleapis.com"
	}
	q := url.Values{
		"latlng":   {fmt.Sprintf("%.5f,%.5f", at.Lat, at.Lng)},
		"language": {langOf(ctx).Pick("th", "en")},
		"region":   {"th"},
		"key":      {g.APIKey},
	}
	req, _ := http.NewRequest(http.MethodGet, base+"/maps/api/geocode/json?"+q.Encode(), nil)
	var body struct {
		Status  string `json:"status"`
		Results []struct {
			FormattedAddress  string `json:"formatted_address"`
			AddressComponents []struct {
				LongName string   `json:"long_name"`
				Types    []string `json:"types"`
			} `json:"address_components"`
		} `json:"results"`
	}
	if err := g.do(ctx, req, &body); err != nil {
		return Address{}, err
	}
	switch {
	case body.Status == "ZERO_RESULTS" || (body.Status == "OK" && len(body.Results) == 0):
		return Address{}, ErrNotFound
	case body.Status != "OK":
		return Address{}, fmt.Errorf("geocoding status %s", body.Status)
	}
	r := body.Results[0]
	name := ""
	for _, typ := range nameTypes {
		for _, c := range r.AddressComponents {
			if name == "" && slices.Contains(c.Types, typ) {
				name = c.LongName
			}
		}
	}
	if name == "" {
		name, _, _ = strings.Cut(r.FormattedAddress, " ")
	}
	return Address{NameTH: name, AddressTH: r.FormattedAddress, Lat: at.Lat, Lng: at.Lng,
		InServiceArea: geo.InServiceArea(at), Source: "google"}, nil
}
