#!/usr/bin/env python3
"""
Bangkok Weather Resilience AI System - Milestone 2 Empirical Challenger Verification
Strict LINE Messaging API Flex Message Schema & Vehicle Clearance Alert Verification

Validates:
1. Generated Apple Spatial Flex Message Bubble JSON matches the LINE Flex container schema
   and can be unmarshaled without error using strict Pydantic models.
2. All 4 vehicle personas (sedan, motorcycle, pickup, transit) generate correct vehicle clearance
   alert styling and thresholds according to CONTEXT.md and PROJECT.md.
3. Live subprocess execution against the Go Gateway Flex Builder.
"""

import sys
import os
import json
import re
import subprocess
from pathlib import Path
from typing import List, Optional, Union, Literal, Dict, Any

from pydantic import BaseModel, Field, field_validator

# Workspace root
WORKSPACE_ROOT = Path(__file__).resolve().parent.parent
GATEWAY_DIR = WORKSPACE_ROOT / "gateway"

HEX_COLOR_PATTERN = re.compile(r"^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$")


# ============================================================================
# Strict Pydantic Models for LINE Messaging API Flex Message Container
# ============================================================================

class LineAction(BaseModel):
    type: Literal["uri", "message", "postback"]
    label: Optional[str] = None
    uri: Optional[str] = None
    text: Optional[str] = None

    @field_validator("uri")
    @classmethod
    def validate_uri(cls, v):
        if v is not None:
            if not (v.startswith("http://") or v.startswith("https://") or v.startswith("line://") or v.startswith("tel:")):
                raise ValueError(f"Invalid URI scheme: {v}")
        return v

    @field_validator("label")
    @classmethod
    def validate_label_length(cls, v):
        if v is not None:
            if len(v) > 40:
                raise ValueError(f"Action label exceeds 40 characters: {len(v)}")
        return v


class LineText(BaseModel):
    type: Literal["text"]
    text: str
    size: Optional[str] = None
    weight: Optional[Literal["regular", "bold"]] = None
    color: Optional[str] = None
    wrap: Optional[bool] = None
    align: Optional[Literal["start", "end", "center"]] = None
    gravity: Optional[Literal["top", "bottom", "center"]] = None
    flex: Optional[int] = None
    margin: Optional[str] = None

    @field_validator("color")
    @classmethod
    def validate_color(cls, v):
        if v is not None and not HEX_COLOR_PATTERN.match(v):
            raise ValueError(f"Invalid hex color: {v}")
        return v


class LineButton(BaseModel):
    type: Literal["button"]
    action: LineAction
    style: Optional[Literal["primary", "secondary", "link"]] = None
    height: Optional[Literal["sm", "md"]] = None
    color: Optional[str] = None
    flex: Optional[int] = None
    margin: Optional[str] = None

    @field_validator("color")
    @classmethod
    def validate_color(cls, v):
        if v is not None and not HEX_COLOR_PATTERN.match(v):
            raise ValueError(f"Invalid hex color: {v}")
        return v


LineComponent = Union["LineBox", LineText, LineButton]


class LineBox(BaseModel):
    type: Literal["box"]
    layout: Literal["horizontal", "vertical", "baseline"]
    contents: List[LineComponent]
    backgroundColor: Optional[str] = None
    borderColor: Optional[str] = None
    borderWidth: Optional[Literal["none", "light", "normal", "medium", "semi-bold", "bold"]] = None
    cornerRadius: Optional[str] = None
    paddingAll: Optional[str] = None
    spacing: Optional[str] = None
    margin: Optional[str] = None
    flex: Optional[int] = None

    @field_validator("backgroundColor", "borderColor")
    @classmethod
    def validate_hex_colors(cls, v):
        if v is not None and not HEX_COLOR_PATTERN.match(v):
            raise ValueError(f"Invalid hex color: {v}")
        return v


LineBox.model_rebuild()


