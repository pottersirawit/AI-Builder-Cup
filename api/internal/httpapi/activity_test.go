package httpapi

import (
	"bytes"
	"strings"
	"testing"
)

func TestDecideActivityWithoutAPlaceAsksWhere(t *testing.T) {
	h := newServer(t)
	code, out := do(t, h, "POST", "/v1/decide", "2026-09-29T16:10:00+07:00",
		bytes.NewBufferString(`{"question_th":"ไปปีนผาต้องเตรียมอะไรบ้าง"}`), "application/json")
	if code != 200 {
		t.Fatalf("status %d: %v", code, out)
	}
	if out["refused"] == true || out["verdict"] != nil {
		t.Fatalf("an activity is not refused nor decided as a trip: %v", out)
	}
	a, ok := out["activity"].(map[string]any)
	if !ok {
		t.Fatalf("want an activity answer, got %v", out)
	}
	if a["kind"] != "climbing" || a["ask_th"] == "" || len(a["checklist"].([]any)) < 4 || len(a["suggestions_th"].([]any)) == 0 {
		t.Fatalf("got %v", a)
	}
}

func TestDecideActivityAtAPlaceAddsTheDaysWeather(t *testing.T) {
	h := newServer(t)
	body := `{"question_th":"ไปปีนผาต้องเตรียมอะไรบ้าง",
		"origin":{"name_th":"บ้าน","lat":13.816,"lng":100.59},
		"destination":{"name_th":"หินเหล็กไฟ","lat":13.65,"lng":99.53},
		"depart_at":"2026-10-03T07:00:00+07:00",
		"activity":{"kind":"climbing","name_th":"ปีนผา","day":"2026-10-03"}}`
	code, out := do(t, h, "POST", "/v1/decide", "2026-09-29T16:10:00+07:00", bytes.NewBufferString(body), "application/json")
	if code != 200 {
		t.Fatalf("status %d: %v", code, out)
	}
	if out["verdict"] == nil || out["trip"].(map[string]any)["destination"].(map[string]any)["name_th"] != "หินเหล็กไฟ" {
		t.Fatalf("want the normal trip answer, got %v", out)
	}
	a := out["activity"].(map[string]any)
	if a["day"] != "2026-10-03" || a["place_th"] != "หินเหล็กไฟ" || a["forecast"] == nil || a["ask_th"] != nil {
		t.Fatalf("got %v", a)
	}
	notes := a["weather_notes_th"].([]any)
	if len(notes) == 0 || !strings.Contains(notes[0].(string), "โอกาสฝน") {
		t.Fatalf("notes %v", notes)
	}
}

func TestDecideActivityFollowUpNamesThePlace(t *testing.T) {
	h := newServer(t)
	body := `{"question_th":"หินเหล็กไฟ เสาร์นี้","activity":{"kind":"climbing","name_th":"ปีนผา"}}`
	code, out := do(t, h, "POST", "/v1/decide", "2026-09-29T16:10:00+07:00", bytes.NewBufferString(body), "application/json")
	if code != 200 {
		t.Fatalf("status %d: %v", code, out)
	}
	np, ok := out["needs_place"].(map[string]any)
	if !ok || np["query_th"] != "หินเหล็กไฟ" {
		t.Fatalf("want the place looked up, got %v", out)
	}
}

func TestDecideStillRefusesOffTopic(t *testing.T) {
	h := newServer(t)
	_, out := do(t, h, "POST", "/v1/decide", "2026-09-29T16:10:00+07:00",
		bytes.NewBufferString(`{"question_th":"ขอสูตรอาหารต้มยำหน่อย"}`), "application/json")
	if out["refused"] != true {
		t.Fatalf("got %v", out)
	}
}

func TestDecideKeepsTheActivityOnAFollowUpWithoutTheQuestion(t *testing.T) {
	h := newServer(t)
	body := `{"origin":{"name_th":"บ้าน","lat":13.816,"lng":100.59},
		"destination":{"name_th":"หินเหล็กไฟ","lat":13.65,"lng":99.53},
		"depart_at":"2026-10-03T08:00:00+07:00","mode":"car",
		"activity":{"kind":"climbing","name_th":"ปีนผา","day":"2026-10-03"}}`
	_, out := do(t, h, "POST", "/v1/decide", "2026-09-29T16:10:00+07:00", bytes.NewBufferString(body), "application/json")
	if a, ok := out["activity"].(map[string]any); !ok || a["kind"] != "climbing" || a["forecast"] == nil {
		t.Fatalf("got %v", out["activity"])
	}
}
