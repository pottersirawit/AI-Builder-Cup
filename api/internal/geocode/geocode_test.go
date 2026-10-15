package geocode

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

func landmarks(t *testing.T) []Landmark {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	ls, err := LoadLandmarks(filepath.Join(filepath.Dir(file), "..", "..", "..", "data", "bkk_landmarks.json"))
	if err != nil {
		t.Fatal(err)
	}
	return ls
}

func TestLoadLandmarks(t *testing.T) {
	ls := landmarks(t)
	if len(ls) < 150 {
		t.Fatalf("only %d landmarks", len(ls))
	}
	ids := map[string]bool{}
	for _, l := range ls {
		if l.ID == "" || l.NameTH == "" || l.NameEN == "" || l.AddressTH == "" || l.Lat == 0 || l.Lng == 0 {
			t.Errorf("incomplete landmark %+v", l)
		}
		if ids[l.ID] {
			t.Errorf("duplicate id %s", l.ID)
		}
		ids[l.ID] = true
	}
	if _, err := LoadLandmarks("nope.json"); err == nil {
		t.Fatal("missing file should fail")
	}
}

func TestLocalSearch(t *testing.T) {
	local := Local{Landmarks: landmarks(t)}
	tests := []struct {
		q, wantFirst string
	}{
		{"เซ็นทรัลเวิลด์", "เซ็นทรัลเวิลด์"},
		{"central world", "เซ็นทรัลเวิลด์"},
		{"CentralWorld", "เซ็นทรัลเวิลด์"},
		{"พารากอน", "สยามพารากอน"},
		{"อโศก", "อโศก"},
		{"bts อโศก", "สถานี BTS อโศก"},
		{"bts chit lom", "สถานี BTS ชิดลม"},
		{"ชิดลม", "สถานี BTS ชิดลม"},
		{"MRT ลาดพร้าว", "สถานี MRT ลาดพร้าว"},
		{"เขตบางกะปิ", "เขตบางกะปิ"},
		{"อิมแพ็ค", "อิมแพ็ค เมืองทองธานี"},
		{"ไปเซ็นทรัลลาดพร้าว", "เซ็นทรัลลาดพร้าว"},
	}
	for _, tt := range tests {
		got, err := local.Search(context.Background(), tt.q)
		if err != nil {
			t.Fatal(err)
		}
		if len(got) == 0 || got[0].NameTH != tt.wantFirst {
			t.Errorf("Search(%q) first = %v, want %q", tt.q, names(got), tt.wantFirst)
			continue
		}
		if got[0].Source != "local" || got[0].AddressTH == "" || got[0].NameEN == "" || got[0].Lat == 0 {
			t.Errorf("Search(%q) = %+v", tt.q, got[0])
		}
		if len(got) > maxResults {
			t.Errorf("Search(%q) returned %d results", tt.q, len(got))
		}
	}
	if got, _ := local.Search(context.Background(), "zzqqxx"); len(got) != 0 {
		t.Fatalf("nonsense query matched %v", names(got))
	}
}

func names(ps []Place) []string {
	var out []string
	for _, p := range ps {
		out = append(out, p.NameTH)
	}
	return out
}

func TestLocalReverse(t *testing.T) {
	local := Local{Landmarks: landmarks(t)}
	tests := []struct {
		name        string
		at          domain.LatLng
		wantName    string
		wantAddress string
		inArea      bool
		maxDistM    int
	}{
		{"on BTS Chit Lom", domain.LatLng{Lat: 13.7441, Lng: 100.5431}, "สถานี BTS ชิดลม", "เขตปทุมวัน", true, 10},
		{"near Central Ladprao", domain.LatLng{Lat: 13.8180, Lng: 100.5640}, "ใกล้เซ็นทรัลลาดพร้าว", "เขตจตุจักร", true, 400},
		{"Chiang Mai", domain.LatLng{Lat: 18.79, Lng: 98.98}, "ใกล้", "", false, 1e9},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := local.Reverse(context.Background(), tt.at)
			if err != nil {
				t.Fatal(err)
			}
			if !strings.HasPrefix(got.NameTH, tt.wantName) || !strings.Contains(got.AddressTH, tt.wantAddress) || got.InServiceArea != tt.inArea || got.Source != "local" {
				t.Fatalf("got %+v", got)
			}
			if got.DistanceM == nil || *got.DistanceM > tt.maxDistM {
				t.Fatalf("distance %v, want <= %d", got.DistanceM, tt.maxDistM)
			}
			if got.Lat != tt.at.Lat || got.Lng != tt.at.Lng {
				t.Fatalf("reverse should echo the queried point, got %v,%v", got.Lat, got.Lng)
			}
		})
	}
}

