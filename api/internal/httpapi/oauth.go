package httpapi

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
)

const (
	googleAuthURL      = "https://accounts.google.com/o/oauth2/v2/auth"
	googleUserinfoURL  = "https://openidconnect.googleapis.com/v1/userinfo"
	defaultRedirectURI = "https://fontokmai-api-lmr33aj5zq-as.a.run.app/oauth2callback"
	scopeBase          = "openid email"
	scopeCalendar      = "https://www.googleapis.com/auth/calendar.readonly"
	scopeGmail         = "https://www.googleapis.com/auth/gmail.readonly"
	// oauthScopes requests both Calendar and Gmail when no specific service is selected.
	oauthScopes = scopeBase + " " + scopeCalendar + " " + scopeGmail
	// firebaseProject owns the Hosting sites (and their preview channels) an
	// OAuth flow may return to.
	firebaseProject = "ai-cup-511208"
	// stateTTL bounds how long a consent screen may stay open.
	stateTTL = 15 * time.Minute
	// callbackTimeout covers the code exchange, the email lookup and the first sync.
	callbackTimeout = 25 * time.Second
	// refreshMargin is how close to expiry an access token is refreshed.
	refreshMargin = 2 * time.Minute
)

// GoogleOAuth is where the Google sign-in flow and the Workspace APIs live.
// Empty fields take Google's endpoints, OAUTH_REDIRECT_URI and APP_URL (a
// comma-separated list of app origins the flow may return to).
type GoogleOAuth struct {
	AuthURL     string
	TokenURL    string
	UserinfoURL string
	CalendarURL string
	GmailURL    string
	RedirectURI string
	AppURLs     []string
	Client      *http.Client
}

func (s *Server) google() GoogleOAuth {
	g := s.Google
	or := func(v *string, def string) {
		if *v == "" {
			*v = def
		}
	}
	or(&g.AuthURL, googleAuthURL)
	or(&g.TokenURL, googleTokenURL)
	or(&g.UserinfoURL, googleUserinfoURL)
	or(&g.CalendarURL, googleCalendarEventsURL)
	or(&g.GmailURL, gmailMessagesURL)
	or(&g.RedirectURI, strings.TrimSpace(os.Getenv("OAUTH_REDIRECT_URI")))
	or(&g.RedirectURI, defaultRedirectURI)
	if g.AppURLs == nil {
		for _, u := range strings.Split(os.Getenv("APP_URL"), ",") {
			if u = strings.TrimSpace(u); u != "" {
				g.AppURLs = append(g.AppURLs, u)
			}
		}
	}
	if g.Client == nil {
		g.Client = http.DefaultClient
	}
	return g
}

// allowedReturn reports whether the app at raw may receive the signed-in
// account: an APP_URL origin, localhost, or a Hosting site of firebaseProject.
func (g GoogleOAuth) allowedReturn(raw string) bool {
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" || u.User != nil {
		return false
	}
	for _, app := range g.AppURLs {
		if a, err := url.Parse(app); err == nil && a.Scheme == u.Scheme && a.Host == u.Host {
			return true
		}
	}
	host := u.Hostname()
	switch u.Scheme {
	case "http":
		return host == "localhost" || host == "127.0.0.1"
	case "https":
		if host == "localhost" {
			return true
		}
		for _, suffix := range []string{".web.app", ".firebaseapp.com"} {
			site, ok := strings.CutSuffix(host, suffix)
			if ok && (site == firebaseProject || strings.HasPrefix(site, firebaseProject+"--")) && !strings.Contains(site, ".") {
				return true
			}
		}
	}
	return false
}

type oauthState struct {
	Return  string `json:"r"`
	Issued  int64  `json:"t"`
	Nonce   string `json:"n,omitempty"`
	Service string `json:"s,omitempty"`
}

// validNonce is the shape of the app's random sign-in id.
var validNonce = regexp.MustCompile(`^[A-Za-z0-9_-]{8,64}$`)

