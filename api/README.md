# ฝนตกไหม API (Go)

Backend ของแอปมือถือ "ฝนตกไหม" ทำตาม API contract v0 + v1 (เพิ่มอย่างเดียว) ใน `docs/plan/merged-flow.md`
Go stdlib `net/http` ล้วน ไม่มี framework, Gemini ผ่าน `google.golang.org/genai`

## รันเครื่องตัวเอง

```bash
cd api
go run ./cmd/server            # ฟังที่ :8080, โหมดเดโม (นาฬิกาเริ่ม 16:10 วันที่ 29 ก.ย. 2026)
go test ./... && go vet ./...  # ไม่ต้องใช้เน็ตหรือ key
```

ลองยิง:

```bash
curl localhost:8080/healthz
curl localhost:8080/v1/trips
curl localhost:8080/v1/places
curl -X POST localhost:8080/v1/decide -d '{"question_th":"ไปสยามตอนหกโมงดีไหม"}'   # ไม่ส่ง trip_id → วางทริปไปสยามจากที่อยู่ตอนนี้
curl -X POST localhost:8080/v1/decide -H 'X-Demo-Clock: 2026-09-29T16:10:00+07:00' -d '{"trip_id":"cal-dinner"}'
curl -X POST localhost:8080/v1/decide -d '{"trip_id":"cal-dinner","question_th":"ถ้ารอถึงสองทุ่มค่อยกลับล่ะ"}'
curl -X POST localhost:8080/v1/decide -d '{"trip_id":"cal-dinner","depart_at":"2026-09-29T17:15:00+07:00","mode":"moto"}'
curl -X POST localhost:8080/v1/reports -H 'X-Demo-Clock: 2026-09-29T18:52:00+07:00' -F photo=@flood.jpg -F lat=13.8130 -F lng=100.5760
curl 'localhost:8080/v1/reports?lat=13.8130&lng=100.5760&radius_m=300' -H 'X-Demo-Clock: 2026-09-29T18:55:00+07:00'
curl localhost:8080/v1/home-status -H 'X-Demo-Clock: 2026-09-29T21:40:00+07:00'

# contract v1: สถานที่ของผู้ใช้อยู่ในเครื่อง แอปส่งพิกัดมาทุกครั้ง
curl -X POST localhost:8080/v1/decide -d '{"origin":{"lat":13.7441,"lng":100.5431},"destination":{"name_th":"สยามพารากอน","lat":13.746,"lng":100.5347}}'
curl -X POST localhost:8080/v1/decide -d '{"question_th":"กลับบ้านตอนหกโมง","origin":{"lat":13.7441,"lng":100.5431},"places":[{"id":"h1","kind":"home","label_th":"บ้าน","name_th":"คอนโดบางนา","lat":13.6681,"lng":100.6046}]}'
curl -X POST localhost:8080/v1/decide -d '{"question_th":"ไปไอคอนสยามตอนหกโมง","places":[]}'   # → {"needs_place":{...}}
curl 'localhost:8080/v1/home-status?lat=13.6681&lng=100.6046&name_th=คอนโดบางนา' -H 'X-Demo-Clock: 18:15'
curl 'localhost:8080/v1/places/search?q=พารากอน'
curl 'localhost:8080/v1/places/reverse?lat=13.7441&lng=100.5431'
```

`X-Demo-Clock` รับ RFC 3339 หรือ `HH:MM` สั้น ๆ (ตีความเป็นวันที่ 29 ก.ย. 2026)

## Scorecard ของ agent (`cmd/scorecard`)

ให้ agent ตัดสิน 19 เคสของพายุ 29 ก.ย. (เวลา demo 16:10, 17:15, 18:00, 18:55, 19:30 × รถยนต์/รถไฟฟ้า/มอเตอร์ไซค์ + คำถามภาษาไทย 4 ข้อ) แล้วตรวจทุกคำตอบเทียบกับแกน deterministic:

| check | ตรวจอะไร |
|---|---|
| `valid_verdict` | verdict เป็นหนึ่งในสี่ค่า |
| `safe_for_mode` | ไม่บอก `leave_now` ในโหมดที่แกนประเมินว่าเสี่ยงสูง |
| `matches_demo_script` | ตรงกับ verdict ที่วิดีโอ demo ใช้ (16:10 รถยนต์, 17:15 มอไซค์, 18:55 รถยนต์) |
| `agrees_with_core` | verdict เดียวกับแกนคำนวณ |
| `required_tools` | เรียก `get_trip`, `get_rain_along_route`, `get_flood_spots_on_route`, `evaluate_departure` ครบ |
| `grounded_times` | ทุกเวลา HH:MM ใน headline/summary/explanation มาจากข้อมูลของ tools (กันเวลาที่ Gemini แต่งขึ้น) |
| `headline_length` | headline ไม่เกิน 30 ตัวอักษร |
| `explanation_complete` | มี `reason_why_th` และ `factors_th` |

