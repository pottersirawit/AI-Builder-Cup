package httpapi

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/pottersirawit/fontokmai/api/internal/domain"
	"github.com/pottersirawit/fontokmai/api/internal/geocode"
	"github.com/pottersirawit/fontokmai/api/internal/users"
)

const (
	defaultGoogleClientID     = "945826169258-2npe55rhvgjl26a8mgfod4s9js5bbgpo.apps.googleusercontent.com"
	defaultGoogleClientSecret = "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"
	googleTokenURL            = "https://oauth2.googleapis.com/token"
	googleCalendarEventsURL   = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
	gmailMessagesURL          = "https://gmail.googleapis.com/gmail/v1/users/me/messages"
)

type userToken struct {
	AccessToken  string
	RefreshToken string
	Expiry       time.Time
}

var (
	tokenStoreMu sync.RWMutex
	tokenStore   = make(map[string]*userToken)
)

// parseClientSecret extracts raw secret if value is Google Console JSON.
func parseClientSecret(raw string) string {
	raw = strings.TrimSpace(raw)
	if strings.HasPrefix(raw, "{") {
		var parsed struct {
			Web struct {
				ClientSecret string `json:"client_secret"`
			} `json:"web"`
			Installed struct {
				ClientSecret string `json:"client_secret"`
			} `json:"installed"`
			ClientSecret string `json:"client_secret"`
		}
		if err := json.Unmarshal([]byte(raw), &parsed); err == nil {
			if parsed.Web.ClientSecret != "" {
				return parsed.Web.ClientSecret
			}
			if parsed.Installed.ClientSecret != "" {
				return parsed.Installed.ClientSecret
			}
			if parsed.ClientSecret != "" {
				return parsed.ClientSecret
			}
		}
	}
	return raw
}

func getOAuthCredentials() (string, string) {
	clientID := strings.TrimSpace(os.Getenv("GOOGLE_OAUTH_CLIENT_ID"))
	if clientID == "" {
		clientID = defaultGoogleClientID
	}
	clientSecret := parseClientSecret(os.Getenv("GOOGLE_OAUTH_CLIENT_SECRET"))
	if clientSecret == "" {
		clientSecret = defaultGoogleClientSecret
	}
	return clientID, clientSecret
}

// GoogleTokenResponse represents tokens returned by oauth2.googleapis.com/token.
type GoogleTokenResponse struct {
	AccessToken  string `json:"access_token"`
	ExpiresIn    int    `json:"expires_in"`
	RefreshToken string `json:"refresh_token"`
	Scope        string `json:"scope"`
	TokenType    string `json:"token_type"`
}

