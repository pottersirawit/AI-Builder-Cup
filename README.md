# Bangkok Weather Resilience AI (ระบบเตือนภัยและรับมือน้ำท่วม/สภาพอากาศเชิงรุก)
> ผสานพลัง **Google WeatherNext 3 (5km FGN)**, **Google Cloud Vertex AI (Gemini 1.5)** และโทรมาตรท้องถิ่นกรุงเทพฯ (เรดาร์ กทม. + ThaiWater Standard API) เพื่อสร้างการแจ้งเตือนและการเตรียมตัวเชิงรุกเฉพาะบุคคล (Hyper-personalized Proactive Advisory)

---

## 🌟 จุดเด่นของระบบ (Key Capabilities)

1. **Google WeatherNext 3 Integration**:
   - พยากรณ์อากาศความละเอียดสูง **5 km grid** (คมชัดกว่าเดิม 5 เท่า) อัปเดตรายชั่วโมง (**Hourly Refresh**)
   - ฝึกฝนจากภาพถ่ายดาวเทียม Geostationary ดิบโดยตรง ทำให้ตรวจจับปรากฏการณ์ **Urban Microclimate** ฝนตกหนักเฉพาะเขตใน กทม. ได้อย่างแม่นยำ
2. **Local Bangkok Flood Telemetry Coupling**:
   - เชื่อมต่อข้อมูลโทรมาตรระดับน้ำในคลองสายหลัก (คลองแสนแสบ, คลองลาดพร้าว, คลองเปรมประชากร) จาก **สสน. (Thaiwater Standard API)**
   - คำนวณ Geofencing จุดตัดพิกัดผู้ใช้และเส้นทางเดินทางกับ **70+ จุดเฝ้าระวังน้ำท่วมขังบนผิวถนน กทม. (BKK Risk Map)**
   - วิเคราะห์เวกเตอร์การเคลื่อนตัวของกลุ่มฝนจาก **เรดาร์ กทม. สถานีหนองจอกและหนองแขม** (dBZ)
3. **Google Calendar Weather Integration**:
   - ซิงก์ตารางนัดหมายของผู้ใช้จาก **Google Calendar API** ล่วงหน้า
   - ดึงพิกัดสถานที่นัดหมาย (Geocoding) และจับคู่กับพยากรณ์อากาศรายชั่วโมงระดับ 5km จาก **WeatherNext 3**
   - ตรวจจับข้อน่ากังวลสภาพอากาศ ณ เวลาและสถานที่นัดหมาย (เช่น เสี่ยงน้ำท่วมผิวจราจร, ฝนตกหนักขัดขวางการเดินทาง, หรือดัชนีความร้อนจัดในกิจกรรมกลางแจ้ง) พร้อมส่งคำแนะนำเชิงรุกก่อนเดินทาง
4. **Vertex AI & Gemini Multimodal Weather Reasoning**:
   - แปลงตัวเลขพยากรณ์ที่ซับซ้อนให้กลายเป็น **Actionable Checklist** ภาษาไทยที่เข้าใจง่ายและปฏิบัติตามได้ทันที
   - แนะนำเฉพาะบุคคลตามประเภทยานพาหนะ (เช่น รถเก๋งเตี้ย vs มอเตอร์ไซค์), เส้นทางกลับบ้าน, และช่วงเวลาเลิกงาน
5. **Polyglot Hybrid Architecture (Go + Python)**:
   - **Go Gateway & Dispatcher**: จัดการ Webhook และใช้ Goroutine Worker Pool ยิง Push Message หาประชาชนนับหมื่น/แสนคนพร้อมกันด้วยความเร็วสูงและใช้หน่วยความจำต่ำ
   - **Python AI Engine**: รันโมเดลวิทยาศาสตร์ข้อมูล, คำนวณ Spatial Matching และเชื่อมต่อ Vertex AI Generative AI

---

## 🏗️ โครงสร้างสถาปัตยกรรม (System Architecture)

```
/Weather
├── data/
│   └── bkk_flood_risk_points.json  # ฐานข้อมูล 70+ จุดเสี่ยงน้ำท่วมผิวจราจร กทม.
├── engine/                         # [Python] Weather Pipeline, Geospatial & Vertex AI Brain
│   ├── collectors/                 # ตัวดึงข้อมูล (WeatherNext 3, ThaiWater API, BMA Radar)
│   ├── geospatial/                 # โมดูลคำนวณระยะห่างจุดเสี่ยงน้ำท่วมและเกณฑ์ฝนวิกฤต
│   ├── ai/                         # Vertex AI Gemini Reasoner & Fallback Engine
│   ├── main.py                     # FastAPI REST Endpoints
│   └── requirements.txt
├── gateway/                        # [Go] API Gateway & Real-time Notification Engine
│   ├── cmd/server/main.go          # Main entry point
│   ├── internal/api/               # REST Endpoints สำหรับ LIFF Web App
│   ├── internal/line/              # ตัวสร้าง LINE Flex Message Bubble JSON
│   ├── internal/dispatcher/        # Goroutine Worker Pool สำหรับยิง Push Notification
│   └── go.mod
├── simulator/
│   ├── scenarios.json              # จำลองเหตุการณ์พายุฝนน้ำท่วม, ฮีทเวฟ, สรุปตอนเช้า
│   └── run_simulation.py           # สคริปต์รันจำลองระบบ End-to-End
├── docker-compose.yml              # PostgreSQL(PostGIS) + Redis + Go Gateway + Python Engine
└── .env.example                    # ตัวอย่างการตั้งค่า API Keys
```

