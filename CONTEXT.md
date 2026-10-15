# Domain Context: Bangkok Weather Resilience & Disaster Preparedness

This document defines the ubiquitous domain language for the Bangkok Weather Resilience system, aligning agents and developers on terminology, data contracts, and boundaries according to the Matt Pocock engineering principles.

---

## 1. Domain Entities & Telemetry

- **WeatherNext 3 (WN3)**: Google DeepMind's flagship 5km spatial grid numerical weather prediction model operating on raw geostationary satellite telemetry, updated hourly. Provides precipitation rate ($\text{mm/h}$), surface wind gust ($\text{km/h}$), temperature, and atmospheric pressure.
- **BMA Radar Composite**: Dual C-Band Doppler radar network operated by the Bangkok Metropolitan Administration (Nong Chok Radar in East Bangkok, Nong Khaem Radar in West Bangkok). Yields radar reflectivity measured in $\text{dBZ}$ (where $\ge 50\text{ dBZ}$ represents intense convective cloudbursts).
- **ThaiWater Telemetry**: Standard national hydrological telemetric data stream (`standard.thaiwater.net`) reporting precipitation accumulation and canal/river stage levels relative to Mean Sea Level ($\text{m MSL}$).
- **BMA Flood Spot**: One of 70+ designated historical flood-prone road segments and intersections in Bangkok (e.g., Sukhumvit 21 Asok, Chaeng Watthana Road, Udomsuk). Each spot has a critical rain threshold (e.g. $40\text{ mm/h}$) and vehicle inundation vulnerability thresholds.
- **Vehicle Clearance Profile**: Persona parameter categorizing vehicle floor/exhaust height:
  - `sedan`: Sedan / Eco-car (water clearance threshold $< 15\text{ cm}$).
  - `moto`: Motorcycle (vulnerable to flash floods and sudden wind gusts $> 45\text{ km/h}$).
  - `pickup`: Pickup / High-clearance SUV (safe up to $35\text{ cm}$).
  - `transit`: Public Transit / BTS / MRT (inundation safety independent of road water level).

---

## 2. Decision Logic & Proactive Triggering

- **Nowcast Horizon**: The $0 - 2$ hour lead-time window where BMA radar tracking vectors project storm velocity into user geofences.
- **Calendar Weather Clash**: When a user's scheduled calendar appointment coincides in time ($t_{\text{start}} - 30\text{m} \le t \le t_{\text{end}}$) and spatial radius ($< 3\text{km}$) with a forecasted severe weather event or road flood spot.
- **Proactive Shift Advisory**: Actionable mitigation strategy suggested by Gemini 1.5 Reasoner:
  - *Early Departure*: Leave $30-45$ minutes earlier before convective cell arrival.
  - *Remote Shift*: Recommending converting the in-person meeting into a Google Meet.
  - *Modal Shift*: Diverting from street vehicles to elevated skytrain (BTS/MRT).

---

## 3. Architecture & Seams

- **Core API (`api/`)**: High-performance Go service deployed on Cloud Run handling HTTP API endpoints, Gemini 2.5 Flash agent reasoning (`agent/`), mathematical risk assessment (`decision/`), geocoding (`geocode/`), and telemetry aggregation (`live/`).
- **Mobile Experience (`app/`)**: Cross-platform Flutter client implementing Contract v1 (departure boards, interactive hourly scrubber, flood camera reporting, demo clock).
- **AI Agent Seam**: Gemini 2.5 Flash operates via function-calling tools (`get_trip`, `get_route`, `get_rain_along_route`, `get_flood_spots_on_route`, `evaluate_departure`) with mathematical guardrails ensuring numerical veracity.
- **GIS / Weather Cache**: BigQuery WeatherNext 3 (`ai-cup-511208:weathernext_3`) cached at 6-hour model run intervals for sub-millisecond local spatial interpolation.
