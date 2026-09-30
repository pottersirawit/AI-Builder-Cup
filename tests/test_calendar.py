"""
Bangkok Weather Resilience & Proactive Disaster Preparedness System
Automated Unit & Integration Test Suite: Google Calendar Weather Clash & Proactive Shift Reasoner (Ticket 06)
"""

import unittest
import sys
import json
import time
from pathlib import Path
from datetime import datetime, timezone, timedelta

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from engine.collectors.google_calendar import (
    GoogleCalendarCollector,
    GoogleOAuthManager,
    TokenStore,
    BANGKOK_PLACES_GEOCODE,
    geocode_bangkok_location
)
from engine.geospatial.calendar_matcher import CalendarWeatherMatcher
from engine.ai.gemini_reasoner import GeminiWeatherReasoner
from engine.geospatial.flood_matcher import haversine_distance_meters
from engine.main import (
    get_calendar_events,
    sync_and_evaluate_calendar,
    get_calendar_auth_url,
    get_calendar_auth_status,
    disconnect_calendar,
    CalendarSyncRequest
)


class TestCalendarEventParsing(unittest.TestCase):
    """Suite 1: Google Calendar Event Ingestion & Normalization"""

    def setUp(self):
        self.collector = GoogleCalendarCollector(mode="mock")

    def test_fetch_calendar_events_structure(self):
        events = self.collector.get_upcoming_events()
        self.assertGreaterEqual(len(events), 3)
        for ev in events:
            self.assertIn("event_id", ev)
            self.assertIn("title", ev)
            self.assertIn("location_raw", ev)
            self.assertIn("location_name", ev)
            self.assertIn("latitude", ev)
            self.assertIn("longitude", ev)
            self.assertIn("start_time", ev)
            self.assertIn("end_time", ev)
            self.assertIsInstance(ev["is_outdoor"], bool)

    def test_event_chronological_ordering(self):
        events = self.collector.get_upcoming_events()
        for i in range(len(events) - 1):
            t1 = datetime.fromisoformat(events[i]["start_time"])
            t2 = datetime.fromisoformat(events[i + 1]["start_time"])
            self.assertLessEqual(t1, t2)

    def test_noisy_location_string_parsing(self):
        noisy_inputs = [
            ("นัดประชุม ชั้น 4 อาคารเสริมมิตร ถ.อโศกมนตรี กทม.", "อาคารเสริมมิตร"),
            ("ห้องประชุมสัญญา ศูนย์ราชการแจ้งวัฒนะ อาคาร B ชั้น 2", "ศูนย์ราชการแจ้งวัฒนะ"),
            ("นัดทานข้าว สยามพารากอน ชั้น G ลานน้ำพุ", "สยามพารากอน"),
            ("ซอยทองหล่อ สุขุมวิท 55 เข้าซอย 200 เมตร", "ทองหล่อ"),
            ("BTS อุดมสุข สุขุมวิท 103 ทางออก 4", "อุดมสุข"),
            ("Meeting Room 101, CentralWorld Rama 1 Road", "เซ็นทรัลเวิลด์"),
            ("True Digital Park Building 101, Room 502", "ทรู ดิจิทัล พาร์ค"),
            ("สัมมนาวิชาการ มศว ประสานมิตร อาคารนวัตกรรม", "มหาวิทยาลัยศรีนครินทรวิโรฒ")
        ]
        for raw_text, expected_key in noisy_inputs:
            coords = self.collector.geocode_location(raw_text)
            self.assertGreater(coords["lat"], 13.0)
            self.assertGreater(coords["lng"], 100.0)
            self.assertIn(expected_key, coords["name_th"])

    def test_empty_location_fallback_to_bangkok_center(self):
        coords_empty = self.collector.geocode_location("")
        self.assertAlmostEqual(coords_empty["lat"], 13.7563, places=3)
        self.assertAlmostEqual(coords_empty["lng"], 100.5018, places=3)

        coords_none = self.collector.geocode_location(None)
        self.assertAlmostEqual(coords_none["lat"], 13.7563, places=3)