// signIns maps a finished sign-in's nonce to its account, so an app that
// opened Google elsewhere (another tab, the system browser) can poll for it.
var (
	signInsMu sync.Mutex
	signIns   = map[string]signIn{}
)

type signIn struct {
	email string
	at    time.Time
}

func recordSignIn(nonce, email string, now time.Time) {
	signInsMu.Lock()
	defer signInsMu.Unlock()
	for n, si := range signIns {
		if now.Sub(si.at) > stateTTL {
			delete(signIns, n)
		}
	}
	signIns[nonce] = signIn{email: email, at: now}
}

func signedInAs(nonce string, now time.Time) string {
	signInsMu.Lock()
	defer signInsMu.Unlock()
	if si, ok := signIns[nonce]; ok && now.Sub(si.at) <= stateTTL {
		return si.email
	}
	return ""
}

func stateKey() []byte {
	if k := os.Getenv("OAUTH_STATE_SECRET"); k != "" {
		return []byte(k)
	}
	_, secret := getOAuthCredentials()
	if secret != "" {
		return []byte(secret)
	}
	return []byte("fontokmai-oauth-state-secret")
}

func signState(st oauthState) string {
	b, _ := json.Marshal(st)
	payload := base64.RawURLEncoding.EncodeToString(b)
	mac := hmac.New(sha256.New, stateKey())
	mac.Write([]byte(payload))
	return payload + "." + base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

// parseState returns what a state this server signed carries.
func parseState(state string, now time.Time) (oauthState, error) {
	payload, sig, ok := strings.Cut(state, ".")
	if !ok {
		return oauthState{}, errors.New("sign-in was not started from the app")
	}
	got, err := base64.RawURLEncoding.DecodeString(sig)
	mac := hmac.New(sha256.New, stateKey())
	mac.Write([]byte(payload))
	if err != nil || !hmac.Equal(got, mac.Sum(nil)) {
		return oauthState{}, errors.New("sign-in state is not valid")
	}
	b, err := base64.RawURLEncoding.DecodeString(payload)
	var st oauthState
	if err != nil || json.Unmarshal(b, &st) != nil {
		return oauthState{}, errors.New("sign-in state is not valid")
	}
	if now.Sub(time.Unix(st.Issued, 0)) > stateTTL {
		return oauthState{}, errors.New("sign-in took too long")
	}
	return st, nil
}

// oauthStart sends the browser to Google's consent screen for every scope the
// app uses, asking for a refresh token. An optional nonce lets the app find
// the account through /v1/oauth/status once the user is done.
func (s *Server) oauthStart(w http.ResponseWriter, r *http.Request) {
	g := s.google()
	ret := r.URL.Query().Get("return")
	if !g.allowedReturn(ret) {
		writeError(w, http.StatusBadRequest, "return must be the app's URL")
		return
	}
	nonce := r.URL.Query().Get("nonce")
	if nonce != "" && !validNonce.MatchString(nonce) {
		writeError(w, http.StatusBadRequest, "nonce must be 8-64 letters, digits, - or _")
		return
	}
	clientID, _ := getOAuthCredentials()
	service := r.URL.Query().Get("service")
	scope := oauthScopes
	if service == "calendar" {
		scope = scopeBase + " " + scopeCalendar
	} else if service == "gmail" {
		scope = scopeBase + " " + scopeGmail
	}
	q := url.Values{
		"client_id":              {clientID},
		"redirect_uri":           {g.RedirectURI},
		"response_type":          {"code"},
		"scope":                  {scope},
		"access_type":            {"offline"},
		"prompt":                 {"consent"},
		"include_granted_scopes": {"true"},
		"state":                  {signState(oauthState{Return: ret, Issued: time.Now().Unix(), Nonce: nonce, Service: service})},
	}
	if hint := r.URL.Query().Get("login_hint"); hint != "" {
		q.Set("login_hint", hint)
	}
	http.Redirect(w, r, g.AuthURL+"?"+q.Encode(), http.StatusFound)
}

// oauth2Callback finishes sign-in inside the request: it exchanges the code,
// keys the token by the account's verified email, syncs once, and returns
// the browser to the app with ?connected=<email>.
func (s *Server) oauth2Callback(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	st, stateErr := parseState(q.Get("state"), time.Now())
	ret := st.Return
	if e := q.Get("error"); e != "" {
		oauthError(w, http.StatusOK, "Authorization Cancelled", e, ret)
		return
	}
	if stateErr != nil {
		oauthError(w, http.StatusBadRequest, "Sign-in Failed", stateErr.Error(), "")
		return
	}
	if q.Get("code") == "" {
		oauthError(w, http.StatusBadRequest, "Sign-in Failed", "Google sent no authorization code", ret)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), callbackTimeout)
	defer cancel()
	g := s.google()
	tokenResp, err := g.exchange(ctx, url.Values{
		"grant_type":   {"authorization_code"},
		"code":         {q.Get("code")},
		"redirect_uri": {g.RedirectURI},
	})
	if err != nil {
		slog.Warn("google oauth exchange failed", "err", err)
		oauthError(w, http.StatusBadGateway, "Sign-in Failed", err.Error(), ret)
		return
	}
	email, err := g.verifiedEmail(ctx, tokenResp)
	if err != nil {
		slog.Warn("google oauth email lookup failed", "err", err)
		oauthError(w, http.StatusBadGateway, "Sign-in Failed", err.Error(), ret)
		return
	}

	now := time.Now()
	tokenStoreMu.Lock()
	tok := &userToken{
		AccessToken:  tokenResp.AccessToken,
		RefreshToken: tokenResp.RefreshToken,
		Expiry:       now.Add(time.Duration(tokenResp.ExpiresIn) * time.Second),
		Scopes:       strings.Fields(tokenResp.Scope),
	}
	if old := tokenStore[email]; old != nil && tok.RefreshToken == "" {
		tok.RefreshToken = old.RefreshToken
	}
	tokenStore[email] = tok
	tokenStoreMu.Unlock()

	s.syncAndRecord(ctx, email, tok.AccessToken, domain.Place{}, now)
	if st.Nonce != "" {
		recordSignIn(st.Nonce, email, now)
	}

	back, _ := url.Parse(ret)
	bq := back.Query()
	bq.Set("connected", email)
	if st.Service != "" {
		bq.Set("service", st.Service)
	}
	back.RawQuery = bq.Encode()
	http.Redirect(w, r, back.String(), http.StatusFound)
}

