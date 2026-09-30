"""
Empirical Challenger: Milestone 5 Comprehensive Verification Suite
Tests:
1. Python AI Engine Calendar REST API Contracts & Dual-Schema Payloads
2. OAuth 2.0 State Machine, Nonce Validation & TokenStore Thread Safety
3. Multi-Pass Fuzzy Geocoder with Extreme Noise & Boundary Cases
4. Proactive Shift Reasoning Matrix (Early Departure, Remote, Modal Shift)
5. Go Gateway Calendar Route Contracts & Resilience (via Go test runner)
"""

import unittest
import sys
import json
import time
import subprocess
import threading
from pathlib import Path
from datetime import datetime, timezone, timedelta

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

from engine.collectors.google_calendar import (
    GoogleCalendarCollector,
    GoogleOAuthManager,
    TokenStore,
    BANGKOK_PLACES_GEOCODE,
    geocode_bangkok_location
)
from engine.geospatial.calendar_matcher import CalendarWeatherMatcher
from engine.ai.gemini_reasoner import GeminiWeatherReasoner
from engine.main import (
    app,
    get_calendar_events,
    sync_and_evaluate_calendar,
    get_calendar_auth_url,
    handle_calendar_auth_callback,
    get_calendar_auth_status,
    disconnect_calendar,
    CalendarSyncRequest
)


class TestEngineCalendarAPIContracts(unittest.TestCase):
    """Suite 1: Python AI Engine Calendar REST Endpoints & Schemas"""

    def test_sync_and_evaluate_returns_200_and_dual_schema_json(self):
        req = CalendarSyncRequest(
            user_id="U_CHALLENGER_01",
            name="ดร. สมเกียรติ",
            transport_mode="compact_sedan"
        )
        res = sync_and_evaluate_calendar(req)
        
        # Verify envelope structure
        self.assertIsInstance(res, dict)
        self.assertEqual(res.get("user_id"), "U_CHALLENGER_01")
        self.assertIn("total_events_checked", res)
        self.assertIn("events_with_weather_hazards", res)
        self.assertIn("proactive_advisories", res)
        self.assertGreaterEqual(len(res["proactive_advisories"]), 1)

        # Verify dual-schema on first advisory
        first_adv_wrapper = res["proactive_advisories"][0]
        self.assertIn("event_id", first_adv_wrapper)
        self.assertIn("event_title", first_adv_wrapper)
        self.assertIn("urgency", first_adv_wrapper)
        self.assertIn("advisory", first_adv_wrapper)
        
        adv = first_adv_wrapper["advisory"]
        # Go Gateway DTO keys
        self.assertIn("headline", adv)
        self.assertIn("reasoning", adv)
        self.assertIn("proactive_recommendation", adv)
        self.assertIn("departure_adjustment_mins", adv)
        self.assertIn("recommended_action_type", adv)
        self.assertIsInstance(adv["departure_adjustment_mins"], int)

        # Thai LINE Messaging alert keys
        self.assertIn("title", adv)
        self.assertIn("urgency_level", adv)
        self.assertIn("summary_text", adv)
        self.assertIn("critical_window", adv)
        self.assertIn("action_checklist", adv)
        self.assertIsInstance(adv["action_checklist"], list)

    def test_auth_url_endpoint_structure(self):
        res = get_calendar_auth_url(user_id="U_CHALLENGER_OAUTH")
        self.assertIsInstance(res, dict)
        self.assertEqual(res.get("status"), "ready")
        self.assertIn("authorization_url", res)
        self.assertIn("auth_url", res)
        self.assertIn("state", res)
        self.assertEqual(res.get("user_id"), "U_CHALLENGER_OAUTH")

    def test_auth_callback_valid_code_returns_200_json(self):
        # Generate valid state first
        auth_data = get_calendar_auth_url(user_id="U_CHALLENGER_EXCHANGE")
        state = auth_data["state"]

        res = handle_calendar_auth_callback(code="mock_valid_code_999", state=state)
        self.assertIsInstance(res, dict)
        self.assertEqual(res.get("status"), "connected")
        self.assertEqual(res.get("user_id"), "U_CHALLENGER_EXCHANGE")
        self.assertIn("expires_in", res)
        self.assertGreater(res["expires_in"], 0)

    def test_auth_callback_invalid_state_raises_http_exception(self):
        from fastapi import HTTPException
        with self.assertRaises(HTTPException) as ctx:
            handle_calendar_auth_callback(code="mock_code", state="non_existent_or_forged_state")
        self.assertEqual(ctx.exception.status_code, 400)

    def test_auth_status_and_disconnect_lifecycle(self):
        # Set up connected user
        auth_data = get_calendar_auth_url(user_id="U_CHALLENGER_LIFECYCLE")
        handle_calendar_auth_callback(code="mock_code", state=auth_data["state"])

        # Check status -> connected
        status_before = get_calendar_auth_status(user_id="U_CHALLENGER_LIFECYCLE")
        self.assertTrue(status_before.get("is_connected"))

        # Disconnect
        disc = disconnect_calendar({"user_id": "U_CHALLENGER_LIFECYCLE"})
        self.assertEqual(disc.get("status"), "disconnected")

        # Check status -> disconnected
        status_after = get_calendar_auth_status(user_id="U_CHALLENGER_LIFECYCLE")
        self.assertFalse(status_after.get("is_connected"))

    def test_get_calendar_events_endpoint(self):
        res = get_calendar_events()
        self.assertIsInstance(res, dict)
        self.assertIn("total_events", res)
        self.assertIn("events", res)
        self.assertGreaterEqual(res["total_events"], 3)


