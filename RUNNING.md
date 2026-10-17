# วิธีรัน ฝนตกไหม (mobile app + API)

repo นี้มีสองส่วนที่ใช้งานคู่กัน

- `api/` คือ Go API ที่มี Gemini agent อยู่ข้างใน และ deploy ขึ้น Cloud Run
- `app/` คือ Flutter app สำหรับ Android, iOS และ web

ส่วน `gateway/` (LINE bot) กับ `engine/` (Python) เป็นงาน Phase 1 ของพี่ Saran ดูวิธีรันได้ใน `README.md`
แผนรวมไอเดียและ API contract อยู่ใน `docs/plan/merged-flow.md` ส่วน AI ดูที่ `docs/ai/HANDOFF.md`

## สิ่งที่ต้องติดตั้ง

- Go 1.26 ขึ้นไป (`api/go.mod` ระบุ 1.26.0 ถ้าเครื่องมี Go เก่ากว่า `GOTOOLCHAIN=auto` จะโหลดตัวที่ต้องใช้ให้เองตอนรันครั้งแรก)
- Flutter 3.35 ขึ้นไป (`flutter doctor` ต้องผ่าน)
- Xcode สำหรับ iOS simulator หรือ Android Studio สำหรับ emulator (ไม่บังคับ เพราะรันบน Chrome ได้)
- `gcloud` ใช้ตอน deploy เท่านั้น

## รันแบบเร็วที่สุด: app อย่างเดียว ต่อ API บน Cloud Run

ตั้งแต่ commit `d58ec05` app จะเรียก API ที่ deploy ไว้แล้วบน Cloud Run (`https://fontokmai-api-945826169258.asia-southeast1.run.app`) เป็นค่าเริ่มต้น จึงไม่ต้องรัน API เอง

```bash
cd app && flutter pub get && flutter run -d chrome --dart-define=DEMO_CLOCK=16:10
```

`DEMO_CLOCK=16:10` ทำให้โปรไฟล์เดโม (มิว) และฉากพายุ 29 ก.ย. ขึ้นตั้งแต่เปิดครั้งแรก ถ้าไม่ใส่ app จะใช้เวลาจริง
เช็คว่า Cloud Run ยังทำงานด้วย `curl https://fontokmai-api-945826169258.asia-southeast1.run.app/v1/healthz` (path `/healthz` บน Cloud Run ตอบ 404 เพราะ Google จองไว้)

## รัน API บนเครื่องตัวเอง (ไม่ต้องมี key อะไรเลย)

เปิด terminal สองหน้าต่าง และต้องบอก app ให้ชี้มาที่เครื่องตัวเอง เพราะค่าเริ่มต้นคือ Cloud Run

```bash
# หน้าต่าง 1: API ที่พอร์ต 8080 ใช้โหมด demo (เล่นซ้ำพายุวันที่ 29 ก.ย.)
cd api && go run ./cmd/server

# หน้าต่าง 2: app
cd app && flutter pub get && flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8080 --dart-define=DEMO_CLOCK=16:10
```

Android emulator ใช้ `API_BASE_URL=http://10.0.2.2:8080` แทน localhost

ถ้าไม่มี `GEMINI_API_KEY` API จะใช้ระบบ fallback ที่ตัดสินจาก rules และตอบกลับด้วย `generated_by: "fallback"`
ถ้า app ต่อ API ไม่ได้ จะใช้ข้อมูลตัวอย่างที่ฝังมากับ app และขึ้นป้าย "ข้อมูลตัวอย่าง"

## วัดคุณภาพคำตอบของ Gemini (scorecard)

```bash
cd api
go run ./cmd/scorecard                 # ไม่ใช้ key: ให้คะแนนระบบ fallback 19 เคส
GEMINI_API_KEY=xxxx go run ./cmd/scorecard -judge -json score.json   # ใช้ Gemini จริง (เสียเงิน ~80 calls)
```

