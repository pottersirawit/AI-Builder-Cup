# สรุปเช้านี้สำหรับนายท่าน (2026-10-18 วันส่งงาน)

สรุปสั้นที่สุด: ทีมแก้ให้แอปใช้บัญชี Google จริงได้ครบแล้วในโค้ด (login จริง, ดึง Calendar และ Gmail จริง, ไม่โชว์ข้อมูลของ มิว ให้บัญชีจริง, ไม่มีภาษาไทยหลุดในโหมดอังกฤษ, หน้าโหลดเต็มหน้าแบบไม่กระตุก) ทุกอย่าง commit ไว้ในเครื่องบน branch `feat/summary-events-redesign` แล้ว ยังไม่ได้ push และยังไม่ได้ deploy

สิ่งที่นายท่านต้องทำเองก่อนเล่นมีอย่างเดียวที่สำคัญที่สุด คือ **deploy API ขึ้น Cloud Run ก่อน แล้วค่อย deploy เว็บขึ้น Firebase Hosting** เพราะตอนนี้ API ที่รันอยู่บน Cloud Run ยังเป็นตัวเก่า ปุ่ม Connect Google จะขึ้น 404 และอีเมลจริงจะได้อีเวนต์ของ มิว กลับมา

คำถามของนายท่านเมื่อคืน "ควรสร้างอีเวนต์ไว้ใน Calendar ใช่ไหม" คำตอบคือใช่ ควรสร้างไว้ก่อนเล่น 4 ถึง 6 อีเวนต์ตามหัวข้อ 4 ด้านล่าง เพราะบัญชีจริงที่ไม่มีอีเวนต์จะเห็นหน้าว่าง (ซึ่งตั้งใจให้เป็นแบบนั้น ไม่เอาข้อมูลปลอมมาเติม)

---

## 1. ทีมทำอะไรไปเมื่อคืน

Commit ทั้งหมดตั้งแต่ `fd60f03` บน branch นี้ เรียงตามเรื่อง (ใหม่อยู่บน)

### Login Google จริง (OAuth)
- `823a2a2` fix(api): server สร้างลิงก์ login เอง, แลก token ให้เสร็จก่อนตอบกลับ, อ่านอีเมลจริงจาก Google แทนอีเมลที่พิมพ์เอง และต่ออายุ token อัตโนมัติ ผลคือ login ครั้งเดียวได้ทั้ง Calendar และ Gmail และไม่หลุดหลังหนึ่งชั่วโมง
- `7aa9035` feat(api): แอปถาม server ได้ว่าการ login เสร็จหรือยัง (poll ด้วย nonce)
- `325d273` fix(app): หน้า Connect Google หน้าเดียว ไม่มีช่องพิมพ์อีเมล รอจนนายท่านกดยินยอมจริงก่อนจึงขึ้นว่าเชื่อมต่อแล้ว
- `aba55ca` fix(app): หน้าต่าง Google ปิดเองเฉพาะเมื่อเป็นการ login ที่เปิดจากหน้านั้นจริง

### ไม่เอาข้อมูลของ มิว มาปนกับบัญชีจริง
- `38318e2` fix(api): บัญชีจริงไม่ได้อีเวนต์ของ มิว อีกแล้ว ถ้ายังไม่มีอะไร sync จะได้รายการว่าง
- `1f826da` fix(app): ถ้า server วางแผนไม่สำเร็จ บัญชีจริงจะเห็นข้อความ "Couldn't work out when to leave" พร้อมปุ่ม Retry แทนเหตุผลปลอมของ มิว และไม่ขึ้นป้าย Sample data

### วางแผนจากบ้านของนายท่านเอง และ Gemini อ่าน Gmail
- `f5d3b4b` fix(api): เวลาออกจากบ้านคิดจากบ้านที่นายท่านบันทึกไว้ ไม่ใช่บ้านของ มิว อีเมลถูกส่งให้ Gemini อ่าน และเก็บเฉพาะอีเมลที่ Gemini เจอทั้งเวลาและสถานที่ ไม่เดาวันเองอีก
- `c06a43f` feat(app): แอปส่งบ้านที่บันทึกไว้ไปตอน sync Calendar และ Gmail
- `069ea9c` feat(api): รู้จักประชุมออนไลน์ (Meet, Zoom, Teams) และเวลาจบของอีเวนต์

