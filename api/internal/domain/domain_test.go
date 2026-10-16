package domain

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestUnresolvedPlaceHasNoCoordinates(t *testing.T) {
	b, _ := json.Marshal(Place{NameTH: "ร้านลับ"})
	if strings.Contains(string(b), "lat") || strings.Contains(string(b), "lng") {
		t.Errorf("unresolved place JSON = %s, want no lat/lng", b)
	}
	if (Place{NameTH: "ร้านลับ"}).Resolved() {
		t.Error("a place at (0,0) must not count as resolved")
	}
	b, _ = json.Marshal(Place{NameTH: "สยาม", Lat: 13.7456, Lng: 100.5341})
	if !strings.Contains(string(b), `"lat":13.7456`) || !(Place{Lat: 13.7, Lng: 100.5}).Resolved() {
		t.Errorf("resolved place JSON = %s", b)
	}
}
