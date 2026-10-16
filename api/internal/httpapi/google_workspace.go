package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"sort"
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
	Scopes       []string
	// LastSync is when Calendar and Gmail were last pulled; LastError is what
	// failed then, if anything.
	LastSync  time.Time
	LastError string
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
	IDToken      string `json:"id_token"`
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
	HangoutLink    string          `json:"hangoutLink"`
	ConferenceData json.RawMessage `json:"conferenceData"`
}

// calendarEvents queries upcoming events from Google Calendar API.
func (g GoogleOAuth) calendarEvents(ctx context.Context, accessToken string, now time.Time) ([]googleCalendarItem, error) {
	tMin := now.Add(-24 * time.Hour)
	realNow := time.Now()
	if realNow.Before(tMin) || realNow.After(now.AddDate(0, 0, 14)) {
		tMin = realNow.Add(-24 * time.Hour)
	}
	timeMin := tMin.UTC().Format(time.RFC3339)
	timeMax := tMin.AddDate(0, 1, 0).UTC().Format(time.RFC3339)

	u := fmt.Sprintf("%s?timeMin=%s&timeMax=%s&singleEvents=true&orderBy=startTime&maxResults=25",
		g.CalendarURL, url.QueryEscape(timeMin), url.QueryEscape(timeMax))

	req, err := http.NewRequestWithContext(ctx, "GET", u, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := g.Client.Do(req)
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

// gmailTravelMessages queries recent booking / ticket messages from Gmail API.
func (g GoogleOAuth) gmailTravelMessages(ctx context.Context, accessToken string) ([]gmailMessageItem, error) {
	q := url.QueryEscape("ticket OR booking OR reservation OR flight OR concert OR hotel OR event")
	u := fmt.Sprintf("%s?q=%s&maxResults=6", g.GmailURL, q)

	req, err := http.NewRequestWithContext(ctx, "GET", u, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)

	resp, err := g.Client.Do(req)
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
		msgReq, err := http.NewRequestWithContext(ctx, "GET", fmt.Sprintf("%s/%s?format=metadata", g.GmailURL, m.ID), nil)
		if err != nil {
			continue
		}
		msgReq.Header.Set("Authorization", "Bearer "+accessToken)
		msgResp, err := g.Client.Do(msgReq)
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

// defaultOrigin is where a synced trip starts when the user has saved no home.
var defaultOrigin = domain.Place{NameTH: "สีลม", Lat: 13.7279, Lng: 100.5281}

// onlineTH names the destination of an online meeting.
const onlineTH = "ออนไลน์"

// connectWindow is how soon after one event ends the next must start for the
// user to travel straight from the first place to the second.
const connectWindow = 3 * time.Hour

// homeOrigin is the user's saved home, or defaultOrigin.
func homeOrigin(savedPlaces []domain.SavedPlace) domain.Place {
	for _, sp := range savedPlaces {
		if sp.Kind == domain.KindHome && sp.Resolved() {
			return sp.Place
		}
	}
	return defaultOrigin
}

// matchSavedPlace is the first saved place whose name or label appears in text.
func matchSavedPlace(text string, savedPlaces []domain.SavedPlace) (domain.Place, bool) {
	text = strings.ToLower(text)
	for _, sp := range savedPlaces {
		for _, name := range []string{sp.NameTH, sp.LabelTH} {
			if name != "" && strings.Contains(text, strings.ToLower(name)) {
				return sp.Place, true
			}
		}
	}
	return domain.Place{}, false
}

var onlineMarkers = []string{"meet.google.com", "zoom.us", "teams.microsoft.com", "zoom", "google meet", "teams"}

// isOnlineMeeting reports whether a Calendar event happens on a video call:
// it carries a Meet link or conference data, or its location is a URL or
// names a video-call service.
func isOnlineMeeting(item googleCalendarItem) bool {
	if item.HangoutLink != "" || len(item.ConferenceData) > 0 && string(item.ConferenceData) != "null" {
		return true
	}
	loc := strings.ToLower(strings.TrimSpace(item.Location))
	if strings.HasPrefix(loc, "http://") || strings.HasPrefix(loc, "https://") {
		return true
	}
	for _, m := range onlineMarkers {
		if strings.Contains(loc, m) {
			return true
		}
	}
	return false
}

// ConvertCalendarEventToTrip turns a Google Calendar entry into a domain.Trip
// from the user's home. It never invents a place or a time: an online meeting
// is Virtual, an all-day event is AllDay, and a location that matches no saved
// place and does not geocode leaves the destination unresolved with the
// location text in LocationTextTH.
func ConvertCalendarEventToTrip(ctx context.Context, item googleCalendarItem, geo geocode.Geocoder, savedPlaces []domain.SavedPlace) domain.Trip {
	title := strings.TrimSpace(item.Summary)
	if title == "" {
		title = "นัดหมายในปฏิทิน"
	}
	trip := domain.Trip{
		ID:      "cal-" + item.ID,
		TitleTH: title,
		Source:  "calendar",
		Origin:  homeOrigin(savedPlaces),
		Mode:    domain.ModeCar,
	}

	if item.Start.DateTime != "" {
		if t, err := time.Parse(time.RFC3339, item.Start.DateTime); err == nil {
			trip.ArriveBy = t.In(domain.Bangkok)
		}
		if t, err := time.Parse(time.RFC3339, item.End.DateTime); err == nil {
			trip.EndsAt = t.In(domain.Bangkok)
		}
	} else if t, err := time.ParseInLocation(time.DateOnly, item.Start.Date, domain.Bangkok); err == nil {
		// Google's all-day end date is exclusive: the midnight the event ends.
		trip.AllDay, trip.ArriveBy, trip.EndsAt = true, t, t.AddDate(0, 0, 1)
		if end, err := time.ParseInLocation(time.DateOnly, item.End.Date, domain.Bangkok); err == nil && end.After(t) {
			trip.EndsAt = end
		}
	}

	location := strings.TrimSpace(item.Location)
	switch {
	case isOnlineMeeting(item):
		trip.Virtual = true
		trip.Destination = domain.Place{NameTH: onlineTH}
	case trip.AllDay:
		trip.Destination = domain.Place{NameTH: location}
		trip.LocationTextTH = location
	default:
		query := location
		if query == "" {
			query = title
		}
		if p, ok := resolveEventPlace(ctx, query, geo, savedPlaces); ok {
			trip.Destination = p
		} else {
			trip.Destination = domain.Place{NameTH: location}
			trip.LocationTextTH = location
		}
	}
	return trip
}

// resolveEventPlace finds query among the saved places, then by geocoding it.
func resolveEventPlace(ctx context.Context, query string, geo geocode.Geocoder, savedPlaces []domain.SavedPlace) (domain.Place, bool) {
	if p, ok := matchSavedPlace(query, savedPlaces); ok {
		return p, true
	}
	if geo == nil {
		return domain.Place{}, false
	}
	candidates, err := geo.Search(ctx, query)
	if err != nil || len(candidates) == 0 || (candidates[0].Lat == 0 && candidates[0].Lng == 0) {
		return domain.Place{}, false
	}
	return domain.Place{NameTH: query, Lat: candidates[0].Lat, Lng: candidates[0].Lng}, true
}

// ConvertCalendarEventsToTrips converts items in start order and chains
// back-to-back events: when the last same-day event the user travelled to
// (not online or all-day, with a resolved place) ends at most connectWindow
// before the next one starts, the next trip starts from that event's place
// instead of home.
func ConvertCalendarEventsToTrips(ctx context.Context, items []googleCalendarItem, geo geocode.Geocoder, savedPlaces []domain.SavedPlace) []domain.Trip {
	trips := make([]domain.Trip, 0, len(items))
	for _, item := range items {
		trips = append(trips, ConvertCalendarEventToTrip(ctx, item, geo, savedPlaces))
	}
	sort.SliceStable(trips, func(i, j int) bool { return trips[i].ArriveBy.Before(trips[j].ArriveBy) })

	var prev *domain.Trip
	for i := range trips {
		t := &trips[i]
		if prev != nil && sameDay(prev.ArriveBy, t.ArriveBy) {
			ended := prev.EndsAt
			if ended.IsZero() {
				ended = prev.ArriveBy
			}
			if gap := t.ArriveBy.Sub(ended); gap >= 0 && gap <= connectWindow {
				t.Origin = prev.Destination
			}
		}
		if !t.Virtual && !t.AllDay && t.Destination.Resolved() {
			prev = t
		}
	}
	return trips
}

func sameDay(a, b time.Time) bool {
	a, b = a.In(domain.Bangkok), b.In(domain.Bangkok)
	return a.Year() == b.Year() && a.YearDay() == b.YearDay()
}

// gmailKeywords are venues a booking email may name that the geocoder knows.
var gmailKeywords = []string{"อิมแพ็ค", "Impact", "Siam", "สยาม", "สนามบิน", "Central", "ไอคอนสยาม"}

// ConvertGmailMessageToTrip turns an extracted travel email into a domain.Trip
// from the user's home. A venue that matches no saved place and no geocoded
// keyword leaves the destination unresolved rather than guessed.
func ConvertGmailMessageToTrip(ctx context.Context, item gmailMessageItem, geo geocode.Geocoder, savedPlaces []domain.SavedPlace) domain.Trip {
	title := strings.TrimSpace(item.Subject)
	if title == "" {
		title = "ตั๋วหรือนัดหมายการเดินทาง"
	}

	text := title + " " + item.Snippet
	destPlace, resolved := matchSavedPlace(text, savedPlaces)
	if !resolved && geo != nil {
		for _, kw := range gmailKeywords {
			if !strings.Contains(strings.ToLower(text), strings.ToLower(kw)) {
				continue
			}
			if candidates, err := geo.Search(ctx, kw); err == nil && len(candidates) > 0 {
				destPlace = domain.Place{NameTH: candidates[0].NameTH, Lat: candidates[0].Lat, Lng: candidates[0].Lng}
				break
			}
		}
	}

	arriveBy := time.Now().Add(24 * time.Hour)
	if item.Date != "" {
		if t, err := time.Parse(time.RFC1123Z, item.Date); err == nil {
			arriveBy = t.Add(24 * time.Hour) // assume event is day after or scheduled
		}
	}

	return domain.Trip{
		ID:          "gmail-" + item.ID,
		TitleTH:     title,
		Source:      "gmail",
		Origin:      homeOrigin(savedPlaces),
		Destination: destPlace,
		ArriveBy:    arriveBy,
		Mode:        domain.ModeCar,
	}
}

// SyncUserWorkspaceData pulls actual events from Google APIs and upserts into
// UserStore. Its error names each service that failed; the other's trips are
// still stored.
func (s *Server) SyncUserWorkspaceData(ctx context.Context, email, accessToken string, now time.Time) error {
	g := s.google()
	var failed []error
	var savedPlaces []domain.SavedPlace
	if s.Planner != nil && s.Planner.Places != nil {
		savedPlaces = s.Planner.Places
	}

	calItems, err := g.calendarEvents(ctx, accessToken, now)
	if err != nil {
		slog.Warn("fetch google calendar events error", "email", email, "err", err)
		failed = append(failed, err)
	} else {
		for _, trip := range ConvertCalendarEventsToTrips(ctx, calItems, s.Geocoder, savedPlaces) {
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

	gmailItems, err := g.gmailTravelMessages(ctx, accessToken)
	if err != nil {
		slog.Warn("fetch gmail messages error", "email", email, "err", err)
		failed = append(failed, err)
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

	return errors.Join(failed...)
}