// syncAndRecord pulls the account's Calendar and Gmail, planned from home, and
// notes the outcome for /v1/oauth/status.
func (s *Server) syncAndRecord(ctx context.Context, email, accessToken string, home domain.Place, now time.Time) {
	err := s.SyncUserWorkspaceData(ctx, email, accessToken, home, now)
	tokenStoreMu.Lock()
	defer tokenStoreMu.Unlock()
	if tok := tokenStore[email]; tok != nil {
		tok.LastSync, tok.LastError = time.Now(), ""
		if err != nil {
			tok.LastError = err.Error()
		}
	}
}

// oauthStatus tells the app whether an account is connected and what it
// granted. ?nonce= asks for the account a sign-in started with that nonce.
func (s *Server) oauthStatus(w http.ResponseWriter, r *http.Request) {
	email := requestEmail(r)
	if nonce := r.URL.Query().Get("nonce"); email == "" && nonce != "" {
		email = signedInAs(nonce, time.Now())
	}
	tokenStoreMu.RLock()
	tok := tokenStore[email]
	var out struct {
		Email     string     `json:"email"`
		Connected bool       `json:"connected"`
		Scopes    []string   `json:"scopes"`
		LastSync  *time.Time `json:"last_sync"`
		LastError string     `json:"last_error,omitempty"`
	}
	out.Email, out.Scopes = email, []string{}
	if tok != nil {
		out.Connected, out.LastError = true, tok.LastError
		if tok.Scopes != nil {
			out.Scopes = tok.Scopes
		}
		if !tok.LastSync.IsZero() {
			last := tok.LastSync
			out.LastSync = &last
		}
	}
	tokenStoreMu.RUnlock()
	writeJSON(w, http.StatusOK, out)
}

