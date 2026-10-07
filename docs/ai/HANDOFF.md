# ส่วน AI — คู่มือส่งต่อให้คนดูแล AI

ส่วน AI ทั้งหมดอยู่ใน Go service `api/` และเปลี่ยน prompt หรือโมเดลได้โดยไม่ต้องแตะ Flutter เพราะ app เห็นแค่ JSON ตาม contract ใน `docs/plan/merged-flow.md`

## Gemini ทำอะไรบ้าง

| งาน | ไฟล์ | Gemini ทำ | ถ้าไม่มี key หรือเรียกไม่สำเร็จ |
|---|---|---|---|
| ตัดสินใจเดินทาง (agent) | `api/internal/agent/decide.go` (`systemPrompt`, `toolDeclarations`, `runAgent`) | เรียก tools ตามลำดับที่ตัดสินใจเอง แล้วเขียน verdict เป็นภาษาไทยพร้อมเหตุผล | `decision` core เรียก tools ชุดเดียวกันตามลำดับคงที่ และใช้ข้อความ template |
| แปลคำถามภาษาไทย | `api/internal/agent/question.go` (`ParseQuestion`) | แปลงคำถามเป็นเวลาออกและโหมดเดินทาง | regex `ParseQuestionTH` (เช่น "สองทุ่ม", "BTS", "มอไซค์") |
| ประเมินรูปน้ำท่วม | `api/internal/vision/vision.go` (`prompt`, `Assess`) | ประเมินความลึก ความมั่นใจ และว่ารถแต่ละแบบผ่านได้ไหม เป็น JSON ตาม schema | คืนค่าจาก scenario |
| โหมดน้ำท่วมที่บ้าน | `api/internal/homestatus` | ยังไม่ใช้ Gemini (ใช้ rules) | — |

Tools ที่ agent เรียกได้ (implement อยู่ใน `api/internal/planner/planner.go`): `get_trip`, `get_route`, `get_rain_along_route`, `get_flood_spots_on_route`, `get_canal_levels`, `get_community_reports`, `evaluate_departure`

## Guardrail ที่ตั้งใจใส่ไว้

- ตัวเลขทุกตัว (leave_by, ระดับน้ำ, ETA) มาจาก deterministic core เสมอ Gemini เป็นคนเลือกคำตัดสินและเขียนเหตุผล
- ถ้า Gemini บอก `leave_now` ในโหมดที่ core ประเมินว่าเสี่ยงสูง ระบบจะใช้คำตอบของ core แทน
- ทุกคำตอบมี `generated_by: "gemini" | "fallback"` ให้ app แสดงได้ว่ามาจากไหน

## ตั้งค่า

```bash
export GEMINI_API_KEY=...            # AI Studio key
# หรือใช้ Vertex AI แทน:
export GOOGLE_CLOUD_PROJECT=... GOOGLE_CLOUD_LOCATION=asia-southeast1
export GEMINI_MODEL=gemini-2.5-flash # ค่าเริ่มต้น
```

## งานที่ยังค้างฝั่ง AI (เรียงตามความสำคัญต่อคะแนน Gen AI 40%)

1. **ยังไม่เคยรันกับ Gemini จริง** ทุกอย่างทดสอบผ่าน fake model เท่านั้น ต้องรันด้วย key จริง แล้วปรับ `systemPrompt` ให้ภาษาฟังเป็นธรรมชาติ
2. **ชุดทดสอบ (eval)** สำหรับ agent: ใช้ demo clock 16:10 / 17:15 / 19:30 / 18:55 คู่กับทั้งสามโหมด แล้วเช็กว่า verdict ตรงกับ core และภาษาไทยอ่านลื่น
3. **ชุดรูปน้ำท่วมจริง** สำหรับทดสอบ vision (ควรมีประมาณ 20 รูป ที่รู้ระดับน้ำจริง)
4. ให้ Gemini เขียน checklist ของโหมดน้ำท่วม ตอนนี้ยังเป็น rules
5. อ่าน Calendar และ Gmail จริง (OAuth): พี่ Saran มี Calendar OAuth กับระบบจับคู่สถานที่ใน `engine/collectors/google_calendar.py` ให้ port มาใช้ได้
6. ตัดสินใจเรื่องโมเดล: ใช้ Flash ทุกงาน หรือใช้ Pro เฉพาะ agent

## วิธีทดสอบแบบเร็ว

```bash
cd api && GEMINI_API_KEY=... go run ./cmd/server
curl -s localhost:8080/v1/decide -H 'X-Demo-Clock: 16:10' -d '{"trip_id":"cal-dinner","mode":"car"}' | jq '.generated_by,.headline_th,.reasoning'
curl -s localhost:8080/v1/reports -H 'X-Demo-Clock: 18:52' -F photo=@flood.jpg -F lat=13.806 -F lng=100.574 | jq
```