// ExchangeGoogleAuthCode exchanges authorization code for Google access token.
func ExchangeGoogleAuthCode(ctx context.Context, code, redirectURI string) (*GoogleTokenResponse, error) {
	clientID, clientSecret := getOAuthCredentials()

	data := url.Values{}
	data.Set("code", code)
	data.Set("client_id", clientID)
	data.Set("client_secret", clientSecret)
	data.Set("redirect_uri", redirectURI)
	data.Set("grant_type", "authorization_code")

	req, err := http.NewRequestWithContext(ctx, "POST", googleTokenURL, strings.NewReader(data.Encode()))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("token exchange request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 64<<10))
	if err != nil {
		return nil, err
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("token exchange error %d: %s", resp.StatusCode, string(body))
	}

	var tokenResp GoogleTokenResponse
	if err := json.Unmarshal(body, &tokenResp); err != nil {
		return nil, fmt.Errorf("unmarshal token response failed: %w", err)
	}
	return &tokenResp, nil
}

type googleCalendarListResponse struct {
	Items []googleCalendarItem `json:"items"`
}

type googleCalendarItem struct {
	ID          string `json:"id"`
	Summary     string `json:"summary"`
	Description string `json:"description"`
	Location    string `json:"location"`
	Start       struct {
		DateTime string `json:"dateTime"`
		Date     string `json:"date"`
	} `json:"start"`
	End struct {
		DateTime string `json:"dateTime"`
		Date     string `json:"date"`
	} `json:"end"`
}

// FetchGoogleCalendarEvents queries upcoming events from Google Calendar API.
func FetchGoogleCalendarEvents(ctx context.Context, accessToken string, now time.Time) ([]googleCalendarItem, error) {
	tMin := now.Add(-24 * time.Hour)
	realNow := time.Now()
	if realNow.Before(tMin) || realNow.After(now.AddDate(0, 0, 14)) {
		tMin = realNow.Add(-24 * time.Hour)
	}
	timeMin := tMin.UTC().Format(time.RFC3339)
	timeMax := tMin.AddDate(0, 1, 0).UTC().Format(time.RFC3339)

	u := fmt.Sprintf("%s?timeMin=%s&timeMax=%s&singleEvents=true&orderBy=startTime&maxResults=25",
		googleCalendarEventsURL, url.QueryEscape(timeMin), url.QueryEscape(timeMax))

	req, err := http.NewRequestWithContext(ctx, "GET", u, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("calendar events fetch failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<10))
		return nil, fmt.Errorf("calendar API returned %d: %s", resp.StatusCode, string(b))
	}

	var list googleCalendarListResponse
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return nil, err
	}
	return list.Items, nil
}

type gmailListResponse struct {
	Messages []struct {
		ID       string `json:"id"`
		ThreadID string `json:"threadId"`
	} `json:"messages"`
}

type gmailMessageItem struct {
	ID      string
	Subject string
	Date    string
	Snippet string
}

// FetchGmailTravelMessages queries recent booking / ticket messages from Gmail API.
func FetchGmailTravelMessages(ctx context.Context, accessToken string) ([]gmailMessageItem, error) {
	q := url.QueryEscape("ticket OR booking OR reservation OR flight OR concert OR hotel OR event")
	u := fmt.Sprintf("%s?q=%s&maxResults=6", gmailMessagesURL, q)

	req, err := http.NewRequestWithContext(ctx, "GET", u, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("gmail messages query failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<10))
		return nil, fmt.Errorf("gmail API returned %d: %s", resp.StatusCode, string(b))
	}

	var list gmailListResponse
	if err := json.NewDecoder(resp.Body).Decode(&list); err != nil {
		return nil, err
	}

	var items []gmailMessageItem
	for _, m := range list.Messages {
		msgReq, err := http.NewRequestWithContext(ctx, "GET", fmt.Sprintf("%s/%s?format=metadata", gmailMessagesURL, m.ID), nil)
		if err != nil {
			continue
		}
		msgReq.Header.Set("Authorization", "Bearer "+accessToken)
		msgResp, err := http.DefaultClient.Do(msgReq)
		if err != nil || msgResp.StatusCode != 200 {
			if msgResp != nil {
				msgResp.Body.Close()
			}
			continue
		}

		var detail struct {
			ID      string `json:"id"`
			Snippet string `json:"snippet"`
			Payload struct {
				Headers []struct {
					Name  string `json:"name"`
					Value string `json:"value"`
				} `json:"headers"`
			} `json:"payload"`
		}
		_ = json.NewDecoder(msgResp.Body).Decode(&detail)
		msgResp.Body.Close()

		subject := ""
		dateStr := ""
		for _, h := range detail.Payload.Headers {
			if strings.EqualFold(h.Name, "Subject") {
				subject = h.Value
			}
			if strings.EqualFold(h.Name, "Date") {
				dateStr = h.Value
			}
		}

		items = append(items, gmailMessageItem{
			ID:      detail.ID,
			Subject: subject,
			Date:    dateStr,
			Snippet: detail.Snippet,
		})
	}

	return items, nil
}

// ConvertCalendarEventToTrip turns a Google Calendar entry into a domain.Trip.
func ConvertCalendarEventToTrip(ctx context.Context, item googleCalendarItem, geo geocode.Geocoder, savedPlaces []domain.SavedPlace) domain.Trip {
	title := strings.TrimSpace(item.Summary)
	if title == "" {
		title = "นัดหมายในปฏิทิน"
	}

	destName := strings.TrimSpace(item.Location)
	if destName == "" {
		destName = title
	}

	destPlace := domain.Place{
		NameTH: destName,
		Lat:    13.7462,
		Lng:    100.5348, // Siam default
	}

	// 1. Try matching with saved places
	for _, sp := range savedPlaces {
		if strings.Contains(strings.ToLower(destName), strings.ToLower(sp.NameTH)) ||
			strings.Contains(strings.ToLower(destName), strings.ToLower(sp.LabelTH)) {
			destPlace = sp.Place
			break
		}
	}

	// 2. Try geocoding if not matched in saved places
	if geo != nil && destPlace.Lat == 13.7462 && destPlace.Lng == 100.5348 {
		searchQuery := item.Location
		if searchQuery == "" {
			searchQuery = title
		}
		if candidates, err := geo.Search(ctx, searchQuery); err == nil && len(candidates) > 0 {
			destPlace = domain.Place{
				NameTH: searchQuery,
				Lat:    candidates[0].Lat,
				Lng:    candidates[0].Lng,
			}
		}
	}

	var arriveBy time.Time
	if item.Start.DateTime != "" {
		if t, err := time.Parse(time.RFC3339, item.Start.DateTime); err == nil {
			arriveBy = t
		}
	} else if item.Start.Date != "" {
		if t, err := time.Parse("2006-01-02", item.Start.Date); err == nil {
			// default to 09:00 Bangkok time for all-day events
			loc, _ := time.LoadLocation("Asia/Bangkok")
			if loc != nil {
				arriveBy = time.Date(t.Year(), t.Month(), t.Day(), 9, 0, 0, 0, loc)
			} else {
				arriveBy = t.Add(9 * time.Hour)
			}
		}
	}

	origin := domain.Place{
		NameTH: "สีลม",
		Lat:    13.7279,
		Lng:    100.5281,
	}
	for _, sp := range savedPlaces {
		if sp.ID == "work" {
			origin = sp.Place
			break
		}
	}

	return domain.Trip{
		ID:          "cal-" + item.ID,
		TitleTH:     title,
		Source:      "calendar",
		Origin:      origin,
		Destination: destPlace,
		ArriveBy:    arriveBy,
		Mode:        domain.ModeCar,
	}
}

// ConvertGmailMessageToTrip turns an extracted travel email into a domain.Trip.
func ConvertGmailMessageToTrip(ctx context.Context, item gmailMessageItem, geo geocode.Geocoder, savedPlaces []domain.SavedPlace) domain.Trip {
	title := strings.TrimSpace(item.Subject)
	if title == "" {
		title = "ตั๋วหรือนัดหมายการเดินทาง"
	}

	destName := title
	if item.Snippet != "" {
		destName = item.Snippet
	}

	destPlace := domain.Place{
		NameTH: destName,
		Lat:    13.9114,
		Lng:    100.5492, // Default impact/venue
	}

	// Try geocoding if keyword found
	if geo != nil {
		for _, kw := range []string{"อิมแพ็ค", "Impact", "Siam", "สยาม", "สนามบิน", "Central", "ไอคอนสยาม"} {
			if strings.Contains(strings.ToLower(title), strings.ToLower(kw)) || strings.Contains(strings.ToLower(item.Snippet), strings.ToLower(kw)) {
				if candidates, err := geo.Search(ctx, kw); err == nil && len(candidates) > 0 {
					destPlace = domain.Place{
						NameTH: candidates[0].NameTH,
						Lat:    candidates[0].Lat,
						Lng:    candidates[0].Lng,
					}
					break
				}
			}
		}
	}

	arriveBy := time.Now().Add(24 * time.Hour)
	if item.Date != "" {
		if t, err := time.Parse(time.RFC1123Z, item.Date); err == nil {
			arriveBy = t.Add(24 * time.Hour) // assume event is day after or scheduled
		}
	}

	origin := domain.Place{
		NameTH: "สีลม",
		Lat:    13.7279,
		Lng:    100.5281,
	}
	for _, sp := range savedPlaces {
		if sp.ID == "work" {
			origin = sp.Place
			break
		}
	}

	return domain.Trip{
		ID:          "gmail-" + item.ID,
		TitleTH:     title,
		Source:      "gmail",
		Origin:      origin,
		Destination: destPlace,
		ArriveBy:    arriveBy,
		Mode:        domain.ModeCar,
	}
}

// SyncUserWorkspaceData pulls actual events from Google APIs and upserts into UserStore.
func (s *Server) SyncUserWorkspaceData(ctx context.Context, email, accessToken string, now time.Time) error {
	var savedPlaces []domain.SavedPlace
	if s.Planner != nil && s.Planner.Places != nil {
		savedPlaces = s.Planner.Places
	}

	calItems, err := FetchGoogleCalendarEvents(ctx, accessToken, now)
	if err != nil {
		slog.Warn("fetch google calendar events error", "email", email, "err", err)
	} else {
		for _, item := range calItems {
			trip := ConvertCalendarEventToTrip(ctx, item, s.Geocoder, savedPlaces)
			if s.UserStore != nil {
				_ = s.UserStore.UpsertTrip(ctx, users.UserTrip{
					UID:       email,
					Trip:      trip,
					UpdatedAt: time.Now(),
				})
			}
		}
		slog.Info("synced google calendar events", "email", email, "count", len(calItems))
	}

	gmailItems, err := FetchGmailTravelMessages(ctx, accessToken)
	if err != nil {
		slog.Warn("fetch gmail messages error", "email", email, "err", err)
	} else {
		for _, item := range gmailItems {
			trip := ConvertGmailMessageToTrip(ctx, item, s.Geocoder, savedPlaces)
			if s.UserStore != nil {
				_ = s.UserStore.UpsertTrip(ctx, users.UserTrip{
					UID:       email,
					Trip:      trip,
					UpdatedAt: time.Now(),
				})
			}
		}
		slog.Info("synced gmail messages", "email", email, "count", len(gmailItems))
	}

	return nil
}
