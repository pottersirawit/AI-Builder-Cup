# วิธีรัน ฝนตกไหม (mobile app + API)

repo นี้มีสองส่วนที่ใช้งานคู่กัน

- `api/` คือ Go API ที่มี Gemini agent อยู่ข้างใน และ deploy ขึ้น Cloud Run
- `app/` คือ Flutter app สำหรับ Android, iOS และ web

ส่วน `gateway/` (LINE bot) กับ `engine/` (Python) เป็นงาน Phase 1 ของพี่ Saran ดูวิธีรันได้ใน `README.md`
แผนรวมไอเดียและ API contract อยู่ใน `docs/plan/merged-flow.md` ส่วน AI ดูที่ `docs/ai/HANDOFF.md`

## สิ่งที่ต้องติดตั้ง

- Go 1.24 ขึ้นไป
- Flutter 3.35 ขึ้นไป (`flutter doctor` ต้องผ่าน)
- Xcode สำหรับ iOS simulator หรือ Android Studio สำหรับ emulator (ไม่บังคับ เพราะรันบน Chrome ได้)
- `gcloud` ใช้ตอน deploy เท่านั้น

## รันแบบเร็วที่สุด (ไม่ต้องมี key อะไรเลย)

เปิด terminal สองหน้าต่าง

```bash
# หน้าต่าง 1: API ที่พอร์ต 8080 ใช้โหมด demo (เล่นซ้ำพายุวันที่ 29 ก.ย.)
cd api && go run ./cmd/server

# หน้าต่าง 2: app
cd app && flutter pub get && flutter run -d chrome
```

ถ้าไม่มี `GEMINI_API_KEY` API จะใช้ระบบ fallback ที่ตัดสินจาก rules และตอบกลับด้วย `generated_by: "fallback"`
ถ้า app ต่อ API ไม่ได้ จะใช้ข้อมูลตัวอย่างที่ฝังมากับ app และขึ้นป้าย "ข้อมูลตัวอย่าง"

## เปิด Gemini จริง

```bash
cd api
export GEMINI_API_KEY=xxxx          # จาก aistudio.google.com
export GOOGLE_MAPS_API_KEY=xxxx     # ไม่บังคับ: ใช้เรียก Weather API และ Routes API จริง
go run ./cmd/server
```

| ตัวแปร | ค่าเริ่มต้น | ความหมาย |
|---|---|---|
| `PORT` | 8080 | พอร์ตของ API |
| `DEMO_MODE` | 1 | `1` เล่นซ้ำสถานการณ์ตัวอย่าง ส่วน `0` ใช้เวลาจริงและข้อมูลจริง |
| `GEMINI_MODEL` | gemini-2.5-flash | โมเดลที่ใช้ |
| `REPORT_STORE` | memory | ตั้งเป็น `firestore` เพื่อเก็บรายงานน้ำท่วมใน Firestore |

รายการทั้งหมดอยู่ใน `api/README.md`

## รันบนมือถือ

```bash
cd app
flutter run -d ios        # iOS simulator: localhost ใช้ได้ตรง ๆ
flutter run -d android    # Android emulator: app เปลี่ยนไปใช้ 10.0.2.2:8080 ให้เอง
# เครื่องจริง หรือเมื่อ API อยู่บน Cloud Run:
flutter run --dart-define=API_BASE_URL=https://<cloud-run-url>
```

## เวลาจำลองสำหรับถ่ายวิดีโอ demo

กดค้างที่นาฬิกามุมซ้ายบนของ app เพื่อเลือกเวลา

| เวลา | ฉากในวิดีโอ |
|---|---|
| 16:10 | แจ้งเตือนจาก Calendar ว่า "ออกก่อน 16:45" |
| 18:52 | ถ่ายรูปน้ำท่วม แล้ว Gemini ประเมินระดับน้ำ |
| 21:40 | โหมดน้ำท่วมที่บ้าน |
| live | ใช้เวลาจริง |

ตั้งเวลาเริ่มต้นได้ด้วย `--dart-define=DEMO_CLOCK=21:40` หรือส่ง header `X-Demo-Clock: 16:10` เมื่อเรียก API ตรง

## ทดสอบ

```bash
cd api && go vet ./... && go test ./...
cd app && flutter analyze && flutter test
```

## Deploy API ขึ้น Cloud Run

```bash
# ครั้งแรก: เก็บ Gemini key ไว้ใน Secret Manager
printf '%s' "$GEMINI_API_KEY" | gcloud secrets create GEMINI_API_KEY --data-file=- --project <PROJECT>
# deploy (region asia-southeast1)
PROJECT=<PROJECT> api/deploy/cloudrun.sh
```

ยังไม่เคยรันสคริปต์ deploy จริง ครั้งแรกให้ดู output ทีละขั้น

## Build app ไปแจกให้คนอื่นลอง

```bash
cd app
flutter build apk --dart-define=API_BASE_URL=https://<cloud-run-url>   # Android
flutter build web --dart-define=API_BASE_URL=https://<cloud-run-url>   # เปิดบนเว็บ / ใช้ Firebase Hosting ได้
```
