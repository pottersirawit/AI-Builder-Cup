# ฝนตกไหม — Design System

The app is a **personal departure board**, not a weather dashboard. The top trip is printed as a paper **pass** standing on a **sky-state field**; the only data texture is the **rain band**. Code lives in `app/lib/design/` (import `design/design.dart`). The live gallery is in the app at Settings → **ระบบดีไซน์**. It renders every token and component in each sky state and serves as the reference this file describes. Machine-readable tokens are in `.impeccable/design.json`.

## Principles

1. The verdict comes before the data. The pass's first line is what to do and by when, set in `displayMedium`.
2. Every block names its source with `SourceLabel`. Gemini vs fallback is shown with `GeneratedBy`. Synthetic demo numbers (notified users, neighbours, the พลอย persona) are labelled "ตัวเลขจำลอง".
3. Never use colour alone. Risk is always an icon, a word and a colour together (`RiskChip`).
4. One escalation. Clear sky, storm and flood are the same screens with a different ground. Flood switches the whole app to the dark scheme with a single amber accent.

## Sky states (the ground)

| State | When | Field top → bottom | Ink on field |
|---|---|---|---|
| `clear` | The trip's departure window has no rain ≥ 2.5 mm/hr and the verdict is "leave now" | `#0B57D0 → #5C9DFF` | `#FFFFFF` / muted `#D7E6FF` |
| `storm` | Rain ≥ 2.5 mm/hr during the trip, or the verdict is wait / switch / don't go | `#232B3E → #55617A` | `#FFFFFF` / `#C9D1E0` |
| `flood` | Home flood level is `danger` (overrides everything) | `#02060F → #0B1730` | `#F2F5FA` / `#A7B4CB` |

`skyFor()` in `lib/departure.dart` decides the state. `SkyField` paints the top 45% of the screen (or the whole header for short screens) and eases between states over 520 ms. On the Verdict screen, dragging the departure into the storm turns the ground slate live.

## Colour

Material 3 `ColorScheme`s live in `lib/design/theme.dart`: `lightScheme` (primary `#0B57D0`, surface `#F3F7FC`, onSurface `#0B1F3A`) and `floodScheme` (primary **amber** `#FFB020`, surface `#050B17`, onSurface `#F2F5FA`). Brand roles that Material has no slot for live in the `FonColors` ThemeExtension (`lib/design/tokens.dart`):

| Role | Light | Flood (dark) |
|---|---|---|
| paper / paperInk / paperMuted | `#FFFEFB` / `#0B1F3A` / `#55657D` | `#0F1A2E` / `#F2F5FA` / `#A7B4CB` |
| perforation | `#C6D3E4` | `#2A3A57` |
| rain 0–3 (none, light, moderate, heavy) | `#DCE7F5 #9CC4FF #4A8FF5 #1A4FB8` | `#17233A #34558A #5F8FD6 #A9CBFF` |
| riskLow / container | `#137333` / `#E3F3E7` | `#8FD4A4` / `#12301F` |
| riskMedium / container | `#9A5200` / `#FFF0D9` | `#FFC34D` / `#3A2A06` |
| riskHigh / container | `#B3261E` / `#FCE4E2` | `#FFB020` / `#402A00` |
| warning | `#E8A100` | `#FFB020` |
| marker (rain-band handle) | `#0B1F3A` | `#FFB020` |

The Gemini gradient (`#4285F4 → #9B72CB → #D96570`) is used **only** on the Gemini spark icon and the report scan line, never on text.

## Type

The face is **Chakra Petch** (bundled in `app/assets/fonts`, so it works offline). Chakra Petch has proportional digits and no `tnum` feature, so `tool/tabular_font.py` derives **Petch Tabular**: the same font with all ten digits on one centred advance. Apply it with `tabular(style)` to any time, distance, percentage or count. The verdict headline uses it too, because "ออกก่อน 16:45" must not jitter while the drag re-letters it.

| Material role | Size / line height / weight | Use |
|---|---|---|
| displayMedium | 42 / 1.2 / 700, −0.8 | Verdict headline |
| displaySmall | 34 / 1.22 / 700 | Flood headline, report depth |
| headlineSmall | 22 / 1.35 / 700 | Field title |
| titleLarge | 20 / 1.4 / 700 | Section heading, board time |
| titleMedium / titleSmall | 16, 14 / 1.45 / 600 | Segment values, row titles |
| bodyLarge / Medium / Small | 16, 14, 12 / 1.6, 1.6, 1.55 / 400 | Prose (Thai needs ≥ 1.55) |
| labelLarge / Medium / Small | 14, 12, 11 / 1.4 / 600 | Chips, segment labels |

Line heights use `TextLeadingDistribution.even` so Thai tone marks and lower vowels sit evenly. The app clamps the system text scale at 2.0. Display headlines clamp at 1.4 and the rain band's labels at 1.3, because their geometry is fixed.

## Space, radii, elevation

- **Space** (4-pt): 4, 8, 12, 16, 20, 24, 32, 40, 48. The screen gutter is 16. Sections sit 32 below the previous block and 12 above their content. Touch targets are 48 dp, and flood actions are 64 dp.
- **Radii**: xs 6, sm 10, md 14, lg/pass 20, pill 999. The perforation notch radius is 9. Nested controls are concentric: `ModeSegmented` is 18 outside and 14 inside with 4 padding.
- **Elevation**: only the pass and the ask bar lift. The pass shadow is `0 1 2 #0B1F3A/12%` plus `0 12 28 −6 #0B1F3A/20%`. In flood mode the shadow becomes a 1 px `#FFFFFF/8%` ring. Board rows and sections are flat on the surface, separated by space and dividers, not cards.

