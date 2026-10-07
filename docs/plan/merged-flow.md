# ฝนตกไหม — merged mobile app plan (draft, 2026-10-07)

Status: draft built on Claude's recommended answers. Open questions are listed at the bottom; anything marked (Q#) may change once the team answers.

## Where the two ideas came from

| | Potter (`fontokmai.html`, `architecture.html`) | Saran (Phase 1 commit `5d12102`) |
|---|---|---|
| Core idea | One question: "should I leave now?" for a specific trip. Calendar/Gmail make it proactive. Flood is the severe mode of the same answer. | Proactive flood/weather alerts pushed over LINE, personalised by vehicle clearance. |
| Strongest assets | Hero scenario (พลอย, 16:10), plain-Thai verdict, departure-time slider, Gemini-vision flood photo reports shared to people on the same route, confidence on every answer, source label on every card | 70+ BMA flood spot dataset with rain thresholds and vehicle risk, vehicle clearance profiles, ThaiWater canal telemetry client, Google Weather API client, Calendar OAuth + Bangkok landmark geocoding, Go gateway + tests |
| Channel | Mobile app mock (HTML) | LINE bot + LIFF |

## Merged product in one sentence

"แชทตอบคำถาม — ฝนตกไหมตอบก่อนที่คุณจะถาม": a Flutter app whose Gemini agent watches your upcoming trips (Calendar, Gmail tickets, or typed in Thai), checks rain along the actual route against Saran's flood-spot thresholds for *your vehicle*, and tells you when and how to leave — with reasons, sources and a confidence score. People caught in flooding post a photo; Gemini vision estimates depth and warns everyone whose route passes there.

## Demo flow (3-minute video = 5 beats)

