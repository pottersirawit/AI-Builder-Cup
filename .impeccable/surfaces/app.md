---
version: 1
slug: "app"
primary_target: "app"
related_targets: []
---

# Surface brief: ฝนตกไหม mobile app (app/)

Scope: whole Flutter app — Home, Trip verdict, Ask, Flood report, Flood mode, Settings. Visitor mode: Operate.
Audience/job: Bangkok commuter deciding when and how to leave; under stress in flood mode. See PRODUCT.md.
Constraints: owner-pinned bright sky-blue Gemini-family palette, Chakra Petch, dark flood mode; Material 3 on Android; every card names its source; synthetic demo data labelled.

## Direction contract

THESIS: The app is a personal departure board, not a weather dashboard. Trips are ranked by "leave by" time and the top one is printed as a pass; refuses the category default of a temperature hero over hourly icons.

OWN-WORLD: The ground is the sky's state: clear daylight blue, bruised storm slate as rain nears, near-black navy with a single warning amber in flood mode. Paper-white passes with perforated segment rules and tabular Chakra Petch numerals; one rain-band graphic (blue intensity bars along a time axis) is the only data texture. Icons from one stroke family (Material Symbols Rounded).

STORY: User sees what to do and by when, sees why (rain hits Rama 4 17:30, flood spot on route for a sedan), trusts it (sources + confidence), acts (leave / switch to BTS / move the car).

FIRST VIEWPORT: Sky-state field fills top ~45%; on it the top trip's pass: huge "ออกก่อน 16:45" verdict, segments ออก | ถึง | โหมด | มั่นใจ, rain band with a draggable departure marker. Below, the board of other trips. Ask bar pinned at bottom above nav as the primary action.

FORM: Departure board + boarding pass (position 3 of my ordered list: verdict stack, time-spine, departure board, map-first, chat-first, sky-as-ground, notification inbox), sky-as-ground (6) folded in as the field; seed 84b91dce. Signature interaction: dragging the departure marker across the rain band re-letters the verdict and reranks the board in place.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