### ภาษาอังกฤษไม่มีไทยหลุด
- `8375fd9` fix(api): คำตอบภาษาอังกฤษไม่มีไทยสำหรับอีเวนต์ไม่มีชื่อ จุดน้ำท่วม และเบอร์ฉุกเฉิน
- `e577c00` fix(app): ข้อมูลตัวอย่างมีฉบับภาษาอังกฤษแล้ว โหมด EN ไม่มีไทยหลุด
- `9996347` fix(app): ข้อความเตือนภาษาไทยเว้นวรรครอบชื่ออีเวนต์และสถานที่ เช่น "ไป AI Builder Cup final pitch ไม่ทัน" แทนข้อความที่ติดกันเป็นพืด

### หน้าตาตอนโหลด (เรื่องที่นายท่านถามว่าโหลดแล้วโชว์ครึ่งหน้า)
- `faa21b2` feat(app): ตอนโหลดครั้งแรกขึ้นโครงเต็มหน้า (skeleton) ทั้ง Summary และ Events ขนาดเท่าของจริง พอโหลดเสร็จจะค่อย ๆ fade เข้ามา ไม่มีอะไรกระโดด
- `a35477e` fix(app): หัวข้อหน้าไม่ซ้อนทับกันตอนเปลี่ยนจาก skeleton เป็นหน้าจริง

### Deploy
- `2b87476` chore(deploy): มี `firebase.json` และ `.firebaserc` ที่ root แล้ว, หน้า splash สีเข้ม, สคริปต์ Cloud Run ตั้งค่าโหมดจริงเป็นค่าเริ่มต้น (DEMO_MODE=0, instance เดียวเปิดตลอด, CPU ไม่ถูกบีบ, APP_URL ชี้ Firebase)
- `6dead35` docs: เพิ่มลำดับ deploy ใน RUNNING.md หัวข้อ "Deploy ให้เล่นด้วยบัญชี Google จริง"

### งานเก่าที่อยู่ในช่วงเดียวกัน (ก่อนเมื่อคืน)
- `fb18a48`, `592326f`, `881b99c`: endpoint พยากรณ์อากาศ, ไอคอนแอป, หน้า Summary แบบวางแผนก่อนและ ticket ธีม night crystal

### สิ่งที่ยังไม่ได้ทำ และเหตุผล
- **ยังไม่ได้ deploy และยังไม่ได้ push** เพราะนายท่านสั่งไว้ และเครื่องนี้ไม่มี firebase CLI กับ gcloud ยังไม่ได้ login
- **Token และอีเวนต์ที่ sync ยังเก็บในหน่วยความจำของ server** ไม่ได้เก็บใน Firestore เพราะใช้เวลามากเกินคืนเดียว ทางแก้ชั่วคราวคือสคริปต์ deploy ตั้ง instance เดียวเปิดตลอดไว้แล้ว ถ้า redeploy API หลัง login ต้องกด Connect Google ใหม่
- **ข้อความ "Gemini อ่านจากอีเมลของคุณ" บน ticket ที่มาจาก Gmail** server ส่งมาแล้ว แต่ ticket ในแอปยังไม่แสดง
- **README ยังเล่าเป็นผลิตภัณฑ์เก่า** (LINE, Python, WeatherNext) ยังไม่ได้เขียนใหม่
- ไอเดียปรับปรุงอื่นจากกรรมการอยู่ในหัวข้อ 6

---

## 2. สถานะเทสต์ (รันเมื่อเช้านี้ก่อนเขียนสรุป)

- `cd app && flutter test` ได้ `00:07 +160: All tests passed!`
- `cd app && flutter analyze` มี 18 รายการ ทั้งหมดเป็นระดับ info ที่มีอยู่ก่อนแล้ว ไม่มี error
- `cd api && go test ./...` ได้ `Go test: 422 passed in 24 packages`
- `cd api && go vet ./...` ได้ `No issues found`
- Working tree สะอาด เหลือแค่โฟลเดอร์ `.claude/` ที่ไม่ได้ commit (ตั้งใจ)