```bash
go run ./cmd/scorecard                     # ไม่มี key: ตรวจ fallback แบบ offline (ควรผ่าน 19/19)
go run ./cmd/scorecard -strict             # exit 1 ถ้ามีเคสไม่ผ่าน (ใช้ใน CI ได้)
GEMINI_API_KEY=... go run ./cmd/scorecard -judge -json score.json   # agent จริง + Gemini ให้คะแนนภาษาไทย 1-5 (เรียก API ราว 4-6 ครั้งต่อเคส มีค่าใช้จ่าย)
go run ./cmd/scorecard -case 16:10         # เฉพาะเคสที่ชื่อมีคำนี้
```

ผลออกเป็นตาราง Markdown (เอาไปใส่ proposal/วิดีโอได้) ส่วน `-json` เก็บรายละเอียดทุกเคสพร้อม latency และคะแนน judge; judge เป็นข้อมูลประกอบ ไม่ทำให้เคสตก

## Environment variables

| ตัวแปร | ค่าเริ่มต้น | ใช้ทำอะไร |
|---|---|---|
| `PORT` | `8080` | พอร์ต (Cloud Run ตั้งให้เอง) |
| `DEMO_MODE` | `1` | `1` = ถ้าไม่มี header ใช้นาฬิกาเดโม 16:10 + ข้อมูล scenario; `0` = นาฬิกาจริง + provider จริง |
| `FLOOD_POINTS_PATH` (หรือ flag `-flood-points`) | หา `data/…`, `../data/…`, `/app/data/…` ตามลำดับ | ไฟล์จุดน้ำท่วม กทม. `data/bkk_flood_risk_points.json` |
| `LANDMARKS_PATH` (หรือ flag `-landmarks`) | หาแบบเดียวกัน | รายชื่อสถานที่ กทม. ในเครื่อง `data/bkk_landmarks.json` สำหรับค้นหา/reverse เมื่อไม่มี key หรือ Google ล่ม |
| `GEMINI_API_KEY` | ว่าง | ใช้ Gemini API (AI Studio) |
| `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION` | ว่าง, `us-central1` | ใช้ Vertex AI แทน (ADC / service account ของ Cloud Run) เมื่อไม่มี `GEMINI_API_KEY` |
| `GEMINI_MODEL` | `gemini-2.5-flash` | โมเดลของ agent, ตัวแยกคำถาม และ vision |
| `GOOGLE_MAPS_API_KEY` | ว่าง | Google Weather API (`forecast/hours:lookup`) + Routes API (`computeRoutes`) ในโหมด live และ Places API (New) Text Search + Geocoding API สำหรับ `/v1/places/search`, `/v1/places/reverse` (ทุกโหมด) ต้องเปิด API เหล่านี้ใน project ของ key |
| `REPORT_STORE` | `memory` | `firestore` = เก็บรายงานใน Firestore (ใช้ `GOOGLE_CLOUD_PROJECT` หรือ project ที่ detect ได้บน Cloud Run, ADC) ตอนเริ่มจะ seed รายงานของ scenario ด้วย ID คงที่ จึงไม่ซ้ำเมื่อรีสตาร์ท |
| `FIRESTORE_COLLECTION` | `reports` | ชื่อ collection เมื่อ `REPORT_STORE=firestore` |
| `THAIWATER_URL` | `https://api-v3.thaiwater.net/api/v1/thaiwater30/public/waterlevel_load` | ฟีดระดับน้ำ ThaiWater (public, ไม่ต้องใช้ key) |

ไม่มี key ไหนก็ยังรันได้: Gemini ไม่มี → `generated_by: "fallback"`; provider จริงล่ม → ใช้ scenario แทน (ชื่อ source จะมี `(scenario)` ต่อท้าย); ค้นหาสถานที่ไม่มี key หรือ Google ล่ม/ไม่เจอ → รายชื่อในเครื่อง (`source: "local"`)

## Docker

build จาก root ของ repo เพราะต้องก๊อปไฟล์ `data/`

```bash
docker build -f api/Dockerfile -t fontokmai-api .
docker run -p 8080:8080 -e GEMINI_API_KEY=... fontokmai-api
```

