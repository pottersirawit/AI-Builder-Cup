# ฝนตกไหม — แอป Flutter

แอปมือถือที่ตอบคำถามเดียว: "ควรออกตอนนี้ไหม" สำหรับทริปที่กำลังจะไป โดยใช้ API contract v0 ใน [`docs/plan/merged-flow.md`](../docs/plan/merged-flow.md) และหน้าตาตามต้นแบบ [`fontokmai.html`](../fontokmai.html)

## หน้าจอ

| หน้าจอ | ไฟล์ | API |
|---|---|---|
| หน้าหลัก: แบนเนอร์แจ้งเตือน 16:10, ช่องถาม, ชิปสถานที่, การ์ดคำตัดสิน, ฝนบนเส้นทาง, การ์ด Calendar, ความเสี่ยงน้ำท่วมที่บ้าน, ตั๋วจาก Gmail | `lib/screens/home_screen.dart` | `GET /v1/trips`, `POST /v1/decide`, `GET /v1/home-status` |
| รายละเอียดคำตัดสิน: แถบเลื่อนเวลาออก, สลับรถยนต์/BTS-MRT/มอเตอร์ไซค์, จุดน้ำท่วมบนเส้นทาง, "Gemini คิดแบบนี้" | `lib/screens/verdict_screen.dart` | `POST /v1/decide` |
| ถามต่อ (แชต) | `lib/screens/ask_screen.dart` | `POST /v1/decide` พร้อม `question_th` |
| รายงานน้ำท่วม (กล้อง/คลังภาพ) | `lib/screens/report_screen.dart` | `POST /v1/reports` (multipart) |
| โหมดน้ำท่วม (ธีมมืด) | `lib/screens/flood_screen.dart` | `GET /v1/home-status` |
| ตั้งค่า (เก็บในเครื่องเท่านั้น) | `lib/screens/settings_screen.dart` | ไม่มี |

## รันแอป

ต้องมี Flutter 3.35 ขึ้นไป

```bash
cd app
flutter pub get
```

**Chrome (เร็วที่สุดสำหรับเดโม)**

```bash
flutter run -d chrome
# หรือสร้างไฟล์ static
flutter build web && python3 -m http.server 8000 --directory build/web
```

**iOS Simulator**

```bash
open -a Simulator
flutter run -d ios
```

**Android Emulator**

```bash
flutter emulators --launch <emulator_id>
flutter run -d android
```

## ชี้ไปที่ backend

ค่าเริ่มต้นคือ `http://localhost:8080` ส่วน Android emulator ใช้ `http://10.0.2.2:8080` ให้เองอัตโนมัติ เพราะ emulator มองเห็นเครื่อง host ที่ 10.0.2.2

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8080
flutter run -d ios --dart-define=API_BASE_URL=https://fontokmai-api-xxxx.a.run.app
```

เครื่องจริงต้องใช้ IP ของเครื่องที่รัน backend ในวง LAN เดียวกัน หรือใช้ URL ของ Cloud Run

ถ้ารันบน Chrome ฝั่ง backend ต้องเปิด CORS ให้ origin ของแอป และต้องอนุญาต header `X-Demo-Clock` และ `Content-Type` ใน preflight ด้วย

## เวลาสาธิต (X-Demo-Clock)

แอปส่ง header `X-Demo-Clock` เพื่อให้ server เล่นสถานการณ์ซ้ำได้เหมือนเดิมทุกครั้งที่ถ่ายวิดีโอ

- **กดค้างที่นาฬิกามุมซ้ายบน** ของทุกหน้าจอ เพื่อเลือก 16:10, 18:52 หรือ 21:40 ของวันที่ 29 ก.ย. 2026 (+07:00) หรือเลือก "เวลาจริง" เพื่อไม่ส่ง header
- จุดเล็ก ๆ ข้างนาฬิกาแปลว่ากำลังใช้เวลาสาธิตอยู่
- เวลาเริ่มต้นคือ 16:10 เปลี่ยนได้ด้วย `--dart-define=DEMO_CLOCK=21:40` หรือ `--dart-define=DEMO_CLOCK=live`

ลำดับเดโม 5 จังหวะ: 16:10 แบนเนอร์และคำตัดสิน, แถบเลื่อนและสลับวิธีเดินทาง, ถามต่อ "ถ้ารอถึงสองทุ่ม", 18:52 ถ่ายรูปน้ำท่วม, 21:40 หน้าหลักจะขึ้นการ์ดโหมดน้ำท่วม แตะเพื่อดูสิ่งที่ต้องทำ

## โหมดออฟไลน์

ถ้าเรียก backend ไม่ได้ (ต่อไม่ติด, timeout หรือ HTTP ที่ไม่ใช่ 2xx) แอปจะใช้ข้อมูลตัวอย่างใน `assets/fixtures/*.json` ซึ่งมีรูปแบบตรงกับ contract และจะแสดงป้าย **ข้อมูลตัวอย่าง** ที่แถบด้านบน ข้อมูลตัวอย่างยังตอบสนองต่อการใช้งาน:

- รถยนต์หรือมอเตอร์ไซค์ที่ออกช่วง 17:15 ถึง 19:59 จะได้คำตัดสินช่วงพายุ (`decide_*_storm.json`)
- BTS/MRT ใช้ `decide_transit.json` และคำถามที่มีคำว่า BTS, MRT หรือรถไฟฟ้าก็ใช้ไฟล์นี้ด้วย
- เวลาสาธิต 21:00 เป็นต้นไปใช้ `home_status_danger.json`

ฟอนต์ Chakra Petch รวมอยู่ใน `assets/google_fonts/` แล้ว จึงแสดงผลได้แม้ไม่มีอินเทอร์เน็ต (สัญญาอนุญาต OFL อยู่ในโฟลเดอร์เดียวกัน)

## ทดสอบ

```bash
flutter analyze
flutter test
```

- `test/models_test.dart` ทดสอบการแปลง JSON จาก fixture ทุกไฟล์
- `test/api_test.dart` ทดสอบ body และ header ที่ส่งไป, การ fallback ไปใช้ fixture และการเลือก fixture
- `test/home_screen_test.dart` ทดสอบว่าหน้าหลักแสดงหัวข้อคำตัดสินจาก fixture และเปิดทุกหน้าจอได้โดยไม่มี error

## ส่วนที่ยังเป็นตัวจำลอง

- ตำแหน่งในการรายงานน้ำท่วมกำหนดไว้ที่ ถ.รัชดาภิเษก หน้าซอยลาดพร้าว 32 (ยังไม่ได้ใช้ GPS)
- แจ้งเตือน 16:10 เป็นแบนเนอร์ในหน้าหลัก ยังไม่ใช่ push notification จริง
- คำทักทาย "สวัสดีพลอย" และสภาพอากาศ "ครึ้ม 30°" เป็นข้อความคงที่
- การ์ดเพื่อนบ้านในโหมดน้ำท่วม (11 คน) เป็นข้อความคงที่ เพราะ contract ยังไม่มีข้อมูลนี้
- หน้าตั้งค่าเก็บค่าในหน่วยความจำเท่านั้น ยังไม่ส่งไป backend