---

## 3. ก่อนเล่น (ทำตามลำดับ)

ทุกคำสั่งรันจาก root ของ repo: `cd /Users/pottersirawit/potter_work/AI_BUILDER_HACKATHON`

**ขั้น 1. ดูงานเมื่อคืนและรันเทสต์ซ้ำ**

```bash
cd /Users/pottersirawit/potter_work/AI_BUILDER_HACKATHON
git log --oneline main..HEAD
(cd api && go test ./... && go vet ./...)
(cd app && flutter analyze && flutter test)
```

**ขั้น 2. Login เครื่องมือ**

```bash
gcloud auth login
gcloud config set project ai-cup-511208
npm i -g firebase-tools
firebase login
```

ถ้าโปรเจกต์ยังไม่ได้เปิด Firebase ให้รัน `firebase projects:addfirebase ai-cup-511208` (หรือกด Add Firebase ใน Firebase console เลือกโปรเจกต์ ai-cup-511208)

**ขั้น 3. เปิด API ของ Google ที่ต้องใช้**

```bash
gcloud services enable calendar-json.googleapis.com gmail.googleapis.com
```

**ขั้น 4. ตั้งค่าหน้า OAuth consent screen** (Cloud Console > APIs & Services > OAuth consent screen)
- Publishing status เป็น Testing
- เพิ่ม Gmail ของนายท่านใน Test users (ขาดข้อนี้จะ login ไม่ได้ เพราะ `gmail.readonly` เป็น scope แบบ restricted)
- Scopes ต้องมี `openid`, `email`, `calendar.readonly`, `gmail.readonly`

**ขั้น 5. ตั้งค่า OAuth client** (Cloud Console > APIs & Services > Credentials > client ที่ขึ้นต้นด้วย `945826169258-`)
- Authorized redirect URIs ต้องมีตรงตัวอักษร: `https://fontokmai-api-lmr33aj5zq-as.a.run.app/oauth2callback`
- Authorized JavaScript origins เพิ่ม `https://ai-cup-511208.web.app` และ `https://ai-cup-511208.firebaseapp.com`

**ขั้น 6. เช็ก secret**

```bash
gcloud secrets list --project ai-cup-511208
```

ต้องมี `GEMINI_API_KEY` (ถ้าไม่มี สคริปต์ deploy จะหยุดและบอกวิธีสร้าง) ส่วน `GOOGLE_OAUTH_CLIENT_ID` และ `GOOGLE_OAUTH_CLIENT_SECRET` ถ้ามีสคริปต์จะ mount ให้เอง ถ้าไม่มี server ใช้ค่าที่ฝังในโค้ดซึ่งใช้ได้สำหรับวันนี้ (ถ้าอยากย้าย secret ออกจากโค้ดตอนนี้เลย ทำแบบนี้ ไม่บังคับ)

```bash
printf '%s' '<client secret>' | gcloud secrets create GOOGLE_OAUTH_CLIENT_SECRET --data-file=-
gcloud secrets add-iam-policy-binding GOOGLE_OAUTH_CLIENT_SECRET \
  --member=serviceAccount:945826169258-compute@developer.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor
```

**ขั้น 7. Deploy API ขึ้น Cloud Run ก่อน (สำคัญที่สุด)**

```bash
PROJECT=ai-cup-511208 DEMO_MODE=0 REPORT_STORE=memory api/deploy/cloudrun.sh
```

ดิฉันเช็กสคริปต์แล้ว มันตั้ง `--min-instances 1 --max-instances 1 --no-cpu-throttling` และ `APP_URL=https://ai-cup-511208.web.app` ให้อยู่แล้ว ไม่ต้องรัน `gcloud run services update` เพิ่ม

**ขั้น 8. Smoke test API**

```bash
U=https://fontokmai-api-lmr33aj5zq-as.a.run.app
curl -s $U/v1/health
curl -s -o /dev/null -w '%{http_code}\n' "$U/v1/outlook?lat=13.74&lng=100.53"
curl -sI "$U/v1/oauth/start?return=https://ai-cup-511208.web.app/&nonce=abcdefgh1234" | head -3
curl -s "$U/v1/trips?email=someone@example.com"
```

