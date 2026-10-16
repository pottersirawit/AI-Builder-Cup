package httpapi

import (
	"context"
	"encoding/base64"
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
	"github.com/pottersirawit/fontokmai/api/internal/extract"
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
	// Body is the message's plain text, or empty when it has none.
	Body string
}

// gmailTravelQuery finds bookings and tickets, leaving out the Promotions and
// Social tabs where the same words mostly sell things.
const gmailTravelQuery = "(ticket OR booking OR reservation OR flight OR concert OR hotel OR event) -category:promotions -category:social"

// gmailPart is a MIME part of a message fetched with format=full.
type gmailPart struct {
	MimeType string `json:"mimeType"`
	Headers  []struct {
		Name  string `json:"name"`
		Value string `json:"value"`
	} `json:"headers"`
	Body struct {
		Data string `json:"data"`
	} `json:"body"`
	Parts []gmailPart `json:"parts"`
}

// plainText is the first text/plain part under p, decoded.
func (p gmailPart) plainText() string {
	if p.MimeType == "text/plain" && p.Body.Data != "" {
		b, err := base64.URLEncoding.DecodeString(p.Body.Data)
		if err != nil {
			b, err = base64.RawURLEncoding.DecodeString(p.Body.Data)
		}
		if err == nil {
			return string(b)
		}
	}
	for _, c := range p.Parts {
		if t := c.plainText(); t != "" {
			return t
		}
	}
	return ""
}

// gmailTravelMessages queries recent booking / ticket messages from Gmail API.
func (g GoogleOAuth) gmailTravelMessages(ctx context.Context, accessToken string) ([]gmailMessageItem, error) {
	q := url.QueryEscape(gmailTravelQuery)
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
		msgReq, err := http.NewRequestWithContext(ctx, "GET", fmt.Sprintf("%s/%s?format=full", g.GmailURL, m.ID), nil)
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
			ID      string    `json:"id"`
			Snippet string    `json:"snippet"`
			Payload gmailPart `json:"payload"`
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
			Body:    detail.Payload.plainText(),
		})
	}

	return items, nil
}

// defaultOrigin is where a synced trip starts when the app sent no home; its
// name says so.
var defaultOrigin = domain.Place{NameTH: "สีลม (ยังไม่ได้ตั้งบ้าน)", Lat: 13.7279, Lng: 100.5281}

// gmailNoteTH marks a trip Gemini found in the user's email.
const gmailNoteTH = "Gemini อ่านจากอีเมลของคุณ"

// homePlaces is the saved places of a user known only by home: none when home
// is unresolved.
func homePlaces(home domain.Place) []domain.SavedPlace {
	if !home.Resolved() {
		return nil
	}
	return []domain.SavedPlace{{ID: "home", Kind: domain.KindHome, LabelTH: "บ้าน", Place: home}}
}

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

// matchSavedPlace is the first saved place other than home whose name or
// label appears in text. Home is never matched: "บ้าน" also begins a friend's
// or a parent's home (บ้านเพื่อน, บ้านแม่).
func matchSavedPlace(text string, savedPlaces []domain.SavedPlace) (domain.Place, bool) {
	text = strings.ToLower(text)
	for _, sp := range savedPlaces {
		if sp.Kind == domain.KindHome {
			continue
		}
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

// ConvertGmailMessageToTrip turns an email Gemini read into a domain.Trip from
// the user's home. ok is false unless the reply is a trip with both a start
// time and a place: an email's own date says nothing about when the event is.
// A place that matches no saved place and does not geocode is left unresolved.
func ConvertGmailMessageToTrip(ctx context.Context, item gmailMessageItem, p extract.Payload, geo geocode.Geocoder, savedPlaces []domain.SavedPlace) (trip domain.Trip, ok bool) {
	place := strings.TrimSpace(p.DestinationText)
	if !p.IsTrip || p.ArriveBy == nil || place == "" {
		return domain.Trip{}, false
	}
	title := strings.TrimSpace(item.Subject)
	if t := strings.TrimSpace(p.TitleTH); t != "" {
		title = t
	}
	if title == "" {
		title = "ตั๋วหรือนัดหมายการเดินทาง"
	}
	trip = domain.Trip{
		ID:       "gmail-" + item.ID,
		TitleTH:  title,
		Source:   "gmail",
		Origin:   homeOrigin(savedPlaces),
		ArriveBy: p.ArriveBy.In(domain.Bangkok),
		Mode:     domain.ModeCar,
		NoteTH:   gmailNoteTH,
	}
	if p.Mode != nil {
		trip.Mode = *p.Mode
	}
	if dest, found := resolveEventPlace(ctx, place, geo, savedPlaces); found {
		trip.Destination = dest
	} else {
		trip.Destination = domain.Place{NameTH: place}
		trip.LocationTextTH = place
	}
	return trip, true
}

// gmailTrips has Gemini read each message, all at once, and keeps the trips.
// Without Gemini there are none.
func (s *Server) gmailTrips(ctx context.Context, items []gmailMessageItem, savedPlaces []domain.SavedPlace, now time.Time) []domain.Trip {
	if !s.Gemini.Available() {
		return nil
	}
	found := make([]*domain.Trip, len(items))
	var wg sync.WaitGroup
	for i, item := range items {
		wg.Add(1)
		go func() {
			defer wg.Done()
			body := item.Body
			if strings.TrimSpace(body) == "" {
				body = item.Snippet
			}
			p, err := extract.WithGemini(ctx, s.Gemini, extract.RawMessage{
				Source:    extract.SourceGmail,
				SourceRef: item.ID,
				Title:     item.Subject,
				Body:      "Sent: " + item.Date + "\n" + body,
			}, now)
			if err != nil {
				slog.Warn("gemini could not read a gmail message", "id", item.ID, "err", err)
				return
			}
			if trip, ok := ConvertGmailMessageToTrip(ctx, item, p, s.Geocoder, savedPlaces); ok {
				found[i] = &trip
			}
		}()
	}
	wg.Wait()
	var trips []domain.Trip
	for _, t := range found {
		if t != nil {
			trips = append(trips, *t)
		}
	}
	return trips
}

// SyncUserWorkspaceData pulls actual events from Google APIs and upserts into
// UserStore, planning each from home (the app's saved home, unresolved when it
// sent none). Only มิว's DemoEmail uses the scenario's saved places. Its error
// names each service that failed; the other's trips are still stored.
func (s *Server) SyncUserWorkspaceData(ctx context.Context, email, accessToken string, home domain.Place, now time.Time) error {
	g := s.google()
	var failed []error
	savedPlaces := homePlaces(home)
	if email == DemoEmail && s.Planner != nil {
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
		trips := s.gmailTrips(ctx, gmailItems, savedPlaces, now)
		for _, trip := range trips {
			if s.UserStore != nil {
				_ = s.UserStore.UpsertTrip(ctx, users.UserTrip{
					UID:       email,
					Trip:      trip,
					UpdatedAt: time.Now(),
				})
			}
		}
		slog.Info("synced gmail messages", "email", email, "count", len(gmailItems), "trips", len(trips))
	}

	return errors.Join(failed...)
}
