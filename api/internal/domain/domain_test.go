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

func TestModePickup(t *testing.T) {
	if !ModePickup.Valid() {
		t.Error("ModePickup should be valid")
	}
	if ModePickup.NameTH() != "รถกระบะ" {
		t.Errorf("ModePickup.NameTH() = %s, want รถกระบะ", ModePickup.NameTH())
	}
	if ModePickup.NameFor(LangEN) != "pickup truck" {
		t.Errorf("ModePickup.NameFor(LangEN) = %s, want pickup truck", ModePickup.NameFor(LangEN))
	}
	found := false
	for _, m := range AllModes {
		if m == ModePickup {
			found = true
			break
		}
	}
	if !found {
		t.Error("AllModes should contain ModePickup")
	}
}
