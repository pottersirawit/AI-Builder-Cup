# สถานที่ของฉัน, onboarding และ empty states

Status: draft 2026-10-08 (decided by Claude on the owner's delegation; correct anything).

## Principles

- Ask nothing up front that the app can work without. The ask bar works with zero setup (PRODUCT.md principle 3); home and work make it *proactive*.
- Aha moment = the first verdict card for a real trip. Onboarding is one optional screen whose only job is to get home (and optionally work) so the app can warn about the commute home.
- Every empty state says what is missing, why it matters in one line, and offers the one action that fixes it, inline where the user is. Never a dead end.
- Places live on the device (shared_preferences). The server never stores them; the app sends coordinates with each request.
- Demo: a "โปรไฟล์เดโม (มิว)" preset loads the scripted places; a reset brings back first-run. Builds default to the demo profile while `DEMO_CLOCK` is set, so the video still works.

## Place model

`SavedPlace { id, kind: home|work|other, label_th (e.g. บ้าน, ที่ทำงาน, ยิม), name_th (resolved address/landmark), lat, lng, icon, days? (work only, default Mon–Fri), leave_time? (work only, usual time to go home, default 18:00) }`

Constraints: at most one home and one work; up to 8 others; a place within 150 m of an existing one is a duplicate (offer to update instead); outside the Bangkok bounding box (13.49–14.10 N, 100.30–100.95 E) is allowed but labelled "นอกพื้นที่ที่แอปรองรับ" — verdicts still compute rain, flood spots/canal data won't exist.

## Ways to set a place

1. **ใช้ตำแหน่งตอนนี้** — GPS → reverse geocode → confirm sheet showing name + small map pin preview (static, no map SDK) + editable label.
2. **ค้นหา** — type Thai/English → `/v1/places/search` → result list → confirm sheet.
3. **From a Calendar event / ask answer** — "บันทึกที่นี่ไว้" chip on a trip whose destination isn't saved.
4. **Edit / delete** from Settings; delete asks confirmation via snackbar undo (not a dialog).

## Scenario matrix

| # | Situation | What the user sees |
|---|---|---|
| 1 | First launch, nothing set | Onboarding screen: headline "ให้แอปเตือนก่อนกลับบ้าน", two rows บ้าน / ที่ทำงาน each with "ใช้ตำแหน่งตอนนี้" and "ค้นหา", primary "เริ่มใช้" (enabled anytime), text button "ข้ามไปก่อน". Also "ใช้โปรไฟล์เดโม" small link. |
| 2 | Skipped onboarding, no home, no work, no Calendar | Home: sky field with ask bar as the hero ("ไปไหน กี่โมง?"), board empty state: "ยังไม่มีทริป — ตั้งบ้านไว้ แอปจะเตือนก่อนเวลาเลิกงานทุกวัน" + button "ตั้งบ้าน". Place chips row shows "+ บ้าน" "+ ที่ทำงาน" ghost chips. |
| 3 | Home set, no work | Proactive home trip needs an origin: use current GPS at the user's usual leave time; board row "กลับบ้าน · จากตำแหน่งตอนนี้". Hint row "ตั้งที่ทำงานเพื่อให้เตือนได้แม่นขึ้น". |
| 4 | Work set, no home | Board hint "ตั้งบ้านเพื่อให้เตือนตอนกลับ"; flood tab shows empty state (row 8). |
| 5 | Home and work set | Daily synthetic trip "กลับบ้าน" from work at leave_time on work days (source: routine-from-settings), plus Calendar/Gmail trips. Weekend: no commute trip. |
| 6 | Ask "กลับบ้าน" with no home | Answer card asks inline: "ยังไม่รู้ว่าบ้านอยู่ไหน" + "ใช้ตำแหน่งตอนนี้" / "ค้นหา"; after saving, the question re-runs automatically. Same for "ไปทำงาน". |
| 7 | Ask a place not saved and not resolvable | Server returns `needs_place` with candidates from search; app shows "หมายถึงที่ไหน" choice list; none → search field prefilled. |
| 8 | Flood tab with no home | Empty state: "ตั้งบ้านเพื่อดูความเสี่ยงน้ำท่วมหน้าบ้าน" + set-home actions; below it, still allow "ดูรายงานน้ำท่วมใกล้ฉัน" (uses GPS). |
| 9 | Home set but no canal station within 3 km | Flood tab shows rain + nearby BMA flood spots + community reports, and an honest note "ไม่มีสถานีวัดระดับคลองใกล้บ้าน" (source label). |
| 10 | Home outside Bangkok | Allowed, badge "นอกพื้นที่ที่รองรับ"; flood tab explains limited data. |
| 11 | Location permission not yet asked | "ใช้ตำแหน่งตอนนี้" triggers the OS prompt with a one-line rationale first. |
| 12 | Permission denied / denied forever | Inline message "ไม่ได้รับสิทธิ์ตำแหน่ง" + "เปิดการตั้งค่า" (app settings) + fallback "ค้นหาแทน". Never loop the prompt. |
| 13 | Location services off | "ตำแหน่งปิดอยู่" + open location settings + search fallback. |
| 14 | GPS timeout / low accuracy (> 200 m) | Show the result with "ตำแหน่งอาจคลาดเคลื่อน ~N ม." and let user adjust via search; timeout → retry or search. |
| 15 | Search: typing | Debounced 300 ms, min 2 chars, skeleton rows. |
| 16 | Search: no results | "ไม่พบ \"…\"" + tips ("ลองพิมพ์ชื่อสถานี BTS หรือห้าง") + "ใช้ตำแหน่งตอนนี้". |
| 17 | Search / reverse offline or API down | Local fallback list of Bangkok landmarks (bundled), labelled "ข้อมูลในเครื่อง"; error with retry. |
| 18 | Duplicate place | Confirm sheet says "ใกล้กับ ‘ยิม’ ที่บันทึกไว้" → "อัปเดตที่เดิม" or "บันทึกแยก". |
| 19 | Home == work (within 150 m, e.g. work from home) | Allowed; commute trip disabled; hint "ทำงานที่บ้าน — แอปจะเตือนเฉพาะทริปอื่น". |
| 20 | Delete home | Snackbar undo; proactive trips and flood tab fall back to rows 2/8. |
| 21 | Too many others (8) | Add button disabled with reason. |
| 22 | Calendar off / not connected | Settings row shows state: ยังไม่เชื่อมต่อ → "เชื่อมต่อ" button; connecting spinner; connected shows account; error with retry. Home board footnote "เชื่อม Calendar เพื่อให้แอปเห็นนัด" once, dismissible. (OAuth itself is stubbed until the AI/Calendar work lands — button shows "เร็ว ๆ นี้" in non-demo builds.) |
| 23 | Calendar connected but no events with a location in the next 24 h | Board shows commute trip only; footnote "ไม่มีนัดที่มีสถานที่ใน 24 ชม.". |
| 24 | Calendar event location can't be resolved | Board row "ไม่รู้ว่าที่ไหน" + "เลือกสถานที่" → search prefilled with the event's location text. |
| 25 | Notifications permission denied | Settings banner "ปิดการแจ้งเตือนอยู่ แอปเตือนก่อนออกไม่ได้" + open settings. |
| 26 | Demo profile active | Small "เดโม" badge in header; Settings: "ออกจากโปรไฟล์เดโม" resets to first-run. |

## API additions (contract v1, additive)

- `POST /v1/decide` accepts `origin` and `destination` objects `{name_th, lat, lng}` instead of `trip_id`; when present they build an ad-hoc trip (`source:"app"`). Optional `places` array (the user's saved places) so free-text questions resolve against the user's own places rather than the demo list. If a question names no resolvable place: `200` with `{"needs_place": {"query_th": "...", "candidates": [Place...]}}` and no verdict fields.
- `GET /v1/home-status?lat=&lng=&name_th=` computes for that point (nearest canal station within 3 km or `canal: null`, flood spots within 2 km, reports within 500 m). Without params: demo home.
- `GET /v1/places/search?q=` → `{"places":[{name_th, address_th, lat, lng, source:"google"|"local"}]}` using Google Places Text Search (New) when `GOOGLE_MAPS_API_KEY` is set, else a bundled Bangkok landmark list (BTS/MRT stations, malls, districts, the demo places).
- `GET /v1/places/reverse?lat=&lng=` → `{name_th, address_th, in_service_area: bool, source}` via Geocoding API, else nearest landmark.