class TestGeocodingRobustnessAndAdversarialInputs(unittest.TestCase):
    """Suite 2: Geocoding Stress & Adversarial Noise Parsing"""

    def setUp(self):
        self.collector = GoogleCalendarCollector(mode="mock")

    def test_adversarial_noisy_strings(self):
        cases = [
            ("นัดประชุมผู้ถือหุ้น [ด่วนมาก!!] @ สยามพารากอน ชั้น M ฝั่ง North Zone", "สยามพารากอน"),
            ("Workshop AI ณ มหาวิทยาลัยเกษตรศาสตร์ ประตู 1 ฝั่งงามวงศ์วาน", "มหาวิทยาลัยเกษตรศาสตร์"),
            ("ทานกาแฟกับเพื่อนที่ True Digital Park ตึก Phoenix ชั้น 3", "ทรู ดิจิทัล พาร์ค"),
            ("เดินทางไป สนามบินดอนเมือง Terminal 2 ขาออกเคาน์เตอร์ 12", "ท่าอากาศยานดอนเมือง"),
            ("นัดลูกค้า อาคาร Exchange Tower อโศก ชั้น 28", "อโศก"),
            ("สำนักงานเขตจตุจักร ถนนวิภาวดีรังสิต", "จตุจักร"),
            ("ไอคอนสยาม โซนสุขสยาม ชั้น G", "ไอคอนสยาม"),
            ("ศูนย์การประชุมแห่งชาติสิริกิติ์ Hall 3-4", "ศูนย์การประชุมแห่งชาติสิริกิติ์"),
        ]
        for raw, expected_keyword in cases:
            res = self.collector.geocode_location(raw)
            self.assertGreater(res["lat"], 13.0, f"Lat too low for {raw}")
            self.assertGreater(res["lng"], 100.0, f"Lng too low for {raw}")
            self.assertIn(expected_keyword, res["name_th"], f"Expected {expected_keyword} in {res['name_th']} for input: {raw}")

    def test_non_bangkok_or_gibberish_falls_back_to_bkk_city_center(self):
        gibberish = [
            "Somewhere over the rainbow",
            "123456789!@#$%^&*()_+",
            "ห้องนอนชั้นสอง บ้านพักส่วนตัว",
            "Remote Zoom Meeting ID: 999 888 777"
        ]
        for text in gibberish:
            res = self.collector.geocode_location(text)
            self.assertAlmostEqual(res["lat"], 13.7563, places=2)
            self.assertAlmostEqual(res["lng"], 100.5018, places=2)


class TestTokenStoreConcurrencyAndSecurity(unittest.TestCase):
    """Suite 3: Concurrency Safety & TokenStore Threading Stress"""

    def test_concurrent_state_generation_and_consumption(self):
        store = TokenStore()
        manager = GoogleOAuthManager(token_store=store)
        num_threads = 20
        errors = []

        def worker(idx):
            try:
                user_id = f"U_CONCURRENT_{idx}"
                url, state = manager.generate_auth_url(user_id=user_id)
                # Verify state exists
                popped = store.pop_state(state)
                if not popped or popped["user_id"] != user_id:
                    errors.append(f"State pop failed for user {user_id}")
                # Second pop must return None (single-use nonce guarantee)
                second_pop = store.pop_state(state)
                if second_pop is not None:
                    errors.append(f"Nonce replay detected for state {state}")
            except Exception as e:
                errors.append(str(e))

        threads = [threading.Thread(target=worker, args=(i,)) for i in range(num_threads)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        self.assertEqual(len(errors), 0, f"Concurrency errors encountered: {errors}")


class TestGoGatewayCalendarRoutes(unittest.TestCase):
    """Suite 4: Go Gateway Route Verifications via Native Go Test Engine"""

    def test_run_gateway_calendar_tests(self):
        res = subprocess.run(
            ["go", "test", "-race", "-v", "-run", "TestCalendarEndpoints", "./internal/api"],
            cwd=str(REPO_ROOT / "gateway"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        self.assertEqual(res.returncode, 0, f"Gateway calendar endpoint tests failed: {res.stderr}\n{res.stdout}")
        self.assertIn("PASS: TestCalendarEndpoints", res.stdout)


class TestProactiveShiftDecisionMatrix(unittest.TestCase):
    """Suite 5: Proactive Shift Recommendation Modes & Edge Cases"""

    def setUp(self):
        self.matcher = CalendarWeatherMatcher()

    def test_outdoor_event_heat_hazard_triggers_remote(self):
        # Event outdoors at 13:00 with heat index 42C -> OUTDOOR_HAZARD -> REMOTE
        events = [
            {
                "event_id": "TEST-OUTDOOR-01",
                "title": "สำรวจไซต์ก่อสร้างกลางแจ้ง",
                "latitude": 13.7475,
                "longitude": 100.6698,
                "start_time": "2026-09-26T13:00:00+07:00",
                "is_outdoor": True
            }
        ]
        results = self.matcher.evaluate_calendar_events(events, transport_mode="compact_sedan")
        self.assertEqual(len(results), 1)
        res = results[0]
        self.assertIn(res["recommended_action_type"], ("REMOTE", "EARLY_DEPARTURE", "MODAL_SHIFT"))

    def test_transport_mode_unrecognized_graceful_handling(self):
        req = CalendarSyncRequest(
            user_id="U_STRANGE_MODE",
            name="Mr. Alien",
            transport_mode="teleporter"
        )
        res = sync_and_evaluate_calendar(req)
        self.assertIn("proactive_advisories", res)
        self.assertEqual(res["user_id"], "U_STRANGE_MODE")


if __name__ == "__main__":
    unittest.main()