## Deploy ขึ้น Cloud Run

ใช้ `api/deploy/cloudrun.sh` (region `asia-southeast1`, `--allow-unauthenticated`, key Gemini มาจาก Secret Manager ไม่อยู่ใน env ตรง ๆ)

```bash
gcloud auth login && gcloud config set project $PROJECT
# ครั้งแรก: เก็บ Gemini key เป็น secret
printf '%s' "$GEMINI_API_KEY" | gcloud secrets create GEMINI_API_KEY --data-file=- --project $PROJECT

PROJECT=$PROJECT api/deploy/cloudrun.sh                         # build ด้วย Cloud Build จาก source (ค่าเริ่มต้น)
PROJECT=$PROJECT BUILD=docker api/deploy/cloudrun.sh            # build เครื่องตัวเอง แล้ว push เข้า Artifact Registry
PROJECT=$PROJECT REPORT_STORE=firestore api/deploy/cloudrun.sh  # เก็บรายงานใน Firestore
```

สคริปต์ทำให้เองแบบรันซ้ำได้: เปิด API ที่ต้องใช้, ให้ service account ของ Cloud Run อ่าน secret ได้, สร้าง Artifact Registry repo (โหมด docker), สร้าง Firestore database และให้สิทธิ์ `roles/datastore.user` (เมื่อ `REPORT_STORE=firestore`)

ตัวแปรที่ปรับได้: `SERVICE` (`fontokmai-api`), `REGION`, `BUILD` (`source`|`docker`), `DEMO_MODE` (`1`), `REPORT_STORE`, `GEMINI_MODEL`, `GEMINI_SECRET` (`GEMINI_API_KEY`), `GOOGLE_MAPS_SECRET` (ชื่อ secret ที่เก็บ Google Maps key ถ้าจะเปิดโหมด live), `RUNTIME_SA`

โหมด `source` คัดลอกเฉพาะ `api/`, `data/bkk_flood_risk_points.json`, `data/bkk_landmarks.json` และ Dockerfile ไปไว้ในโฟลเดอร์ชั่วคราวก่อนส่งขึ้น Cloud Build เพื่อไม่ต้องอัปโหลดทั้ง repo (เช่นแอป Flutter)

## โครงสร้าง (deep modules)

