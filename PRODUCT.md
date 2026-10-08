# Product

<!-- impeccable:product-schema 1 -->

> Facts marked *(inferred)* were filled in by Claude on 2026-10-07 from prior session decisions and the repo, because the owner delegated decisions overnight. Confirm or correct them.

## Platform

android

Flutter app shipped to Android first and iOS second (Thailand is Android-majority *(inferred)*). One Material 3–based design language on both; iOS still gets safe areas, Reduce Motion and edge-swipe back.

## Stack

Flutter (app/) + Go API on Cloud Run (api/) + Gemini (Vertex AI / AI Studio). Chosen by the owner on 2026-10-07. The teammate's Phase 1 LINE gateway (gateway/) and Python engine (engine/) remain in the repo as the LINE channel.

## Users

Bangkok commuters, hero persona มิว: office worker in Silom, lives in Lat Phrao near Khlong Lat Phrao, drives home along Rama 4 → Ratchada. The job: at the end of the workday, decide *when* and *how* to travel so rain and street flooding do not wreck the trip. Secondary: people whose home is flood-prone and need to act in the minutes before water arrives. Tertiary *(inferred)*: neighbours without smartphones reached via LINE/SMS/voice.

## Product Purpose

Answer one question before the user thinks to ask it: "ควรออกเดินทางตอนนี้ไหม". A Gemini agent reads the user's upcoming trips (Google Calendar, Gmail tickets, or a plain-Thai question), checks rain along the actual route against Bangkok flood-spot thresholds for the user's vehicle, and returns a verdict with leave-by time, reasons, sources and confidence. Flood is the severe mode of the same answer. Success: the user leaves at the suggested time and stays dry/safe; judges of AI Builder Cup 2026 see Gemini acting as an agent, not a chatbot.

## Positioning

"แชทตอบคำถาม — ฝนตกไหมตอบก่อนที่คุณจะถาม." General chat answers when asked and at city level; this app is proactive (Calendar-triggered), route- and time-specific, vehicle-aware (sedan / BTS-MRT / motorbike verdicts differ), and fed by community flood photos assessed by Gemini vision and fanned out to people on the same route.

## Operating Context

Glanced at on a phone at a desk at 16:10, on a sidewalk, or at home at night during a storm, often one-handed and in a hurry. Push notification is the main entry point; the app opens to a verdict, not a dashboard. Demo context: a 3-minute video and a live judged prototype on Cloud Run.

## Capabilities and Constraints

- Trip entry: plain-Thai ask bar (works with nothing connected), Calendar, Gmail e-tickets, learned routine (future).
- Verdict per trip and per mode: leave now / wait until / switch mode / don't go, leave-by time, rain timeline on route, flood spots on route, confidence, sources, reasoning trace.
- Community flood reports: photo → Gemini vision depth estimate → notify users whose route passes within ~300 m.
- Flood mode for home: canal level (ThaiWater), ordered action checklist, neighbours alerted.
- Bangkok only. Thai UI only for now (English name undecided).
- Data constraints: BMA drainage data has no public API; Google Flood Hub API is waitlisted; WeatherNext data access is unconfirmed. A demo clock replays the scripted 2026-09-29 storm so the demo is reproducible.

## Brand Commitments

- Name: ฝนตกไหม (Thai only for now).
- Voice: plain spoken Thai, "ภาษาคน ไม่ใช่กรมอุตุ" — verdict first, numbers second.
- Owner's binding visual constraint: bright sky-blue palette in the family of Google / Gemini; dark tone in flood mode; Chakra Petch typeface (from the approved prototype `fontokmai.html`).
- Every card shows its data source.

## Evidence on Hand

- `fontokmai.html` — approved clickable prototype (copy, screens, scenario numbers).
- `architecture.html` — honest architecture page with data-access risks.
- `data/bkk_flood_risk_points.json` — BMA flood-prone spots with rain thresholds and vehicle risk (teammate).
- All scenario numbers (มิว, 27 users notified, 84% confidence, etc.) are synthetic demo data and must be labelled as such; there are no real users, testimonials or accuracy benchmarks yet.

## Product Principles

1. Verdict before data: the first thing on screen is what to do and by when.
2. Show your sources and your confidence; never fake certainty.
3. Works with nothing connected; connecting Calendar/Gmail makes it proactive, not possible.
4. The same question escalates — rain advice and flood emergency are one product, one voice.
5. Reach people beyond the app (neighbours, LINE, voice) when it is an emergency.

## Accessibility & Inclusion

Thai script needs generous line height and must stay legible at large system font scales; flood mode is used under stress and possibly low battery/dim light — high contrast, large targets (48 dp), no information conveyed by colour alone *(inferred)*.
