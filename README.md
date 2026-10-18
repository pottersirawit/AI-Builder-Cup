# Fon Tok Mai (ฝนตกไหม)

**Proactive, route-aware rain and flood advisories for Bangkok commuters, powered by a Gemini agent.**

Fon Tok Mai ("Is it raining?") answers one question before the user thinks to ask it: *should I leave now?* A Gemini agent reads the user's upcoming trips from Google Calendar, Gmail e-tickets, or a plain-Thai question, checks forecast rain along the actual route against Bangkok flood-spot thresholds for the user's vehicle, and returns a verdict with a leave-by time, reasons, data sources, and a confidence level. Flooding is treated as the severe mode of the same answer rather than a separate product.

Built for the AI Builder Cup 2026.

| Component | Location |
|---|---|
| Web app | https://ai-cup-511208.web.app |
| API (Cloud Run) | https://fontokmai-api-945826169258.asia-southeast1.run.app |

---

## Key Capabilities

- **Departure verdicts per trip and per travel mode.** Leave now, wait until a given time, switch mode, or do not travel. Sedan, motorcycle, and BTS/MRT verdicts differ because each has a different flood clearance.
- **Calendar- and Gmail-triggered planning.** After the user connects a Google account, upcoming events and e-tickets are geocoded and evaluated automatically. The app also works with nothing connected through a plain-Thai ask bar.
- **Agentic reasoning with numerical guardrails.** Gemini 2.5 Flash on Vertex AI uses function-calling tools (`get_trip`, `get_route`, `get_rain_along_route`, `get_flood_spots_on_route`, `evaluate_departure`). Deterministic risk assessment in Go keeps every number the agent reports verifiable.
- **Home flood mode.** Canal levels from ThaiWater, an ordered action checklist, and neighbour alerts for flood-prone homes.
- **Transparent sources.** Every card shows where its data came from and how confident the system is.

## Data Sources

| Source | Purpose |
|---|---|
| Google WeatherNext 3 (BigQuery) | 5 km hourly forecast grid, cached per 6-hour model run |
| Google Maps Platform (Weather, Routes, Geocoding) | Live conditions, routing, and place resolution |
| ThaiWater Standard API | Rainfall accumulation and canal stage levels |
| BMA flood-prone spots (`data/bkk_flood_risk_points.json`) | 70+ road segments with rain and vehicle-depth thresholds |
| Google Calendar and Gmail | The user's trips, read with the user's own OAuth token |

---

## Architecture

```
Browser / Android / iOS
  Flutter app (app/)
        |
        v
  Go API on Cloud Run (api/)
        |-- Gemini 2.5 Flash on Vertex AI (agent)
        |-- Google Weather, Routes, and Maps APIs
        |-- WeatherNext 3 via BigQuery, ThaiWater telemetry
        `-- Google Calendar and Gmail (per-user OAuth)
```

The web build is served from Firebase Hosting and calls the Cloud Run API directly. Google sign-in runs through `/v1/oauth/start` on the API, which redirects back to the app once the account is connected.

## Repository Layout

```
.
├── app/            Flutter client for Android, iOS, and web
├── api/            Go API: Gemini agent, decision engine, live data, OAuth
│   ├── cmd/server      HTTP server entry point
│   ├── cmd/scorecard   Offline evaluation of agent answers
│   ├── internal/       agent, decision, floodspot, geocode, live, planner, ...
│   └── deploy/         Cloud Run deployment scripts (bash and PowerShell)
├── data/           BMA flood-prone spot dataset
├── gateway/        Phase 1: Go LINE gateway and push dispatcher
├── engine/         Phase 1: Python FastAPI engine and geospatial pipeline
├── simulator/      Phase 1: end-to-end storm and calendar scenarios
├── tests/          Phase 1 test suites
└── docs/           Deployment guide, plans, AI handoff notes, privacy policy
```

---

## Getting Started

### Prerequisites

- Go 1.26 or later (with `GOTOOLCHAIN=auto`, older installs download the required toolchain automatically)
- Flutter 3.35 or later, with `flutter doctor` passing
- Xcode or Android Studio for device simulators (optional; the app runs in Chrome)
- `gcloud` and `firebase-tools` for deployment only

### Run the app against the hosted API

The app targets the deployed Cloud Run API by default, so no local backend is required.

```bash
cd app
flutter pub get
flutter run -d chrome --dart-define=DEMO_CLOCK=16:10
```

`DEMO_CLOCK` replays the scripted 29 September 2026 storm scenario. Omit it to use the real clock.

### Run the API locally

The API runs in demo mode with no keys or network access required.

```bash
cd api
go run ./cmd/server   # listens on :8080
```

Then point the app at it:

```bash
cd app
flutter run -d chrome  --dart-define=API_BASE_URL=http://localhost:8080
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Example requests and the full endpoint list are in [`api/README.md`](api/README.md).

