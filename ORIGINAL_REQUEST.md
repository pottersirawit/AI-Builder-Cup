# Original User Request

## 2026-09-25T15:41:03Z

Implement the complete Phase 1 deliverables (Tickets 01 through 06) for the Bangkok Weather Resilience and Proactive Disaster Preparedness System, connecting the Go Gateway, LINE Messaging API (Theme 1: Apple Spatial Weather), Python AI Engine, and Docker Compose orchestration.

Working directory: /Users/saransirichote/Desktop/playground/Weather
Integrity mode: development

Reference material:
- Domain Glossary: CONTEXT.md
- Tickets: .scratch/phase1-line-gateway/issues/01-line-webhook-receiver.md through 06-google-calendar-oauth-live-ai.md
- Strategic Plan: strategic_implementation_plan.md

## Requirements

### R1. LINE Webhook Receiver & HMAC-SHA256 Signature Verification
Implement an HTTP POST /webhook/line endpoint in the Go Gateway. Incoming requests must be verified against LINE_CHANNEL_SECRET using HMAC-SHA256 comparison of the X-Line-Signature header. Requests with invalid or missing signatures must return HTTP 401 Unauthorized; valid requests must return HTTP 200 OK and parse the event stream into internal typed structures.

### R2. Apple Spatial Weather Flex Message & Quick Reply Builder
Implement a builder in the Go Gateway that constructs LINE Flex Message Bubbles, Carousels, and Quick Reply actions matching Theme 1: Apple Spatial Weather (dark frosted visual hierarchy, status urgency tags, bento telemetry tiles for rain rate, canal stage, heat index, and wind gusts, vehicle clearance alerts, and deep-link CTA buttons).

### R3. Thai NLP Intent Router & Dispatcher
Implement conversational intent matching for incoming Thai user messages (including "อากาศ", "สภาพอากาศ", "น้ำท่วม", "จุดเสี่ยง", "นัดหมาย", "ปฏิทิน", "รถเก๋ง", "มอเตอร์ไซค์"). The router queries the Python AI Engine or local telemetry cache, formats the response using the Apple Spatial Flex builder, and dispatches the reply using the LINE Messaging API.

### R4. LIFF Deep Linking & Query Parameter Synchronization
Enhance the LINE LIFF Web App (gateway/static/liff/index.html) to parse query parameters (tab=dashboard|calendar|profile, vehicle=sedan|moto|pickup|transit) on load, automatically switching tabs, focusing relevant hazard cards, and syncing selected vehicle parameters.

### R5. Multi-Stage Docker Compose Containerization
Create multi-stage Dockerfiles for the Go Gateway (producing a minimal alpine/scratch binary) and Python AI Engine, along with a docker-compose.yml orchestrating Go Gateway (port 8080), Python Engine (port 8000), and a Redis cache instance for 5-minute radar telemetry and user sessions.

### R6. Google Calendar OAuth & Landmark Geocoding Integration
Implement the Google Calendar integration enabling user calendar event ingestion, landmark coordinate matching in Bangkok, and proactive schedule shift recommendations using Gemini 1.5 with deterministic fallback.

## Acceptance Criteria

### Automated Verification
- [ ] cd gateway && go test -v ./... passes with 100% test success on webhook verification and flex message generation.
- [ ] Table-driven tests verify valid signatures, invalid signatures, missing signature headers, and malformed request bodies with appropriate HTTP status codes.
- [ ] Flex message generator produces valid JSON matching the LINE Flex container schema.
- [ ] Python test suites pass: venv/bin/python tests/test_runner.py and venv/bin/python tests/test_calendar.py.
- [ ] docker compose config validates without syntax or port binding errors.
- [ ] docker compose build succeeds for both Go Gateway and Python AI Engine services.
- [ ] End-to-end simulation script confirms that simulated LINE webhook calls trigger proper intent routing and generate expected reply payloads.
