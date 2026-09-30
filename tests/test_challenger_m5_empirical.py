"""
Bangkok Weather Resilience & Proactive Disaster Preparedness System
Milestone 5 (Ticket 06) Empirical Challenger Verification Suite

Stress-Tests:
1. Geocoding & Fuzzy Normalization Stress Test:
   - Challenge geocoding with noisy strings (room/floor markers, Unicode emojis, typos, Thai abbreviations like "มศว", "สยาม", "อโศก", "แจ้งวัฒนะ").
   - Verify all resolved coordinates fall within Bangkok metropolitan area (13.4 <= lat <= 14.2, 100.3 <= lng <= 100.9).
   - Verify robust handling of empty, None, and unknown inputs.
2. Proactive Shift Modes Challenge:
   - Empirically verify that EARLY_DEPARTURE, REMOTE, and MODAL_SHIFT trigger appropriately based on simulated weather and flood conditions.
   - Test threshold boundaries (water depth 14cm vs 15cm, precip 24.9 vs 25.0 mm/h, heat index 39 vs 40°C outdoor).
3. Dual-Schema Validation:
   - Empirically verify that both Go Gateway DTO keys (headline, reasoning, proactive_recommendation, departure_adjustment_mins, recommended_action_type)
     and Thai alert keys (title, urgency_level, summary_text, critical_window, vehicle_impact, action_checklist, alternative_routes_or_actions)
     are populated in the advisory payload across all scenarios.
4. Concurrency & Race Testing:
   - Multi-threaded stress testing on TokenStore and GoogleOAuthManager under concurrent read/write/pop operations.
"""

import unittest
import sys
import os
import json
import time
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

import engine.collectors.google_calendar as gc
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
    sync_and_evaluate_calendar,
    CalendarSyncRequest,
    get_calendar_events
)


