# ฝนตกไหม API (Go)

Backend ของแอปมือถือ "ฝนตกไหม" ทำตาม API contract v0 ใน `docs/plan/merged-flow.md`
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
curl -X POST localhost:8080/v1/decide -H 'X-Demo-Clock: 2026-09-29T16:10:00+07:00' -d '{"trip_id":"cal-dinner"}'
curl -X POST localhost:8080/v1/decide -d '{"trip_id":"cal-dinner","question_th":"ถ้ารอถึงสองทุ่มค่อยกลับล่ะ"}'
curl -X POST localhost:8080/v1/decide -d '{"trip_id":"cal-dinner","depart_at":"2026-09-29T17:15:00+07:00","mode":"moto"}'
curl -X POST localhost:8080/v1/reports -H 'X-Demo-Clock: 2026-09-29T18:52:00+07:00' -F photo=@flood.jpg -F lat=13.8130 -F lng=100.5760
curl 'localhost:8080/v1/reports?lat=13.8130&lng=100.5760&radius_m=300' -H 'X-Demo-Clock: 2026-09-29T18:55:00+07:00'
curl localhost:8080/v1/home-status -H 'X-Demo-Clock: 2026-09-29T21:40:00+07:00'
```

`X-Demo-Clock` รับ RFC 3339 หรือ `HH:MM` สั้น ๆ (ตีความเป็นวันที่ 29 ก.ย. 2026)

## Environment variables

| ตัวแปร | ค่าเริ่มต้น | ใช้ทำอะไร |
|---|---|---|
| `PORT` | `8080` | พอร์ต (Cloud Run ตั้งให้เอง) |
| `DEMO_MODE` | `1` | `1` = ถ้าไม่มี header ใช้นาฬิกาเดโม 16:10 + ข้อมูล scenario; `0` = นาฬิกาจริง + provider จริง |
| `FLOOD_POINTS_PATH` (หรือ flag `-flood-points`) | หา `data/…`, `../data/…`, `/app/data/…` ตามลำดับ | ไฟล์จุดน้ำท่วม กทม. `data/bkk_flood_risk_points.json` |
| `GEMINI_API_KEY` | ว่าง | ใช้ Gemini API (AI Studio) |
| `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION` | ว่าง, `us-central1` | ใช้ Vertex AI แทน (ADC / service account ของ Cloud Run) เมื่อไม่มี `GEMINI_API_KEY` |
| `GEMINI_MODEL` | `gemini-2.5-flash` | โมเดลของ agent, ตัวแยกคำถาม และ vision |
| `GOOGLE_MAPS_API_KEY` | ว่าง | Google Weather API (`forecast/hours:lookup`) + Routes API (`computeRoutes`) ในโหมด live |
| `THAIWATER_URL` | `https://api-v3.thaiwater.net/api/v1/thaiwater30/public/waterlevel_load` | ฟีดระดับน้ำ ThaiWater (public, ไม่ต้องใช้ key) |

ไม่มี key ไหนก็ยังรันได้: Gemini ไม่มี → `generated_by: "fallback"`; provider จริงล่ม → ใช้ scenario แทน (ชื่อ source จะมี `(scenario)` ต่อท้าย)

## Docker / Cloud Run

build จาก root ของ repo เพราะต้องก๊อปไฟล์ `data/`

```bash
docker build -f api/Dockerfile -t fontokmai-api .
docker run -p 8080:8080 -e GEMINI_API_KEY=... fontokmai-api

IMAGE=asia-southeast1-docker.pkg.dev/$PROJECT/fontokmai/api
docker build --platform linux/amd64 -f api/Dockerfile -t $IMAGE . && docker push $IMAGE
gcloud run deploy fontokmai-api --image asia-southeast1-docker.pkg.dev/$PROJECT/fontokmai/api \
  --region asia-southeast1 --allow-unauthenticated --set-env-vars GOOGLE_CLOUD_PROJECT=$PROJECT,GOOGLE_CLOUD_LOCATION=us-central1
```

## โครงสร้าง (deep modules)