1. **16:10 push notification** (proactive): "ออกก่อน 16:45 ทันนัดกินข้าวที่บ้าน" — triggered by Calendar event 18:30.
2. **Verdict screen**: rain timeline on route, departure slider, mode toggle (car / BTS-MRT / motorbike — Saran's clearance profiles drive the different verdicts), "Gemini คิดแบบนี้" reasoning trace showing tool calls, source chips.
3. **Ask in Thai**: "ถ้ารอถึงสองทุ่มล่ะ" — agent re-plans (works with no Calendar connected).
4. **Flood photo report** 18:52: camera → Gemini vision → depth 20–25 cm, 84% → fan-out to N users whose route crosses the spot.
5. **Flood mode** 21:40 at home: canal level from ThaiWater, ordered action checklist, neighbours alerted (LINE push from Saran's dispatcher as the "reach people without the app" channel).

A **demo clock** (server-side scenario replay) makes beats 1–5 reproducible on camera regardless of real weather; live mode uses real APIs.

## Architecture

```
Flutter app (app/)  ──HTTPS/JSON──▶  Go API on Cloud Run (api/)
                                       ├─ Gemini agent (function calling, google.golang.org/genai)
                                       │    tools: get_trip, get_route, get_rain_along_route,
                                       │           get_flood_spots_on_route, get_canal_levels,
                                       │           get_community_reports
                                       ├─ Gemini vision: assess flood photo
                                       ├─ data: data/bkk_flood_risk_points.json (Saran)
                                       ├─ providers: Google Weather API, Routes API, ThaiWater
                                       │             — each with a scenario/mock implementation
                                       └─ Firestore (reports, users) — in-memory in dev
Saran's gateway/ + engine/ stay as-is (LINE channel), not on the critical path (Q3).
```

Why one Go service: one Cloud Run deploy, one language for the backend as the team asked, and the Python engine's logic that we need (haversine flood matching, fallback advisory) is small enough to port.

## API contract v0 (both sides build against this)

All JSON, Thai strings in `*_th` fields, times RFC 3339 in Bangkok time (`+07:00`). Header `X-Demo-Clock: 2026-09-29T16:10:00+07:00` (or bare `HH:MM` on the demo day) optional; when present the server replays the scenario at that time. With `DEMO_MODE=1` (default) a request without the header replays 16:10; with `DEMO_MODE=0` it uses the real clock and live providers. Errors are `{"error":"…"}` with 400 (bad input), 404 (unknown trip) or 502 (provider failure). CORS is open.

Fields marked *(additive)* were added after v0 was agreed; v0 clients can ignore them.

`GET /healthz` → `{"ok":true}`

`GET /v1/trips` → upcoming trips for the demo user, relative to the request clock (live mode: today's dinner; it rolls to tomorrow after 21:30). The concert is the next Saturday 19:00.
```json
{"trips":[{"id":"cal-dinner","title_th":"กินข้าวเย็นกับที่บ้าน","source":"calendar",
  "origin":{"name_th":"สีลม ซอย 3","lat":13.7263,"lng":100.5340},
  "destination":{"name_th":"บ้านลาดพร้าว","lat":13.8160,"lng":100.5900},
  "arrive_by":"2026-09-29T18:30:00+07:00","mode":"car"},
 {"id":"gmail-concert","title_th":"คอนเสิร์ตที่อิมแพ็ค","source":"gmail", "…":"…"}]}
```
`source` is `calendar`, `gmail` or `question` (a trip typed as a question, see below). `arrive_by` is omitted when the trip has no deadline.

`GET /v1/places` *(additive)* → the user's saved places a question can name, and where they are now (origin of a typed trip: the Silom office on weekdays 08:00–19:00, home otherwise)
```json
{"places":[{"id":"home","label_th":"บ้าน","name_th":"บ้านลาดพร้าว","lat":13.816,"lng":100.59},
  {"id":"work","label_th":"ที่ทำงาน","name_th":"สีลม ซอย 3","lat":13.7263,"lng":100.534},
  {"id":"siam","label_th":"สยาม","name_th":"สยาม","lat":13.7456,"lng":100.5341},
  {"id":"thonglor","label_th":"ทองหล่อ","name_th":"ทองหล่อ","lat":13.7243,"lng":100.5853},
  {"id":"impact","label_th":"อิมแพ็ค","name_th":"อิมแพ็ค เมืองทองธานี","lat":13.9119,"lng":100.548}],
 "current_place_id":"work"}
```

`POST /v1/decide` body (all fields optional) `{"trip_id":"cal-dinner","depart_at":"… or HH:MM","mode":"car|transit|moto","question_th":"ถ้ารอถึงสองทุ่มค่อยกลับล่ะ"}`
- No `trip_id`: the first trip, unless `question_th` names a saved place ("ไปสยามตอนหกโมงดีไหม"). Then the server uses an upcoming Calendar/Gmail trip to that place within 12 hours ("กลับบ้าน" at 16:10 = `cal-dinner`), or plans a typed trip `adhoc-<place id>` from the current place, by car, with no deadline. Gemini parses the destination when available; Thai keywords otherwise.
- With `trip_id` (including `adhoc-siam` sent back by the app when the slider moves) the question only changes time and mode.
```json
{"verdict":"leave_now|wait|switch_mode|dont_go",
 "headline_th":"ออกก่อน 16:45","summary_th":"…","leave_by":"2026-09-29T16:45:00+07:00",
 "confidence":0.78,
 "rain_timeline":[{"time":"…","mm_per_hr":2.1}],
 "mode_options":[{"mode":"car","verdict":"leave_now","eta_min":50,"risk":"low|medium|high","note_th":"…"}],
 "flood_spots":[{"id":"BKK-FL-001","name_th":"…","lat":0,"lng":0,"expected_depth_cm":15,"risk":"high"}],
 "reasoning":[{"tool":"parse_question|parse_question_fallback|get_trip|get_route|get_rain_along_route|get_flood_spots_on_route|get_canal_levels|get_community_reports|evaluate_departure","summary_th":"ฝนถึงพระราม 4 ราว 17:30"}],
 "sources":["Google Weather API","Google Routes API","ThaiWater (HII)","BMA flood spots"],
 "generated_by":"gemini|fallback",
 "depart_at":"2026-09-29T16:10:00+07:00",
 "mode":"car",
 "trip":{"id":"adhoc-siam","title_th":"ไปสยาม","source":"question","origin":{"name_th":"สีลม ซอย 3","lat":13.7263,"lng":100.534},"destination":{"name_th":"สยาม","lat":13.7456,"lng":100.5341},"mode":"car"}}
```
*(additive)* `depart_at` and `mode` are what was actually evaluated (after parsing the question), so the app can move its slider and mode toggle; `trip` is the trip actually decided, same shape as `/v1/trips`. `leave_by` may be `null`. `reasoning` lists each tool call once, in order; it starts with the parse step when a question was asked. Source names end with ` (scenario)` when the scenario replaced a live provider.

`POST /v1/reports` multipart `photo`, `lat`, `lng` → **HTTP 201**
```json
{"id":"r1","lat":13.813,"lng":100.576,"created_at":"2026-09-29T18:52:00+07:00",
 "depth_cm_min":20,"depth_cm_max":25,"confidence":0.84,"description_th":"…",
 "passable":{"car":"slow","transit":"yes","moto":"no"},"generated_by":"gemini|fallback",
 "notified_users":27,"corroborating_reports":2}
```
*(additive)* `lat`, `lng`, `created_at`, `generated_by`. `id` is `r<n>` in memory and a Firestore document ID when `REPORT_STORE=firestore`.

`GET /v1/reports?lat=&lng=&radius_m=` → `{"reports":[…]}` — each report has the fields above except `notified_users` and `corroborating_reports`; reports from the last 24 hours of the request clock, oldest first. Without `lat`/`lng`: all of Bangkok; with them, `radius_m` defaults to 1000.

`GET /v1/home-status` → flood mode payload:
```json
{"level":"normal|watch|danger","headline_th":"น้ำจะถึงหน้าบ้านใน 40 นาที","summary_th":"…",
 "canal":{"name_th":"คลองลาดพร้าว","level_m":1.8,"bank_m":1.8,"rise_cm_2h":40},
 "minutes_to_doorstep":40,"rain_today_mm":68,"reports_nearby":11,
 "actions":[{"order":1,"text_th":"…"}],"sources":["ThaiWater (HII) (scenario)","…"]}
```
*(additive)* `summary_th`, `minutes_to_doorstep` (`null` when the canal is not rising toward the house), `rain_today_mm`, `reports_nearby`.

## Open questions — see the grilling round in the chat / session summary