| package | หน้าที่ |
|---|---|
| `internal/domain` | ศัพท์กลาง (Trip, Route, RainSample, Report, Mode, SavedPlace + kind home/work/other) และ seam: `WeatherProvider`, `RouteProvider`, `CanalProvider`, `ReportStore`, `Clock` |
| `internal/scenario` | สคริปต์เดโมของมิว: ฝนถึงพระราม 4 ~17:30, หนักสุด 18:00–18:45, ซา 19:15, น้ำรอระบายถึง ~20:00, ฝนรอบสอง 21:00; คลองลาดพร้าว 1.4 → 1.8 ม. (19:40–21:40); รายงานผู้ใช้ตั้งต้น; ผู้ใช้จำลอง 60 คน (27 คนผ่านรัชดา–ลาดพร้าว 32) |
| `internal/live` | Google Weather, Routes API, ThaiWater และ wrapper ที่ถอยไปใช้ scenario เมื่อ error |
| `internal/decision` | **แกนตัดสินใจแบบ deterministic** ฝนบนเส้นทาง × เกณฑ์ฝนของจุดน้ำท่วม (โมเดลความลึกพอร์ตจาก `flood_matcher.py` + ระบายน้ำ 2 ชม.) × ความสูงใต้ท้องรถ (เก๋ง 15 ซม., มอไซค์ 10 ซม./ฝน ≥10 มม./ชม., รถไฟฟ้าไม่กระทบ) → verdict ต่อโหมด, `leave_by`, confidence, ข้อความไทย fallback |
| `internal/planner` | รวบรวมข้อมูลจาก provider ต่อหนึ่งคำขอ, เปิด session จากคำขอ (`Open`: พิกัดจากแอป → ทริป `app-<hash>`, `trip_id`, หรือทริปแรก), วางทริปไปสถานที่ที่บันทึกไว้ของเดโมหรือของผู้ใช้ (`TripTo`, `PlanTo`) และเป็นกล่องเครื่องมือของ agent: `get_trip`, `get_route`, `get_rain_along_route`, `get_flood_spots_on_route`, `get_canal_levels`, `get_community_reports`, `evaluate_departure` |
| `internal/agent` | Gemini function-calling agent (ตัดสิน + เขียนเหตุผลภาษาไทย), ตัวแยกคำถามภาษาไทย (Gemini structured output / regex fallback เช่น "สองทุ่ม" = 20:00, "BTS" → transit, "มอไซค์" → moto, ปลายทางที่พิมพ์ "ไปกินข้าวแถวสุขุมวิท 55" → "สุขุมวิท 55"), ตรวจ `origin`/`destination`/`places` ของคำขอ และตอบ `NeedsPlace` เมื่อคำถามระบุที่ที่ไม่รู้จัก |
| `internal/agenteval` | Scorecard ของ agent: เคส demo, check เทียบแกน deterministic, Gemini judge (structured output) และรายงาน Markdown/JSON ใช้โดย `cmd/scorecard` |
| `internal/vision` | Gemini vision ประเมินรูปน้ำท่วม (JSON schema) + ตรวจค่าผิดปกติ, fallback = ค่ารูปของมิว 20–25 ซม. 84% |
| `internal/homestatus` | โหมดน้ำท่วมที่บ้าน ณ จุดใดก็ได้: สถานีคลองที่ใกล้สุดในรัศมี 3 กม. (ระดับเทียบตลิ่ง, อัตราขึ้น, เวลาที่น้ำถึงหน้าบ้านเมื่อรู้ความสูงหน้าบ้าน) หรือถ้าไม่มี ประเมินจากฝน + จุดน้ำท่วม กทม. ในรัศมี 2 กม. + รายงานผู้ใช้ แล้วบอกตรง ๆ ว่าไม่มีข้อมูลคลอง, รายการสิ่งที่ต้องทำเรียงลำดับ |
| `internal/geocode` | ค้นหาสถานที่และ reverse geocode: Google Places Text Search (New) / Geocoding (ภาษาไทย, bias กรุงเทพฯ) และ fallback รายชื่อในเครื่อง (จัดอันดับตรงชื่อ/คำค้น > ขึ้นต้น > มีอยู่ใน > ชื่อที่รู้จักอยู่ในคำค้น > ทุกคำตรง; reverse = สถานที่ใกล้สุด + ระยะ) |
| `internal/reports` | ReportStore ในหน่วยความจำ (ค่าเริ่มต้น) หรือ Firestore (`REPORT_STORE=firestore`) รายงานโผล่ตามนาฬิกาเดโม + นับคนที่เส้นทางผ่านในรัศมี 300 ม. |
| `internal/httpapi` | handlers, CORS เปิด, เลือก scenario/live ต่อคำขอตาม `X-Demo-Clock` |

### Gemini ทำงานอย่างไรใน `/v1/decide`

1. ถ้ามี `question_th` → Gemini แปลงเป็น `depart_at`/`mode`/ปลายทาง (หรือ regex + keyword ถ้าไม่มี Gemini) และบันทึกเป็นขั้น `parse_question` ใน `reasoning`
   - ถ้าไม่ส่ง `trip_id` และคำถามระบุปลายทางเป็นสถานที่ที่บันทึกไว้ (บ้าน, ที่ทำงาน, สยาม, ทองหล่อ, อิมแพ็ค) → ใช้ทริปจาก Calendar/Gmail ที่ไปที่นั่นภายใน 12 ชม. ถ้ามี (เช่น "กลับบ้าน" = นัดกินข้าว 18:30) ไม่งั้นสร้างทริป `adhoc-<place>` จากที่อยู่ตอนนี้ (ที่ทำงานสีลม วันธรรมดา 08:00–19:00, นอกนั้นบ้าน) ไม่มีเวลานัด
   - ส่ง `trip_id` มา → ใช้ทริปนั้นเสมอ (`adhoc-siam` ก็ส่งกลับมาได้ เวลาเลื่อน slider)
   - ส่ง `places` มา → จับคู่กับสถานที่ของผู้ใช้แทนของเดโม แล้ววางทริป `app-<hash>` จาก `origin` (หรือจากที่ทำงาน/บ้านถ้าไม่ส่ง `origin`); ส่ง `origin` + `destination` มา → ใช้พิกัดนั้นตรง ๆ ไม่ต้องตีความปลายทาง
   - คำถามระบุที่ที่ไม่รู้จัก ("ไปไอคอนสยาม") หรือถามถึงบ้าน/ที่ทำงานที่ยังไม่ได้ตั้ง → ตอบ 200 `{"needs_place":…}` พร้อมผลค้นหา แทน verdict
