import unittest
from unittest import mock
import sys
from pathlib import Path

# Add project root to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from engine.geospatial.flood_matcher import FloodRiskMatcher, haversine_distance_meters
from engine.ai.gemini_reasoner import GeminiWeatherReasoner

class TestWeatherEngineDirect(unittest.TestCase):
    def test_haversine_distance(self):
        # Distance between Asoke (13.7372, 100.5638) and Udom Suk (13.6798, 100.6083) is roughly 8-9 km
        dist = haversine_distance_meters(13.7372, 100.5638, 13.6798, 100.6083)
        self.assertTrue(7000 < dist < 10000)

    def test_flood_risk_matcher(self):
        matcher = FloodRiskMatcher()
        self.assertGreaterEqual(len(matcher.flood_points), 8)

        # Test user right at Asoke hotspot with heavy rain
        hourly_fc = {
            "precipitation_rate_mm_hr": 50.0,
            "wind_gust_kmh": 45.0,
            "heat_index_c": 36.0,
            "condition": "Severe Thunderstorm"
        }
        canals = [
            {"canal_name": "คลองแสนแสบ", "status": "WARNING"}
        ]

        risk = matcher.evaluate_user_risk(
            user_lat=13.7372,
            user_lng=100.5638,
            transport_mode="compact_sedan",
            hourly_forecast=hourly_fc,
            canal_telemetry=canals
        )

        self.assertIn(risk["risk_level"], ("HIGH", "SEVERE"))
        self.assertGreaterEqual(risk["flood_impact"]["max_street_depth_cm"], 10)
        self.assertGreater(len(risk["flood_impact"]["matched_hotspots"]), 0)

    def test_gemini_reasoner_fallback(self):
        reasoner = GeminiWeatherReasoner()
        user = {
            "name": "คุณสมชาย",
            "transport_mode": "compact_sedan",
            "location_name": "ถ.อโศกมนตรี"
        }
        risk = {
            "risk_level": "SEVERE",
            "weather_metrics": {"precip_rate_mm_hr": 48.0, "heat_index_c": 35.0},
            "flood_impact": {
                "max_street_depth_cm": 20,
                "matched_hotspots": [{"name_th": "ถนนสุขุมวิท ช่วงอโศก"}],
                "critical_canals_nearby": ["คลองแสนแสบ"]
            }
        }
        radar = {"max_reflectivity_dbz": 50}

        advisory = reasoner.generate_advisory(user, risk, radar, alert_type="EVENT_DRIVEN")

        self.assertEqual(advisory["urgency_level"], "CRITICAL")
        self.assertIn("action_checklist", advisory)
        self.assertGreaterEqual(len(advisory["action_checklist"]), 3)
        self.assertIn("critical_window", advisory)

    @unittest.mock.patch("engine.collectors.thaiwater.requests.get")
    def test_thaiwater_collector_none_coalesce(self, mock_get):
        from engine.collectors.thaiwater import ThaiWaterCollector
        mock_resp = unittest.mock.MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "data": [
                {
                    "station_id": "ST-01",
                    "canal_name": "Test Canal",
                    "district": "Bangkok",
                    "water_level_msl": None,
                    "bank_height_msl": None,
                    "status": "NORMAL"
                },
                {
                    "station_id": "ST-02",
                    "canal_name": "Test Canal 2",
                    "district": "Bangkok",
                    "water_level_msl": 1.2,
                    "bank_height_msl": None,
                    "status": "WARNING"
                }
            ]
        }
        mock_get.return_value = mock_resp
        collector = ThaiWaterCollector(mode="live")
        collector.api_key = "test_key"
        telemetry = collector._fetch_live_telemetry()
        self.assertEqual(len(telemetry), 2)
        self.assertEqual(telemetry[0]["margin_to_overflow_m"], 0.0)
        self.assertEqual(telemetry[1]["margin_to_overflow_m"], -1.2)

    @unittest.mock.patch("engine.collectors.weather_next3.requests.get")
    def test_weather_next3_collector_none_access(self, mock_get):
        from engine.collectors.weather_next3 import WeatherNext3Collector
        mock_resp = unittest.mock.MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            "forecastHours": [
                {
                    "forecastTime": "2026-10-18T10:00:00Z",
                    "temperature": None,
                    "relativeHumidity": 80,
                    "heatIndex": None,
                    "precipitation": None,
                    "wind": None,
                    "weatherCondition": None
                }
            ]
        }
        mock_get.return_value = mock_resp
        collector = WeatherNext3Collector(mode="live")
        collector.api_key = "test_key"
        forecasts = collector._fetch_live_forecast(13.75, 100.5, 1)
        self.assertEqual(len(forecasts), 1)
        self.assertIsNone(forecasts[0]["temperature_c"])
        self.assertIsNone(forecasts[0]["heat_index_c"])
        self.assertEqual(forecasts[0]["precipitation_rate_mm_hr"], 0.0)
        self.assertEqual(forecasts[0]["precipitation_probability"], 0)
        self.assertEqual(forecasts[0]["wind_speed_kmh"], 0.0)
        self.assertEqual(forecasts[0]["wind_gust_kmh"], 0.0)
        self.assertEqual(forecasts[0]["condition"], "Clear")

if __name__ == "__main__":
    unittest.main()
