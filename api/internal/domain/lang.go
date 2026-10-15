package domain

import (
	"net/http"
	"strings"
)

// Lang is the language the API writes user-facing text in. Thai is the
// default; the app asks for English with an Accept-Language header.
type Lang string

const (
	LangTH Lang = "th"
	LangEN Lang = "en"
)

// LangFromRequest reads the first language of Accept-Language. Anything that
// is not English is Thai.
func LangFromRequest(r *http.Request) Lang {
	first, _, _ := strings.Cut(r.Header.Get("Accept-Language"), ",")
	if strings.HasPrefix(strings.ToLower(strings.TrimSpace(first)), "en") {
		return LangEN
	}
	return LangTH
}

// Pick returns the Thai or English text for l.
func (l Lang) Pick(th, en string) string {
	if l == LangEN {
		return en
	}
	return th
}
