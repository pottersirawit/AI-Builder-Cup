# Deploy ฝนตกไหม (Firebase Hosting + Cloud Run)

คู่มือสำหรับคนที่ deploy ต่อ อ่านหัวข้อ "สถานะตอนนี้" และ "ข้อควรระวัง" ก่อนกดอะไร

## สถานะตอนนี้ (deploy ล่าสุด 2026-10-17)

| ส่วน | ที่อยู่ | หมายเหตุ |
|---|---|---|
| เว็บ (Flutter web) | https://ai-cup-511208.web.app | Firebase Hosting โปรเจกต์ `ai-cup-511208` |
| API (Go) | https://fontokmai-api-lmr33aj5zq-as.a.run.app | Cloud Run service `fontokmai-api` region `asia-southeast1` (URL แบบใหม่ `https://fontokmai-api-945826169258.asia-southeast1.run.app` คือ service เดียวกัน) |
| Revision ปัจจุบัน | `fontokmai-api-00032-qvk` | deploy จาก commit `2c53474` |
| Revision ก่อนหน้า | `fontokmai-api-00031-kkv` | ตัวเก่า (ใช้ rollback ได้) |

ค่าที่ตั้งไว้บน Cloud Run (อย่าลบ)

- Service account: `fontokmai-api@ai-cup-511208.iam.gserviceaccount.com`
- Env: `DEMO_MODE=0`, `REPORT_STORE=firestore`, `GEMINI_MODEL=gemini-2.5-flash`, `GEMINI_FAST_MODEL=gemini-2.5-flash-lite`, `GEMINI_CONTEXT_CACHE=1`, `GOOGLE_CLOUD_PROJECT=ai-cup-511208`, `GOOGLE_CLOUD_LOCATION=asia-southeast1`, `TASKS_*`, `PUBSUB_TOPIC_RAW`, `APP_URL=https://ai-cup-511208.web.app`, `OAUTH_REDIRECT_URI=https://fontokmai-api-lmr33aj5zq-as.a.run.app/oauth2callback`
- Secrets: `GOOGLE_MAPS_API_KEY`, `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `LINE_CHANNEL_SECRET`, `LINE_CHANNEL_ACCESS_TOKEN`
- Gemini เรียกผ่าน **Vertex AI** ด้วย service account ไม่มี `GEMINI_API_KEY`
- เครื่อง: 1 vCPU, 512 MiB, **min 1 / max 1 instance, ไม่บีบ CPU** (เหตุผลในหัวข้อข้อควรระวัง)

## ภาพรวมระบบ

```
เบราว์เซอร์ ──> Firebase Hosting (app/build/web)
     │
     └─ เรียก API ตรง (API_BASE_URL ค่าเริ่มต้นใน app/lib/config.dart) ──> Cloud Run fontokmai-api
                                                                      ├─ Gemini (Vertex AI)
Login Google:                                                         ├─ Google Weather / Routes / Maps
  แอป ─> /v1/oauth/start ─> Google ─> /oauth2callback (Cloud Run)      ├─ Calendar / Gmail (token ของผู้ใช้)
       <─ redirect กลับ APP_URL?connected=<email> <──────────────────── └─ Firestore (รายงานน้ำท่วม)
```

- `DEMO_MODE=0` คือใช้เวลาจริงและข้อมูลจริง ถ้า request ส่ง header `X-Demo-Clock` มา API จะเล่นซ้ำอากาศ น้ำท่วม และการจราจรของวันพายุแทน แต่นัดหมายยังมาจากปฏิทินจริงของบัญชีนั้น (เว็บที่ build ด้วย `--dart-define=DEMO_CLOCK=...` จะส่ง header นี้ ดู [DEMO.md](DEMO.md))
- บัญชีจริงที่ยังไม่ได้ sync จะได้ `{"connected":false,"trips":[]}` ไม่มีข้อมูลของ มิว ปน

## ขั้นตอน deploy

ต้อง deploy **API ก่อนเว็บ** เสมอ เพราะเว็บตัวใหม่เรียก endpoint ที่ API ตัวเก่าไม่มี

### 0. ครั้งแรกบนเครื่องใหม่

```bash
gcloud auth login
gcloud config set project ai-cup-511208
npm i -g firebase-tools
firebase login
```

บัญชีต้องเป็น Owner หรือ Editor ของโปรเจกต์ `ai-cup-511208` และ**ไม่ต้องรัน `firebase init`** (`firebase.json` กับ `.firebaserc` อยู่ใน repo แล้ว ถ้ารันจะเขียนทับ)

### 1. Deploy API

macOS / Linux

```bash
PROJECT=ai-cup-511208 api/deploy/cloudrun.sh
```

Windows (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File api\deploy\cloudrun.ps1 -Project ai-cup-511208
```

ทั้งสองสคริปต์ใส่ค่าโหมดจริงให้เป็นค่าเริ่มต้นแล้ว สคริปต์ `.sh` **อัปเดต**เฉพาะค่าที่มันรู้จัก (`--update-env-vars`) ค่าอื่นบน service ไม่หาย ส่วน `.ps1` ตั้งค่าทุกตัวใหม่ทั้งชุด (`--set-env-vars`) ซึ่งครบตามรายการข้างบนแล้ว ถ้าเพิ่ม env ใหม่บน Cloud Run ต้องเพิ่มใน `.ps1` ด้วย ไม่อย่างนั้นค่าจะหายตอน deploy รอบหน้า

คำสั่งเดียวที่ใช้ deploy เมื่อ 2026-10-17 (ถ้าไม่อยากใช้สคริปต์)