สิ่งที่ต้องเห็น: outlook ได้ `200`, oauth/start ได้ `302` ไปที่ `accounts.google.com` (ถ้าได้ `404` แปลว่ายังเป็น API ตัวเก่า), trips ได้วันที่วันนี้และ `trips: []` ห้ามเห็น "Dinner with family" หรือ "Concert at IMPACT" ของ มิว

**ขั้น 9. Build เว็บแบบโหมดจริง (ไม่ใส่ DEMO_CLOCK)**

```bash
cd app && python3 tool/l10n_merge.py && flutter gen-l10n \
  && flutter build web --release --dart-define=API_BASE_URL=https://fontokmai-api-lmr33aj5zq-as.a.run.app \
  && cd ..
```

(URL นี้เป็นค่าเริ่มต้นใน `app/lib/config.dart` อยู่แล้ว ใส่ไว้เพื่อความชัวร์)

**ขั้น 10. Deploy เว็บขึ้น Firebase Hosting**

```bash
firebase deploy --only hosting --project ai-cup-511208
```

แล้วเปิด https://ai-cup-511208.web.app

**ขั้น 11. ทางสำรองถ้า login จริงพังตอนสาธิต** ทำเว็บโหมดเดโม่ไว้บน channel แยก (ไม่ทับเว็บหลัก)

```bash
cd app && flutter build web --release --dart-define=DEMO_CLOCK=16:10 \
  --dart-define=API_BASE_URL=https://fontokmai-api-lmr33aj5zq-as.a.run.app && cd ..
firebase hosting:channel:deploy demo --project ai-cup-511208
```

คำสั่งนี้เขียนทับ `app/build/web` ก่อน deploy เว็บหลักรอบถัดไปต้อง build แบบขั้น 9 ใหม่ทุกครั้ง

**ขั้น 12. Push และเปิด PR เมื่อพอใจเท่านั้น**

```bash
git push -u origin feat/summary-events-redesign
gh pr create --base main
```

หลังจบการแข่ง ให้ rotate OAuth client secret เพราะมันอยู่ใน git history แล้ว

---

## 4. สร้างข้อมูลจริงสำหรับทดสอบ

### สิ่งที่ server ดึงมา (ดิฉันอ่านจาก `api/internal/httpapi/google_workspace.go`)
- **Calendar**: ปฏิทินหลัก (primary) ตั้งแต่ 24 ชั่วโมงก่อนถึงอีก 1 เดือนข้างหน้า สูงสุด 25 อีเวนต์ อีเวนต์ซ้ำถูกแตกเป็นรายครั้ง
  - มีลิงก์ Meet หรือ conference data หรือช่อง Location เป็น URL หรือมีคำว่า zoom, teams, google meet จะนับเป็นประชุมออนไลน์ (ไม่ต้องเดินทาง)
  - อีเวนต์ทั้งวันนับเป็น All day
  - ช่อง Location ที่หาพิกัดไม่เจอ แอปจะถามนายท่านว่าที่นั่นอยู่ไหน
  - อีเวนต์ที่อยู่ติดกันในวันเดียวกันและห่างกันไม่นาน จะคิดจุดเริ่มต้นจากอีเวนต์ก่อนหน้าแทนบ้าน
- **Gmail**: ค้นด้วย query นี้ แล้วเอา **6 ฉบับล่าสุด** ที่ตรง

  ```
  (ticket OR booking OR reservation OR flight OR concert OR hotel OR event) -category:promotions -category:social
  ```

  แต่ละฉบับถูกส่งให้ **Gemini อ่านเนื้อหา** (format=full) ระบบเก็บเป็นทริปเฉพาะเมื่อ Gemini ตอบว่าเป็นทริป และเจอทั้ง **เวลาเริ่ม** และ **สถานที่** วันที่ส่งอีเมลไม่ถูกใช้เป็นวันของงาน ถ้า Gemini ไม่ได้ตั้งค่าบน Cloud Run จะไม่มีทริปจาก Gmail เลย (ตั้งใจ)