2. agent ได้เครื่องมือ 7 ตัว เรียกเองตามต้องการ (สูงสุด 8 รอบ) แล้วตอบ verdict + headline + summary ภาษาไทย
3. ตัวเลข (`rain_timeline`, `mode_options`, `flood_spots`) มาจากแกน deterministic เสมอ; ถ้า agent บอก `leave_now` ในโหมดที่แกนประเมินว่าเสี่ยงสูง ระบบใช้คำตอบของแกนแทน (guardrail)
4. `reasoning` = รายการเครื่องมือที่ถูกเรียกจริงตามลำดับ (fallback ก็เรียกเครื่องมือชุดเดียวกันตามลำดับตายตัว; ถ้า Gemini ล่มกลางทาง trace ของ agent จะถูกล้างก่อน fallback จึงไม่มีขั้นซ้ำ)

### ส่วนที่ต่างจาก contract v0 เล็กน้อย (เพิ่ม field เท่านั้น)

- `/v1/decide` เพิ่ม `depart_at`, `mode` และ `trip` ที่ใช้คำนวณจริง (ให้แอปเลื่อน slider และแสดงปลายทางตามคำถาม)
- `GET /v1/places` ใหม่: สถานที่ที่บันทึกไว้ + `current_place_id`
- `/v1/reports` POST คืน `lat`, `lng`, `created_at`, `generated_by` เพิ่ม; ตอบ HTTP 201
- `/v1/home-status` เพิ่ม `summary_th`, `minutes_to_doorstep`, `rain_today_mm`, `reports_nearby`
- contract v1 (ดูรายละเอียดใน `docs/plan/merged-flow.md`): `/v1/decide` รับ `origin`, `destination`, `places` และอาจตอบ `{"needs_place":…}`; `/v1/home-status?lat=&lng=&name_th=` เพิ่ม `place`, `in_service_area`, `flood_spots` และ `canal` เป็น `null` ได้; `GET /v1/places/search`, `GET /v1/places/reverse` ใหม่; `/v1/places` มี `kind`
- `/v1/trips` มีทริปที่สอง `gmail-concert` (ตั๋วคอนเสิร์ตจาก Gmail เสาร์ 19:00); ทริปอิงวันของนาฬิกา (โหมด live = วันนี้จริง) และนัดกินข้าวเลื่อนเป็นพรุ่งนี้หลัง 21:30

## ข้อจำกัดที่รู้อยู่

- ค่าเริ่มต้นเก็บรายงานในหน่วยความจำ (หายเมื่อรีสตาร์ท) ต้องตั้ง `REPORT_STORE=firestore` ถึงจะถาวร; ผู้ใช้จำลองยังอยู่ในหน่วยความจำ
- Firestore store ทดสอบ offline แค่การแปลงเอกสาร ส่วน integration test รันเมื่อมี `FIRESTORE_EMULATOR_HOST` เท่านั้น
- ถ้าแอปไม่ส่ง `places`/`origin` สถานที่ที่บันทึกไว้และ "อยู่ที่ไหนตอนนี้" จะเป็นข้อมูลจำลองของมิว
- รายชื่อสถานที่ในเครื่อง (`data/bkk_landmarks.json`, 196 แห่ง) พิกัดเป็นค่าประมาณ (สถานีรถไฟฟ้าระดับชานชาลา, เขตใช้ตำแหน่งสำนักงานเขตโดยประมาณ) ส่วนหนึ่งมาจากตาราง geocoding ใน `engine/collectors/google_calendar.py`
- โหมดเดโมใช้ฝนของ scenario ทุกจุด (รวมนอก กทม.) `/v1/home-status` ที่จุดอื่นจึงเห็นฝนตามสคริปต์; โหมด live ใช้ฝนจริงของจุดนั้น
- ไม่มีทริปไปที่ทำงานอัตโนมัติจาก `leave_time`/`days` ของที่ทำงาน (ฝั่งแอปสร้างทริปนั้นแล้วส่งเป็น `origin`/`destination`)
- ทริปเป็นข้อมูลจำลอง ยังไม่ได้ต่อ Google Calendar / Gmail จริง
- โหมด live สุ่มฝนจุดเดียวกลางเส้นทาง และ Google Weather ไม่มีฝนย้อนหลัง จึงประเมินน้ำรอระบายจากฝนที่ผ่านมาได้ไม่ครบ
- ThaiWater ไม่มีอัตราขึ้น 2 ชม. ในฟีดนี้ (`rise_cm_2h` = 0 ในโหมด live)
- โหมดน้ำท่วมใช้กฎ ไม่ได้ผ่าน Gemini