| package | หน้าที่ |
|---|---|
| `internal/domain` | ศัพท์กลาง (Trip, Route, RainSample, Report, Mode) และ seam: `WeatherProvider`, `RouteProvider`, `CanalProvider`, `ReportStore`, `Clock` |
| `internal/scenario` | สคริปต์เดโมของพลอย: ฝนถึงพระราม 4 ~17:30, หนักสุด 18:00–18:45, ซา 19:15, น้ำรอระบายถึง ~20:00, ฝนรอบสอง 21:00; คลองลาดพร้าว 1.4 → 1.8 ม. (19:40–21:40); รายงานผู้ใช้ตั้งต้น; ผู้ใช้จำลอง 60 คน (27 คนผ่านรัชดา–ลาดพร้าว 32) |
| `internal/live` | Google Weather, Routes API, ThaiWater และ wrapper ที่ถอยไปใช้ scenario เมื่อ error |
| `internal/decision` | **แกนตัดสินใจแบบ deterministic** ฝนบนเส้นทาง × เกณฑ์ฝนของจุดน้ำท่วม (โมเดลความลึกพอร์ตจาก `flood_matcher.py` + ระบายน้ำ 2 ชม.) × ความสูงใต้ท้องรถ (เก๋ง 15 ซม., มอไซค์ 10 ซม./ฝน ≥10 มม./ชม., รถไฟฟ้าไม่กระทบ) → verdict ต่อโหมด, `leave_by`, confidence, ข้อความไทย fallback |
| `internal/planner` | รวบรวมข้อมูลจาก provider ต่อหนึ่งคำขอ และเป็นกล่องเครื่องมือของ agent: `get_trip`, `get_route`, `get_rain_along_route`, `get_flood_spots_on_route`, `get_canal_levels`, `get_community_reports`, `evaluate_departure` |
| `internal/agent` | Gemini function-calling agent (ตัดสิน + เขียนเหตุผลภาษาไทย), ตัวแยกคำถามภาษาไทย (Gemini structured output / regex fallback เช่น "สองทุ่ม" = 20:00, "BTS" → transit, "มอไซค์" → moto) |
| `internal/vision` | Gemini vision ประเมินรูปน้ำท่วม (JSON schema) + ตรวจค่าผิดปกติ, fallback = ค่ารูปของพลอย 20–25 ซม. 84% |
| `internal/homestatus` | โหมดน้ำท่วมที่บ้าน: ระดับคลองเทียบตลิ่ง, อัตราขึ้น, เวลาที่น้ำถึงหน้าบ้าน, รายการสิ่งที่ต้องทำเรียงลำดับ |
| `internal/reports` | ReportStore ในหน่วยความจำ (รายงานโผล่ตามนาฬิกาเดโม) + นับคนที่เส้นทางผ่านในรัศมี 300 ม. |
| `internal/httpapi` | handlers, CORS เปิด, เลือก scenario/live ต่อคำขอตาม `X-Demo-Clock` |

### Gemini ทำงานอย่างไรใน `/v1/decide`

1. ถ้ามี `question_th` → Gemini แปลงเป็น `depart_at`/`mode` (หรือ regex ถ้าไม่มี Gemini) และบันทึกเป็นขั้น `parse_question` ใน `reasoning`
2. agent ได้เครื่องมือ 7 ตัว เรียกเองตามต้องการ (สูงสุด 8 รอบ) แล้วตอบ verdict + headline + summary ภาษาไทย
3. ตัวเลข (`rain_timeline`, `mode_options`, `flood_spots`) มาจากแกน deterministic เสมอ; ถ้า agent บอก `leave_now` ในโหมดที่แกนประเมินว่าเสี่ยงสูง ระบบใช้คำตอบของแกนแทน (guardrail)
4. `reasoning` = รายการเครื่องมือที่ถูกเรียกจริงตามลำดับ (fallback ก็เรียกเครื่องมือชุดเดียวกันตามลำดับตายตัว)

### ส่วนที่ต่างจาก contract v0 เล็กน้อย (เพิ่ม field เท่านั้น)

- `/v1/decide` เพิ่ม `depart_at` และ `mode` ที่ใช้คำนวณจริง (ให้แอปเลื่อน slider ตามคำถาม)
- `/v1/reports` POST คืน `lat`, `lng`, `created_at`, `generated_by` เพิ่ม; ตอบ HTTP 201
- `/v1/home-status` เพิ่ม `summary_th`, `minutes_to_doorstep`, `rain_today_mm`, `reports_nearby`
- `/v1/trips` มีทริปที่สอง `gmail-concert` (ตั๋วคอนเสิร์ตจาก Gmail เสาร์ 19:00)

## ข้อจำกัดที่รู้อยู่

- รายงานและผู้ใช้เก็บในหน่วยความจำ (ยังไม่ต่อ Firestore) ข้อมูลหายเมื่อ instance รีสตาร์ท
- ทริปเป็นข้อมูลจำลอง ยังไม่ได้ต่อ Google Calendar / Gmail จริง
- โหมด live สุ่มฝนจุดเดียวกลางเส้นทาง และ Google Weather ไม่มีฝนย้อนหลัง จึงประเมินน้ำรอระบายจากฝนที่ผ่านมาได้ไม่ครบ
- ThaiWater ไม่มีอัตราขึ้น 2 ชม. ในฟีดนี้ (`rise_cm_2h` = 0 ในโหมด live)
- โหมดน้ำท่วมใช้กฎ ไม่ได้ผ่าน Gemini
