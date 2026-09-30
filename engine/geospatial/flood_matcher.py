import json
import math
from pathlib import Path
from typing import Dict, Any, List
from engine.config import settings

def haversine_distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two GPS coordinates in meters"""
    R = 6371000  # Radius of Earth in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2.0) ** 2 + \
        math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

class FloodRiskMatcher:
    """
    Evaluates geospatial flood risk by matching user coordinates & commute routes
    against BMA flood-prone hotspots, WeatherNext 3 rainfall forecasts, and canal water levels.
    """

    def __init__(self, flood_points_path: Path = None):
        path = flood_points_path or settings.FLOOD_POINTS_FILE
        with open(path, "r", encoding="utf-8") as f:
            self.flood_points: List[Dict[str, Any]] = json.load(f)

    def evaluate_user_risk(
        self,
        user_lat: float,
        user_lng: float,
        transport_mode: str,
        hourly_forecast: Dict[str, Any],
        canal_telemetry: List[Dict[str, Any]],
        search_radius_meters: float = 2000.0
    ) -> Dict[str, Any]:
        """
        Evaluate flood & storm risk for a specific user location.
        """
        matched_spots = []
        precip_rate = hourly_forecast.get("precipitation_rate_mm_hr", 0.0)
        wind_gust = hourly_forecast.get("wind_gust_kmh", 0.0)
        heat_index = hourly_forecast.get("heat_index_c", 0.0)

        # 1. Match against BMA Flood Risk Points
        max_estimated_depth_cm = 0
        for spot in self.flood_points:
            dist = haversine_distance_meters(user_lat, user_lng, spot["latitude"], spot["longitude"])
            radius = spot.get("risk_radius_meters", search_radius_meters)

            if dist <= radius:
                # User is within the flood-prone zone
                threshold = spot.get("critical_rain_threshold_mm_hr", 35.0)
                is_exceeded = precip_rate >= threshold

                # Estimate flood depth on street
                if is_exceeded:
                    excess_ratio = min((precip_rate - threshold) / threshold, 1.5)
                    est_depth = int(spot.get("historical_max_depth_cm", 20) * (0.5 + 0.5 * excess_ratio))
                else:
                    est_depth = int(spot.get("historical_max_depth_cm", 20) * 0.2) if precip_rate > 15 else 0

                if est_depth > max_estimated_depth_cm:
                    max_estimated_depth_cm = est_depth

                matched_spots.append({
                    "id": spot["id"],
                    "name_th": spot["name_th"],
                    "district": spot["district"],
                    "distance_meters": int(dist),
                    "critical_rain_threshold_mm_hr": threshold,
                    "drainage_canal": spot.get("drainage_canal"),
                    "estimated_street_depth_cm": est_depth,
                    "is_vehicle_vulnerable": transport_mode in spot.get("high_risk_vehicles", [])
                })

        # 2. Check Canal Levels
        critical_canals = [c for c in canal_telemetry if c.get("status") in ("WARNING", "CRITICAL")]

        # 3. Compute Risk Level
        risk_level = "LOW"
        risk_score = 10 # 0-100 scale

        if max_estimated_depth_cm >= 20 or (precip_rate >= 45 and matched_spots):
            risk_level = "SEVERE"
            risk_score = 90
        elif max_estimated_depth_cm >= 10 or precip_rate >= 30:
            risk_level = "HIGH"
            risk_score = 75
        elif precip_rate >= 15 or heat_index >= 41.0 or wind_gust >= 45.0:
            risk_level = "MODERATE"
            risk_score = 45

        # Vehicle vulnerability
        is_vehicle_in_danger = False
        if transport_mode in ("compact_sedan", "motorcycle") and max_estimated_depth_cm >= 15:
            is_vehicle_in_danger = True

        return {
            "risk_level": risk_level,
            "risk_score": risk_score,
            "user_location": {"lat": user_lat, "lng": user_lng},
            "transport_mode": transport_mode,
            "weather_metrics": {
                "precip_rate_mm_hr": precip_rate,
                "wind_gust_kmh": wind_gust,
                "heat_index_c": heat_index,
                "condition": hourly_forecast.get("condition")
            },
            "flood_impact": {
                "max_street_depth_cm": max_estimated_depth_cm,
                "is_vehicle_in_danger": is_vehicle_in_danger,
                "matched_hotspots": matched_spots,
                "critical_canals_nearby": [c["canal_name"] for c in critical_canals]
            }
        }