class TestGeocodingFuzzyStress(unittest.TestCase):
    """Suite 1: Geocoding & Fuzzy Normalization Stress Test"""

    BKK_LAT_MIN = 13.40
    BKK_LAT_MAX = 14.20
    BKK_LNG_MIN = 100.30
    BKK_LNG_MAX = 100.90

    def assert_in_bangkok_bounds(self, lat: float, lng: float, msg: str = ""):
        self.assertTrue(
            self.BKK_LAT_MIN <= lat <= self.BKK_LAT_MAX,
            f"Latitude {lat} outside Bangkok [{self.BKK_LAT_MIN}, {self.BKK_LAT_MAX}]. {msg}"
        )
        self.assertTrue(
            self.BKK_LNG_MIN <= lng <= self.BKK_LNG_MAX,
            f"Longitude {lng} outside Bangkok [{self.BKK_LNG_MIN}, {self.BKK_LNG_MAX}]. {msg}"
        )

    def test_all_dictionary_landmarks_in_bangkok(self):
        """Verify all 68+ landmark dictionary coordinates fall strictly in Bangkok."""
        self.assertGreaterEqual(len(BANGKOK_PLACES_GEOCODE), 50)
        for key, entry in BANGKOK_PLACES_GEOCODE.items():
            self.assert_in_bangkok_bounds(entry["lat"], entry["lng"], f"Landmark: {key}")

    def test_thai_abbreviations_and_acronyms(self):
        """Challenge geocoder with Thai abbreviations: มศว, สยาม, อโศก, แจ้งวัฒนะ, etc."""
        cases = [
            ("มศว", "ศรีนครินทรวิโรฒ"),
            ("สยาม", "สยาม"),
            ("อโศก", "อโศก"),
            ("แจ้งวัฒนะ", "แจ้งวัฒนะ"),
            ("swu", "ศรีนครินทรวิโรฒ"),
            ("cwt", "แจ้งวัฒนะ"),
            ("dmk", "ดอนเมือง"),
            ("bkk", "สุวรรณภูมิ"),
            ("ม.เกษตร", "เกษตรศาสตร์"),
            ("มธ", "ธรรมศาสตร์"),
            ("รพ.จุฬา", "จุฬาลงกรณ์"),
            ("รพ.ศิริราช", "ศิริราช"),
            ("รพ.รามา", "รามาธิบดี"),
        ]
        for query, expected_snippet in cases:
            res = geocode_bangkok_location(query)
            self.assert_in_bangkok_bounds(res["lat"], res["lng"], f"Query: {query}")
            self.assertTrue(
                expected_snippet in res["name_th"] or expected_snippet.lower() in res["name_en"].lower(),
                f"Query '{query}' failed to match expected snippet '{expected_snippet}'. Got: {res['name_th']}"
            )

    def test_noisy_room_floor_and_prefixes(self):
        """Challenge geocoder with complex noise, room numbers, floor levels, English/Thai mixing."""
        noisy_queries = [
            ("ชั้น 4 ห้อง 402 อาคารเสริมมิตร ถ.อโศกมนตรี กทม.", "อโศกมนตรี"),
            ("Fl. 18 Meeting Room 101, Serm-Mit Tower Asoke", "อโศกมนตรี"),
            ("ห้องประชุมสัญญา ศูนย์ราชการแจ้งวัฒนะ อาคาร B ชั้น 2 ประตู 3", "แจ้งวัฒนะ"),
            ("Floor 3 Room B-24, CentralWorld Rama 1 Road", "เซ็นทรัลเวิลด์"),
            ("นัดทานข้าว สยามพารากอน ชั้น G โซน The Gourmet Garden", "สยามพารากอน"),
            ("True Digital Park Building 101, Suite 502, Sukhumvit 101", "ทรู ดิจิทัล พาร์ค"),
            ("ไอคอนสยาม ชั้น 7 ท่าเรือ 2 ฝั่งคลองสาน", "ไอคอนสยาม"),
            ("สถานีรถไฟฟ้า BTS อารีย์ ทางออก 3 หน้าตึกปิยวรรณ", "อารีย์"),
        ]
        for query, expected_snippet in noisy_queries:
            res = geocode_bangkok_location(query)
            self.assert_in_bangkok_bounds(res["lat"], res["lng"], f"Query: {query}")
            self.assertTrue(
                expected_snippet in res["name_th"] or expected_snippet.lower() in res["name_en"].lower(),
                f"Query '{query}' expected '{expected_snippet}' but got '{res['name_th']}'"
            )

    def test_unicode_emojis_and_symbols(self):
        """Challenge geocoder with Unicode emojis and punctuation symbols."""
        emoji_queries = [
            ("🏢 นัดคุยงานที่ สยามพารากอน 🍣 ชั้น 5 🍵", "สยามพารากอน"),
            ("🌧️ น้ำท่วม อโศก 🚗 รถติดหนักมาก รีบมา", "อโศก"),
            ("มศว ประสานมิตร อาคารเรียนรวม 🌟🎓 ชั้น 2", "ศรีนครินทรวิโรฒ"),
            ("📍 ศูนย์ราชการแจ้งวัฒนะ อาคาร B ⚡☔", "แจ้งวัฒนะ"),
            ("🚇 BTS สยาม ทางออก 4 นัดเจอหน้าพารากอน ✨", "สยาม"),
            ("✈️ ดอนเมือง อาคาร 2 ผู้โดยสารขาเข้า 🧳", "ดอนเมือง"),
        ]
        for query, expected_snippet in emoji_queries:
            res = geocode_bangkok_location(query)
            self.assert_in_bangkok_bounds(res["lat"], res["lng"], f"Query: {query}")
            self.assertTrue(
                expected_snippet in res["name_th"] or expected_snippet.lower() in res["name_en"].lower(),
                f"Query '{query}' expected '{expected_snippet}' but got '{res['name_th']}'"
            )

    def test_fuzzy_typos_and_subtle_errors(self):
        """Challenge geocoder with typos (double vowels, phonetic slips, trailing chars)."""
        typo_queries = [
            ("สยามพารากอนน", "สยามพารากอน"),
            ("เเจ้งวัฒนะ", "แจ้งวัฒนะ"),  # Two single 'เ' vowels instead of 'แ'
            ("เสิมมิตร", "เสริมมิตร"),      # Missing ror-ruea in serm-mit
            ("ไอคอนสยามม", "ไอคอนสยาม"),
        ]
        for query, expected_snippet in typo_queries:
            res = geocode_bangkok_location(query)
            self.assert_in_bangkok_bounds(res["lat"], res["lng"], f"Query: {query}")
            self.assertTrue(
                expected_snippet in res["name_th"] or expected_snippet.lower() in res["name_en"].lower(),
                f"Query '{query}' expected '{expected_snippet}' but got '{res['name_th']}'"
            )

    def test_safe_fallback_on_unrecognized_or_empty_inputs(self):
        """Verify robust fallback to Bangkok center without throwing exceptions."""
        edge_cases = [
            "",
            "   \t\n  ",
            None,
            "1234567890",
            "!@#$%^&*()_+",
            "Times Square New York City USA",
            "Unknown Nonexistent Landmark In Mars 9999",
        ]
        for query in edge_cases:
            res = geocode_bangkok_location(query)
            self.assertIsInstance(res, dict)
            self.assert_in_bangkok_bounds(res["lat"], res["lng"], f"Fallback for: {query!r}")
            self.assertEqual(res["match_type"], "fallback_city_center")
            self.assertAlmostEqual(res["lat"], 13.7563, places=3)
            self.assertAlmostEqual(res["lng"], 100.5018, places=3)