class TestLandmarkGeocoding(unittest.TestCase):
    """Suite 2: Bangkok Landmark Geocoding Dictionary & Bounding Boxes"""

    def test_comprehensive_50_plus_landmarks_coverage(self):
        # Must have at least 50 mapped landmarks covering key Bangkok hubs
        self.assertGreaterEqual(len(BANGKOK_PLACES_GEOCODE), 50)

    def test_all_landmarks_within_bangkok_bounding_box(self):
        # Bangkok metropolitan coordinate envelope: 13.45 <= lat <= 13.98, 100.30 <= lng <= 100.95
        for landmark, data in BANGKOK_PLACES_GEOCODE.items():
            lat = data["lat"]
            lng = data["lng"]
            self.assertTrue(
                13.45 <= lat <= 13.98,
                f"Landmark {landmark} latitude {lat} outside Bangkok envelope"
            )
            self.assertTrue(
                100.30 <= lng <= 100.95,
                f"Landmark {landmark} longitude {lng} outside Bangkok envelope"
            )

    def test_geodesic_distance_calculation(self):
        # Asok to Udomsuk is approx 8-9 km
        asok = BANGKOK_PLACES_GEOCODE["อาคารเสริมมิตร"]
        udomsuk = BANGKOK_PLACES_GEOCODE["อุดมสุข"]
        distance = haversine_distance_meters(asok["lat"], asok["lng"], udomsuk["lat"], udomsuk["lng"])
        self.assertTrue(7000 <= distance <= 11000)


class TestCalendarClashMatching(unittest.TestCase):
    """Suite 3: Weather Clash Detection & Threat Tagging"""

    def setUp(self):
        self.collector = GoogleCalendarCollector(mode="mock")
        self.matcher = CalendarWeatherMatcher()

    def test_weather_hazard_clash_detection(self):
        events = self.collector.get_upcoming_events()
        evaluations = self.matcher.evaluate_calendar_events(events, transport_mode="compact_sedan")
        self.assertEqual(len(evaluations), len(events))

        flagged = [ev for ev in evaluations if ev["has_weather_concern"]]
        self.assertGreaterEqual(len(flagged), 1)

        # Event 1 (Chaeng Watthana afternoon storm) must be tagged
        evt1 = next(e for e in evaluations if e["event"]["event_id"] == "GCAL-EVT-001")
        self.assertTrue(evt1["has_weather_concern"])
        self.assertIn(evt1["urgency"], ("CRITICAL", "WARNING"))
        self.assertGreaterEqual(evt1["recommended_early_departure_minutes"], 30)

    def test_transport_mode_sensitivity(self):
        events = self.collector.get_upcoming_events()
        eval_sedan = self.matcher.evaluate_calendar_events(events, transport_mode="compact_sedan")
        eval_pickup = self.matcher.evaluate_calendar_events(events, transport_mode="pickup")

        evt1_sedan = next(e for e in eval_sedan if e["event"]["event_id"] == "GCAL-EVT-001")
        evt1_pickup = next(e for e in eval_pickup if e["event"]["event_id"] == "GCAL-EVT-001")
        urgency_ranks = {"INFO": 0, "ADVISORY": 1, "WARNING": 2, "CRITICAL": 3}
        self.assertGreaterEqual(urgency_ranks[evt1_sedan["urgency"]], urgency_ranks[evt1_pickup["urgency"]])