รายละเอียดอยู่ใน `api/README.md` และจุดอ่อนเทียบเกณฑ์ตัดสินอยู่ใน `docs/plan/competition-gaps-2026-10-13.md`

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
flutter run -d ios --dart-define=DEMO_CLOCK=16:10       # ต่อ Cloud Run (ค่าเริ่มต้น)
flutter run -d android --dart-define=DEMO_CLOCK=16:10   # ต่อ Cloud Run (ค่าเริ่มต้น)
# ถ้าจะใช้ API บนเครื่องตัวเอง:
flutter run -d ios --dart-define=API_BASE_URL=http://localhost:8080
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## เวลาจำลองสำหรับถ่ายวิดีโอ demo

แตะที่ชิปนาฬิกามุมซ้ายบนของ app เพื่อเลือกเวลา

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

บน Windows ใช้ `api/deploy/infra.ps1` (สร้าง service account และ infra) แล้วตามด้วย `api/deploy/cloudrun.ps1 -Project <PROJECT>` สคริปต์นี้ใช้ Gemini ผ่าน Vertex AI เป็นค่าเริ่มต้น จึงไม่ต้องใช้ `GEMINI_API_KEY`

## Deploy ให้เล่นด้วยบัญชี Google จริง (ทำตามลำดับนี้)

ต้อง deploy API ก่อน Hosting เสมอ: app เวอร์ชันใหม่เรียก `/v1/oauth/start` ซึ่ง API ตัวเก่าบน Cloud Run ไม่มี ถ้า deploy แค่ Hosting ปุ่ม Connect Google จะขึ้นหน้า 404 และ API ตัวเก่ายังตอบอีเวนต์ของ มิว ให้อีเมลจริงด้วย

1. เช็กก่อน deploy API
   - มี secret `GOOGLE_OAUTH_CLIENT_ID` และ `GOOGLE_OAUTH_CLIENT_SECRET` แล้ว: `gcloud secrets list --project ai-cup-511208`
   - ใน OAuth client (Google Cloud Console > APIs & Services > Credentials) มี `https://fontokmai-api-lmr33aj5zq-as.a.run.app/oauth2callback` เป็น Authorized redirect URI
   - อีเมล Gmail ของคุณอยู่ใน Test users ของ OAuth consent screen (`gmail.readonly` เป็น restricted scope คนนอกรายชื่อจะ login ไม่ได้)
2. Deploy API (โหมดจริง `DEMO_MODE=0` และ instance เดียวที่เปิดตลอด เป็นค่าเริ่มต้นของสคริปต์อยู่แล้ว)

   ```bash
   gcloud auth login
   PROJECT=ai-cup-511208 api/deploy/cloudrun.sh
   ```

3. เช็กว่า API ตัวใหม่ขึ้นแล้ว
   - `curl -sI 'https://fontokmai-api-lmr33aj5zq-as.a.run.app/v1/oauth/start?return=https://ai-cup-511208.web.app/&nonce=abcdefgh1234'` ต้องได้ `302` ไปที่ `accounts.google.com` (ถ้าได้ `404` แปลว่ายังเป็นตัวเก่า)
   - `curl -s 'https://fontokmai-api-lmr33aj5zq-as.a.run.app/v1/trips?email=someone@example.com'` ต้องได้รายการว่าง ไม่ใช่อีเวนต์ของ มิว
4. Build และ deploy เว็บขึ้น Firebase Hosting (`firebase.json` และ `.firebaserc` อยู่ที่ root แล้ว)

   ```bash
   npm install -g firebase-tools && firebase login
   (cd app && flutter build web --release)
   firebase deploy --only hosting
   ```

5. เปิด https://ai-cup-511208.web.app แล้วกด Connect Google ใน Settings

## Build app ไปแจกให้คนอื่นลอง

```bash
cd app
flutter build apk   # Android (ชี้ Cloud Run เป็นค่าเริ่มต้นอยู่แล้ว)
flutter build web   # เปิดบนเว็บ / ใช้ Firebase Hosting ได้
```