### Demo clock

Tap the clock chip in the top-left corner of the app, pass `--dart-define=DEMO_CLOCK=HH:MM`, or send an `X-Demo-Clock` header to the API.

| Time | Scene |
|---|---|
| 16:10 | Calendar-triggered alert: leave before 16:45 |
| 18:52 | Peak storm commute advisory |
| 21:40 | Home flood mode |
| live | Real time and live data |

### Tests

```bash
cd api && go vet ./... && go test ./...
cd app && flutter analyze && flutter test
```

---

## Configuration

Key API environment variables:

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | HTTP port |
| `DEMO_MODE` | `1` | `1` replays the demo scenario; `0` uses the real clock and live data |
| `GEMINI_MODEL` | `gemini-2.5-flash` | Model used by the agent |
| `GEMINI_API_KEY` | none | AI Studio key for local runs; Cloud Run uses Vertex AI through its service account instead |
| `GOOGLE_MAPS_API_KEY` | none | Optional; enables live Weather and Routes calls |
| `REPORT_STORE` | `memory` | Set to `firestore` to persist flood reports |

The complete list is in [`api/README.md`](api/README.md). Phase 1 services read their settings from `.env` (copy `.env.example`).

## Deployment

The API deploys to Cloud Run in `asia-southeast1` and the web build to Firebase Hosting. Always deploy the API before the web app, because new web builds call endpoints that older API revisions do not serve.

```bash
PROJECT=ai-cup-511208 api/deploy/cloudrun.sh
(cd app && flutter build web --release)
firebase deploy --only hosting
```

See [`docs/DEPLOY.md`](docs/DEPLOY.md) for the current deployment state, required secrets, OAuth setup, rollback, and known pitfalls.

---

## Phase 1: LINE Channel

The `gateway/` and `engine/` directories contain the original LINE-based delivery channel: a Go gateway that builds LINE Flex Messages and dispatches push notifications through a goroutine worker pool, and a Python FastAPI engine that performs geospatial matching against flood-prone spots.

```bash
# End-to-end storm and calendar simulations
./venv/bin/python simulator/run_simulation.py
./venv/bin/python simulator/run_calendar_simulation.py

# Go gateway on :8080
cd gateway && go run ./cmd/server

# Python engine on :8000 (Swagger UI at /docs)
./venv/bin/uvicorn engine.main:app --host 0.0.0.0 --port 8000 --reload

# Full stack: PostgreSQL (PostGIS), Redis, gateway, and engine
docker compose up --build
```

---

## Documentation

| Document | Contents |
|---|---|
| [`RUNNING.md`](RUNNING.md) | Detailed run instructions (Thai) |
| [`docs/DEPLOY.md`](docs/DEPLOY.md) | Deployment guide and live configuration |
| [`api/README.md`](api/README.md) | API endpoints, environment variables, agent scorecard |
| [`app/README.md`](app/README.md) | Flutter app structure |
| [`docs/plan/merged-flow.md`](docs/plan/merged-flow.md) | Product flow and API contract |
| [`docs/ai/HANDOFF.md`](docs/ai/HANDOFF.md) | Gemini agent design notes |
| [`CONTEXT.md`](CONTEXT.md) | Domain glossary |
| [`PRODUCT.md`](PRODUCT.md) and [`DESIGN.md`](DESIGN.md) | Product principles and design system |
| [`docs/PRIVACY.md`](docs/PRIVACY.md) | Privacy policy |

All scenario figures in the demo (the persona, notification counts, confidence values) are synthetic and are labelled as such in the app.
