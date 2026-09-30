import math
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List, Optional
from engine.collectors.weather_next3 import WeatherNext3Collector
from engine.collectors.thaiwater import ThaiWaterCollector
from engine.collectors.bma_radar import BMARadarCollector
from engine.geospatial.flood_matcher import FloodRiskMatcher, haversine_distance_meters


class CalendarWeatherMatcher:
    """
    Evaluates weather hazards and flood risks specifically for scheduled
    Google Calendar appointments by matching event times and venues with
    hyper-local WeatherNext 3 predictions (5km storm footprint) and BMA telemetry.
    Supports proactive shift recommendation modes:
    - EARLY_DEPARTURE (ออกเดินทางก่อนเวลา 30–45 นาที)
    - REMOTE (เปลี่ยนเป็นการประชุมออนไลน์ Google Meet / เลื่อนนัด)
    - MODAL_SHIFT (เปลี่ยนรูปแบบการเดินทาง เช่น ใช้รถไฟฟ้า BTS/MRT)
    """

    def __init__(
        self,
        weather_collector: Optional[WeatherNext3Collector] = None,
        flood_matcher: Optional[FloodRiskMatcher] = None,
        thaiwater_collector: Optional[ThaiWaterCollector] = None,
        radar_collector: Optional[BMARadarCollector] = None
    ):
        self.weather = weather_collector or WeatherNext3Collector()
        self.flood = flood_matcher or FloodRiskMatcher()
        self.thaiwater = thaiwater_collector or ThaiWaterCollector()
        self.radar = radar_collector or BMARadarCollector()

    def evaluate_calendar_events(
        self,
        events: List[Dict[str, Any]],
        transport_mode: str = "compact_sedan"
    ) -> List[Dict[str, Any]]:
        """
        Analyzes a list of Google Calendar events and tags each with weather risk assessments.
        """
        canals = self.thaiwater.get_canal_telemetry()
        radar = self.radar.get_radar_summary()
        results = []

        for event in events:
            # Parse start time
            start_str = event.get("start_time")
            try:
                event_dt = datetime.fromisoformat(start_str)
                event_hour = event_dt.hour
            except Exception:
                event_hour = 14  # Default to afternoon

            # Safe coordinate parsing with fallback to Bangkok Center
            try:
                raw_lat = event.get("latitude")
                raw_lng = event.get("longitude")
                lat = float(raw_lat) if raw_lat is not None else 13.7563
                lng = float(raw_lng) if raw_lng is not None else 100.5018
                if math.isnan(lat) or math.isinf(lat):
                    lat = 13.7563
                if math.isnan(lng) or math.isinf(lng):
                    lng = 100.5018
            except (ValueError, TypeError):
                lat, lng = 13.7563, 100.5018
            is_outdoor = bool(event.get("is_outdoor", False))

            # 1. Fetch 5km WeatherNext 3 forecast for this specific location & hour
            forecasts = self.weather.get_hourly_forecast(lat, lng, hours=1, override_hour=event_hour)
            fc = forecasts[0] if forecasts else {}

            precip = fc.get("precipitation_rate_mm_hr", 0.0)
            heat_idx = fc.get("heat_index_c", 0.0)
            wind_gust = fc.get("wind_gust_kmh", 0.0)

            # 2. Evaluate geospatial flood risk at destination
            risk = self.flood.evaluate_user_risk(
                user_lat=lat,
                user_lng=lng,
                transport_mode=transport_mode,
                hourly_forecast=fc,
                canal_telemetry=canals
            )

            # Distance to nearest BMA Flood Risk Hotspot
            nearest_spot = None
            min_spot_dist = 999999.0
            for spot in self.flood.flood_points:
                d = haversine_distance_meters(lat, lng, spot["latitude"], spot["longitude"])
                if d < min_spot_dist:
                    min_spot_dist = d
                    nearest_spot = spot

            risk_radius = float(nearest_spot.get("risk_radius_meters", 1500) if nearest_spot else 1500)
            is_in_flood_zone = (min_spot_dist <= risk_radius)

            # 3. Detect Weather Concerns & Assign Proactive Shift Modes
            has_concern = False
            concern_type = "NONE"
            urgency = "INFO"
            concern_details = []
            recommended_early_minutes = 0
            recommended_action_type = "EARLY_DEPARTURE"

            max_depth = risk.get("flood_impact", {}).get("max_street_depth_cm", 0)
            matched_spots = risk.get("flood_impact", {}).get("matched_hotspots", [])

            # Rule A: Flash flood risk or severe cloudburst at destination
            if max_depth >= 15 or (precip >= 40.0 and (matched_spots or is_in_flood_zone)):
                has_concern = True
                concern_type = "FLOOD_AND_TRAFFIC_JAM"
                urgency = "CRITICAL"
                spot_name = matched_spots[0]["name_th"] if matched_spots else (nearest_spot["name_th"] if nearest_spot else event.get("location_name", "จุดนัดหมาย"))
                concern_details.append(
                    f"ปลายทางอยู่ในจุดเสี่ยงน้ำท่วมขัง ({spot_name}) คาดการณ์ระดับน้ำสูง {max_depth} ซม. ฝนตกหนัก {precip} มม./ชม."
                )
                recommended_early_minutes = 45

                if transport_mode in ("compact_sedan", "motorcycle"):
                    recommended_action_type = "MODAL_SHIFT"
                    concern_details.append(
                        f"ระดับน้ำท่วมผิวจราจร {max_depth} ซม. เสี่ยงน้ำเข้าท่อไอเสีย {transport_mode} แนะนำสลับใช้รถไฟฟ้า BTS/MRT"
                    )
                else:
                    recommended_action_type = "REMOTE"
                    concern_details.append(
                        f"สภาพจราจรวิกฤตจากน้ำท่วมขัง แนะนำพิจารณาปรับประชุมออนไลน์ผ่าน Google Meet"
                    )

            # Rule B: Moderate Rain & Sluggish Traffic (5km WeatherNext 3 footprint)
            elif max_depth >= 5 or precip >= 25.0:
                has_concern = True
                concern_type = "RAIN_AND_SLUGGISH_TRAFFIC"
                urgency = "WARNING"
                recommended_early_minutes = 30
                recommended_action_type = "EARLY_DEPARTURE"
                concern_details.append(
                    f"กลุ่มฝน WeatherNext 3 ({precip} มม./ชม.) ครอบคลุมรัศมี 5km ผิวจราจรเปียกลื่นและรถติดสะสม"
                )

            # Rule C: Extreme Heat during outdoor activity
            if is_outdoor and heat_idx >= 40.0:
                has_concern = True
                if urgency != "CRITICAL":
                    urgency = "WARNING"
                    concern_type = "EXTREME_HEAT_OUTDOOR"
                    recommended_action_type = "REMOTE"  # Reschedule or move indoors
                    recommended_early_minutes = 0
                concern_details.append(
                    f"กิจกรรมกลางแจ้งตรวจพบดัชนีความร้อน {heat_idx:.1f}°C เสี่ยงต่อภาวะฮีทสโตรก แนะนำเลื่อนเวลาหรือจัดในอาคาร"
                )

            # Rule D: Severe Wind Gusts
            if wind_gust >= 50.0:
                has_concern = True
                concern_details.append(f"ลมกระโชกแรง {wind_gust} กม./ชม. ระวังกิ่งไม้และป้ายโฆษณา")

            results.append({
                "event": event,
                "weather_at_event": fc,
                "flood_risk": risk,
                "has_weather_concern": has_concern,
                "urgency": urgency,
                "concern_type": concern_type,
                "concern_details": concern_details,
                "recommended_early_departure_minutes": recommended_early_minutes,
                "recommended_action_type": recommended_action_type,
                "nearest_flood_hotspot_distance_m": round(min_spot_dist, 1)
            })

        return results