## Motion

Use `Motion.of(context)`. When the system *Reduce Motion* / *Remove animations* setting is on (`MediaQuery.disableAnimations`), every duration becomes 0.

| Token | ms | Curve | Moment |
|---|---|---|---|
| tap | 120 | standard `(0.2, 0, 0, 1)` | Segment selection |
| flap | 180 | emphasized decelerate `(0.05, 0.7, 0.1, 1)` | Verdict re-letters (slide up 25% plus fade, like a split-flap board) |
| rerank | 260 | standard | Board rows slide to their new rank |
| enter | 320 | emphasized decelerate | Push banner drops in; report result scrolls into view |
| sky | 520 | standard | Ground colour between sky states; theme change into flood |

**Signature interaction.** Dragging the departure marker across the rain band does four things live: it re-letters the verdict from an on-device preview (`previewOptions` / `previewHeadline`), reranks the board in place, and shifts the sky. Each 5-minute step gives a selection haptic. On release, the agent is asked (`POST /v1/decide` with `depart_at`) and its answer replaces the preview. While previewing, the pass says so: "ประเมินจากฝนบนเส้นทาง ปล่อยนิ้วเพื่อให้ Gemini ยืนยัน".

## Components (`lib/design/components/`)

| Component | What it is |
|---|---|
| `Pass`, `PassSection`, `PassSegments` | Paper pass. A custom render object punches a notch on both edges and draws a dashed perforation at every section seam. Segments are label over tabular value, separated by hairlines (ออก, ถึง, โหมด, มั่นใจ). |
| `RainBand` | 15-minute rain bars on a soft power scale, hour axis, dashed "now" tick, and an on-road bracket from depart to arrive. The draggable marker carries an "ออก HH:MM" bubble and snaps to 5 minutes, never earlier than now. It is a semantic slider (increase or decrease by 15 minutes). |
| `BoardRow`, `DepartureBoard` | Departure-board line: time, mode icon, title and note, status chip. Rows have a fixed height (scaled by text size) so the board animates reranks by position, and the semantic order follows the rank. |
| `ModeSegmented` | Car / BTS-MRT / motorbike with each mode's own ETA and status beneath. |
| `RiskChip`, `SampleBadge` | Risk as icon, word and colour. `SampleBadge` is the "ข้อมูลตัวอย่าง" badge shown when bundled fixtures are on screen. |
| `ConfidenceMeter` | Ten ticks plus a tabular percentage. |
| `SourceLabel`, `GeminiMark`, `GeneratedBy` | Provenance line; the Gemini spark (a rule icon for fallback); "ตัดสินโดย Gemini" or "กฎสำรอง · Gemini ไม่ตอบในรอบนี้". |
| `AskBar` | Pill question field with the Gemini spark and a 48 dp send button, pinned above the nav bar on Home. |
| `SkyField`, `FieldHeader` | The ground and the title row on it (back, title, subtitle, actions). |
| `NotificationBanner` | In-app stand-in for the 16:10 push. Opaque, swipe up or close to dismiss. |
| `Skeleton`, `PassSkeleton`, `ErrorState`, `EmptyState` | Loading pulse (static under reduce motion), the pass's shape while loading, failure with recovery, and nothing-yet with a next step. |

## States, screen by screen

- **Home**: pass skeleton while loading; `ErrorState` "โหลดทริปไม่ได้" with retry; `EmptyState` "วันนี้ยังไม่มีทริป" pointing at the ask bar and Calendar; the sample badge on the field when offline; the flood pass replaces the trip pass at `danger`.
- **Verdict**: progress line under the header while the agent answers; preview copy while dragging; "ไม่มีจุดน้ำขังบนเส้นทางนี้" when there are no flood spots.
- **Ask**: thinking skeleton; a failed answer offers "ถามใหม่".
- **Report**: GPS states ("กำลังหาตำแหน่ง…", GPS coordinates, or a named fallback to ถ.รัชดาภิเษก with a "ลองหา GPS" retry); scan line while Gemini looks; "ส่งรายงานไม่สำเร็จ" keeps the photo and offers "ส่งอีกครั้ง".
- **Home (บ้าน tab)**: an error tells the user what to do anyway; flood actions are 64 dp check-off rows.

## Do and don't

- **Do** put numbers in `tabular()`. **Don't** set times in the proportional face.
- **Do** give every block a `SourceLabel`. **Don't** ship a number without saying where it came from, or whether it is synthetic.
- **Do** separate sections with space and dividers on the surface. **Don't** wrap sections in cards or nest cards.
- **Do** use the amber only for warnings in flood mode. **Don't** add a second accent there (badges included).
- **Do** use Material Symbols Rounded (`Symbols.*_rounded`), filled to show selection. **Don't** use emoji or Unicode glyphs as icons.
- **Do** read durations through `Motion.of(context).d(...)`. **Don't** hard-code an animation that ignores Reduce Motion.
- **Don't** apply the Gemini gradient to text, or use gradients as decoration.

## Demo and screenshots

`--dart-define=DEMO_CLOCK=16:10|18:52|21:40|live` sets the scenario time. `--dart-define=DEMO_SCREEN=verdict@18:00/moto | report_result | home_tab | ask | settings | gallery` opens a state on launch. Review captures are in `.impeccable/review/phone-*.png` (iPhone 17 Pro simulator, live API with Gemini off, so verdicts show the fallback label).