### อีเวนต์ที่ควรสร้าง (ตัวอย่าง สมมติเริ่มเล่นราว 09:00)

| # | เพื่อทดสอบ | ชื่อ | เวลา | Location |
|---|---|---|---|---|
| 1 | อีเวนต์ปกติในอีกไม่กี่ชั่วโมง | Lunch with the team | วันนี้ 12:00 ถึง 13:00 | Siam Paragon, Rama I Rd, Pathum Wan, Bangkok |
| 2 | สองนัดติดกันต่างเขต (ไปไม่ทัน) | Client meeting | วันนี้ 14:00 ถึง 15:00 | Samyan Mitrtown, Rama IV Rd, Bangkok |
| 3 | (คู่กับข้อ 2) | Coffee at ICONSIAM | วันนี้ 15:15 ถึง 16:00 | ICONSIAM, Charoen Nakhon Rd, Khlong San, Bangkok |
| 4 | ประชุมออนไลน์ | Design sync | วันนี้ 10:30 ถึง 11:00 | ไม่ใส่ Location แต่กด "Add Google Meet video conferencing" |
| 5 | ทั้งวัน | AI Builder Cup submission day | วันนี้ ติ๊ก All day | เว้นว่าง |
| 6 | ไม่มีสถานที่ | Call mom | วันนี้ 19:00 ถึง 19:15 | เว้นว่าง |
| 7 | ช่วงฝนตก | Dinner at Central World | ช่วงที่บรรทัดอากาศในแอปบอกว่าฝนจะมา (ส่วนใหญ่บ่ายถึงเย็น เช่น 17:30) | CentralWorld, Ratchadamri Rd, Bangkok |
| 8 | วันพรุ่งนี้ (หน้า Events แยกวัน) | Morning run | พรุ่งนี้ 07:00 | Lumphini Park, Bangkok |

ข้อ 2 กับ 3 ห่างกันแค่ 15 นาทีจากสามย่านไปฝั่งธน ควรขึ้นเตือนว่าไปไม่ทันหรือเวลาเผื่อน้อยใน "Before you go" ส่วนข้อ 7 ฝนตกจริงไม่ได้ ให้เปิดแอปดูบรรทัดอากาศก่อน แล้วย้ายเวลาอีเวนต์ไปอยู่ในช่วงที่พยากรณ์ว่าฝนมา

### อีเมลที่ควรส่งหาตัวเอง (Gmail)
ส่งจาก Gmail ของนายท่านไปหาตัวเอง หัวเรื่องต้องมีคำใดคำหนึ่งใน query ข้างบน และเนื้อหาต้องมีวันเวลาและสถานที่ชัดเจน (ใช้วันในอนาคต)

ตัวอย่างที่ 1 (คอนเสิร์ต)

```
Subject: Your ticket confirmation - Bangkok Jazz Night
Body:
Thank you for your booking.
Event: Bangkok Jazz Night
Date: 19 October 2026
Doors open: 19:00
Venue: Thunder Dome, Muang Thong Thani, Nonthaburi
Seat: B12
```

ตัวอย่างที่ 2 (รถไฟหรือเที่ยวบิน)

```
Subject: Booking confirmed: train to Chiang Mai
Body:
Booking reference: TH12345
Train: Special Express 9
Departure: 20 October 2026 at 18:40
Station: Krung Thep Aphiwat Central Terminal, Bangkok
Arrive at the station 30 minutes before departure.
```

หลัง Connect Google แล้ว อีเมลเหล่านี้ควรขึ้นเป็น ticket ในหน้า Events ตามวันที่ ถ้าไม่ขึ้น ให้ลอง pull to refresh และเช็กว่าอีเมลไม่ได้เข้าแท็บ Promotions

---

## 5. ลองเล่นยังไง (10 ขั้น)