// accessToken is a usable access token for email, refreshed when it expires
// within refreshMargin. ok is false when there is none or the refresh fails.
func (s *Server) accessToken(ctx context.Context, email string) (string, bool) {
	tokenStoreMu.RLock()
	tok, has := tokenStore[email]
	var cur userToken
	if has && tok != nil {
		cur = *tok
	}
	tokenStoreMu.RUnlock()
	if cur.AccessToken == "" {
		return "", false
	}
	if cur.Expiry.IsZero() || time.Until(cur.Expiry) > refreshMargin {
		return cur.AccessToken, true
	}
	if cur.RefreshToken == "" {
		return "", false
	}
	resp, err := s.google().exchange(ctx, url.Values{
		"grant_type":    {"refresh_token"},
		"refresh_token": {cur.RefreshToken},
	})
	if err != nil {
		slog.Warn("google token refresh failed", "email", email, "err", err)
		return "", false
	}
	tokenStoreMu.Lock()
	defer tokenStoreMu.Unlock()
	if tok := tokenStore[email]; tok != nil {
		tok.AccessToken = resp.AccessToken
		tok.Expiry = time.Now().Add(time.Duration(resp.ExpiresIn) * time.Second)
		if resp.RefreshToken != "" {
			tok.RefreshToken = resp.RefreshToken
		}
		if resp.Scope != "" {
			tok.Scopes = strings.Fields(resp.Scope)
		}
	}
	return resp.AccessToken, true
}

// exchange posts a grant to Google's token endpoint with the app's client
// credentials.
func (g GoogleOAuth) exchange(ctx context.Context, form url.Values) (*GoogleTokenResponse, error) {
	clientID, clientSecret := getOAuthCredentials()
	form.Set("client_id", clientID)
	form.Set("client_secret", clientSecret)

	req, err := http.NewRequestWithContext(ctx, "POST", g.TokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := g.Client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("token request failed: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("token error %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	var tokenResp GoogleTokenResponse
	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return nil, fmt.Errorf("unmarshal token response failed: %w", err)
	}
	if tokenResp.AccessToken == "" {
		return nil, errors.New("token response has no access token")
	}
	return &tokenResp, nil
}

type googleIdentity struct {
	Email         string `json:"email"`
	EmailVerified any    `json:"email_verified"`
}

// verified accepts email_verified as Google sends it: a bool from userinfo,
// sometimes a string in an id_token.
func (id googleIdentity) verified() bool {
	switch v := id.EmailVerified.(type) {
	case bool:
		return v
	case string:
		return v == "true"
	}
	return false
}

// verifiedEmail is the signed-in account's verified address: from the
// id_token Google just issued over TLS, else from the userinfo endpoint.
func (g GoogleOAuth) verifiedEmail(ctx context.Context, tok *GoogleTokenResponse) (string, error) {
	if parts := strings.Split(tok.IDToken, "."); len(parts) == 3 {
		var id googleIdentity
		if b, err := base64.RawURLEncoding.DecodeString(parts[1]); err == nil && json.Unmarshal(b, &id) == nil && id.Email != "" && id.verified() {
			return strings.ToLower(id.Email), nil
		}
	}
	req, err := http.NewRequestWithContext(ctx, "GET", g.UserinfoURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+tok.AccessToken)
	resp, err := g.Client.Do(req)
	if err != nil {
		return "", fmt.Errorf("userinfo request failed: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<10))
		return "", fmt.Errorf("userinfo error %d: %s", resp.StatusCode, strings.TrimSpace(string(b)))
	}
	var id googleIdentity
	if err := json.NewDecoder(io.LimitReader(resp.Body, 64<<10)).Decode(&id); err != nil {
		return "", fmt.Errorf("userinfo response: %w", err)
	}
	if id.Email == "" || !id.verified() {
		return "", errors.New("Google did not share a verified email address")
	}
	return strings.ToLower(id.Email), nil
}