```bash
ctx=$(mktemp -d) && mkdir -p $ctx/data \
  && rsync -a --exclude '.*' api $ctx/ \
  && cp data/bkk_flood_risk_points.json data/bkk_landmarks.json $ctx/data/ \
  && cp api/Dockerfile $ctx/Dockerfile \
  && gcloud run deploy fontokmai-api --project ai-cup-511208 --region asia-southeast1 --source $ctx \
       --update-env-vars DEMO_MODE=0,APP_URL=https://ai-cup-511208.web.app,OAUTH_REDIRECT_URI=https://fontokmai-api-lmr33aj5zq-as.a.run.app/oauth2callback \
       --min-instances 1 --max-instances 1 --no-cpu-throttling --timeout 120
```

### 2. Smoke test API

```bash
U=https://fontokmai-api-lmr33aj5zq-as.a.run.app
curl -s $U/v1/health                                   # 200
curl -s "$U/v1/outlook?lat=13.74&lng=100.53" | head -c 200   # อากาศวันนี้ ไม่ใช่วันเดโม 29 ก.ย.
curl -sI "$U/v1/oauth/start?return=https://ai-cup-511208.web.app/&nonce=abcdefgh1234" | head -3   # 302 ไป accounts.google.com
curl -s "$U/v1/trips?email=someone@example.com"        # {"connected":false,"trips":[]}
```

ถ้า `oauth/start` ได้ 404 แปลว่ายังเป็น API ตัวเก่า ถ้า trips ได้ "กินข้าวเย็นกับที่บ้าน" แปลว่า `DEMO_MODE` ยังเป็น 1

### 3. Build และ deploy เว็บ

```bash
cd app
python3 tool/l10n_merge.py && flutter gen-l10n
flutter build web --release        # ห้ามใส่ DEMO_CLOCK สำหรับเว็บหลัก
cd ..
firebase deploy --only hosting
```

แล้วเปิด https://ai-cup-511208.web.app ในหน้าต่าง Incognito (กัน cache เก่า)

### 4. เว็บโหมดเดโมแยก (ไม่ทับเว็บหลัก)

```bash
cd app && flutter build web --release --dart-define=DEMO_CLOCK=16:10 && cd ..
firebase hosting:channel:deploy demo
```

ได้ URL preview ของ channel `demo` (หมดอายุเองใน 7 วัน) คำสั่งนี้เขียนทับ `app/build/web` ก่อน deploy เว็บหลักรอบถัดไปต้อง build ใหม่ตามขั้น 3

วิธีเตรียมปฏิทินและเวลาที่ใช้อัดอยู่ใน [DEMO.md](DEMO.md)

## ตั้งค่า OAuth (Google Cloud Console > APIs & Services)

- **Credentials** > OAuth client ที่ขึ้นต้นด้วย `945826169258-`
  - Authorized redirect URIs: `https://fontokmai-api-lmr33aj5zq-as.a.run.app/oauth2callback`
  - Authorized JavaScript origins: `https://ai-cup-511208.web.app`
- **OAuth consent screen**
  - Scopes: `openid`, `email`, `calendar.readonly`, `gmail.readonly`
  - ถ้ายังเป็น Testing คนที่ login ได้ต้องอยู่ใน Test users
  - ถ้ากด Publish (In production) แบบยังไม่ verify ทุกคน login ได้ แต่จะเห็นหน้า "Google hasn't verified this app" ต้องกด Advanced ก่อน
  - การ verify จริงใช้เวลาหลายวัน และ `gmail.readonly` เป็น restricted scope ต้องผ่าน security assessment (CASA) ถ้าจะ verify ให้พิจารณาตัด Gmail ออก

## Rollback

API กลับไป revision ก่อนหน้า (ไม่ต้อง build ใหม่)

```bash
gcloud run services update-traffic fontokmai-api --region asia-southeast1 --to-revisions fontokmai-api-00019-v9c=100
# กลับมาใช้ตัวล่าสุด
gcloud run services update-traffic fontokmai-api --region asia-southeast1 --to-latest
```

เว็บ: Firebase Console > Hosting > Release history > เลือกเวอร์ชันก่อนหน้า > Rollback

## ข้อควรระวัง

- **Token ของผู้ใช้เก็บในหน่วยความจำของ instance** จึงต้องมี instance เดียวเปิดตลอด ทุกครั้งที่ deploy API ใหม่หรือ instance restart ผู้ใช้ต้องกด Connect Google ใหม่ (งานต่อไป: ย้าย token ไปเก็บใน Firestore)
- **ห้ามรัน `firebase init`** มันเขียนทับ `firebase.json` ให้ไปใช้โฟลเดอร์ `public` และสร้าง GitHub workflow ที่ build ด้วย npm ซึ่งใช้กับ Flutter ไม่ได้
- **`/v1/trips?email=` ยังไม่มีการยืนยันตัวตน** ใครรู้อีเมลก็อ่านทริปที่ sync ไว้ได้ อย่าแชร์ URL ของ API สาธารณะ
- **Client secret ของ OAuth เคยอยู่ในโค้ดและ git history** ให้ rotate หลังจบการแข่ง แล้วอัปเดต secret `GOOGLE_OAUTH_CLIENT_SECRET`
- ถ้าเพิ่ม env บน Cloud Run ให้เพิ่มในตารางข้างบนและใน `api/deploy/cloudrun.ps1` ด้วย

## ค่าใช้จ่ายและหลังจบงาน

- Cloud Run แบบเปิดตลอด 1 vCPU / 512 MiB ราว $1.5 ต่อวัน ส่วนอื่น (Hosting, Calendar/Gmail API, Gemini ระดับเดโม) ฟรีหรือหลักเซนต์
- ตั้ง budget alert ที่ Cloud Console > Billing > Budgets
- หลังจบงาน ลดเหลือศูนย์เมื่อไม่มีคนใช้

```bash
gcloud run services update fontokmai-api --region asia-southeast1 --min-instances 0
```
