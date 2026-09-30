#!/usr/bin/env python3
"""
Bangkok Weather Resilience - Milestone 3 Remediation Empirical Challenger
Empirical Verification of TabDestination Parameter Generation in Flex Messages
"""

import sys
import os
import json
import subprocess
from pathlib import Path
from urllib.parse import urlparse, parse_qs

WORKSPACE_ROOT = Path(__file__).resolve().parent.parent
GATEWAY_DIR = WORKSPACE_ROOT / "gateway"

def query_preview_flex(payload: dict) -> dict:
    """Executes the Go gateway preview tool to generate a Flex bubble."""
    env = os.environ.copy()
    env["LIFF_ENDPOINT_URL"] = "https://liff.line.me/test-app-id"
    proc = subprocess.run(
        ["go", "run", "./cmd/preview"],
        cwd=GATEWAY_DIR,
        input=json.dumps(payload).encode("utf-8"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        check=True
    )
    return json.loads(proc.stdout.decode("utf-8"))

def extract_cta_buttons(bubble_json: dict):
    """Extracts primary and secondary buttons from footer."""
    footer = bubble_json.get("footer", {})
    contents = footer.get("contents", [])
    assert len(contents) >= 2, f"Expected at least 2 footer buttons, got {len(contents)}"
    
    primary_btn = contents[0]
    secondary_btn = contents[1]
    
    primary_uri = primary_btn.get("action", {}).get("uri", "")
    secondary_uri = secondary_btn.get("action", {}).get("uri", "")
    
    return primary_uri, secondary_uri

def run_tab_destination_tests():
    test_cases = [
        {
            "name": "TabDestination == 'profile' with moto",
            "payload": {
                "title": "บันทึกพาหนะเรียบร้อยแล้ว",
                "urgency_level": "INFO",
                "summary_text": "อัปเดตเป็นมอเตอร์ไซค์",
                "vehicle_type": "moto",
                "tab_destination": "profile",
                "extra_params": "vehicle=moto"
            },
            "expected_tab": "profile",
            "expected_vehicle": "moto",
            "expected_cal_tab": "calendar"
        },
        {
            "name": "TabDestination == 'profile' with motorcycle alias",
            "payload": {
                "title": "บันทึกพาหนะเรียบร้อยแล้ว",
                "urgency_level": "INFO",
                "summary_text": "อัปเดตเป็นมอเตอร์ไซค์",
                "vehicle_type": "motorcycle",
                "tab_destination": "profile",
                "extra_params": "vehicle=motorcycle"
            },
            "expected_tab": "profile",
            "expected_vehicle": "motorcycle",
            "expected_cal_tab": "calendar"
        },
        {
            "name": "TabDestination == 'calendar' with sedan",
            "payload": {
                "title": "ตารางนัดหมายและการเดินทาง",
                "urgency_level": "INFO",
                "summary_text": "พบการชนเวลาสภาพอากาศ",
                "vehicle_type": "sedan",
                "tab_destination": "calendar"
            },
            "expected_tab": "calendar",
            "expected_vehicle": "sedan",
            "expected_cal_tab": "calendar"
        },
        {
            "name": "TabDestination == 'dashboard' explicit",
            "payload": {
                "title": "สภาพอากาศปัจจุบัน",
                "urgency_level": "INFO",
                "summary_text": "ท้องฟ้าแจ่มใส",
                "vehicle_type": "pickup",
                "tab_destination": "dashboard"
            },
            "expected_tab": "dashboard",
            "expected_vehicle": "pickup",
            "expected_cal_tab": "calendar"
        },
        {
            "name": "TabDestination empty defaults to 'dashboard'",
            "payload": {
                "title": "สภาพอากาศปัจจุบัน",
                "urgency_level": "INFO",
                "summary_text": "ท้องฟ้าแจ่มใส",
                "vehicle_type": "sedan",
                "tab_destination": ""
            },
            "expected_tab": "dashboard",
            "expected_vehicle": "sedan",
            "expected_cal_tab": "calendar"
        },
        {
            "name": "TabDestination == 'profile' with CRITICAL urgency does not override tab",
            "payload": {
                "title": "แจ้งเตือนพาหนะระดับวิกฤต",
                "urgency_level": "CRITICAL",
                "summary_text": "ความสูงไม่พ้นน้ำ",
                "vehicle_type": "compact_sedan",
                "tab_destination": "profile",
                "extra_params": "vehicle=compact_sedan"
            },
            "expected_tab": "profile",
            "expected_vehicle": "compact_sedan",
            "expected_cal_tab": "calendar"
        },
        {
            "name": "TabDestination == 'dashboard' with CRITICAL urgency includes focus=hazard",
            "payload": {
                "title": "น้ำท่วมระดับวิกฤต",
                "urgency_level": "CRITICAL",
                "summary_text": "น้ำท่วม 20 ซม.",
                "vehicle_type": "sedan",
                "tab_destination": "dashboard"
            },
            "expected_tab": "dashboard",
            "expected_vehicle": "sedan",
            "expected_focus": "hazard",
            "expected_cal_tab": "calendar"
        }
    ]

    print("============================================================================")
    print(" EMPIRICAL CHALLENGER: TAB DESTINATION FLEX MESSAGE GENERATION")
    print("============================================================================\n")

    passed = 0
    total = len(test_cases)

    for tc in test_cases:
        name = tc["name"]
        bubble = query_preview_flex(tc["payload"])
        primary_uri, secondary_uri = extract_cta_buttons(bubble)

        parsed_primary = urlparse(primary_uri)
        q_primary = parse_qs(parsed_primary.query)

        parsed_sec = urlparse(secondary_uri)
        q_sec = parse_qs(parsed_sec.query)

        # 1. Verify primary tab
        actual_tab = q_primary.get("tab", [None])[0]
        assert actual_tab == tc["expected_tab"], f"[{name}] Primary tab: expected '{tc['expected_tab']}', got '{actual_tab}' in {primary_uri}"

        # 2. Verify primary vehicle
        actual_veh = q_primary.get("vehicle", [None])[0]
        assert actual_veh == tc["expected_vehicle"], f"[{name}] Primary vehicle: expected '{tc['expected_vehicle']}', got '{actual_veh}' in {primary_uri}"

        # 3. Verify no duplicated vehicle params
        all_veh_params = q_primary.get("vehicle", [])
        assert len(all_veh_params) == 1, f"[{name}] Duplicate vehicle parameters detected: {all_veh_params} in {primary_uri}"

        # 4. Verify focus=hazard if expected
        if tc.get("expected_focus"):
            actual_focus = q_primary.get("focus", [None])[0]
            assert actual_focus == tc["expected_focus"], f"[{name}] Expected focus='{tc['expected_focus']}', got '{actual_focus}'"

        # 5. Verify secondary button points to calendar tab
        actual_cal_tab = q_sec.get("tab", [None])[0]
        assert actual_cal_tab == tc["expected_cal_tab"], f"[{name}] Secondary button tab: expected '{tc['expected_cal_tab']}', got '{actual_cal_tab}' in {secondary_uri}"

        print(f"  [PASS] {name}")
        print(f"         Primary URI   : {primary_uri}")
        print(f"         Secondary URI : {secondary_uri}")
        passed += 1

    print("\n============================================================================")
    print(f" TAB DESTINATION EMPIRICAL VERIFICATION: {passed}/{total} PASSED (100%)")
    print("============================================================================\n")

if __name__ == "__main__":
    run_tab_destination_tests()
