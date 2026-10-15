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
| ตั้งค่า: สถานที่ของฉัน (แก้/ลบพร้อมเลิกทำ), Google Calendar, โปรไฟล์เดโม | `lib/screens/settings_screen.dart` | ไม่มี |
| เริ่มใช้ครั้งแรก: ตั้งบ้านและที่ทำงาน (ข้ามได้) | `lib/screens/onboarding_screen.dart` | ไม่มี |
| เลือกสถานที่: ค้นหา, ใช้ตำแหน่งตอนนี้ และสิทธิ์ตำแหน่งทุกสถานะ, หน้ายืนยันก่อนบันทึก | `lib/screens/place_picker.dart` | `GET /v1/places/search`, `GET /v1/places/reverse` |

## สถานที่ของฉัน

ตามสเปก [`docs/plan/places-and-empty-states.md`](../docs/plan/places-and-empty-states.md) แอปเก็บสถานที่ไว้ในเครื่องด้วย shared_preferences (`lib/places.dart`): บ้าน 1 ที่ ที่ทำงาน 1 ที่ และที่อื่นไม่เกิน 8 ที่ ถ้าห่างจากที่บันทึกไว้ไม่เกิน 150 ม. ถือว่าซ้ำ และถ้าอยู่นอกกรอบกรุงเทพฯ (13.49–14.10 N, 100.30–100.95 E) จะติดป้าย "นอกพื้นที่ที่แอปรองรับ" เซิร์ฟเวอร์ไม่เก็บสถานที่ แอปส่งพิกัดไปกับแต่ละคำขอเท่านั้น

- มีบ้านและที่ทำงาน: แอปสร้างทริป "กลับบ้าน" ของวันทำงานเองจากเวลาออกจากงานปกติ แล้วส่งเป็น `origin`/`destination` ไปที่ `POST /v1/decide` (ถ้ามีนัดใน Calendar ที่กลับบ้านวันนั้นอยู่แล้วจะไม่สร้างซ้ำ)
- มีแต่บ้าน: ทริปกลับบ้านเริ่มจากตำแหน่งตอนกดปุ่ม "เช็กทางกลับบ้าน"
- คำถามที่ใช้สถานที่ที่ยังไม่ได้ตั้ง เช่น "กลับบ้าน" ตอนยังไม่มีบ้าน แอปถามกลับในการ์ดคำตอบ บันทึกแล้วถามคำถามเดิมซ้ำให้เอง ส่วน `needs_place` จากเซิร์ฟเวอร์จะแสดงเป็นรายการ "หมายถึงที่ไหน"
- ข้อมูล Calendar/Gmail จาก `/v1/trips` แสดงเฉพาะเมื่อเชื่อม Calendar แล้ว (ตอนนี้เชื่อมได้เฉพาะโปรไฟล์เดโม)

**โปรไฟล์เดโม (มิว)** เปิดเองในการติดตั้งครั้งแรกเมื่อมีเวลาสาธิต (ค่าเริ่มต้น) จึงยังถ่ายวิดีโอเดโมได้เหมือนเดิม ป้าย "เดโม" อยู่ข้างคำทักทาย ออกได้ที่ ตั้งค่า → "ออกจากโปรไฟล์เดโม" ซึ่งล้างสถานที่และกลับไปหน้าเริ่มใช้

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

## เปิดหน้าจอที่ต้องการตอนเริ่มแอป (DEMO_SCREEN)

```bash
flutter run -d ios --dart-define=DEMO_SCREEN=onboarding
```

ค่าที่ใช้ได้: `verdict@18:00/moto`, `report`, `report_result`, `home_tab`, `ask`, `settings`, `gallery` (โปรไฟล์เดโม) และ `onboarding`, `empty_home`, `place_search`, `place_confirm`, `flood_nohome`, `location_denied` (เริ่มจากเครื่องใหม่ที่ยังไม่ตั้งอะไร) กับ `settings_places` (โปรไฟล์เดโมพร้อมแบนเนอร์ปิดการแจ้งเตือน) ค่าเหล่านี้จะรีเซ็ตสถานที่ที่บันทึกในเครื่อง บน iOS Simulator ต้องใช้ `--dart-define` เพราะตัวแปร environment ของ `simctl launch` ไม่ถึงแอป

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
- `test/places_test.dart` ทดสอบ PlacesStore (ซ้ำ 150 ม., จำกัดจำนวน, กรอบกรุงเทพฯ, เก็บข้าม restart, ลบแล้วเลิกทำ), ทริปกลับบ้าน, การค้นหาและ reverse แบบออฟไลน์ และรูปแบบ JSON ของ contract v1
- `test/places_flow_test.dart` ทดสอบหน้าเริ่มใช้, ข้ามแล้วตั้งบ้านจากหน้าว่าง, ถาม "กลับบ้าน" ตอนยังไม่มีบ้าน, `needs_place` จากเซิร์ฟเวอร์, แท็บบ้านตอนยังไม่มีบ้าน, สิทธิ์ตำแหน่งถูกปฏิเสธ และลบบ้านแล้วเลิกทำ

## ส่วนที่ยังเป็นตัวจำลอง

- แจ้งเตือน 16:10 เป็นแบนเนอร์ในหน้าหลัก ยังไม่ใช่ push notification จริง
- คำทักทาย "สวัสดีมิว" และสภาพอากาศ "ครึ้ม 30°" เป็นข้อความคงที่
- การ์ดเพื่อนบ้านในโหมดน้ำท่วม (11 คน) เป็นข้อความคงที่ เพราะ contract ยังไม่มีข้อมูลนี้
- สวิตช์ในหน้าตั้งค่าเก็บค่าในหน่วยความจำเท่านั้น (สถานที่ของฉันเก็บถาวรในเครื่อง)
- การเชื่อม Google Calendar (OAuth) ยังเป็นตัวจำลอง: นอกโปรไฟล์เดโมปุ่มขึ้นว่า "เร็ว ๆ นี้" ส่วนในโปรไฟล์เดโมกดแล้วจะเชื่อมกับบัญชีจำลอง
- การเช็กสิทธิ์แจ้งเตือนยังเป็นตัวจำลอง เพราะแอปยังไม่มีแพ็กเกจ notification แบนเนอร์ "ปิดการแจ้งเตือนอยู่" จึงขึ้นเฉพาะ `DEMO_SCREEN=settings_places`
