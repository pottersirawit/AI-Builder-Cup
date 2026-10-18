# ฝนตกไหม — merged mobile app plan (draft, 2026-10-07)

Status: draft built on Claude's recommended answers. Open questions are listed at the bottom; anything marked (Q#) may change once the team answers.

## Where the two ideas came from

| | Potter (`fontokmai.html`, `architecture.html`) | Saran (Phase 1 commit `5d12102`) |
|---|---|---|
| Core idea | One question: "should I leave now?" for a specific trip. Calendar/Gmail make it proactive. Flood is the severe mode of the same answer. | Proactive flood/weather alerts pushed over LINE, personalised by vehicle clearance. |
| Strongest assets | Hero scenario (มิว, 16:10), plain-Thai verdict, departure-time slider, Gemini-vision flood photo reports shared to people on the same route, confidence on every answer, source label on every card | 70+ BMA flood spot dataset with rain thresholds and vehicle risk, vehicle clearance profiles, ThaiWater canal telemetry client, Google Weather API client, Calendar OAuth + Bangkok landmark geocoding, Go gateway + tests |
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
{"places":[{"id":"home","kind":"home","label_th":"บ้าน","name_th":"บ้านลาดพร้าว","lat":13.816,"lng":100.59},
  {"id":"work","kind":"work","label_th":"ที่ทำงาน","name_th":"สีลม ซอย 3","lat":13.7263,"lng":100.534},
  {"id":"siam","kind":"other","label_th":"สยาม","name_th":"สยาม","lat":13.7456,"lng":100.5341},
  {"id":"thonglor","kind":"other","label_th":"ทองหล่อ","name_th":"ทองหล่อ","lat":13.7243,"lng":100.5853},
  {"id":"impact","kind":"other","label_th":"อิมแพ็ค","name_th":"อิมแพ็ค เมืองทองธานี","lat":13.9119,"lng":100.548}],
 "current_place_id":"work"}
```
*(v1)* `kind` is `home`, `work` or `other`. These are the demo user's places; a real user's places live on the device and are sent with each request (see contract v1 below).

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
 "minutes_to_doorstep":40,"rain_today_mm":68,
 "actions":[{"order":1,"text_th":"…"}],"sources":["ThaiWater (HII) (scenario)","…"]}
```
*(additive)* `summary_th`, `minutes_to_doorstep` (`null` when the canal is not rising toward the house), `rain_today_mm`.

## API contract v1 (additive, 2026-10-08)

Everything in v0 still works unchanged. Places live on the device (`docs/plan/places-and-empty-states.md`); the server stores none and the app sends coordinates with every request. Place objects are `{"name_th","lat","lng"}` like trip ends.

**`POST /v1/decide`** accepts three more optional fields:
```json
{"question_th":"ไปยิมตอนหกโมง",
 "origin":{"name_th":"ตำแหน่งปัจจุบัน","lat":13.7441,"lng":100.5431},
 "destination":{"name_th":"สยามพารากอน","lat":13.746,"lng":100.5347},
 "places":[{"id":"h1","kind":"home","label_th":"บ้าน","name_th":"คอนโดบางนา","lat":13.6681,"lng":100.6046},
           {"id":"g1","kind":"other","label_th":"ยิม","name_th":"ฟิตเนส อารีย์","lat":13.7797,"lng":100.5448}]}
```
- `origin` + `destination` → an app trip: `{"id":"app-b7c3c044fe","title_th":"ไปสยามพารากอน","source":"app","origin":{…},"destination":{…},"mode":"car"}`, no `arrive_by`. The ID is a hash of the coordinates; for slider/mode follow-ups send `trip_id` **and** the same `origin`/`destination` again (an `app-…` ID alone → 400). `name_th` may be omitted (`ตำแหน่งปัจจุบัน` / `ปลายทาง`).
- `origin` alone = where the phone is; it is the start of a trip that `question_th` names.
- `places` = the user's saved places. When present (even `[]`), questions resolve against them instead of the demo list: by `label_th`, `name_th` (without a trailing "(…)"), and for `kind:"home"` บ้าน/home, for `kind:"work"` ที่ทำงาน/ทำงาน/ออฟฟิศ/office/work. `kind` defaults to `other`; each place needs `id`, `lat`, `lng`. A question naming one of them becomes an app trip from `origin`, or without `origin` from work (going home) / home (anywhere else); title `กลับบ้าน` for home, `ไป<label_th>` otherwise. If the place is where an upcoming Calendar/Gmail trip goes within 12 h, that trip is used instead (the demo profile's "กลับบ้าน" at 16:10 is still `cal-dinner`). No origin and no home/work to start from → 400.
- Precedence: `destination` > `trip_id` > a place named in `question_th` > the first trip.
- A question that names somewhere not resolvable (no `trip_id`, no `destination`) → **200** with only:
```json
{"needs_place":{"query_th":"เซ็นทรัลเวิลด์","candidates":[
  {"name_th":"เซ็นทรัลเวิลด์","name_en":"CentralWorld","address_th":"เขตปทุมวัน กรุงเทพมหานคร","lat":13.7466,"lng":100.5393,"source":"local"}]}}
```
  `candidates` are `/v1/places/search` results for `query_th` (may be `[]`). Asking for home or work when `places` has none of that kind ("กลับบ้าน", "ไปทำงาน") → `{"needs_place":{"query_th":"บ้าน","kind":"home","candidates":[]}}` (`kind` is `home` or `work`, present only for this case). After the user picks, re-ask with `destination` set (or with the new place in `places`).
