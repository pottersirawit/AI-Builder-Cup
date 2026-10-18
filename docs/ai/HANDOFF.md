# ส่วน AI ของ ฝนตกไหม — เอกสารส่งมอบ

อัปเดต 2026-10-08 · branch `feat/mobile-app`

เอกสารนี้สำหรับคนที่มารับช่วงส่วน AI ต่อ อ่านจบแล้วควรรู้ว่า Gemini ทำอะไรอยู่ตรงไหน, แก้ prompt ที่ไฟล์ไหน, ทดสอบอย่างไร และอะไรที่ยังไม่ได้ทำ

## สรุปสั้น

- Gemini ทำ 3 งาน คือ agent ที่ตัดสินใจเดินทาง, แปลคำถามภาษาไทย และประเมินรูปน้ำท่วม ทั้งหมดอยู่ใน Go service `api/` และใช้ SDK `google.golang.org/genai`
- ทุกงานมี fallback แบบ rules ถ้าไม่มี key หรือ Gemini ตอบไม่ได้ ระบบก็ยังตอบได้ และ field `generated_by` จะบอกว่าคำตอบมาจาก `gemini` หรือ `fallback`
- **ยังไม่เคยรันกับ Gemini จริงเลย** ทุกอย่างทดสอบด้วย fake model งานแรกของคนรับช่วงจึงเป็นการรันด้วย key จริงแล้วปรับ prompt
- แก้ prompt หรือเปลี่ยนโมเดลได้โดยไม่ต้องแตะ Flutter เพราะ app เห็นแค่ JSON ตาม contract ใน `docs/plan/merged-flow.md`
- น้ำหนักคะแนน Technical Merit & Gen AI คือ 40% กรรมการต้องเห็นว่า Gemini เป็น agent ที่ใช้ tools ตัดสินใจ ไม่ใช่แค่กล่องแชท

## ภาพรวม: คำขอ `POST /v1/decide` หนึ่งครั้งทำงานอย่างไร

1. `httpapi` รับคำขอแล้วสร้าง `planner.Session` สำหรับเวลานั้น (เวลาจริง หรือเวลาจำลองจาก header `X-Demo-Clock`)
2. หาทริปที่จะตัดสินใจ:
   - ถ้ามี `origin` กับ `destination` ใช้ทริปจากพิกัดนั้น
   - ถ้ามี `trip_id` ใช้ทริปนั้น
   - ถ้ามีแค่ `question_th` ให้ `ParseQuestion` แปลคำถามก่อน ได้เวลาออก, วิธีเดินทาง และปลายทาง
   - ถ้าคำถามระบุที่ที่หาไม่เจอ หรือถามว่า "กลับบ้าน" แต่ผู้ใช้ยังไม่ได้ตั้งบ้าน ระบบตอบกลับเป็น `needs_place` แล้ว app จะถามผู้ใช้
3. Deterministic core (`decision`) คำนวณคำตอบพื้นฐานของทุกวิธีเดินทางไว้ก่อน
4. ถ้ามี Gemini `runAgent` จะส่ง system prompt กับ tools ให้ Gemini เรียก tools ได้สูงสุด 8 รอบ แล้วตอบเป็น JSON
5. `applyAgent` รวมคำตอบของ Gemini เข้ากับคำตอบพื้นฐาน (กติกาอยู่ในหัวข้อ guardrail ด้านล่าง)
6. ถ้า Gemini error, timeout (45 วินาที), ตอบโดยไม่เรียก tool เลย หรือ JSON พัง ระบบจะล้างประวัติการเรียก tools แล้วใช้ fallback ที่เรียก tools ชุดเดียวกันตามลำดับคงที่

## Gemini ทำอะไร และแก้ที่ไหน

| งาน | ไฟล์ | Config | Fallback |
|---|---|---|---|
| Agent ตัดสินใจเดินทาง | `api/internal/agent/decide.go`: `systemPrompt`, `runAgent`, `applyAgent` | temperature 0.2, function calling, ตอบ JSON ผ่าน prompt (ไม่ได้ใช้ schema) | `decision` core + ข้อความ template ใน `decision/narrate.go` |
| แปลคำถามภาษาไทย | `api/internal/agent/question.go`: `ParseQuestion` | temperature 0, `ResponseSchema` | regex `ParseQuestionTH` + keyword `MatchPlace` / `DestinationPhrase` |
| โหมดน้ำท่วมที่บ้าน | `api/internal/homestatus` | ยังไม่ใช้ Gemini | rules ล้วน |
| สร้าง client | `api/internal/agent/gemini.go`: `NewGeminiFromEnv`, interface `Generator` | — | — |