class TestProactiveShiftReasoning(unittest.TestCase):
    """Suite 4: Gemini 1.5 Proactive Shift Reasoning (The 3 Required Modes & Dual-Schema)"""

    def setUp(self):
        self.reasoner = GeminiWeatherReasoner()
        self.user = {"name": "คุณสมชาย", "transport_mode": "compact_sedan"}

    def test_mode_1_early_departure(self):
        mock_eval = {
            "event": {
                "event_id": "GCAL-01",
                "title": "นัดตรวจงาน แจ้งวัฒนะ",
                "location_name": "ศูนย์ราชการแจ้งวัฒนะ",
                "start_time": "2026-09-26T16:30:00+07:00"
            },
            "weather_at_event": {"precipitation_rate_mm_hr": 35.0, "heat_index_c": 32.0},
            "flood_risk": {"flood_impact": {"max_street_depth_cm": 15}},
            "concern_type": "FLOOD_AND_TRAFFIC_JAM",
            "urgency": "CRITICAL",
            "recommended_early_departure_minutes": 45,
            "recommended_action_type": "EARLY_DEPARTURE"
        }
        adv = self.reasoner.generate_calendar_advisory(self.user, mock_eval)
        self.assertIn("title", adv)
        self.assertEqual(adv["urgency_level"], "CRITICAL")
        self.assertTrue(any("ออกเดินทาง" in item for item in adv["action_checklist"]))
        self.assertIn("45", " ".join(adv["action_checklist"]))

    def test_mode_2_remote_shift_google_meet(self):
        mock_eval = {
            "event": {
                "event_id": "GCAL-02",
                "title": "ประชุมทีมบริหารและสรุปงบประมาณ",
                "location_name": "ถนนอโศกมนตรี",
                "start_time": "2026-09-26T17:00:00+07:00"
            },
            "weather_at_event": {"precipitation_rate_mm_hr": 45.0, "heat_index_c": 30.0},
            "flood_risk": {"flood_impact": {"max_street_depth_cm": 25}},
            "concern_type": "FLOOD_AND_TRAFFIC_JAM",
            "urgency": "CRITICAL",
            "recommended_early_departure_minutes": 45,
            "recommended_action_type": "REMOTE"
        }
        adv = self.reasoner.generate_calendar_advisory(self.user, mock_eval)
        full_text = json.dumps(adv, ensure_ascii=False)
        self.assertTrue("Google Meet" in full_text or "ออนไลน์" in full_text)

    def test_mode_3_modal_shift_bts_mrt(self):
        mock_eval = {
            "event": {
                "event_id": "GCAL-03",
                "title": "ทานข้าวกับ Partner",
                "location_name": "ซอยทองหล่อ",
                "start_time": "2026-09-26T18:00:00+07:00"
            },
            "weather_at_event": {"precipitation_rate_mm_hr": 20.0, "heat_index_c": 32.0},
            "flood_risk": {"flood_impact": {"max_street_depth_cm": 16}},
            "concern_type": "FLOOD_AND_TRAFFIC_JAM",
            "urgency": "CRITICAL",
            "recommended_early_departure_minutes": 30,
            "recommended_action_type": "MODAL_SHIFT"
        }
        adv = self.reasoner.generate_calendar_advisory(self.user, mock_eval)
        full_text = json.dumps(adv, ensure_ascii=False)
        self.assertTrue("BTS" in full_text or "รถไฟฟ้า" in full_text or "ระบบราง" in full_text)

    def test_dual_schema_compatibility(self):
        mock_eval = {
            "event": {
                "event_id": "GCAL-04",
                "title": "ประชุมยุทธศาสตร์ประจำปี",
                "location_name": "อาคารเสริมมิตร (อโศก)",
                "start_time": "2026-09-26T15:00:00+07:00"
            },
            "weather_at_event": {"precipitation_rate_mm_hr": 30.0, "heat_index_c": 33.0},
            "flood_risk": {"flood_impact": {"max_street_depth_cm": 10}},
            "concern_type": "RAIN_AND_SLUGGISH_TRAFFIC",
            "urgency": "WARNING",
            "recommended_early_departure_minutes": 30,
            "recommended_action_type": "EARLY_DEPARTURE"
        }
        adv = self.reasoner.generate_calendar_advisory(self.user, mock_eval)

        # 1. Verify Go Gateway DTO keys
        self.assertIn("headline", adv)
        self.assertIn("reasoning", adv)
        self.assertIn("proactive_recommendation", adv)
        self.assertIn("departure_adjustment_mins", adv)
        self.assertIn("recommended_action_type", adv)
        self.assertEqual(adv["departure_adjustment_mins"], 30)

        # 2. Verify Thai alert keys
        self.assertIn("title", adv)
        self.assertIn("urgency_level", adv)
        self.assertIn("summary_text", adv)
        self.assertIn("critical_window", adv)
        self.assertIn("vehicle_impact", adv)
        self.assertIn("action_checklist", adv)
        self.assertIn("alternative_routes_or_actions", adv)