1. **เปิดหน้าต่าง Incognito** แล้วไปที่ https://ai-cup-511208.web.app (กันข้อมูล มิว ที่ cache ไว้) ดีคือ ขึ้นภาษาอังกฤษเป็นค่าเริ่มต้น และตอนโหลดเห็นโครงเต็มหน้าแล้วค่อย fade เป็นหน้าจริง ไม่กระโดด
2. **ข้ามโปรไฟล์ มิว และบันทึกบ้านจริง** ดีคือ ไม่มีป้าย Demo และไม่มีป้าย Sample data
3. **Settings > Connect Google** เลือกบัญชี กด Advanced > Go to … (unsafe) แล้วอนุญาตทั้ง Calendar และ Gmail ดีคือ เด้งกลับเข้าแอปเอง และขึ้นว่าเชื่อมต่อแล้ว
4. **หน้า Summary** ดีคือ ticket ใหญ่ด้านบนเป็นนัดถัดไปจริงของนายท่าน (Lunch with the team) มีเวลาที่ควรออก วงนับถอยหลัง และของที่ควรพก เวลาออกคิดจากบ้านที่บันทึกไว้
5. **กล่อง "Before you go"** ดีคือ มีเตือนเรื่อง Client meeting กับ Coffee at ICONSIAM ว่าไปไม่ทันหรือเผื่อเวลาน้อย และถ้ามีนัดช่วงฝน จะเตือนเรื่องฝน
6. **หน้า Events** ดีคือ ticket แยกตามวัน มีชิปเลือกวัน, Design sync ขึ้นว่าออนไลน์, All day ไม่มีเวลาออก, Call mom ไม่มีสถานที่ก็ไม่พัง, อีเมลตั๋วขึ้นในวันที่ถูก
7. **กดเข้าไปดูรายละเอียดหนึ่ง ticket** ดีคือ เห็นเหตุผลที่ Gemini ให้ (ช่วงไหนฝน ไปทางไหน) และตรงกับเวลาออกบนหน้า Summary ถ้าเป็นอีเวนต์ที่หาสถานที่ไม่เจอ แอปจะถามว่าอยู่ไหน
8. **ปุ่ม Ask (ประกายดาว) ถาม Gemini** เช่น "Should I leave for Siam Paragon at 6pm?" ดีคือ ได้คำตอบภาษาอังกฤษ มีเหตุผลและแหล่งข้อมูล ไม่ค้าง
9. **สลับภาษาเป็นไทยใน Settings แล้วกลับเป็นอังกฤษ** ดีคือ โหมดไทย ข้อความเตือนเว้นวรรครอบชื่ออีเวนต์อังกฤษ เช่น "ไป Coffee at ICONSIAM ไม่ทัน" และโหมดอังกฤษ ไม่มีภาษาไทยหลุด ยกเว้นชื่ออีเวนต์ที่นายท่านพิมพ์เป็นไทยเอง
10. **Pull to refresh และเปิดแท็บใหม่** ดีคือ ข้อมูลยังเป็นของนายท่าน ไม่มีของ มิว โผล่ ถ้าเห็นหน้าว่างพร้อมข้อความ Connect ให้ต่อ Google ใหม่ (server อาจ restart แล้ว token หาย)

ถ้าเจออะไรแปลก จดไว้พร้อม screenshot แล้วบอกดิฉัน ทีมจะแก้ต่อเป็นรอบถัดไป

---

## 6. ไอเดียจากกรรมการที่เลื่อนไว้ และความเสี่ยงที่ยังเปิดอยู่