class LineBlockStyle(BaseModel):
    backgroundColor: Optional[str] = None
    separator: Optional[bool] = None
    separatorColor: Optional[str] = None

    @field_validator("backgroundColor", "separatorColor")
    @classmethod
    def validate_colors(cls, v):
        if v is not None and not HEX_COLOR_PATTERN.match(v):
            raise ValueError(f"Invalid hex color: {v}")
        return v


class LineBubbleStyles(BaseModel):
    header: Optional[LineBlockStyle] = None
    hero: Optional[LineBlockStyle] = None
    body: Optional[LineBlockStyle] = None
    footer: Optional[LineBlockStyle] = None


class LineBubbleContainer(BaseModel):
    type: Literal["bubble"]
    size: Optional[Literal["nano", "micro", "kilo", "mega", "giga"]] = None
    direction: Optional[Literal["ltr", "rtl"]] = None
    header: Optional[LineBox] = None
    body: Optional[LineBox] = None
    footer: Optional[LineBox] = None
    styles: Optional[LineBubbleStyles] = None


# ============================================================================
# Empirical Verification Harness
# ============================================================================

def query_preview_flex(payload: Dict[str, Any]) -> Dict[str, Any]:
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    proc = subprocess.Popen(
        ["go", "run", "./cmd/preview"],
        cwd=str(GATEWAY_DIR),
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    out, err = proc.communicate(input=data)
    if proc.returncode != 0:
        raise RuntimeError(f"Go preview CLI error (code {proc.returncode}): {err.decode('utf-8')}")
    return json.loads(out.decode("utf-8"))


def run_empirical_verification():
    passed_count = 0
    total_count = 0

    # --------------------------------------------------------------------
    # TEST SUITE 1: 4 Vehicle Personas & Threshold Boundaries
    # --------------------------------------------------------------------
    vehicle_tests = [
        # Sedan Tests
        {
            "name": "Sedan Safe (8cm depth)",
            "payload": {"title": "เช็กระดับน้ำ", "vehicle_type": "sedan", "flood_depth_cm": 8.0, "summary_text": "สรุปสภาพอากาศ"},
            "expected_badge": "🚗 รถเก๋งเตี้ย: ระดับน้ำปกติ สัญจรได้",
            "expected_bg": "#162238",
            "expected_border": "#2A3B5C"
        },
        {
            "name": "Sedan Warning Boundary (10.0cm depth)",
            "payload": {"title": "เช็กระดับน้ำ", "vehicle_type": "sedan", "flood_depth_cm": 10.0, "summary_text": "สรุปสภาพอากาศ"},
            "expected_badge": "🚗 รถเก๋งเตี้ย: เฝ้าระวังระดับน้ำ",
            "expected_bg": "#2D2210",
            "expected_border": "#F59E0B"
        },
        {
            "name": "Sedan Critical Boundary (15.0cm depth)",
            "payload": {"title": "เช็กระดับน้ำ", "vehicle_type": "sedan", "flood_depth_cm": 15.0, "summary_text": "สรุปสภาพอากาศ"},
            "expected_badge": "🚗 รถเก๋งเตี้ย: วิกฤตน้ำท่วมขัง",
            "expected_bg": "#2D121B",
            "expected_border": "#F43F5E"
        },
        # Motorcycle Tests
        {
            "name": "Motorcycle Safe (calm & shallow)",
            "payload": {"title": "เช็กสภาพลม", "vehicle_type": "moto", "flood_depth_cm": 5.0, "wind_gust": 20.0, "summary_text": "สรุปสภาพอากาศ"},
            "expected_badge": "🛵 มอเตอร์ไซค์: สภาพลมและถนนปลอดภัย",
            "expected_bg": "#162238",
            "expected_border": "#2A3B5C"
        },
        {
            "name": "Motorcycle Critical Wind (>45 km/h)",
            "payload": {"title": "เช็กสภาพลม", "vehicle_type": "motorcycle", "flood_depth_cm": 2.0, "wind_gust": 46.0, "summary_text": "สรุปสภาพอากาศ"},
            "expected_badge": "🛵 มอเตอร์ไซค์: เสี่ยงลมกระโชกและน้ำท่วม",
            "expected_bg": "#2D121B",
            "expected_border": "#F43F5E"
        },
        {
            "name": "Motorcycle Critical Flood (>=10cm)",
            "payload": {"title": "เช็กน้ำท่วม", "vehicle_type": "moto", "flood_depth_cm": 10.0, "wind_gust": 15.0, "summary_text": "สรุปสภาพอากาศ"},
            "expected_badge": "🛵 มอเตอร์ไซค์: เสี่ยงลมกระโชกและน้ำท่วม",
            "expected_bg": "#2D121B",
            "expected_border": "#F43F5E"
        },
        # Pickup / SUV Tests
        {
            "name": "Pickup Safe (30cm flood)",
            "payload": {"title": "เช็กกระบะ", "vehicle_type": "pickup", "flood_depth_cm": 30.0, "summary_text": "สรุปสภาพอากาศ"},
            "expected_badge": "🚙 รถกระบะ/SUV: สัญจรได้ปลอดภัย",
            "expected_bg": "#0F291E",
            "expected_border": "#34D399"
        },
        {
            "name": "Pickup Critical (>35cm flood)",
            "payload": {"title": "เช็กกระบะวิกฤต", "vehicle_type": "pickup", "flood_depth_cm": 36.0, "summary_text": "สรุปสภาพอากาศ"},
            "expected_badge": "🚙 รถกระบะ/SUV: น้ำท่วมระดับวิกฤต",
            "expected_bg": "#2D121B",
            "expected_border": "#F43F5E"
        },
        # Transit Tests
        {
            "name": "Transit Safe in Dry Weather",
            "payload": {"title": "เช็กบีทีเอส", "vehicle_type": "transit", "flood_depth_cm": 0.0, "summary_text": "สรุปสภาพอากาศ"},
            "expected_badge": "🚆 รถไฟฟ้า BTS/MRT: สัญจรปลอดภัย 100%",
            "expected_bg": "#0F291E",
            "expected_border": "#34D399"
        },
        {
            "name": "Transit Safe in Severe Street Inundation (50cm)",
            "payload": {"title": "เช็กเอ็มอาร์ที", "vehicle_type": "mrt", "flood_depth_cm": 50.0, "summary_text": "สรุปสภาพอากาศ"},
            "expected_badge": "🚆 รถไฟฟ้า BTS/MRT: สัญจรปลอดภัย 100%",
            "expected_bg": "#0F291E",
            "expected_border": "#34D399"
        },
    ]

    print("\n--- TIER 1: Vehicle Clearance Styling & Threshold Boundaries ---")
    for vt in vehicle_tests:
        total_count += 1
        bubble_json = query_preview_flex(vt["payload"])

        # 1. Strict Pydantic validation
        parsed_bubble = LineBubbleContainer.model_validate(bubble_json)
        assert parsed_bubble.type == "bubble"

        # 2. Extract vehicle card inside body contents index 2
        veh_card = parsed_bubble.body.contents[2]
        assert isinstance(veh_card, LineBox)
        assert veh_card.backgroundColor == vt["expected_bg"], f"bg mismatch: want {vt['expected_bg']}, got {veh_card.backgroundColor}"
        assert veh_card.borderColor == vt["expected_border"], f"border mismatch: want {vt['expected_border']}, got {veh_card.borderColor}"

        veh_badge_text = veh_card.contents[0].text
        assert veh_badge_text == vt["expected_badge"], f"badge mismatch: want {vt['expected_badge']}, got {veh_badge_text}"

        print(f"  [PASS] {vt['name']}: {veh_badge_text} ({veh_card.backgroundColor})")
        passed_count += 1

    # --------------------------------------------------------------------
    # TEST SUITE 2: Strict LINE Flex Bubble Schema Validation
    # --------------------------------------------------------------------
    print("\n--- TIER 2: Strict LINE Flex Container Schema Validation ---")
    scenarios = [
        {
            "name": "Full Asok Sukhumvit 21 Critical Advisory",
            "payload": {
                "title": "⚠️ พายุฤดูร้อนและเสี่ยงน้ำท่วมขัง ถนนสุขุมวิท",
                "urgency_level": "CRITICAL",
                "summary_text": "เรดาร์ BMA ตรวจพบกลุ่มฝนฟ้าคะนองรุนแรง ลมกระโชกแรง และเสี่ยงน้ำท่วมขัง",
                "critical_window": "17:00 - 19:30 น.",
                "location_name": "สุขุมวิท 21 (อโศกมนตรี)",
                "temperature": 29.0,
                "condition": "⛈️ พายุฝนฟ้าคะนองรุนแรง",
                "rain_rate": 48.5,
                "canal_name": "คลองแสนแสบ",
                "canal_stage": 0.85,
                "canal_remaining_cm": 15.0,
                "heat_index": 37.6,
                "wind_gust": 54.0,
                "vehicle_type": "sedan",
                "flood_depth_cm": 18.0,
                "action_checklist": ["หลีกเลี่ยงถนนสุขุมวิท", "ใช้ระบบรถไฟฟ้า BTS/MRT"],
                "alternative_routes_or_actions": "ใช้ทางด่วนเฉลิมมหานคร",
                "liff_url": "https://liff.line.me/test-weather"
            }
        },
        {
            "name": "Midday Heatwave Warning Ratchada",
            "payload": {
                "title": "☀️ ดัชนีความร้อนสูงมาก",
                "urgency_level": "WARNING",
                "summary_text": "ดัชนีความร้อนสะสมแตะ 42.5°C แดดจัดมาก",
                "location_name": "รัชดาภิเษก",
                "temperature": 37.0,
                "heat_index": 42.5,
                "wind_gust": 12.0,
                "vehicle_type": "motorcycle"
            }
        },
        {
            "name": "Morning Commute Info Chatuchak",
            "payload": {
                "title": "🌤️ สภาพอากาศยามเช้า ปลอดโปร่ง",
                "urgency_level": "INFO",
                "summary_text": "ไม่มีกลุ่มฝนในรัศมี 15 กม. สัญจรได้ปกติ",
                "location_name": "จตุจักร",
                "temperature": 27.0,
                "vehicle_type": "transit"
            }
        }
    ]

    for sc in scenarios:
        total_count += 1
        bubble_json = query_preview_flex(sc["payload"])

        # Strict Pydantic Unmarshaling
        parsed = LineBubbleContainer.model_validate(bubble_json)
        assert parsed.type == "bubble"
        assert parsed.size == "mega"
        assert parsed.styles.header.backgroundColor == "#091122"
        assert parsed.styles.body.backgroundColor == "#0B132B"
        assert parsed.styles.footer.backgroundColor == "#091122"

        # Check 2x2 Bento grid tiles (Body contents[1])
        bento = parsed.body.contents[1]
        assert isinstance(bento, LineBox)
        assert len(bento.contents) == 2  # 2 rows

        # Check CTA Deep-Links in Footer
        footer = parsed.footer
        assert isinstance(footer, LineBox)
        assert len(footer.contents) == 2
        btn_dash = footer.contents[0]
        btn_cal = footer.contents[1]
        assert "tab=dashboard" in btn_dash.action.uri
        assert "tab=calendar" in btn_cal.action.uri

        print(f"  [PASS] {sc['name']}: Successfully unmarshaled into strict LineBubbleContainer")
        passed_count += 1

    print(f"\n=======================================================")
    print(f" EMPIRICAL CHALLENGER VERIFICATION RESULTS: {passed_count}/{total_count} PASSED (100%)")
    print(f"=======================================================\n")


if __name__ == "__main__":
    run_empirical_verification()