class TestCalendarOAuthFlow(unittest.TestCase):
    """Suite 5: OAuth 2.0 Mock Token Handling & Lifecycle"""

    def setUp(self):
        self.store = TokenStore()
        self.manager = GoogleOAuthManager(token_store=self.store)

    def test_oauth_auth_url_and_csrf_state(self):
        auth_url, state = self.manager.generate_auth_url(user_id="U_TEST_OAUTH")
        self.assertIn("accounts.google.com", auth_url)
        self.assertIn("calendar.readonly", auth_url)
        self.assertIn(state, auth_url)

        # Verify state exists in store
        popped = self.store.pop_state(state)
        self.assertIsNotNone(popped)
        self.assertEqual(popped["user_id"], "U_TEST_OAUTH")

    def test_oauth_code_exchange(self):
        _, state = self.manager.generate_auth_url(user_id="U_TEST_EXCHANGE")
        tokens = self.manager.exchange_code(code="mock_auth_code_12345", state=state)
        self.assertIn("access_token", tokens)
        self.assertIn("refresh_token", tokens)
        self.assertEqual(tokens["user_id"], "U_TEST_EXCHANGE")

        # Verify invalid state raises error
        with self.assertRaises(ValueError):
            self.manager.exchange_code(code="mock_code", state="invalid_or_expired_state")

    def test_token_persistence_and_refresh(self):
        _, state = self.manager.generate_auth_url(user_id="U_TEST_PERSIST")
        self.manager.exchange_code(code="mock_auth_code_999", state=state)

        # Check retrieval
        token = self.manager.get_valid_access_token("U_TEST_PERSIST")
        self.assertIsNotNone(token)
        self.assertTrue(token.startswith("mock_access_token_"))

        # Check refresh
        refreshed = self.manager.refresh_user_token("U_TEST_PERSIST")
        self.assertIsNotNone(refreshed)
        self.assertTrue(refreshed["access_token"].startswith("mock_refreshed_token_"))


class TestCalendarAPIEndpoints(unittest.TestCase):
    """Suite 6: FastAPI Calendar REST API Integration"""

    def test_api_calendar_events(self):
        data = get_calendar_events()
        self.assertIn("total_events", data)
        self.assertGreaterEqual(data["total_events"], 3)

    def test_api_calendar_auth_url(self):
        data = get_calendar_auth_url(user_id="U1001")
        self.assertEqual(data["status"], "ready")
        self.assertIn("authorization_url", data)
        self.assertIn("state", data)
        self.assertEqual(data["user_id"], "U1001")

    def test_api_calendar_auth_status_and_disconnect(self):
        status = get_calendar_auth_status(user_id="U_TEST_STATUS")
        self.assertIn("is_connected", status)

        disc = disconnect_calendar({"user_id": "U_TEST_STATUS"})
        self.assertEqual(disc["status"], "disconnected")

    def test_api_calendar_sync_and_evaluate(self):
        req = CalendarSyncRequest(user_id="U1001", name="คุณสมชาย", transport_mode="compact_sedan")
        data = sync_and_evaluate_calendar(req)
        self.assertIn("user_id", data)
        self.assertIn("total_events_checked", data)
        self.assertIn("events_with_weather_hazards", data)
        self.assertIn("proactive_advisories", data)
        self.assertGreaterEqual(len(data["proactive_advisories"]), 1)

        # Verify dual-schema in first advisory
        adv = data["proactive_advisories"][0]["advisory"]
        self.assertIn("headline", adv)
        self.assertIn("title", adv)
        self.assertIn("departure_adjustment_mins", adv)


if __name__ == "__main__":
    unittest.main()