---

## 🚀 วิธีการทดสอบและรันระบบ (Quick Start)

### 1. ทดสอบการจำลองสถานการณ์พายุและน้ำท่วม (End-to-End Simulator)
คุณสามารถรันตัวจำลองเพื่อดูการประมวลผลข้อมูล WeatherNext 3, การจับคู่จุดเสี่ยงน้ำท่วม และการสร้างคำแนะนำภาษาไทยได้ทันที:

```bash
# 1.1 รันการจำลองสถานการณ์พายุฝนและฮีทเวฟทั่วไป
./venv/bin/python simulator/run_simulation.py

# 1.2 รันการจำลองเชื่อมต่อ Google Calendar ตรวจจับสภาพอากาศตามนัดหมาย
./venv/bin/python simulator/run_calendar_simulation.py
```

### 2. รัน Go API Gateway
```bash
cd gateway
go run ./cmd/server
# เซิร์ฟเวอร์จะเปิดที่พอร์ต http://localhost:8080
```

### 3. รัน Python AI Engine
```bash
./venv/bin/uvicorn engine.main:app --host 0.0.0.0 --port 8000 --reload
# เอกสาร Swagger API: http://localhost:8000/docs
```

### 4. รันผ่าน Docker Compose ครบวงจร
```bash
docker compose up --build
```

---

## 📋 ตัวอย่างผลลัพธ์การเตือนภัยเชิงรุก (LINE Flex Message)

เมื่อโมเดลตรวจพบกลุ่มฝนตกหนักมุ่งหน้าสู่อโศก-สุขุมวิท ระบบจะประเมินความเสี่ยงต่อรถยนต์ขนาดเล็กและส่งข้อความเตือนภัย:

```
🚨 [CRITICAL] เตือนภัยระดับวิกฤต
พาดหัว: แจ้งเตือนด่วน: พายุฝนและเสี่ยงน้ำท่วมขัง ถนนอโศกมนตรี (วัฒนา)
สถานการณ์: กลุ่มฝนฟ้าคะนองกำลังเคลื่อนเข้าพื้นที่ของคุณในอีก 25-35 นาที 
         อัตราฝน 48.5 มม./ชม. เสี่ยงน้ำท่วมขังผิวจราจร 20 ซม. (ถนนสุขุมวิท ช่วงอโศก - พร้อมพงษ์)

⏱️ ช่วงเวลาวิกฤต: 16:45 - 18:30 น.
🚗 ผลกระทบต่อพาหนะ: ระดับน้ำคาดการณ์ 20 ซม. เสี่ยงน้ำเข้าท่อไอเสียและห้องเครื่องของ รถเก๋งเตี้ยของคุณ

📋 แผนการเตรียมตัวเชิงรุก (Action Checklist):
   1. หากจอดรถในที่ลุ่มต่ำ แนะนำรีบขยับรถขึ้นที่สูงทันทีก่อนฝนตกหนัก
   2. หากกำลังจะเลิกงาน แนะนำเลื่อนเวลาเดินทางออกไป หรือออกทันทีใน 15 นาทีนี้
   3. หลีกเลี่ยงการขับผ่านจุดเสี่ยง: สุขุมวิท 21 - 39 และซอยอุดมสุข

🛣️ เส้นทางสำรอง: คลองแสนแสบใกล้ล้นตลิ่ง แนะนำใช้ทางด่วนหรือรถไฟฟ้า BTS แทนเส้นทางผิวถนน
```

---

## 🔑 การตั้งค่า Environment Variables (`.env`)

คัดลอกไฟล์ `.env.example` ไปเป็น `.env` และกรอกข้อมูล:
```bash
cp .env.example .env
```
- `GEMINI_API_KEY`: API Key จาก Google AI Studio หรือ Google Cloud Vertex AI
- `WEATHER_DATA_MODE`: ตั้งเป็น `mock` สำหรับการทดสอบออฟไลน์ หรือ `live` สำหรับเชื่อมต่อ Google Maps Platform Weather API
- `LINE_CHANNEL_ACCESS_TOKEN`: Token จาก LINE Developers Console สำหรับยิง Push Notification จริง