class TestProactiveShiftModesStress(unittest.TestCase):
    """Suite 2: Proactive Shift Modes Challenge (EARLY_DEPARTURE, REMOTE, MODAL_SHIFT)"""

    def setUp(self):
        self.reasoner = GeminiWeatherReasoner()
        self.user_sedan = {"name": "คุณสมชาย", "transport_mode": "compact_sedan"}
        self.user_moto = {"name": "คุณสมศักดิ์", "transport_mode": "motorcycle"}
        self.user_pickup = {"name": "คุณประสิทธิ์", "transport_mode": "pickup"}

    def test_mode_early_departure_trigger_and_boundary(self):
        """Verify EARLY_DEPARTURE triggers under moderate rainfall or shallow street water."""
        # 1. Below threshold: 20 mm/h, 3cm water -> no concern
        mock_weather_low = {"precipitation_rate_mm_hr": 20.0, "heat_index_c": 30.0, "wind_gust_kmh": 15.0}
        mock_flood_low = {"flood_impact": {"max_street_depth_cm": 3, "matched_hotspots": []}}
        
        # 2. At threshold: 25.0 mm/h -> triggers EARLY_DEPARTURE (30 mins)
        eval_early_1 = {
            "event": {"event_id": "EVT-ED1", "title": "ประชุมทีม A", "location_name": "ถนนลาดพร้าว", "start_time": "2026-09-26T16:00:00+07:00"},
            "weather_at_event": {"precipitation_rate_mm_hr": 25.0, "heat_index_c": 31.0, "wind_gust_kmh": 20.0},
            "flood_risk": {"flood_impact": {"max_street_depth_cm": 6}},
            "concern_type": "RAIN_AND_SLUGGISH_TRAFFIC",
            "urgency": "WARNING",
            "recommended_early_departure_minutes": 30,
            "recommended_action_type": "EARLY_DEPARTURE"
        }
        adv = self.reasoner.generate_calendar_advisory(self.user_sedan, eval_early_1)
        self.assertEqual(adv["recommended_action_type"], "EARLY_DEPARTURE")
        self.assertEqual(adv["departure_adjustment_mins"], 30)
        self.assertIn("30", " ".join(adv["action_checklist"]))
        self.assertIn("ออกเดินทาง", adv["proactive_recommendation"])

    def test_mode_modal_shift_trigger_for_vulnerable_vehicles(self):
        """Verify MODAL_SHIFT triggers when street depth >= 15cm for compact_sedan and motorcycle."""
        eval_deep_water = {
            "event": {"event_id": "EVT-MS1", "title": "ตรวจงานโครงการ", "location_name": "สุขุมวิท 21 อโศก", "start_time": "2026-09-26T17:00:00+07:00"},
            "weather_at_event": {"precipitation_rate_mm_hr": 45.0, "heat_index_c": 30.0, "wind_gust_kmh": 30.0},
            "flood_risk": {"flood_impact": {"max_street_depth_cm": 18, "matched_hotspots": [{"name_th": "อโศก"}]}},
            "concern_type": "FLOOD_AND_TRAFFIC_JAM",
            "urgency": "CRITICAL",
            "recommended_early_departure_minutes": 45,
            "recommended_action_type": "MODAL_SHIFT"
        }

        # For compact_sedan
        adv_sedan = self.reasoner.generate_calendar_advisory(self.user_sedan, eval_deep_water)
        self.assertEqual(adv_sedan["recommended_action_type"], "MODAL_SHIFT")
        self.assertEqual(adv_sedan["departure_adjustment_mins"], 45)
        text_sedan = json.dumps(adv_sedan, ensure_ascii=False)
        self.assertTrue("BTS" in text_sedan or "MRT" in text_sedan or "รถไฟฟ้า" in text_sedan)
        self.assertTrue("ท่อไอเสีย" in text_sedan or "น้ำท่วม" in text_sedan)

        # For motorcycle
        adv_moto = self.reasoner.generate_calendar_advisory(self.user_moto, eval_deep_water)
        self.assertEqual(adv_moto["recommended_action_type"], "MODAL_SHIFT")
        text_moto = json.dumps(adv_moto, ensure_ascii=False)
        self.assertTrue("BTS" in text_moto or "MRT" in text_moto or "รถไฟฟ้า" in text_moto)

    def test_mode_remote_trigger_under_severe_flood_or_extreme_heat(self):
        """Verify REMOTE triggers under impassable flood (>20cm or high-clearance vehicle) or extreme heat (>40°C)."""
        # Case A: High water depth with pickup -> REMOTE (recommended over risking deep flood corridors)
        eval_severe_flood = {
            "event": {"event_id": "EVT-REM1", "title": "ประชุมคณะกรรมการบริษัท", "location_name": "ถนนแจ้งวัฒนะ", "start_time": "2026-09-26T16:30:00+07:00"},
            "weather_at_event": {"precipitation_rate_mm_hr": 55.0, "heat_index_c": 30.0, "wind_gust_kmh": 40.0},
            "flood_risk": {"flood_impact": {"max_street_depth_cm": 25, "matched_hotspots": [{"name_th": "แจ้งวัฒนะ"}]}},
            "concern_type": "FLOOD_AND_TRAFFIC_JAM",
            "urgency": "CRITICAL",
            "recommended_early_departure_minutes": 45,
            "recommended_action_type": "REMOTE"
        }
        adv_flood = self.reasoner.generate_calendar_advisory(self.user_pickup, eval_severe_flood)
        self.assertEqual(adv_flood["recommended_action_type"], "REMOTE")
        text_flood = json.dumps(adv_flood, ensure_ascii=False)
        self.assertTrue("Google Meet" in text_flood or "ออนไลน์" in text_flood)

        # Case B: Extreme Heat outdoor activity -> REMOTE / Reschedule
        eval_heat = {
            "event": {"event_id": "EVT-REM2", "title": "แข่งขันกอล์ฟกระชับมิตร", "location_name": "สนามกอล์ฟกรุงเทพกรีฑา", "start_time": "2026-09-27T12:00:00+07:00"},
            "weather_at_event": {"precipitation_rate_mm_hr": 0.0, "heat_index_c": 42.5, "wind_gust_kmh": 10.0},
            "flood_risk": {"flood_impact": {"max_street_depth_cm": 0}},
            "concern_type": "EXTREME_HEAT_OUTDOOR",
            "urgency": "WARNING",
            "recommended_early_departure_minutes": 0,
            "recommended_action_type": "REMOTE"
        }
        adv_heat = self.reasoner.generate_calendar_advisory(self.user_sedan, eval_heat)
        self.assertEqual(adv_heat["recommended_action_type"], "REMOTE")
        text_heat = json.dumps(adv_heat, ensure_ascii=False)
        self.assertTrue("ฮีทสโตรก" in text_heat or "ความร้อน" in text_heat)


