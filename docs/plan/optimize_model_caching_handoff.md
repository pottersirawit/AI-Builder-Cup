# Handoff Document: Feature Enhancements & Optimizations

**Date:** 2026-10-17  
**Branch:** `feat/optimize-model-caching`  
**Cloud Run Production Service:** `https://fontokmai-api-lmr33aj5zq-as.a.run.app`  
**Firebase Hosting:** `https://ai-cup-511208.web.app`  

---

## 1. Executive Summary

This branch delivers end-to-end optimizations across data ingestion, AI guardrails, deterministic deduplication, and workspace OAuth scope separation for ฝนตกไหม (Fontokmai).

Key achievements:
1. **OAuth Scope Splitting**: Users can connect Google Calendar and Gmail independently. Connecting Calendar requests only `calendar.readonly`, and connecting Gmail requests only `gmail.readonly`, using Google's incremental authorization (`include_granted_scopes=true`).
2. **Deterministic Event Deduplication**: When both Google Calendar and Gmail report the same flight, concert, or meeting, the system deterministically collapses them into a single ticket in microseconds—preserving Calendar schedule accuracy while adopting resolved coordinates from Gmail, with zero increase in AI decider latency.
3. **HTML Email Ingestion**: Gmail extraction now decodes and strips HTML tags from HTML-only booking confirmations (Airlines, Agoda, Eventpop, Ticketmelon) instead of falling back to truncated 100-character snippets. Added Thai travel keywords (`ตั๋ว`, `การจอง`, `นัดหมาย`, `เที่ยวบิน`).
4. **Rain Probability Integration**: Decision engine and Flutter mode comparison incorporate rain probability (`ProbPct >= 40%`) into motorcycle safety risk warnings.
5. **AI Safety & Unrelated Query Guardrails**: Hardened Gemini system prompts to refuse prompt injection and off-topic requests (recipes, coding, trivia) with standardized refusals and persistent accuracy disclaimers.
6. **All-Day Events & Route Management**: All-day events geocode accurately, carry zero late-penalty deadlines, and render as interactive tickets that tap into `VerdictScreen` with dynamic origin switching.

---

## 2. Architecture & Control Flow

```
┌────────────────────────────────────────────────────────┐
│                   Flutter Client                       │
│  - SettingsScreen: Independent Calendar & Gmail rows   │
│  - GoogleLink: Service-specific OAuth start & polling   │
│  - EventsScreen & SummaryScreen: Single deduped tickets│
│  - AskScreen & VerdictScreen: Advisory disclaimers     │
└──────────────────────────┬─────────────────────────────┘
                           │ HTTPS / REST
┌──────────────────────────▼─────────────────────────────┐
│                 Go Cloud Run Backend                   │
│  - oauth.go: ?service=calendar | gmail scope split    │
│  - dedup.go: Deterministic Calendar/Gmail deduplication│
│  - google_workspace.go: HTML body parsing + Thai query │
│  - decide.go: Off-topic guardrails & rain probability  │
│  - extract.go: Bilingual travel entity extraction      │
└────────────────────────────────────────────────────────┘
```

---

## 3. Detailed Feature Breakdown

### A. OAuth Scope Separation (`api/internal/httpapi/oauth.go`, `app/lib/google_link.dart`)
- **Backend**:
  - `oauthStart` accepts `?service=calendar` (requests `scopeBase + calendar.readonly`) or `?service=gmail` (requests `scopeBase + gmail.readonly`).
  - Google's `include_granted_scopes=true` ensures existing permissions are merged when connecting a second service.
  - Returns `scopes: []` in `/v1/oauth/status`.
  - Added `ErrScopeNotGranted` in `google_workspace.go`: `SyncUserWorkspaceData` skips unlinked services without raising errors or clearing existing trips.
- **Frontend**:
  - `PlacesStore` tracks `calendar` and `gmail` linking states independently.
  - `SettingsScreen` rows trigger service-specific OAuth dialogs explaining only the relevant permission.

### B. Deterministic Event Deduplication (`api/internal/httpapi/dedup.go`)
- **Matching Criteria**:
  - Same calendar day in Bangkok Indochina Time (`ICT`).
  - Arrival times within 90 minutes (or both all-day events).
  - AND either coordinates within 1,000 meters, matching destination names, or token-level title overlap (flight numbers, concert names).
- **Precedence & Enrichment**:
  - Calendar schedule is retained as the authoritative timeline.
  - If Calendar destination is unresolved but Gmail ticket has geocoded coordinates, the destination is automatically adopted.
  - Duplicate Gmail ticket is dropped.
  - Offline/deterministic execution (0 AI calls, < 1ms execution).

### C. HTML Email Ingestion Fallback (`api/internal/httpapi/google_workspace.go`)
- Added `stripHTML` and `bodyText()` to MIME part traversal:
  - If `text/plain` is empty, searches for `text/html`, decodes Base64-URL, and converts block elements (`<p>`, `<div>`, `<br>`, `<tr>`) into clean linebreaks.
  - Unescapes HTML entities.
  - Eliminates extraction failures caused by Gmail's 100-character snippet fallback.
- Query expanded: `(ticket OR booking OR reservation OR flight OR concert OR hotel OR event OR ตั๋ว OR จอง OR นัดหมาย OR เที่ยวบิน OR โรงแรม OR คอนเสิร์ต) -category:promotions -category:social`.

### D. AI Decider Guardrails & Accuracy Disclaimers (`api/internal/agent/decide.go`)
- **Unrelated Question Guardrail**:
  - Rejects queries outside travel, route conditions, rain, and floods.
  - Returns `refused: true` with a Thai message: `"ขออภัย ระบบตอบได้เฉพาะเรื่องการเดินทาง สภาพอากาศ และความปลอดภัยจากน้ำท่วมเท่านั้น"`.
  - Frontend renders refusal as a clean conversational bubble without empty trip pass cards.
- **Accuracy Disclaimer**:
  - Added persistent advisory labels across `AskScreen` and `VerdictScreen`.
  - Added Rule 7 to Gemini system prompt instructing advisory phrasing for fluctuating weather.

### E. Motorcycle Risk & Rain Probability (`api/internal/decision/decision.go`, `app/lib/departure.dart`)
- Evaluator incorporates rain probability (`ProbPct >= 40%`) into the risk matrix.
- High probability with moderate precipitation flags motorcycle travel with heightened warning and recommends mode switching (`switch_mode`).

---

## 4. Test Coverage & Verification

### Go Test Suite (`api/`)
```powershell
go test ./...
```
- `api/internal/httpapi/dedup_test.go`: Tests deduplication across flights, concerts, all-day events, and venue enrichment.
- `api/internal/httpapi/oauth_test.go`: Tests scope separation for `service=calendar` and `service=gmail`.
- `api/internal/httpapi/google_workspace_test.go`: Tests HTML body stripping and query filters.
- **Status**: 100% passing across all packages.

### Flutter Test Suite (`app/`)
```powershell
flutter test
```
- `app/test/oauth_flow_test.dart`: Tests independent Google Calendar and Gmail linking and URL return stripping.
- `app/test/ask_screen_test.dart`: Tests guardrail refusal bubbles and disclaimers.
- `app/test/summary_screen_test.dart`: Tests event tickets, all-day navigation, and origin switching.
- **Status**: All **181 tests** passing.

---

## 5. Deployment Commands

### Backend (Cloud Run)
```powershell
cd api
.\deploy\cloudrun.ps1
```

### Frontend (Firebase Hosting)
```powershell
cd app
flutter build web --release
firebase deploy --only hosting
```
