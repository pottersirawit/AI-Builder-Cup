package domain

import (
	"net/http/httptest"
	"testing"
)

func TestLangFromRequest(t *testing.T) {
	for header, want := range map[string]Lang{
		"":               LangTH,
		"th":             LangTH,
		"th-TH,en;q=0.8": LangTH,
		"en":             LangEN,
		"en-US,en;q=0.9": LangEN,
		" EN-gb":         LangEN,
		"fr":             LangTH,
	} {
		r := httptest.NewRequest("GET", "/", nil)
		if header != "" {
			r.Header.Set("Accept-Language", header)
		}
		if got := LangFromRequest(r); got != want {
			t.Errorf("Accept-Language %q: got %q, want %q", header, got, want)
		}
	}
}

func TestLangPick(t *testing.T) {
	if LangTH.Pick("ไทย", "English") != "ไทย" || LangEN.Pick("ไทย", "English") != "English" {
		t.Fatal("Pick must choose by language")
	}
}