### ไอเดียที่คุ้มที่สุด (ยังไม่ได้ทำ)
1. **ทำให้ Gemini มองเห็นบนหน้า Summary**: เพิ่มบรรทัด "Gemini · 84% sure · 3 sources" ใต้ ticket ใหญ่ กดแล้วเปิดเหตุผลเต็ม กรรมการต้องเห็นภายใน 3 นาทีว่ามี agent ตัดสินใจ (Gen AI = 40% ของคะแนน)
2. **เขียน README ใหม่**: pitch หนึ่งประโยค, URL ของเว็บจริง, screenshot, สถาปัตยกรรม (Flutter web บน Firebase Hosting, Go API บน Cloud Run, Gemini agent พร้อม tools และ guardrails, Calendar/Gmail OAuth) และย้ายเรื่อง LINE, Python, WeatherNext ไปหัวข้ออนาคต กรรมการอ่าน README ก่อน
3. **ช่อง Ask Gemini ที่เด่นขึ้น** พร้อมชิปตัวอย่างในหน้าว่าง และปุ่ม Refresh/Ask ในหน้า Events ตอนว่าง
4. **แสดง "Read by Gemini from your email"** บน ticket ที่มาจาก Gmail (server ส่งมาแล้ว แก้แค่ฝั่งแอป)
5. ให้ "Go by" และเวลาบน ticket ใหญ่ตรงกับหน้ารายละเอียดเสมอ
6. จอเล็ก 360dp ตัวอักษรใหญ่ 2 เท่า: ให้เวลาออกย่อเองได้และวางวงนับถอยหลังไว้ใต้
7. อีเวนต์ทั้งวันไม่มีสถานที่: ซ่อนแถวหมุดว่างและไม่เขียน "All day" ซ้ำสองครั้ง
8. บรรทัดอากาศ: เอาเวลาฝนขึ้นก่อน และให้สีฝนต่างจากสีอีเวนต์ใน Today strip
9. Cache พยากรณ์และการตัดสินใจล่าสุด ให้เปิดครั้งที่สองขึ้นทันที
10. ขัดเกลา: "Today" ในวันที่ของอีเวนต์วันนี้, พื้นที่กดของ DemoClockChip 44dp, animation ตอนกดและ fade-up ทีละบล็อก
11. (ข้ามไว้) rewrite `/v1/**` ผ่าน Firebase Hosting ไป Cloud Run เพราะ timeout 60 วินาทีและต้องเปลี่ยน redirect URI

### ความเสี่ยงที่ยังเปิดอยู่
- **API บน Cloud Run ยังเป็นตัวเก่า** จนกว่านายท่านจะทำขั้น 7 ตัวเก่ายังบอกอีเมลของบัญชีอื่นผ่าน `/v1/oauth/status` ให้ใครก็ได้ที่เรียก ยิ่ง deploy เร็วยิ่งดี
- **Token อยู่ในหน่วยความจำ** ถ้า Cloud Run restart หรือ redeploy ต้อง Connect Google ใหม่
- **`/v1/trips?email=` ไม่มีการยืนยันตัวตน** ใครรู้อีเมลก็อ่านทริปได้ ไม่ควรแชร์ลิงก์ API สาธารณะระหว่างนี้
- **Client secret ฝังอยู่ในโค้ดและ git history** ต้อง rotate หลังจบการแข่ง
- **หน้า Google ขึ้นคำเตือน "unsafe"** เพราะแอปอยู่ในโหมด Testing และใช้ scope แบบ restricted ต้องกด Advanced ทุกครั้ง และใช้ได้เฉพาะบัญชีใน Test users ถ้ากรรมการจะลองด้วยบัญชีตัวเอง ต้องเพิ่มอีเมลเขาใน Test users ก่อน
- **ถ้าบันทึกบ้านหลังจาก Connect Google** ทริปจะยังคิดจากจุดเริ่มเดิมจนกว่าจะ pull to refresh จึงควรบันทึกบ้านก่อนกด Connect (ตามขั้น 2 ในหัวข้อ 5)
- **สถานะน้ำท่วมของบ้าน** ถ้า server ติดต่อไม่ได้ ยังใช้ข้อมูลตัวอย่างและขึ้นป้าย Sample data ได้ (เป็นแบบอิงตำแหน่ง ไม่ใช่ข้อมูลของ มิว)
- **หน้า /privacy ไม่มีอีเมลติดต่อแล้ว** ถ้า Google ขออีเมลติดต่อบนหน้านโยบาย ให้เพิ่มใน `api/internal/httpapi/static_pages.go`
- **โควตา Gemini**: ถ้าเกินโควตา Gmail จะไม่มีทริป และการวางแผนจะตกไปใช้ fallback ของ server
- `api/deploy/cloudrun.ps1` ยังไม่ได้ทดสอบ (เครื่องนี้ไม่มี pwsh) ให้ใช้ `cloudrun.sh`