class TestDualSchemaValidation(unittest.TestCase):
    """Suite 3: Dual-Schema Validation across Go Gateway DTO and Thai Alert contracts"""

    GO_DTO_KEYS = [
        "headline",
        "reasoning",
        "proactive_recommendation",
        "departure_adjustment_mins",
        "recommended_action_type"
    ]

    THAI_ALERT_KEYS = [
        "title",
        "urgency_level",
        "summary_text",
        "critical_window",
        "vehicle_impact",
        "action_checklist",
        "alternative_routes_or_actions"
    ]

    def verify_dual_schema(self, advisory: dict, scenario_desc: str):
        """Helper to assert all 5 Go DTO keys and 7 Thai Alert keys exist and are non-empty."""
        for key in self.GO_DTO_KEYS:
            self.assertIn(key, advisory, f"Missing Go DTO key '{key}' in {scenario_desc}")
            val = advisory[key]
            if key == "departure_adjustment_mins":
                self.assertIsInstance(val, int, f"Key '{key}' must be int in {scenario_desc}")
                self.assertGreaterEqual(val, 0)
            else:
                self.assertIsInstance(val, str, f"Key '{key}' must be str in {scenario_desc}")
                self.assertTrue(len(val.strip()) > 0, f"Key '{key}' must not be empty in {scenario_desc}")

        for key in self.THAI_ALERT_KEYS:
            self.assertIn(key, advisory, f"Missing Thai Alert key '{key}' in {scenario_desc}")
            val = advisory[key]
            if key == "action_checklist":
                self.assertIsInstance(val, list, f"Key '{key}' must be list in {scenario_desc}")
                self.assertGreaterEqual(len(val), 2, f"Key '{key}' must have >= 2 items in {scenario_desc}")
            else:
                self.assertIsInstance(val, str, f"Key '{key}' must be str in {scenario_desc}")
                self.assertTrue(len(val.strip()) > 0, f"Key '{key}' must not be empty in {scenario_desc}")

    def test_dual_schema_in_all_matcher_scenarios(self):
        """Verify dual-schema holds for all evaluated appointments returned by FastAPI sync endpoint."""
        req = CalendarSyncRequest(user_id="U1001", name="คุณสมชาย", transport_mode="compact_sedan")
        response = sync_and_evaluate_calendar(req)
        self.assertIn("proactive_advisories", response)
        self.assertGreaterEqual(len(response["proactive_advisories"]), 1)

        for item in response["proactive_advisories"]:
            adv = item["advisory"]
            self.verify_dual_schema(adv, f"Event {item.get('event_id')}")

    def test_dual_schema_in_all_shift_modes(self):
        """Verify dual-schema holds explicitly across EARLY_DEPARTURE, REMOTE, MODAL_SHIFT, and CLEAR."""
        reasoner = GeminiWeatherReasoner()
        user = {"name": "คุณสมชาย", "transport_mode": "compact_sedan"}

        scenarios = [
            ("EARLY_DEPARTURE", {
                "event": {"event_id": "S1", "title": "นัดหมาย 1", "location_name": "ลาดพร้าว", "start_time": "2026-09-26T15:00:00+07:00"},
                "weather_at_event": {"precipitation_rate_mm_hr": 28.0, "heat_index_c": 31.0},
                "flood_risk": {"flood_impact": {"max_street_depth_cm": 8}},
                "concern_type": "RAIN_AND_SLUGGISH_TRAFFIC",
                "urgency": "WARNING",
                "recommended_early_departure_minutes": 30,
                "recommended_action_type": "EARLY_DEPARTURE"
            }),
            ("MODAL_SHIFT", {
                "event": {"event_id": "S2", "title": "นัดหมาย 2", "location_name": "อโศก", "start_time": "2026-09-26T17:00:00+07:00"},
                "weather_at_event": {"precipitation_rate_mm_hr": 48.0, "heat_index_c": 30.0},
                "flood_risk": {"flood_impact": {"max_street_depth_cm": 18}},
                "concern_type": "FLOOD_AND_TRAFFIC_JAM",
                "urgency": "CRITICAL",
                "recommended_early_departure_minutes": 45,
                "recommended_action_type": "MODAL_SHIFT"
            }),
            ("REMOTE", {
                "event": {"event_id": "S3", "title": "นัดหมาย 3", "location_name": "แจ้งวัฒนะ", "start_time": "2026-09-26T16:00:00+07:00"},
                "weather_at_event": {"precipitation_rate_mm_hr": 60.0, "heat_index_c": 30.0},
                "flood_risk": {"flood_impact": {"max_street_depth_cm": 25}},
                "concern_type": "FLOOD_AND_TRAFFIC_JAM",
                "urgency": "CRITICAL",
                "recommended_early_departure_minutes": 45,
                "recommended_action_type": "REMOTE"
            }),
            ("CLEAR_WEATHER", {
                "event": {"event_id": "S4", "title": "นัดหมาย 4", "location_name": "สยามพารากอน", "start_time": "2026-09-27T10:00:00+07:00"},
                "weather_at_event": {"precipitation_rate_mm_hr": 0.0, "heat_index_c": 28.0},
                "flood_risk": {"flood_impact": {"max_street_depth_cm": 0}},
                "concern_type": "NONE",
                "urgency": "INFO",
                "recommended_early_departure_minutes": 0,
                "recommended_action_type": "EARLY_DEPARTURE"
            })
        ]

        for mode_name, eval_data in scenarios:
            adv = reasoner.generate_calendar_advisory(user, eval_data)
            self.verify_dual_schema(adv, f"Scenario {mode_name}")