- New 400s: `destination` without `origin`, an `app-…` trip ID without coordinates, a place without `id`/`lat`/`lng`, an unknown `kind`.

**`GET /v1/home-status?lat=&lng=&name_th=`** computes for that point; without `lat`/`lng` it is the demo home as before (`name_th` defaults to `บ้าน`; only one of `lat`/`lng` → 400). Within 300 m of the demo home the scenario profile (doorstep height, parking, sandbag point) still applies, so the demo profile gets the scripted flood mode. Added fields:
```json
{"place":{"name_th":"คอนโดบางนา","lat":13.6681,"lng":100.6046},"in_service_area":true,
 "level":"danger","headline_th":"น้ำท่วมถนนแถวบ้านได้ถึง 26 ซม.",
 "summary_th":"ไม่มีสถานีวัดระดับคลองใกล้บ้าน ประเมินจากฝนและจุดน้ำท่วม กทม. 1 จุดในรัศมี 2 กม. ฝนสะสมวันนี้ 13 มม. ฝนหนักสุด 52 มม./ชม. ใน 2 ชั่วโมงนี้ สุขุมวิท อาจมีน้ำขัง 26 ซม.",
 "canal":null,"minutes_to_doorstep":null,"rain_today_mm":13,"reports_nearby":0,
 "flood_spots":[{"id":"BKK-FL-003","name_th":"ถนนสุขุมวิท ซอยอุดมสุข (สุขุมวิท 103) ถึงแยกบางนา","lat":13.6798,"lng":100.6083,
   "distance_m":1361,"expected_depth_cm":26,"historical_max_depth_cm":30}],
 "actions":[{"order":1,"text_th":"…"}],"sources":["Google Weather API","BMA flood spots","รายงานผู้ใช้"]}
```
- `canal` = nearest station within 3 km (scenario: คลองลาดพร้าว and three others; live: ThaiWater), else `null`. With a canal the levels and wording are v0's; `minutes_to_doorstep` is only known for the demo home.
- Without a canal the level comes from rain (peak from now to +2 h, total since midnight), the BMA flood spots within 2 km and neighbour reports, and `summary_th` says it has no canal station. `flood_spots` (nearest first, at most 5; `expected_depth_cm` at the peak rain) is always a list, possibly empty. `reports_nearby` = reports within 500 m in the last hour.
- `in_service_area` = inside 13.49–14.10 N, 100.30–100.95 E. Outside it the summary says only rain is available.
- `sources` lists the canal source only when a canal was used, and `BMA flood spots` only when a spot is within 2 km.

**`GET /v1/places/search?q=`** (q trimmed, at least 2 characters, else 400) →
```json
{"places":[{"name_th":"สยามพารากอน","name_en":"Siam Paragon","address_th":"เขตปทุมวัน กรุงเทพมหานคร","lat":13.746,"lng":100.5347,"source":"local"}]}
```
Up to 8 results, `[]` when nothing matches. With `GOOGLE_MAPS_API_KEY`: Places API Text Search (New), Thai, region TH, biased to 50 km around Bangkok, `source:"google"`, no `name_en`. Without a key, or when Google fails or finds nothing: the bundled landmark list `data/bkk_landmarks.json` (BTS/MRT/ARL stations, malls, landmarks, the 50 districts, the demo places), `source:"local"`, ranked exact name/keyword > prefix > contains > a known name inside the query > all words match, case/space-insensitive Thai and English.

**`GET /v1/places/reverse?lat=&lng=`** (both required, else 400) →
```json
{"name_th":"ใกล้เซ็นทรัลลาดพร้าว","address_th":"ถ.พหลโยธิน เขตจตุจักร กรุงเทพมหานคร","lat":13.818,"lng":100.564,
 "in_service_area":true,"source":"local","distance_m":312}
```
`lat`/`lng` echo the query (save these, not the landmark's). Google Geocoding (Thai) when a key is set: `name_th` is the most specific named component (place, building, road, แขวง), `address_th` the formatted address, no `distance_m`. Local fallback: the nearest landmark; `name_th` is its name within 150 m, else `ใกล้<name>`; `distance_m` is the distance to it.

## Open questions — see the grilling round in the chat / session summary
