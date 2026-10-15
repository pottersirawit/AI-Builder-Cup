# Handoff Document: Google Workspace & OAuth Integration

**Date:** 2026-10-16  
**Branch:** `feat/oauth-and-implement-additional-data-source`  
**Cloud Run Production Service:** `https://fontokmai-api-lmr33aj5zq-as.a.run.app`  
**Current Revision:** `fontokmai-api-00014-82x`

---

## 1. Executive Summary

This phase delivered full end-to-end integration of Google Workspace (Google Calendar & Gmail) as live data sources for Fontokmai, alongside production-ready Google OAuth 2.0 verification pages, persistent local authentication, and live AI decision reasoning using real user events.

Previously:
- The app relied on static mock scenario fixtures (`cal-dinner` with "กินข้าวที่บ้าน 18:30" and `gmail-concert`).
- Browser reloads/refreshes reset the OAuth link state to `notConnected`, requiring reconnecting every time.
- `/v1/decide` failed with 404 for live Google Calendar IDs, silently triggering the offline fallback to the hardcoded dinner fixture in the "เหตุผลที่แนะนำแบบนี้" (Reasoning Trace) section.
- Google OAuth verification encountered domain accessibility issues on the home page and privacy policy.

Now:
- Live Google Calendar events and Gmail travel itineraries are fetched, geocoded, and converted to real `domain.Trip` objects.
- Connection state, authenticated email, and synced trips persist in `localStorage` (`SharedPreferences`), surviving page refreshes and browser restarts.
- Decision sessions in `/v1/decide` use real user trip parameters, allowing Gemini and the Planner to evaluate the user's actual destination, route, and deadline.
- OAuth verification compliance is satisfied with accessible Home Page, Privacy Policy, and a custom branded callback screen.

---

## 2. Key Architecture & File Changes

```
┌────────────────────────────────────────────────────────┐
│                   Flutter Client                       │
│  - places.dart: SharedPreferences persistence          │
│  - home_screen.dart: Instant cached trips + live sync  │
│  - models.dart: DecideRequest with full Trip & email   │
│  - settings_screen.dart: Friendly OAuth dialog         │
└──────────────────────────┬─────────────────────────────┘
                           │ HTTPS / REST
┌──────────────────────────▼─────────────────────────────┐
│                 Go Cloud Run Backend                   │
│  - httpapi.go: /v1/trips, /v1/trips/sync, /v1/decide   │
│  - google_workspace.go: Token exchange, Calendar/Gmail │
│  - planner.go: Dynamic session with user domain.Trip   │
│  - users.go: UserStore with FindTripByID               │
│  - static_pages.go: Home, Privacy Policy, OAuth return │
└────────────────────────────────────────────────────────┘
```

### A. Frontend Changes (`app/`)