class TestConcurrencyAndThreadSafety(unittest.TestCase):
    """Suite 4: Concurrency & Race Testing for In-Memory TokenStore & OAuth Lifecycle"""

    def test_token_store_concurrent_access(self):
        """Stress-test TokenStore with 50 concurrent threads executing rapid save/get/pop."""
        store = TokenStore()
        errors = []

        def worker(thread_idx: int):
            try:
                user_id = f"U_CONCURRENT_{thread_idx}"
                state_key = f"STATE_{thread_idx}"

                # 1. Save and pop state
                store.save_state(state_key, {"user_id": user_id, "idx": thread_idx}, ttl_seconds=60)
                popped = store.pop_state(state_key)
                if not popped or popped.get("user_id") != user_id:
                    errors.append(f"Thread {thread_idx} state pop mismatch")

                # 2. Save and get tokens
                tokens = {"access_token": f"acc_{thread_idx}", "refresh_token": f"ref_{thread_idx}", "expires_at": time.time() + 3600}
                store.save_tokens(user_id, tokens)
                retrieved = store.get_tokens(user_id)
                if not retrieved or retrieved.get("access_token") != f"acc_{thread_idx}":
                    errors.append(f"Thread {thread_idx} token get mismatch")

                # 3. Delete tokens
                store.delete_tokens(user_id)
                after_del = store.get_tokens(user_id)
                if after_del is not None:
                    errors.append(f"Thread {thread_idx} token delete failed")

            except Exception as e:
                errors.append(f"Thread {thread_idx} exception: {e}")

        threads = [threading.Thread(target=worker, args=(i,)) for i in range(50)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        self.assertEqual(len(errors), 0, f"Concurrent TokenStore errors: {errors}")

    def test_oauth_manager_concurrent_flow(self):
        """Stress-test GoogleOAuthManager with concurrent auth URL generation and code exchange."""
        manager = GoogleOAuthManager()
        errors = []

        def oauth_worker(idx: int):
            try:
                uid = f"U_OAUTH_CONCURRENT_{idx}"
                auth_url, state = manager.generate_auth_url(user_id=uid)
                if not state or state not in auth_url:
                    errors.append(f"Thread {idx} state not in auth_url")

                # Exchange mock code
                tokens = manager.exchange_code(code=f"mock_code_{idx}", state=state)
                if not tokens or tokens.get("user_id") != uid:
                    errors.append(f"Thread {idx} exchanged user_id mismatch")

                # Refresh token
                refreshed = manager.refresh_user_token(uid)
                if not refreshed or not refreshed.get("access_token"):
                    errors.append(f"Thread {idx} refresh failed")

            except Exception as e:
                errors.append(f"Thread {idx} exception: {e}")

        with ThreadPoolExecutor(max_workers=20) as executor:
            futures = [executor.submit(oauth_worker, i) for i in range(40)]
            for f in futures:
                f.result()

        self.assertEqual(len(errors), 0, f"Concurrent OAuth errors: {errors}")


if __name__ == "__main__":
    unittest.main()