### Tools ของ agent

ทั้ง declaration และ implementation อยู่ใน `planner.Tools` ที่ `api/internal/planner/planner.go` ส่วน `toolDeclarations()` แปลงเป็น schema ของ Gemini ให้เอง

| Tool | ได้อะไร | แหล่งข้อมูล |
|---|---|---|
| `get_trip` | ต้นทาง, ปลายทาง, เวลานัด, ที่มาของทริป | Calendar / Gmail (ยัง mock), app, คำถาม |
| `get_route` | เวลาเดินทางและถนนที่ผ่าน | Google Routes API (fallback เป็นค่าใน scenario) |
| `get_rain_along_route` | ฝนรายช่วงบนเส้นทาง 5 ชั่วโมงข้างหน้า | Google Weather API (fallback เป็นค่าใน scenario) |
| `get_flood_spots_on_route` | จุดน้ำท่วมซ้ำซากบนเส้นทาง พร้อมความลึกที่คาด | `data/bkk_flood_risk_points.json` |
| `get_canal_levels` | ระดับคลองเทียบตลิ่ง | ThaiWater (HII) ใช้ข้อมูลจริงได้แล้ว |
| `evaluate_departure` | ความเสี่ยงแบบคำนวณแน่นอนของเวลาออกและวิธีเดินทางที่ระบุ | `decision` core |

ถ้าเพิ่ม tool ใหม่ ให้เพิ่มใน `planner.Tools` ที่เดียว ทั้ง agent และ trace ใน app จะเห็นเอง app แสดงชื่อ tool และ `summary_th` ในส่วน "Gemini คิดแบบนี้"

## Guardrail (กติกาใน `applyAgent`)

- ถ้า Gemini ตอบ `leave_now` ในวิธีเดินทางที่ core ประเมินว่าเสี่ยงสูง ระบบทิ้งคำตอบของ Gemini แล้วใช้ของ core
- ถ้า verdict ไม่อยู่ในสี่ค่านี้ (`leave_now`, `wait`, `switch_mode`, `dont_go`) หรือ headline/summary ว่าง ระบบใช้ของ core
- `leave_by` กับ `confidence` **รับค่าจาก Gemini** ถ้า Gemini ให้มาและค่าถูกรูปแบบ ส่วน ETA, ระดับน้ำ, กราฟฝน, จุดน้ำท่วม และ `mode_options` มาจาก core เสมอ
  - ควรพิจารณาว่าจะให้ `leave_by` มาจาก core อย่างเดียวไหม เพราะเป็นตัวเลขที่ผู้ใช้ทำตามจริง
- `reasoning` แสดงเฉพาะ tools ที่ถูกเรียกจริง โดยใช้ข้อความอธิบายจาก Gemini ถ้ามี

## ตั้งค่าและรัน

```bash
cd api
export GEMINI_API_KEY=...             # AI Studio
# หรือใช้ Vertex AI แทน:
# export GOOGLE_CLOUD_PROJECT=... GOOGLE_CLOUD_LOCATION=asia-southeast1
export GEMINI_MODEL=gemini-2.5-flash  # ค่าเริ่มต้น
export GOOGLE_MAPS_API_KEY=...        # ไม่บังคับ: Weather, Routes, Places, Geocoding ของจริง
go run ./cmd/server
```

ลองยิงแต่ละฉากของ demo:

```bash
H='X-Demo-Clock: 16:10'
curl -s localhost:8080/v1/decide -H "$H" -d '{"trip_id":"cal-dinner","mode":"car"}' | jq '.generated_by,.headline_th,.summary_th,.reasoning'
curl -s localhost:8080/v1/decide -H "$H" -d '{"trip_id":"cal-dinner","question_th":"ถ้ารอถึงสองทุ่มค่อยกลับล่ะ"}' | jq '.headline_th,.depart_at'
curl -s localhost:8080/v1/decide -H "$H" -d '{"question_th":"ไปสยามตอนหกโมงดีไหม"}' | jq '.trip.id,.headline_th'
curl -s localhost:8080/v1/decide -H "$H" -d '{"question_th":"กลับบ้าน","places":[]}' | jq   # ได้ needs_place
curl -s localhost:8080/v1/reports -H 'X-Demo-Clock: 18:52' -F photo=@flood.jpg -F lat=13.8063 -F lng=100.5737 | jq
```

ถ้าคำตอบที่ได้เป็น `generated_by: "fallback"` ทั้งที่ตั้ง key แล้ว ให้ดู log ของ server ซึ่งเป็น JSON และบอกเหตุผลว่าทำไมใช้ fallback

## ทดสอบ