1. **Local Authentication & Trip Persistence ([`app/lib/places.dart`](file:///c:/AICup/AI-Builder-Cup/app/lib/places.dart)):**
   - Added persistence keys:
     - `_kCalendarState = 'profile.calendar_state'`
     - `_kGmailState = 'profile.gmail_state'`
     - `_kCalendarEmail = 'profile.calendar_email'`
     - `_kGmailEmail = 'profile.gmail_email'`
     - `_kCachedTrips = 'profile.cached_trips'`
   - Updated `_read()` and `_write()` to persist and restore `_calendar`, `_gmail`, and `_cachedTrips`.
   - Updated `connectCalendar({allowLive = false, email})` and `connectGmail({email})` to immediately save state to preferences.
   - Updated `disconnectCalendar()` and `disconnectGmail()` to remove saved keys and clear associated trips.

2. **Decide Request & Trip Serialization ([`app/lib/models.dart`](file:///c:/AICup/AI-Builder-Cup/app/lib/models.dart)):**
   - Implemented `Trip.toJson()`.
   - Extended `DecideRequest` to include `Trip? trip` and `String? email`, ensuring `copyWith` and `toJson()` preserve full trip details.

3. **Trip Loading & Request Builder ([`app/lib/screens/home_screen.dart`](file:///c:/AICup/AI-Builder-Cup/app/lib/screens/home_screen.dart)):**
   - `_load()` immediately renders `store.cachedTrips` on page load, eliminating empty UI while background sync runs.
   - `_requestFor(Trip t)` passes the complete trip (`origin`, `destination`, `tripId`, `trip: t`, `email: email`) to `/v1/decide`.

4. **Friendly OAuth Permission Dialog ([`app/lib/screens/settings_screen.dart`](file:///c:/AICup/AI-Builder-Cup/app/lib/screens/settings_screen.dart)):**
   - Removed technical jargon (`calendar.readonly`, `gmail.readonly`).
   - Replaced with clear, benefit-oriented Thai/English explanations of what the app accesses (read-only schedule times and destinations to alert about flood/rain risks).

### B. Backend Changes (`api/`)

1. **Workspace Data Sync ([`api/internal/httpapi/google_workspace.go`](file:///c:/AICup/AI-Builder-Cup/api/internal/httpapi/google_workspace.go)):**
   - `ExchangeGoogleAuthCode`: Performs OAuth code exchange with `oauth2.googleapis.com/token`.
   - `FetchGoogleCalendarEvents`: Dynamically handles wall-clock and demo-clock windows to query upcoming events up to 30 days ahead.
   - `ConvertCalendarEventToTrip`: Parses title, start time, and performs geocoding on location and event summary using Bangkok geocoder.
   - `FetchGmailTravelMessages`: Scans messages for travel itineraries and flight/train/hotel bookings.
   - `SyncUserWorkspaceData`: Stores converted trips into `UserStore`.

2. **Dynamic Trip Decision Planning ([`api/internal/planner/planner.go`](file:///c:/AICup/AI-Builder-Cup/api/internal/planner/planner.go)):**
   - Extended `TripRequest` with `Trip *domain.Trip` and `Email string`.
   - Updated `Planner.open`: If `req.Trip != nil`, the planner initializes the decision session directly with the user's actual trip (preserving Title, ArriveBy deadline, and Source), preventing `ErrUnknownTrip`.
   - Planner tool `get_trip` generates real reasoning summary:
     `"นัด<Title> ต้องถึง<Destination>ก่อน <Time> (จาก Google Calendar)"`.
   - Route and departure evaluations route to the actual destination coordinates.

3. **Decide Endpoint Trip Resolution ([`api/internal/httpapi/httpapi.go`](file:///c:/AICup/AI-Builder-Cup/api/internal/httpapi/httpapi.go)):**
   - In `s.decide`: If `tripReq.Trip != nil`, it upserts the trip into `UserStore`.
   - If `tripReq.Trip == nil && tripReq.TripID != ""`, it resolves the trip from `s.UserStore.FindTripByID`.

4. **User Storage Lookup ([`api/internal/users/users.go`](file:///c:/AICup/AI-Builder-Cup/api/internal/users/users.go)):**
   - Added `FindTripByID(ctx context.Context, tripID string) (UserTrip, error)` to `UserStore` interface and `MemoryUserStore`.

5. **Static Pages & OAuth Callback ([`api/internal/httpapi/static_pages.go`](file:///c:/AICup/AI-Builder-Cup/api/internal/httpapi/static_pages.go)):**
   - Served compliant Home Page (`GET /`) and Privacy Policy (`GET /privacy`).
   - Redesigned `GET /oauth2callback` using the Chakra Petch design system with user email badge, return button, and `window.opener.postMessage` trigger.

---

## 3. Verification & Test Results

### Go Backend
```bash
go test ./...
```
* **Result:** All 22 packages passed.
* **Coverage Highlights:**
  - Added test case in [`google_workspace_test.go`](file:///c:/AICup/AI-Builder-Cup/api/internal/httpapi/google_workspace_test.go) verifying that `/v1/decide` with custom user calendar trip returns 200 and matches the custom title in the reasoning trace.

### Flutter Client
```bash
flutter test
```
* **Result:** 96 out of 96 tests passed (0 failures).
* **Coverage Highlights:**
  - Added test case in [`places_test.dart`](file:///c:/AICup/AI-Builder-Cup/app/test/places_test.dart) verifying `PlacesStore` survives restarts/refreshes with persistent `calendar`, `gmail`, and `cachedTrips`.

---

## 4. How to Run & Test Locally

### Option A: Run Flutter Web with Live Cloud Run Backend
```powershell
flutter run -d chrome --web-port 8081 --dart-define=API_BASE_URL=https://fontokmai-api-lmr33aj5zq-as.a.run.app
```

### Option B: Run Full Local Stack
1. Start Go Server:
   ```powershell
   cd api
   go run ./cmd/server
   ```
2. Start Flutter Web (in another terminal):
   ```powershell
   cd app
   flutter run -d chrome --web-port 8081 --dart-define=API_BASE_URL=http://localhost:8080
   ```

---

## 5. Deployment Information
* **GCP Project:** `ai-cup-511208`
* **Region:** `asia-southeast1`
* **Cloud Run Service:** `fontokmai-api`
* **Live Endpoint:** `https://fontokmai-api-lmr33aj5zq-as.a.run.app`
* **OAuth Redirect URI:** `https://fontokmai-api-lmr33aj5zq-as.a.run.app/oauth2callback`
* **Deployment Script:** `api\deploy\cloudrun.ps1`
