#!/usr/bin/env python3
"""
Bangkok Weather Resilience AI System
Unit and Integration Test Suite: LINE Webhook Receiver, HMAC Verification & Intent Routing

Covers Tiers 1-4:
- Tier 1: Feature Isolation (Valid signatures, event deserialization, 200 OK)
- Tier 2: Boundary & Corner Cases (Missing signature 401, Invalid signature 401,
          Malformed body 400, Empty body 400, Method gating 405)
- Tier 3: Cross-Feature Integration (Thai intents: Weather, Flood, Calendar, Vehicle,
          Flex bubble container constraints, LIFF query sync)
- Tier 4: Real-World Workload Scenarios (Commuters, delivery riders, multi-event batches)

Execution:
    venv/bin/python -m unittest tests/test_e2e_webhook.py
    venv/bin/python tests/test_e2e_webhook.py
"""

import sys
import os
import json
import unittest
from pathlib import Path

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from tests.e2e_simulation import (
    compute_line_signature,
    verify_line_signature,
    build_line_event_payload,
    build_text_message_event,
    build_apple_spatial_flex_bubble,
    build_quick_replies,
    MockGatewayHandler,
    SimulationRunner,
    DEFAULT_CHANNEL_SECRET
)


class TestLineWebhookE2E(unittest.TestCase):
    """Automated test cases covering LINE Webhook, HMAC crypto, and Thai Intent routing."""

    def setUp(self):
        self.secret = DEFAULT_CHANNEL_SECRET
        self.runner = SimulationRunner(
            target_url="http://127.0.0.1:8080/webhook/line",
            secret=self.secret,
            transport="in_memory",
            verbose=False
        )

    # ------------------------------------------------------------------------
    # Tier 1: Feature Isolation
    # ------------------------------------------------------------------------

    def test_01_valid_signature_returns_200(self):
        """Verifies that a validly signed event batch returns HTTP 200 OK."""
        ev = build_text_message_event("สวัสดี", user_id="U1001")
        body = json.dumps(build_line_event_payload([ev]), ensure_ascii=False).encode("utf-8")
        status, resp_bytes, _ = self.runner.execute_http_request(
            method="POST",
            path="/webhook/line",
            body=body,
            custom_headers={
                "Content-Type": "application/json",
                "X-Line-Signature": compute_line_signature(body, self.secret)
            }
        )
        self.assertEqual(status, 200)
        resp = json.loads(resp_bytes.decode("utf-8"))
        self.assertEqual(resp.get("status"), "OK")
        self.assertEqual(resp.get("events_processed"), 1)

    def test_02_empty_events_verification_ping(self):
        """Verifies LINE Developers Console webhook verification ping (empty events list)."""
        body = json.dumps(build_line_event_payload([])).encode("utf-8")
        status, resp_bytes, _ = self.runner.execute_http_request(
            method="POST",
            path="/webhook/line",
            body=body,
            custom_headers={
                "Content-Type": "application/json",
                "X-Line-Signature": compute_line_signature(body, self.secret)
            }
        )
        self.assertEqual(status, 200)
        resp = json.loads(resp_bytes.decode("utf-8"))
        self.assertEqual(resp.get("events_processed"), 0)

    def test_03_thai_unicode_and_emojis(self):
        """Verifies HMAC calculation over raw UTF-8 bytes with Thai unicode and multi-byte emojis."""
        text = "ฝนตกไหมแถวอโศก 🚗🌧️ ทะเลาะกับน้ำท่วมประจำวัน"
        ev = build_text_message_event(text, user_id="U1001")
        body = json.dumps(build_line_event_payload([ev]), ensure_ascii=False).encode("utf-8")
        sig = compute_line_signature(body, self.secret)
        self.assertTrue(verify_line_signature(body, sig, self.secret))

        status, resp_bytes, _ = self.runner.execute_http_request(
            method="POST",
            path="/webhook/line",
            body=body,
            custom_headers={
                "Content-Type": "application/json",
                "X-Line-Signature": sig
            }
        )
        self.assertEqual(status, 200)

    # ------------------------------------------------------------------------
    # Tier 2: Boundary & Corner Cases (Error Handling)
    # ------------------------------------------------------------------------

    def test_04_missing_signature_returns_401(self):
        """Requests without X-Line-Signature must be rejected with HTTP 401."""
        ev = build_text_message_event("สวัสดี", user_id="U1001")
        body = json.dumps(build_line_event_payload([ev])).encode("utf-8")
        status, resp_bytes, _ = self.runner.execute_http_request(
            method="POST",
            path="/webhook/line",
            body=body,
            custom_headers={"Content-Type": "application/json"}
        )
        self.assertEqual(status, 401)
        resp = json.loads(resp_bytes.decode("utf-8"))
        self.assertIn("Missing X-Line-Signature", resp.get("error", ""))

    def test_05_invalid_signature_returns_401(self):
        """Tampered or invalid signature must be rejected with HTTP 401."""
        ev = build_text_message_event("สวัสดี", user_id="U1001")
        body = json.dumps(build_line_event_payload([ev])).encode("utf-8")
        status, resp_bytes, _ = self.runner.execute_http_request(
            method="POST",
            path="/webhook/line",
            body=body,
            custom_headers={
                "Content-Type": "application/json",
                "X-Line-Signature": "totally_fabricated_invalid_signature_digest="
            }
        )
        self.assertEqual(status, 401)
        resp = json.loads(resp_bytes.decode("utf-8"))
        self.assertIn("Invalid HMAC-SHA256 signature", resp.get("error", ""))

    def test_06_tampered_body_returns_401(self):
        """Signature calculated for one body must fail if body bytes are altered."""
        body_original = b'{"destination":"U1","events":[]}'
        body_tampered = b'{"destination":"U2","events":[]}'
        sig = compute_line_signature(body_original, self.secret)

        status, _, _ = self.runner.execute_http_request(
            method="POST",
            path="/webhook/line",
            body=body_tampered,
            custom_headers={
                "Content-Type": "application/json",
                "X-Line-Signature": sig
            }
        )
        self.assertEqual(status, 401)

    def test_07_malformed_json_returns_400(self):
        """Malformed or incomplete JSON body must return HTTP 400 Bad Request."""
        corrupt_body = b'{"destination":"U100","events":[{"type":"message",'
        sig = compute_line_signature(corrupt_body, self.secret)

        status, resp_bytes, _ = self.runner.execute_http_request(
            method="POST",
            path="/webhook/line",
            body=corrupt_body,
            custom_headers={
                "Content-Type": "application/json",
                "X-Line-Signature": sig
            }
        )
        self.assertEqual(status, 400)
        resp = json.loads(resp_bytes.decode("utf-8"))
        self.assertIn("Malformed JSON payload", resp.get("error", ""))

    def test_08_empty_body_returns_400(self):
        """Zero-byte request body must return HTTP 400 Bad Request."""
        sig = compute_line_signature(b"", self.secret)
        status, resp_bytes, _ = self.runner.execute_http_request(
            method="POST",
            path="/webhook/line",
            body=b"",
            custom_headers={
                "Content-Type": "application/json",
                "X-Line-Signature": sig
            }
        )
        self.assertEqual(status, 400)

    def test_09_non_post_get_method_returns_405(self):
        """HTTP GET to /webhook/line must return HTTP 405 Method Not Allowed."""
        status, resp_bytes, headers = self.runner.execute_http_request(
            method="GET",
            path="/webhook/line"
        )
        self.assertEqual(status, 405)
        self.assertEqual(headers.get("Allow"), "POST")

    def test_10_non_post_put_method_returns_405(self):
        """HTTP PUT to /webhook/line must return HTTP 405 Method Not Allowed."""
        status, _, headers = self.runner.execute_http_request(
            method="PUT",
            path="/webhook/line",
            body=b"test"
        )
        self.assertEqual(status, 405)
        self.assertEqual(headers.get("Allow"), "POST")

    def test_11_non_post_delete_method_returns_405(self):
        """HTTP DELETE to /webhook/line must return HTTP 405 Method Not Allowed."""
        status, _, headers = self.runner.execute_http_request(
            method="DELETE",
            path="/webhook/line"
        )
        self.assertEqual(status, 405)
        self.assertEqual(headers.get("Allow"), "POST")

    # ------------------------------------------------------------------------
    # Tier 3: Cross-Feature Integration (Thai NLP Intents & Flex Schema)
    # ------------------------------------------------------------------------

    def test_12_weather_intent_bubble_structure(self):
        """Thai weather intent generates Apple Spatial Flex Bubble with Bento telemetry and LIFF CTA."""
        ev = build_text_message_event("ขอตรวจสอบสภาพอากาศวันนี้หน่อยครับ", user_id="U1001")
        body = json.dumps(build_line_event_payload([ev]), ensure_ascii=False).encode("utf-8")
        status, resp_bytes, _ = self.runner.execute_http_request(
            method="POST",
            path="/webhook/line",
            body=body,
            custom_headers={
                "Content-Type": "application/json",
                "X-Line-Signature": compute_line_signature(body, self.secret)
            }
        )
        self.assertEqual(status, 200)
        resp = json.loads(resp_bytes.decode("utf-8"))
        replies = resp.get("replies", [])
        self.assertEqual(len(replies), 1)

        reply = replies[0]
        self.assertEqual(reply["intent"], "WEATHER")
        bubble = reply["flex_bubble"]
        self.assertEqual(bubble["type"], "bubble")
        self.assertEqual(bubble["styles"]["body"]["backgroundColor"], "#091122")
        self.assertIn("tab=dashboard", bubble["footer"]["contents"][0]["action"]["uri"])

    def test_13_flood_intent_bubble_structure(self):
        """Thai flood intent generates Critical Urgency Flex Bubble with hazard CTA."""
        ev = build_text_message_event("ตอนนี้มีจุดเสี่ยงน้ำท่วมและระดับคลองเป็นอย่างไร", user_id="U1001")
        body = json.dumps(build_line_event_payload([ev]), ensure_ascii=False).encode("utf-8")
        status, resp_bytes, _ = self.runner.execute_http_request(
            method="POST",
            path="/webhook/line",
            body=body,
            custom_headers={
                "Content-Type": "application/json",
                "X-Line-Signature": compute_line_signature(body, self.secret)
            }
        )
        self.assertEqual(status, 200)
        resp = json.loads(resp_bytes.decode("utf-8"))
        reply = resp["replies"][0]
        self.assertEqual(reply["intent"], "FLOOD")
        bubble = reply["flex_bubble"]
        self.assertEqual(bubble["header"]["backgroundColor"], "#D32F2F")  # CRITICAL red
        self.assertIn("focus=hazard", bubble["footer"]["contents"][0]["action"]["uri"])

    def test_14_calendar_intent_bubble_structure(self):
        """Thai calendar intent generates Calendar Clash advisory with tab=calendar CTA."""
        ev = build_text_message_event("วันนี้มีนัดหมายประชุม ต้องเตรียมตัวอย่างไร", user_id="U1001")
        body = json.dumps(build_line_event_payload([ev]), ensure_ascii=False).encode("utf-8")
        status, resp_bytes, _ = self.runner.execute_http_request(
            method="POST",
            path="/webhook/line",
            body=body,
            custom_headers={
                "Content-Type": "application/json",
                "X-Line-Signature": compute_line_signature(body, self.secret)
            }
        )
        self.assertEqual(status, 200)
        resp = json.loads(resp_bytes.decode("utf-8"))
        reply = resp["replies"][0]
        self.assertEqual(reply["intent"], "CALENDAR")
        self.assertIn("tab=calendar", reply["flex_bubble"]["footer"]["contents"][0]["action"]["uri"])

    def test_15_vehicle_profile_intent_persistence(self):
        """Updating vehicle mode updates user session and syncs to LIFF CTA."""
        ev = build_text_message_event("ฉันเปลี่ยนมาขับรถ มอเตอร์ไซค์ แล้วนะ", user_id="U1001")
        body = json.dumps(build_line_event_payload([ev]), ensure_ascii=False).encode("utf-8")
        status, resp_bytes, _ = self.runner.execute_http_request(
            method="POST",
            path="/webhook/line",
            body=body,
            custom_headers={
                "Content-Type": "application/json",
                "X-Line-Signature": compute_line_signature(body, self.secret)
            }
        )
        self.assertEqual(status, 200)
        resp = json.loads(resp_bytes.decode("utf-8"))
        reply = resp["replies"][0]
        self.assertEqual(reply["intent"], "VEHICLE_PROFILE")
        self.assertIn("vehicle=motorcycle", reply["flex_bubble"]["footer"]["contents"][0]["action"]["uri"])

    def test_16_quick_reply_constraints(self):
        """Validates that Quick Reply chips adhere to LINE limits (<= 13 items, labels <= 20 runes)."""
        qr = build_quick_replies()
        items = qr.get("items", [])
        self.assertLessEqual(len(items), 13)
        for it in items:
            action = it.get("action", {})
            self.assertEqual(action.get("type"), "message")
            label = action.get("label", "")
            self.assertLessEqual(len(label), 20)

    # ------------------------------------------------------------------------
    # Tier 4: Real-World Workload Scenarios
    # ------------------------------------------------------------------------

    def test_17_high_volume_batch_events(self):
        """Simulates 25 events delivered in a single webhook batch, verifying zero drops."""
        events = [
            build_text_message_event(f"ผู้ใช้งาน {i} สอบถาม สภาพอากาศ", user_id=f"U_BATCH_{i}")
            for i in range(25)
        ]
        body = json.dumps(build_line_event_payload(events), ensure_ascii=False).encode("utf-8")
        status, resp_bytes, _ = self.runner.execute_http_request(
            method="POST",
            path="/webhook/line",
            body=body,
            custom_headers={
                "Content-Type": "application/json",
                "X-Line-Signature": compute_line_signature(body, self.secret)
            }
        )
        self.assertEqual(status, 200)
        resp = json.loads(resp_bytes.decode("utf-8"))
        self.assertEqual(resp.get("events_processed"), 25)
        self.assertEqual(len(resp.get("replies", [])), 25)


if __name__ == "__main__":
    unittest.main()