- `go test ./...` รันได้โดยไม่ต้องมีเน็ตหรือ key
- Fake model สำหรับเขียน test ของ agent อยู่ที่ `scriptedGemini` ใน `api/internal/agent/agent_test.go` ใช้กำหนดล่วงหน้าว่าแต่ละรอบจะเรียก tool อะไรหรือตอบอะไร ส่วน vision ใช้ `fakeGen` ใน `vision_test.go`
- เวลา demo ที่ใช้ทดสอบ:

| เวลา | ผลที่ core ให้ |
|---|---|
| 16:10 รถยนต์ | ออกก่อน 16:45 |
| 17:15 มอเตอร์ไซค์ | ให้เปลี่ยนไปนั่งรถไฟฟ้า |
| 18:55 รถยนต์ (หลังรายงาน 18:52) | น้ำรัชดา 25 ซม. ให้เปลี่ยนไปนั่งรถไฟฟ้า |
| 19:30 | รอถึง 20:00 ค่อยออก |
| 21:40 (`/v1/home-status`) | น้ำจะถึงหน้าบ้านใน 40 นาที |

## งานที่ค้าง เรียงตามผลต่อคะแนน

1. **รันกับ Gemini จริงแล้วปรับ `systemPrompt`** ให้ภาษาไทยเป็นธรรมชาติ, headline ไม่เกิน 30 ตัวอักษร และให้ agent เรียก tools ตามที่ prompt กำหนด ควรวัดเวลาตอบด้วย ถ้าเกิน 5 วินาทีต้องคิดเรื่องการแสดงผลระหว่างรอ
2. **ทำชุด eval ของ agent**: ทุกเวลา demo ด้านบน × 3 วิธีเดินทาง × มีและไม่มีคำถาม เช็กว่า verdict ไม่ขัดกับ core, ใน `reasoning` มี tools ที่บังคับครบ และภาษาอ่านลื่น ใช้ Gemini ตัดสินเรื่องภาษาก็ได้ (LLM-as-judge)
3. **ทำชุดทดสอบ vision จากรูปจริง** ประมาณ 20 รูปที่รู้ระดับน้ำ (ข่าวน้ำท่วม กทม. หรือถ่ายเอง) แล้ววัดความคลาดเคลื่อนของความลึก
4. **แก้ fallback ของ vision ก่อนใช้งานจริง** ตอนนี้ถ้าไม่มี key ระบบตอบ "20–25 ซม. 84%" กับทุกรูป เหมาะกับ demo เท่านั้น ในโหมดจริงควรบอกว่า "ประเมินไม่ได้"
5. **ใช้ Gemini ในโหมดน้ำท่วม**: ให้เขียน checklist ตามสถานการณ์ เช่น บ้านชั้นเดียว มีผู้สูงอายุ ที่จอดรถใกล้สุด
6. **เชื่อม Calendar และ Gmail จริง**: พี่ Saran มี Calendar OAuth กับระบบจับคู่สถานที่ใน `engine/collectors/google_calendar.py` ส่วน Gmail ให้ Gemini ดึงข้อมูลตั๋ว (ที่ไหน กี่โมง) จากอีเมลยืนยัน
   - ฝั่ง app รอ field สำหรับนัดที่หาสถานที่ไม่เจอ ตอนนี้ app เดาชื่อไว้เป็น `destination: null` + `location_text_th` ถ้าใช้ชื่ออื่นต้องแจ้ง
7. **เลือกโมเดล**: Flash ทุกงาน หรือ Pro เฉพาะ agent ให้ตัดสินจากผล eval ข้อ 2 และเวลาตอบ

## ข้อมูลที่ต้องรู้ก่อนเริ่ม

- `data/bkk_flood_risk_points.json` มีจุดเสี่ยง **8 จุด** ไม่ใช่ 70 กว่าจุดตามที่ README เดิมเขียน หลายเส้นทางจึงไม่เจอจุดเสี่ยงเลย ต้องเติมจากข้อมูลจริงของ กทม. ห้ามแต่งพิกัดขึ้นเอง
- `data/bkk_landmarks.json` (196 แห่ง) ใช้เป็น fallback ของการค้นหาสถานที่ พิกัดเป็นค่าประมาณ
- ในโหมด demo ฝนจาก scenario ใช้กับทุกพิกัด รวมถึงนอกกรุงเทพฯ
- ตัวเลขในฉาก demo (ผู้ใช้ได้รับแจ้ง 27 คน, เพื่อนบ้าน 11 คน, ความมั่นใจ 84%) เป็นข้อมูลจำลองทั้งหมด และ app ติดป้ายไว้แล้ว
