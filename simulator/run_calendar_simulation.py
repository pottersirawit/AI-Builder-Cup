#!/usr/bin/env python3
"""
Bangkok Weather Resilience AI - Google Calendar Weather Proactive Monitor
Simulates continuous monitoring of Google Calendar appointments against
WeatherNext 3 5km forecasts and BMA flood risk points.
"""

import sys
import os
import json
from pathlib import Path

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from engine.collectors.google_calendar import GoogleCalendarCollector
from engine.geospatial.calendar_matcher import CalendarWeatherMatcher
from engine.ai.gemini_reasoner import GeminiWeatherReasoner

def render_box(title: str, content: str, color_code: str = "36"):
    border = "=" * 70
    print(f"\033[{color_code}m{border}")
    print(f" {title.center(68)}")
    print(f"{border}\033[0m")
    print(content)
    print()

def main():
    print("\n" + "=" * 70)
    print(" GOOGLE CALENDAR WEATHER RESILIENCE MONITOR ")
    print(" Powered by Google Calendar API, WeatherNext 3 & Vertex AI (Gemini)")
    print("=" * 70)

    user_profile = {
        "user_id": "U1001",
        "name": "คุณสมชาย",
        "transport_mode": "compact_sedan"  # ขับรถเก๋ง
    }

    print(f"👤 ผู้ใช้งาน: {user_profile['name']} | ยานพาหนะ: {user_profile['transport_mode']}")
    print("🔄 กำลังดึงตารางนัดหมายจาก Google Calendar API...")

    cal_collector = GoogleCalendarCollector()
    events = cal_collector.get_upcoming_events()
    print(f"✅ ตรวจพบนัดหมายในปฏิทินทั้งหมด {len(events)} รายการ\n")

    matcher = CalendarWeatherMatcher()
    evaluations = matcher.evaluate_calendar_events(events, transport_mode=user_profile["transport_mode"])

    reasoner = GeminiWeatherReasoner()

    for idx, ev_eval in enumerate(evaluations, 1):
        event = ev_eval["event"]
        weather = ev_eval["weather_at_event"]
        has_concern = ev_eval["has_weather_concern"]
        urgency = ev_eval["urgency"]

        print(f"\033[1m[{idx}] นัดหมาย: {event['title']}\033[0m")
        print(f"    🕒 เวลา: {event['start_time']} ถึง {event['end_time']}")
        print(f"    📍 สถานที่: {event['location_name']} (พิกัด: {event['latitude']:.4f}, {event['longitude']:.4f})")
        print(f"    🌦️ สภาพอากาศคาดการณ์ (WeatherNext 3): {weather.get('condition', 'N/A')}")
        print(f"       - ฝน: {weather.get('precipitation_rate_mm_hr', 0)} มม./ชม. | ลมกระโชก: {weather.get('wind_gust_kmh', 0)} กม./ชม. | ดัชนีความร้อน: {weather.get('heat_index_c', 0)}°C")

        if has_concern:
            print(f"    ⚠️ \033[1;31mตรวจพบข้อน่ากังวลสภาพอากาศ! [{ev_eval['concern_type']}]\033[0m")
            for d in ev_eval["concern_details"]:
                print(f"       * {d}")

            # Generate Gemini proactive advisory
            advisory = reasoner.generate_calendar_advisory(user_profile, ev_eval)

            color = "31" if urgency == "CRITICAL" else "33"
            rendered = f"""
ระดับความเร่งด่วน: [{advisory.get('urgency_level')}]
พาดหัว: {advisory.get('title')}
สรุปผลกระทบ: {advisory.get('summary_text')}

⏱️ ช่วงเวลานัดหมาย & วิกฤต: {advisory.get('critical_window')}
🚗 ผลกระทบต่อพาหนะ: {advisory.get('vehicle_impact')}

📋 แผนการเตรียมตัวเชิงรุกก่อนเดินทาง (Proactive Action Checklist):
"""
            for i, act in enumerate(advisory.get("action_checklist", []), 1):
                rendered += f"   {i}. {act}\n"

            rendered += f"\n🛣️ ทางเลือกสำรอง / แผนฉุกเฉิน: {advisory.get('alternative_routes_or_actions')}"

            render_box(f"LINE PUSH ALERT FOR CALENDAR EVENT #{idx}", rendered.strip(), color)
        else:
            print(f"    ✅ \033[1;32mสภาพอากาศปลอดภัย เหมาะสำหรับการเดินทางและทำกิจกรรมตามปกติ\033[0m\n")

    print("=" * 70)
    print("✅ การตรวจสอบสภาพอากาศตาม Google Calendar เสร็จสมบูรณ์!")
    print("=" * 70)

if __name__ == "__main__":
    main()
