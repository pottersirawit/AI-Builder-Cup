#!/usr/bin/env python3
"""
Bangkok Weather Resilience System - Live Gateway Adversarial Challenge Suite
Tests the compiled Go Gateway HTTP server against adversarial payloads,
cryptographic tampering, malformed JSON, boundary payload sizes, and complex Thai Unicode/emojis.
"""

import sys
import os
import time
import json
import hmac
import hashlib
import base64
import subprocess
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
GATEWAY_BIN = PROJECT_ROOT / "gateway" / "bin" / "server"
TEST_PORT = 8089
BASE_URL = f"http://127.0.0.1:{TEST_PORT}"
WEBHOOK_URL = f"{BASE_URL}/webhook/line"
TEST_SECRET = "challenger_adversarial_channel_secret_bangkok_2026_!@#"


def compute_signature(secret: str, body: bytes) -> str:
    mac = hmac.new(secret.encode("utf-8"), body, hashlib.sha256)
    return base64.b64encode(mac.digest()).decode("utf-8")


def send_http_request(method: str, url: str, body: bytes = None, headers: dict = None, timeout: float = 5.0):
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    hdrs = headers.copy() if headers else {}
    req = urllib.request.Request(
        url=url,
        data=body if method in ("POST", "PUT", "PATCH") else None,
        headers=hdrs,
        method=method
    )
    try:
        with opener.open(req, timeout=timeout) as resp:
            return resp.status, resp.read(), dict(resp.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read(), dict(e.headers)


def main():
    print("=" * 70)
    print("STARTING LIVE GO GATEWAY ADVERSARIAL CHALLENGE HARNESS")
    print(f"Target Binary: {GATEWAY_BIN}")
    print(f"Target URL:    {WEBHOOK_URL}")
    print(f"Secret:        {TEST_SECRET}")
    print("=" * 70)

    # 1. Compile if not already compiled
    if not GATEWAY_BIN.exists():
        print("Compiling gateway binary...")
        build_res = subprocess.run(
            ["go", "build", "-o", str(GATEWAY_BIN), "./cmd/server"],
            cwd=str(PROJECT_ROOT / "gateway"),
            capture_output=True,
            text=True
        )
        if build_res.returncode != 0:
            print(f"Compilation failed: {build_res.stderr}")
            sys.exit(1)

    # 2. Launch server in subprocess
    env = os.environ.copy()
    env["GATEWAY_PORT"] = str(TEST_PORT)
    env["LINE_CHANNEL_SECRET"] = TEST_SECRET
    env["WORKER_POOL_SIZE"] = "5"

    proc = subprocess.Popen(
        [str(GATEWAY_BIN)],
        cwd=str(PROJECT_ROOT / "gateway"),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    tests_run = 0
    tests_passed = 0
    tests_failed = 0

    try:
        # Wait for server to become healthy
        server_ready = False
        for _ in range(30):
            time.sleep(0.1)
            try:
                status, body, _ = send_http_request("GET", f"{BASE_URL}/health", timeout=1.0)
                if status == 200:
                    server_ready = True
                    break
            except Exception:
                pass

        if not server_ready:
            print("ERROR: Gateway server failed to start on port", TEST_PORT)
            sys.exit(1)

        print("SUCCESS: Live Go Gateway is UP and HEALTHY on port", TEST_PORT)
        print("-" * 70)

        def assert_test(name: str, cond: bool, detail: str = ""):
            nonlocal tests_run, tests_passed, tests_failed
            tests_run += 1
            if cond:
                tests_passed += 1
                print(f"  [PASS] {name}")
            else:
                tests_failed += 1
                print(f"  [FAIL] {name} - Detail: {detail}")

        # ====================================================================
        # Category A: Genuine HMAC & Valid Webhooks
        # ====================================================================
        print("\n--- Category A: Genuine HMAC Authentication & Valid Payloads ---")

        # A1: Standard valid text message
        payload_a1 = {
            "destination": "U1234567890abcdef",
            "events": [{
                "type": "message",
                "mode": "active",
                "timestamp": int(time.time() * 1000),
                "source": {"type": "user", "userId": "U1001"},
                "replyToken": "tokenA1",
                "message": {"id": "m1", "type": "text", "text": "สวัสดี"}
            }]
        }
        body_a1 = json.dumps(payload_a1).encode("utf-8")
        sig_a1 = compute_signature(TEST_SECRET, body_a1)
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=body_a1, headers={
            "Content-Type": "application/json",
            "X-Line-Signature": sig_a1
        })
        assert_test("Valid HMAC signature returns 200 OK with 'OK' body", status == 200 and resp_bytes.strip() == b"OK", f"status={status}, body={resp_bytes}")

        # A2: Empty events array (LINE Developers Console verification ping)
        payload_a2 = {"destination": "U1234567890abcdef", "events": []}
        body_a2 = json.dumps(payload_a2).encode("utf-8")
        sig_a2 = compute_signature(TEST_SECRET, body_a2)
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=body_a2, headers={
            "Content-Type": "application/json",
            "X-Line-Signature": sig_a2
        })
        assert_test("Empty events ping returns 200 OK", status == 200 and resp_bytes.strip() == b"OK", f"status={status}")

        # A3: Valid signature with leading/trailing whitespace in header
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=body_a1, headers={
            "Content-Type": "application/json",
            "X-Line-Signature": f"  \t {sig_a1} \r\n "
        })
        assert_test("Signature with surrounding whitespace passes (TrimSpace)", status == 200, f"status={status}")

        # ====================================================================
        # Category B: Cryptographic Tampering & Unauthorized Requests (401)
        # ====================================================================
        print("\n--- Category B: Cryptographic Tampering & Unauthorized Rejection (401) ---")

        # B1: Missing X-Line-Signature header
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=body_a1, headers={"Content-Type": "application/json"})
        assert_test("Missing X-Line-Signature returns 401 Unauthorized", status == 401, f"status={status}")

        # B2: Empty X-Line-Signature header
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=body_a1, headers={"Content-Type": "application/json", "X-Line-Signature": ""})
        assert_test("Empty X-Line-Signature returns 401 Unauthorized", status == 401, f"status={status}")

        # B3: Tampered body bytes against valid signature
        tampered_body = body_a1.replace(b"U1001", b"U9999")
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=tampered_body, headers={
            "Content-Type": "application/json",
            "X-Line-Signature": sig_a1
        })
        assert_test("Tampered body bytes rejected with 401 Unauthorized", status == 401, f"status={status}")

        # B4: Bit-flipped signature (single bit modification)
        sig_bytes = bytearray(base64.b64decode(sig_a1))
        sig_bytes[0] ^= 0x01
        corrupted_sig = base64.b64encode(sig_bytes).decode("utf-8")
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=body_a1, headers={
            "Content-Type": "application/json",
            "X-Line-Signature": corrupted_sig
        })
        assert_test("Bit-flipped signature rejected with 401 Unauthorized", status == 401, f"status={status}")

        # B5: Signature calculated with wrong channel secret
        wrong_sig = compute_signature("wrong_attacker_channel_secret_999", body_a1)
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=body_a1, headers={
            "Content-Type": "application/json",
            "X-Line-Signature": wrong_sig
        })
        assert_test("Signature with wrong secret rejected with 401 Unauthorized", status == 401, f"status={status}")

        # B6: Truncated signature
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=body_a1, headers={
            "Content-Type": "application/json",
            "X-Line-Signature": sig_a1[:15]
        })
        assert_test("Truncated signature rejected with 401 Unauthorized", status == 401, f"status={status}")

        # B7: Non-base64 malformed characters in signature
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=body_a1, headers={
            "Content-Type": "application/json",
            "X-Line-Signature": "???invalid-non-base64-bytes-%%%$$$==="
        })
        assert_test("Malformed non-base64 signature rejected with 401 Unauthorized", status == 401, f"status={status}")

        # ====================================================================
        # Category C: Malformed Bodies & Protocol Rejection (400, 405)
        # ====================================================================
        print("\n--- Category C: Malformed Bodies & Method Gating (400, 405) ---")

        # C1: Empty body (0 bytes) with signature on empty bytes
        empty_body = b""
        sig_empty = compute_signature(TEST_SECRET, empty_body)
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=empty_body, headers={
            "Content-Type": "application/json",
            "X-Line-Signature": sig_empty
        })
        assert_test("Zero-byte request body returns 400 Bad Request", status == 400, f"status={status}")

        # C2: Whitespace-only body with valid signature
        ws_body = b"  \r\n\t   \n  "
        sig_ws = compute_signature(TEST_SECRET, ws_body)
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=ws_body, headers={
            "Content-Type": "application/json",
            "X-Line-Signature": sig_ws
        })
        assert_test("Whitespace-only request body returns 400 Bad Request", status == 400, f"status={status}")

        # C3: Malformed JSON syntax (truncated JSON) with matching signature
        bad_json = b'{"destination":"U123","events":[{"type":"message",'
        sig_bad_json = compute_signature(TEST_SECRET, bad_json)
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=bad_json, headers={
            "Content-Type": "application/json",
            "X-Line-Signature": sig_bad_json
        })
        assert_test("Malformed truncated JSON returns 400 Bad Request", status == 400, f"status={status}")

        # C4: Invalid JSON data type (JSON integer instead of object)
        int_json = b'123456789'
        sig_int = compute_signature(TEST_SECRET, int_json)
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=int_json, headers={
            "Content-Type": "application/json",
            "X-Line-Signature": sig_int
        })
        assert_test("Invalid JSON root type returns 400 Bad Request", status == 400, f"status={status}")

        # C5: HTTP GET rejected with 405
        status, resp_bytes, hdrs = send_http_request("GET", WEBHOOK_URL)
        assert_test("HTTP GET returns 405 Method Not Allowed with Allow: POST", status == 405 and "POST" in hdrs.get("Allow", ""), f"status={status}, allow={hdrs.get('Allow')}")

        # C6: HTTP PUT rejected with 405
        status, resp_bytes, hdrs = send_http_request("PUT", WEBHOOK_URL, body=body_a1, headers={"X-Line-Signature": sig_a1})
        assert_test("HTTP PUT returns 405 Method Not Allowed", status == 405, f"status={status}")

        # C7: HTTP DELETE rejected with 405
        status, resp_bytes, hdrs = send_http_request("DELETE", WEBHOOK_URL)
        assert_test("HTTP DELETE returns 405 Method Not Allowed", status == 405, f"status={status}")

        # C8: HTTP PATCH rejected with 405
        status, resp_bytes, hdrs = send_http_request("PATCH", WEBHOOK_URL, body=body_a1, headers={"X-Line-Signature": sig_a1})
        assert_test("HTTP PATCH returns 405 Method Not Allowed", status == 405, f"status={status}")

        # ====================================================================
        # Category D: Thai Unicode, Multi-Byte Characters & Emojis
        # ====================================================================
        print("\n--- Category D: Complex Thai Unicode, Tone Marks & Emojis ---")

        thai_messages = [
            "สวัสดีครับ ขอทราบสภาพอากาศและปริมาณฝนสะสมเขตวัฒนา 🌧️☔",
            "น้ำท่วมขังรอการระบายในซอยสุขุมวิท ๑๐๑/๑ แยก ๕ หรือไม่ครับ 🚗🌊",
            "ฤ ฤๅ ฦ ฦๅ ฯ ะ ั า ำ ิ ี ึ ื ุ ู ฺ ฿ เ แ โ ใ ไ ๅ ๆ ็ ่ ้ ๊ ๋ ์ ํ ๎ ๏ ๐ ๑ ๒ ๓ ๔ ๕ ๖ ๗ ๘ ๙ ๚ ๛",
            "เตือนภัยน้ำท่วมระดับวิกฤต คลองแสนแสบล้นตลิ่ง +2.15 ม.รทก. 🚨🛑⚠️",
            "ขับมอเตอร์ไซค์ 🛵 ลุยน้ำลึก 25 ซม. ท่อไอเสียจะดับไหม 🛵⚡⛈️",
            "นัดหมายประชุมบ่ายนี้ที่ศูนย์ประชุมแห่งชาติสิริกิติ์ MRT สะดวกกว่า 🏢🚆",
            "ทดสอบ Thai Zero Width Space\u200Bและสระจมสระลอย\u0e48\u0e49\u0e4a\u0e4b\u0e4c",
            "🌧️⛈️⚡🌦️🌤️⛅🌥️☁️🌩️🌨️🌊🚨🚗🚙🚚🚛🛵🏍️🚲🚶‍♂️🏊‍♀️"
        ]

        for idx, text in enumerate(thai_messages, 1):
            payload = {
                "destination": "U1234567890abcdef",
                "events": [{
                    "type": "message",
                    "mode": "active",
                    "timestamp": int(time.time() * 1000) + idx,
                    "source": {"type": "user", "userId": f"U_THAI_{idx}"},
                    "replyToken": f"token_thai_{idx}",
                    "message": {"id": f"msg_thai_{idx}", "type": "text", "text": text}
                }]
            }
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            sig = compute_signature(TEST_SECRET, body)
            status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=body, headers={
                "Content-Type": "application/json; charset=utf-8",
                "X-Line-Signature": sig
            })
            assert_test(f"Thai Payload D.{idx} ({text[:25]}...) returns 200 OK", status == 200 and resp_bytes.strip() == b"OK", f"status={status}")

        # ====================================================================
        # Category E: High Volume & Concurrency Stress
        # ====================================================================
        print("\n--- Category E: Batch Delivery & High Concurrency Blasting ---")

        # E1: High volume batch (50 simultaneous events)
        batch_events = [
            {
                "type": "message",
                "mode": "active",
                "timestamp": int(time.time() * 1000) + i,
                "source": {"type": "user", "userId": f"U_BATCH_{i}"},
                "replyToken": f"token_batch_{i}",
                "message": {"id": f"msg_{i}", "type": "text", "text": f"ข้อความ {i} สภาพอากาศ กรุงเทพฯ ⛈️"}
            }
            for i in range(50)
        ]
        payload_batch = {"destination": "U1234567890abcdef", "events": batch_events}
        body_batch = json.dumps(payload_batch, ensure_ascii=False).encode("utf-8")
        sig_batch = compute_signature(TEST_SECRET, body_batch)
        status, resp_bytes, _ = send_http_request("POST", WEBHOOK_URL, body=body_batch, headers={
            "Content-Type": "application/json",
            "X-Line-Signature": sig_batch
        })
        assert_test("Batch of 50 simultaneous events returns 200 OK", status == 200 and resp_bytes.strip() == b"OK", f"status={status}")

        # E2: Concurrent request blast (50 parallel threads alternating valid & invalid)
        def blast_request(worker_id):
            if worker_id % 2 == 0:
                p = {"destination": "U123", "events": [{"type": "message", "source": {"userId": f"U_{worker_id}"}, "message": {"type": "text", "text": "ฝนตก"}}]}
                b = json.dumps(p, ensure_ascii=False).encode("utf-8")
                s = compute_signature(TEST_SECRET, b)
                st, rb, _ = send_http_request("POST", WEBHOOK_URL, body=b, headers={"Content-Type": "application/json", "X-Line-Signature": s})
                return st == 200
            else:
                p = {"destination": "U123", "events": []}
                b = json.dumps(p).encode("utf-8")
                st, rb, _ = send_http_request("POST", WEBHOOK_URL, body=b, headers={"Content-Type": "application/json", "X-Line-Signature": "forged_sig=="})
                return st == 401

        with ThreadPoolExecutor(max_workers=20) as executor:
            blast_results = list(executor.map(blast_request, range(50)))

        all_blast_passed = all(blast_results)
        assert_test("50 concurrent burst requests all returned exact expected status codes (200 / 401)", all_blast_passed, f"passed={blast_results.count(True)}/50")

        # ====================================================================
        # Summary & Verdict
        # ====================================================================
        print("\n" + "=" * 70)
        print("EMPIRICAL TEST SUMMARY:")
        print(f"Total Tests Executed: {tests_run}")
        print(f"Passed:               {tests_passed}")
        print(f"Failed:               {tests_failed}")
        if tests_failed == 0:
            print("VERDICT: ALL TESTS PASSED! APPROVE")
        else:
            print(f"VERDICT: {tests_failed} DEFECT(S) FOUND! DEFECT_FOUND")
        print("=" * 70)

        sys.exit(0 if tests_failed == 0 else 1)

    finally:
        # Terminate server process cleanly
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
        print("Gateway server subprocess terminated cleanly.")


if __name__ == "__main__":
    main()
