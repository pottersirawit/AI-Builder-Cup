#!/usr/bin/env python3
"""
Bangkok Weather Resilience AI - End-to-End Simulation Runner
Demonstrates the integration of:
1. Google WeatherNext 3 (5km hourly forecast)
2. BMA C-band Rain Radar & Canal Telemetry
3. BMA 70+ Flood Hotspots Geospatial Matching
4. Gemini AI Multimodal Reasoning & Actionable Thai Advisory
5. LINE Flex Message Generation
"""

import sys
import os
import json
from pathlib import Path

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from engine.collectors.weather_next3 import WeatherNext3Collector
from engine.collectors.thaiwater import ThaiWaterCollector
from engine.collectors.bma_radar import BMARadarCollector
from engine.geospatial.flood_matcher import FloodRiskMatcher
from engine.ai.gemini_reasoner import GeminiWeatherReasoner

def render_box(title: str, content: str, color_code: str = "36"):
    border = "=" * 70
    print(f"\033[{color_code}m{border}")
    print(f" {title.center(68)}")
    print(f"{border}\033[0m")
    print(content)
    print()

def run_scenario(scenario: dict):
    s_id = scenario["scenario_id"]
    name = scenario["name"]
    desc = scenario["description"]
    user = scenario["user"]

    print(f"\n\033[1;33m>>> กำลังรันสถานการณ์: [{s_id}] {name}\033[0m")
    print(f"คำอธิบาย: {desc}")
    print(f"ผู้ใช้งาน: {user['name']} | ยานพาหนะ: {user['transport_mode']} | พิกัด: {user['location_name']}")
    print("-" * 70)

    # 1. Ingest WeatherNext 3 Forecast
    weather_collector = WeatherNext3Collector()
    sim_hour = scenario.get("simulated_hour")
    forecasts = weather_collector.get_hourly_forecast(user["latitude"], user["longitude"], hours=1, override_hour=sim_hour)
    current_weather = forecasts[0]

    print(f"🌦️ [WeatherNext 3 (5km FGN)]")
    print(f"   - สภาพอากาศ: {current_weather['condition']}")
    print(f"   - อัตราฝน: {current_weather['precipitation_rate_mm_hr']} มม./ชม. (โอกาสเกิด {current_weather['precipitation_probability']}%)")
    print(f"   - อุณหภูมิ: {current_weather['temperature_c']}°C (ดัชนีความร้อน Heat Index: {current_weather['heat_index_c']}°C)")
    print(f"   - ลมกระโชก: {current_weather['wind_gust_kmh']} กม./ชม.")

    # 2. Ingest Local Telemetry (Radar + Canals)
    radar_collector = BMARadarCollector()
    radar = radar_collector.get_radar_summary()
    thaiwater_collector = ThaiWaterCollector()
    canals = thaiwater_collector.get_canal_telemetry()

    crit_canals = [c for c in canals if c.get("status") in ("WARNING", "CRITICAL")]
    print(f"\n📡 [โทรมาตร กทม. & สสน.]")
    print(f"   - เรดาร์หนองจอก/หนองแขม: ความสะท้อนสูงสุด {radar['max_reflectivity_dbz']} dBZ | ทิศทาง {radar['primary_storm_vector']['movement_direction_deg']}°")
    print(f"   - คลองที่มีความเสี่ยง: {', '.join([c['canal_name'] + ' (ระดับ ' + str(c['water_level_m']) + 'm)' for c in crit_canals])}")

    # 3. Geospatial Flood Matching
    flood_matcher = FloodRiskMatcher()
    risk = flood_matcher.evaluate_user_risk(
        user_lat=user["latitude"],
        user_lng=user["longitude"],
        transport_mode=user["transport_mode"],
        hourly_forecast=current_weather,
        canal_telemetry=canals
    )

    print(f"\n📍 [ผลวิเคราะห์ความเสี่ยงเชิงพื้นที่ (BKK Risk Map Matching)]")
    print(f"   - ระดับความเสี่ยง (Risk Level): {risk['risk_level']} (คะแนน {risk['risk_score']}/100)")
    print(f"   - คาดการณ์ระดับน้ำท่วมผิวจราจร: {risk['flood_impact']['max_street_depth_cm']} ซม.")
    print(f"   - ยานพาหนะอยู่ในเกณฑ์อันตราย: {'⚠️ ใช่ (อันตรายต่อน้ำเข้าท่อ/ห้องเครื่อง)' if risk['flood_impact']['is_vehicle_in_danger'] else '✅ ไม่อยู่ในเกณฑ์อันตราย'}")
    if risk["flood_impact"]["matched_hotspots"]:
        for h in risk["flood_impact"]["matched_hotspots"]:
            print(f"     * จุดเสี่ยง: {h['name_th']} ({h['district']}) - ห่าง {h['distance_meters']} ม. - เกณฑ์ฝนวิกฤต {h['critical_rain_threshold_mm_hr']} มม./ชม.")

    # 4. Gemini AI Multimodal Reasoning
    ai_reasoner = GeminiWeatherReasoner()
    advisory = ai_reasoner.generate_advisory(
        user_profile=user,
        risk_assessment=risk,
        radar_summary=radar,
        alert_type=user.get("alert_type", "EVENT_DRIVEN")
    )

    color = "31" if advisory.get("urgency_level") == "CRITICAL" else ("33" if advisory.get("urgency_level") == "WARNING" else "32")
    rendered_text = f"""
ระดับความเร่งด่วน: [{advisory.get('urgency_level')}]
พาดหัว: {advisory.get('title')}
บทสรุป: {advisory.get('summary_text')}

⏱️ ช่วงเวลาวิกฤต: {advisory.get('critical_window')}
🚗 ผลกระทบต่อพาหนะ: {advisory.get('vehicle_impact')}

📋 เช็กลิสต์การเตรียมตัวเชิงรุก (Proactive Checklist):
"""
    for i, act in enumerate(advisory.get("action_checklist", []), 1):
        rendered_text += f"   {i}. {act}\n"

    rendered_text += f"\n🛣️ คำแนะนำเส้นทาง/ทางเลือก: {advisory.get('alternative_routes_or_actions')}"

    render_box(f"LINE FLEX MESSAGE PAYLOAD ({user['name']})", rendered_text.strip(), color)

def main():
    scenarios_path = PROJECT_ROOT / "simulator" / "scenarios.json"
    with open(scenarios_path, "r", encoding="utf-8") as f:
        scenarios = json.load(f)

    print("\n" + "=" * 70)
    print(" BANGKOK WEATHER RESILIENCE AI SIMULATOR ")
    print(" Powered by WeatherNext 3, BMA Telemetry & Vertex AI (Gemini)")
    print("=" * 70)

    for sc in scenarios:
        run_scenario(sc)

    print("\n✅ การทดสอบจำลองเสร็จสมบูรณ์ทุกสถานการณ์!")

if __name__ == "__main__":
    main()
