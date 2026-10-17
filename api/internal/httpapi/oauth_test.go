package httpapi

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func TestOAuthStartScopes(t *testing.T) {
	s := &Server{
		Google: GoogleOAuth{
			AuthURL:     "https://accounts.google.com/o/oauth2/v2/auth",
			RedirectURI: "https://example.com/callback",
			AppURLs:     []string{"https://ai-cup-511208.web.app"},
		},
	}

	tests := []struct {
		name          string
		serviceParam  string
		wantCalendar  bool
		wantGmail     bool
	}{
		{
			name:         "service=calendar requests only calendar and base scopes",
			serviceParam: "calendar",
			wantCalendar: true,
			wantGmail:    false,
		},
		{
			name:         "service=gmail requests only gmail and base scopes",
			serviceParam: "gmail",
			wantCalendar: false,
			wantGmail:    true,
		},
		{
			name:         "no service param requests all scopes",
			serviceParam: "",
			wantCalendar: true,
			wantGmail:    true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			u := "/v1/oauth/start?return=https://ai-cup-511208.web.app"
			if tc.serviceParam != "" {
				u += "&service=" + tc.serviceParam
			}
			req := httptest.NewRequest("GET", u, nil)
			w := httptest.NewRecorder()

			s.oauthStart(w, req)
			resp := w.Result()
			if resp.StatusCode != http.StatusFound {
				t.Fatalf("expected status 302, got %d", resp.StatusCode)
			}
			loc := resp.Header.Get("Location")
			parsed, err := url.Parse(loc)
			if err != nil {
				t.Fatalf("failed to parse redirect location %q: %v", loc, err)
			}
			scope := parsed.Query().Get("scope")
			if !strings.Contains(scope, "openid") || !strings.Contains(scope, "email") {
				t.Errorf("scope %q missing openid or email", scope)
			}
			hasCal := strings.Contains(scope, "calendar.readonly")
			hasGmail := strings.Contains(scope, "gmail.readonly")
			if hasCal != tc.wantCalendar {
				t.Errorf("calendar.readonly in scope = %v, want %v (scope: %s)", hasCal, tc.wantCalendar, scope)
			}
			if hasGmail != tc.wantGmail {
				t.Errorf("gmail.readonly in scope = %v, want %v (scope: %s)", hasGmail, tc.wantGmail, scope)
			}
		})
	}
}