func TestGoogleSearchParsesTextSearch(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body map[string]any
		json.NewDecoder(r.Body).Decode(&body)
		if r.URL.Path != "/v1/places:searchText" || r.Header.Get("X-Goog-Api-Key") != "k" || body["textQuery"] != "ร้านกาแฟ" ||
			body["languageCode"] != "th" || body["regionCode"] != "TH" || body["locationBias"] == nil ||
			!strings.Contains(r.Header.Get("X-Goog-FieldMask"), "places.location") {
			http.Error(w, "bad request", 400)
			return
		}
		json.NewEncoder(w).Encode(map[string]any{"places": []any{
			map[string]any{"displayName": map[string]any{"text": "ร้านกาแฟ อารีย์"}, "formattedAddress": "ซอยอารีย์ 1 พญาไท กรุงเทพมหานคร",
				"location": map[string]any{"latitude": 13.7799, "longitude": 100.5446}},
		}})
	}))
	defer srv.Close()
	got, err := Google{APIKey: "k", PlacesURL: srv.URL}.Search(context.Background(), "ร้านกาแฟ")
	if err != nil {
		t.Fatal(err)
	}
	want := Place{NameTH: "ร้านกาแฟ อารีย์", AddressTH: "ซอยอารีย์ 1 พญาไท กรุงเทพมหานคร", Lat: 13.7799, Lng: 100.5446, Source: "google"}
	if len(got) != 1 || got[0] != want {
		t.Fatalf("got %+v", got)
	}
}

func TestGoogleReverseParsesGeocoding(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		if r.URL.Path != "/maps/api/geocode/json" || q.Get("key") != "k" || q.Get("latlng") != "13.74410,100.54310" || q.Get("language") != "th" {
			http.Error(w, "bad request", 400)
			return
		}
		json.NewEncoder(w).Encode(map[string]any{"status": "OK", "results": []any{
			map[string]any{"formatted_address": "1027 ถนน เพลินจิต แขวงลุมพินี เขตปทุมวัน กรุงเทพมหานคร 10330", "address_components": []any{
				map[string]any{"long_name": "1027", "types": []string{"street_number"}},
				map[string]any{"long_name": "ถนน เพลินจิต", "types": []string{"route"}},
				map[string]any{"long_name": "แขวงลุมพินี", "types": []string{"sublocality_level_2", "sublocality", "political"}},
			}},
		}})
	}))
	defer srv.Close()
	got, err := Google{APIKey: "k", GeocodeURL: srv.URL}.Reverse(context.Background(), domain.LatLng{Lat: 13.7441, Lng: 100.5431})
	if err != nil {
		t.Fatal(err)
	}
	if got.NameTH != "ถนน เพลินจิต" || !strings.HasPrefix(got.AddressTH, "1027 ถนน เพลินจิต") || !got.InServiceArea || got.Source != "google" || got.DistanceM != nil {
		t.Fatalf("got %+v", got)
	}
}

type broken struct{}

func (broken) Search(context.Context, string) ([]Place, error) { return nil, errors.New("down") }
func (broken) Reverse(context.Context, domain.LatLng) (Address, error) {
	return Address{}, errors.New("down")
}

type empty struct{}

func (empty) Search(context.Context, string) ([]Place, error) { return nil, nil }
func (empty) Reverse(context.Context, domain.LatLng) (Address, error) {
	return Address{}, ErrNotFound
}

func TestFallbackUsesLocalWhenGoogleFailsOrFindsNothing(t *testing.T) {
	local := Local{Landmarks: landmarks(t)}
	for _, primary := range []Geocoder{broken{}, empty{}} {
		f := Fallback{Primary: primary, Fallback: local}
		got, err := f.Search(context.Background(), "สยามพารากอน")
		if err != nil || len(got) == 0 || got[0].Source != "local" {
			t.Fatalf("%T search: %v %v", primary, got, err)
		}
		addr, err := f.Reverse(context.Background(), domain.LatLng{Lat: 13.7441, Lng: 100.5431})
		if err != nil || addr.Source != "local" {
			t.Fatalf("%T reverse: %v %v", primary, addr, err)
		}
	}
}

func TestLocalEnglish(t *testing.T) {
	l := Local{Landmarks: landmarks(t)}
	ctx := WithLang(context.Background(), domain.LangEN)
	found, _ := l.Search(ctx, "พารากอน")
	if len(found) == 0 || found[0].NameTH != "Siam Paragon" {
		t.Fatalf("search = %+v", found)
	}
	th, _ := l.Search(context.Background(), "พารากอน")
	if th[0].NameTH != "สยามพารากอน" {
		t.Fatalf("Thai search changed: %+v", th[0])
	}
	// far from any landmark the name says "Near ..."
	far, err := l.Reverse(ctx, domain.LatLng{Lat: 13.7441, Lng: 100.5500})
	if err != nil || domain.HasThai(far.NameTH) || !strings.HasPrefix(far.NameTH, "Near ") {
		t.Fatalf("reverse = %+v %v", far, err)
	}
}
