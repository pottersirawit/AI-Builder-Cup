import json
from typing import Dict, Any, Optional
from engine.config import settings

class GeminiWeatherReasoner:
    """
    Synthesizes meteorological data, radar trends, and local BMA flood telemetry
    into hyper-personalized, empathetic Thai proactive advisories and checklists.
    """

    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY
        self.model_name = settings.GEMINI_MODEL
        self._client = None

        if self.api_key:
            try:
                import google.generativeai as genai
                genai.configure(api_key=self.api_key)
                self._client = genai.GenerativeModel(self.model_name)
                print(f"[GeminiReasoner] Successfully initialized Gemini model: {self.model_name}")
            except Exception as e:
                print(f"[GeminiReasoner] Warning: Could not initialize Gemini SDK ({e}). Will use fallback engine.")

    def generate_advisory(
        self,
        user_profile: Dict[str, Any],
        risk_assessment: Dict[str, Any],
        radar_summary: Dict[str, Any],
        alert_type: str = "EVENT_DRIVEN"  # or "DAILY_ROUTINE"
    ) -> Dict[str, Any]:
        """
        Generates hyper-personalized Thai advisory.
        Uses Gemini if available, otherwise executes high-fidelity fallback reasoning.
        """
        if self._client:
            try:
                return self._call_gemini_reasoning(user_profile, risk_assessment, radar_summary, alert_type)
            except Exception as e:
                print(f"[GeminiReasoner] Gemini call failed ({e}). Reverting to fallback reasoning.")

        return self._generate_fallback_advisory(user_profile, risk_assessment, radar_summary, alert_type)

    def _call_gemini_reasoning(
        self,
        user: Dict[str, Any],
        risk: Dict[str, Any],
        radar: Dict[str, Any],
        alert_type: str
    ) -> Dict[str, Any]:
        prompt = f"""
คุณคือ AI ผู้เชี่ยวชาญด้านสภาพอากาศและการจัดการภัยพิบัติเชิงรุกประจำกรุงเทพมหานคร (Bangkok Weather Resilience AI)
หน้าที่ของคุณคือวิเคราะห์ข้อมูลพยากรณ์อากาศความละเอียด 5km จาก Google WeatherNext 3, ข้อมูลเรดาร์ กทม., ระดับน้ำในคลอง และความเสี่ยงน้ำท่วมผิวจราจร เพื่อสร้างข้อความเตือนภัยและคำแนะนำเชิงรุกแบบ Hyper-personalized ถึงผู้ใช้

ข้อมูลผู้ใช้งาน (User Profile):
- ชื่อ: {user.get('name', 'ผู้ใช้งาน')}
- พาหนะหลัก: {user.get('transport_mode')}
- พิกัด/สถานที่: {user.get('location_name')} ({risk.get('user_location')})
- บริบทเฉพาะ: {user.get('context_notes', '-')}

ผลประเมินความเสี่ยงและสภาพอากาศ (Risk Assessment):
{json.dumps(risk, ensure_ascii=False, indent=2)}

ข้อมูลเรดาร์ตรวจฝน กทม. (BMA Radar):
{json.dumps(radar, ensure_ascii=False, indent=2)}

ประเภทการแจ้งเตือน: {alert_type}

ข้อกำหนดในการตอบ (Response Guidelines):
1. สื่อสารด้วยภาษาไทยที่เป็นมิตร ชัดเจน ตรงประเด็น กระชับ เข้าใจง่าย
2. ระบุช่วงเวลาวิกฤต (Critical Window) และผลกระทบต่อยานพาหนะหรือการเดินทางของผู้ใช้โดยตรง
3. ให้ Actionable Checklist เชิงรุก 3-4 ข้อ ที่ทำได้ทันทีก่อนเกิดเหตุ (เช่น เวลาที่ควรออกเดินทาง, จุดเลี่ยง, การขยับรถขึ้นที่สูง, การพกอุปกรณ์)
4. ส่งผลลัพธ์กลับมาเป็น JSON ตามโครงสร้างนี้เท่านั้น ห้ามใส่ markdown code block นอกเหนือจาก JSON:
{{
  "title": "พาดหัวแจ้งเตือน",
  "urgency_level": "CRITICAL / WARNING / ADVISORY / INFO",
  "summary_text": "สรุปสถานการณ์และผลกระทบตรงต่อผู้ใช้",
  "critical_window": "ช่วงเวลาที่ต้องระวัง เช่น 16:45 - 18:30 น.",
  "vehicle_impact": "คำเตือนเฉพาะยานพาหนะของผู้ใช้",
  "action_checklist": [
    "สิ่งที่ควรทำทันทีข้อ 1",
    "สิ่งที่ควรทำทันทีข้อ 2",
    "สิ่งที่ควรทำทันทีข้อ 3"
  ],
  "alternative_routes_or_actions": "เส้นทางแนะนำ หรือ ทางเลือกสำรอง"
}}
"""
        response = self._client.generate_content(
            prompt,
            generation_config={"response_mime_type": "application/json"}
        )
        return json.loads(response.text)

    def _generate_fallback_advisory(
        self,
        user: Dict[str, Any],
        risk: Dict[str, Any],
        radar: Dict[str, Any],
        alert_type: str
    ) -> Dict[str, Any]:
        """
        High-fidelity deterministic fallback engine simulating Gemini's output
        based on risk rules and user persona.
        """
        name = user.get("name", "คุณผู้ใช้งาน")
        mode = user.get("transport_mode", "compact_sedan")
        loc_name = user.get("location_name", "จุดพิกัดของคุณ")
        metrics = risk.get("weather_metrics", {})
        precip = metrics.get("precip_rate_mm_hr", 0.0)
        heat_idx = metrics.get("heat_index_c", 0.0)
        flood_impact = risk.get("flood_impact", {})
        est_depth = flood_impact.get("max_street_depth_cm", 0)
        hotspots = flood_impact.get("matched_hotspots", [])
        risk_level = risk.get("risk_level", "LOW")

        # Mode translation
        mode_labels = {
            "compact_sedan": "รถยนต์นั่งส่วนบุคคล (ท้องรถต่ำ)",
            "motorcycle": "รถจักรยานยนต์",
            "pickup": "รถกระบะ / ยกสูง",
            "pedestrian": "เดินเท้า / ขนส่งสาธารณะ"
        }
        vehicle_label = mode_labels.get(mode, mode)

        if alert_type == "DAILY_ROUTINE":
            # Morning briefing scenario
            if heat_idx >= 40.0:
                return {
                    "title": f"☀️ สรุปสภาพอากาศประจำวันสำหรับ {name}",
                    "urgency_level": "ADVISORY",
                    "summary_text": f"วันนี้แดดจัด ความร้อนสะสมสูง ดัชนีความร้อน (Heat Index) แตะ {heat_idx:.1f}°C ช่วง 11:30 - 14:30 น. เสี่ยงต่อภาวะฮีทสโตรก",
                    "critical_window": "11:30 - 14:30 น.",
                    "vehicle_impact": "หลีกเลี่ยงการจอดรถกลางแดดจัด ตรวจสอบความดันลมยาง",
                    "action_checklist": [
                        "ดื่มน้ำสะอาดเพิ่มขึ้นอย่างน้อย 1-1.5 ลิตรระหว่างวัน",
                        "หลีกเลี่ยงกิจกรรมกลางแจ้งที่ใช้แรงต่อเนื่องช่วงบ่าย",
                        "เตรียมร่มกันแดดหรือสวมเสื้อผ้าสีอ่อนระบายอากาศได้ดี"
                    ],
                    "alternative_routes_or_actions": "ช่วงบ่ายหากต้องเดินทาง แนะนำใช้ทางเดินเชื่อมในอาคาร (Skywalk) หรือรถไฟฟ้า"
                }
            else:
                return {
                    "title": f"🌤️ สรุปสภาพอากาศประจำวันสำหรับ {name}",
                    "urgency_level": "INFO",
                    "summary_text": f"วันนี้ช่วงเช้าถึงบ่ายสภาพอากาศโปร่ง แต่ช่วงเย็น (16:30 น. เป็นต้นไป) มีโอกาสเกิดพายุฝนฟ้าคะนอง 80% ปริมาณฝนสูงสุด {precip} มม./ชม.",
                    "critical_window": "16:30 - 19:00 น.",
                    "vehicle_impact": f"ยานพาหนะ ({vehicle_label}) ควรตรวจสอบใบปัดน้ำฝนและไฟหน้ารถให้พร้อม",
                    "action_checklist": [
                        "พกร่มหรือชุดกันฝนติดตัวในการเดินทาง",
                        "วางแผนงานช่วงเย็น หากสามารถเดินทางกลับก่อน 16:30 น. จะเลี่ยงพายุได้",
                        "ติดตามอัปเดตแจ้งเตือนฝนเรียลไทม์จากระบบช่วงบ่าย"
                    ],
                    "alternative_routes_or_actions": "หากเลิกงานช้า แนะนำรอในอาคารช่วง 17:00-18:30 น. เพื่อให้กลุ่มฝนผ่านพ้น"
                }

        # EVENT-DRIVEN ALERT SCENARIO
        if risk_level in ("SEVERE", "HIGH"):
            hotspot_names = ", ".join([h["name_th"] for h in hotspots[:2]]) if hotspots else "เส้นทางใกล้เคียง"
            canals = ", ".join(flood_impact.get("critical_canals_nearby", [])) or "คลองสายหลัก"

            return {
                "title": f"⚠️ แจ้งเตือนด่วน: พายุฝนและเสี่ยงน้ำท่วมขัง {loc_name}",
                "urgency_level": "CRITICAL" if risk_level == "SEVERE" else "WARNING",
                "summary_text": f"กลุ่มฝนฟ้าคะนองกำลังเคลื่อนเข้าพื้นที่ของคุณในอีก 25-35 นาที อัตราฝน {precip} มม./ชม. เสี่ยงน้ำท่วมขังผิวจราจร {est_depth} ซม. ({hotspot_names})",
                "critical_window": "อีก 30 นาที ถึง 2 ชั่วโมงข้างหน้า",
                "vehicle_impact": f"ระดับน้ำคาดการณ์ {est_depth} ซม. เสี่ยงน้ำเข้าท่อไอเสียและห้องเครื่องของ {vehicle_label}",
                "action_checklist": [
                    f"หากจอดรถในที่ลุ่มต่ำ แนะนำรีบขยับรถขึ้นที่สูงทันทีก่อนฝนตกหนัก",
                    "หากกำลังจะเดินทาง แนะนำเลื่อนเวลาเดินทางออกไป หรือออกทันทีใน 15 นาทีนี้",
                    f"หลีกเลี่ยงการขับผ่านจุดเสี่ยง: {hotspot_names}"
                ],
                "alternative_routes_or_actions": f"ระดับน้ำใน {canals} อยู่ในเกณฑ์เตือนภัย แนะนำใช้ทางด่วนหรือระบบราง (BTS/MRT) แทนเส้นทางผิวถนน"
            }
        else:
            return {
                "title": f"ℹ️ รายงานสภาพอากาศ: {loc_name}",
                "urgency_level": "INFO",
                "summary_text": f"สภาพอากาศอยู่ในเกณฑ์ปกติ มีฝนโปรยปรายเล็กน้อย ({precip} มม./ชม.) ไม่พบความเสี่ยงน้ำท่วมขังบนผิวถนน",
                "critical_window": "สภาพอากาศปกติ",
                "vehicle_impact": "ไม่มีผลกระทบต่อยานพาหนะ ขับขี่ด้วยความระมัดระวังตามปกติ",
                "action_checklist": [
                    "ขับขี่ตามกฎจราจร",
                    "รักษาระยะห่างจากคันหน้ากรณีถนนเปียก"
                ],
                "alternative_routes_or_actions": "สามารถสัญจรได้ทุกเส้นทางตามปกติ"
            }

    def generate_calendar_advisory(
        self,
        user_profile: Dict[str, Any],
        calendar_eval: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Synthesizes a proactive advisory tailored to an upcoming Google Calendar appointment
        that faces weather risks (flash flood, severe storm, extreme heat).
        """
        event = calendar_eval.get("event", {})
        title = event.get("title", "นัดหมาย")
        loc_name = event.get("location_name", "สถานที่นัดหมาย")
        start_time = event.get("start_time", "")
        weather = calendar_eval.get("weather_at_event", {})
        flood = calendar_eval.get("flood_risk", {})
        details = calendar_eval.get("concern_details", [])
        urgency = calendar_eval.get("urgency", "WARNING")
        early_mins = calendar_eval.get("recommended_early_departure_minutes", 30)

        # Format time for display
        try:
            from datetime import datetime
            dt = datetime.fromisoformat(start_time)
            display_time = dt.strftime("%H:%M น.")
        except Exception:
            display_time = start_time

        mode = user_profile.get("transport_mode", "compact_sedan")
        mode_labels = {
            "compact_sedan": "รถยนต์นั่งส่วนบุคคล (ท้องรถต่ำ)",
            "motorcycle": "รถจักรยานยนต์",
            "pickup": "รถกระบะ / ยกสูง",
            "pedestrian": "เดินเท้า / ขนส่งสาธารณะ"
        }
        vehicle_label = mode_labels.get(mode, mode)

        precip = weather.get("precipitation_rate_mm_hr", 0.0)
        heat_idx = weather.get("heat_index_c", 0.0)
        est_depth = flood.get("flood_impact", {}).get("max_street_depth_cm", 0)

        action_type = calendar_eval.get("recommended_action_type", "EARLY_DEPARTURE")

        # AI prompt or fallback
        if self._client:
            try:
                prompt = f"""
คุณคือ AI ผู้ช่วยวางแผนชีวิตและสภาพอากาศอัจฉริยะ (Bangkok Weather Resilience Assistant)
ตรวจพบว่าผู้ใช้มีนัดหมายใน Google Calendar ที่เสี่ยงต่อสภาพอากาศ:
- ชื่องาน: {title}
- เวลา: {display_time} ({start_time})
- สถานที่: {loc_name}
- พาหนะ: {vehicle_label}
- ปริมาณฝนคาดการณ์ (WeatherNext 3): {precip} มม./ชม.
- ดัชนีความร้อน: {heat_idx}°C
- ความเสี่ยงน้ำท่วมผิวจราจร: {est_depth} ซม.
- ข้อสังเกตความเสี่ยง: {', '.join(details)}
- โหมดคำแนะนำเชิงรุก: {action_type}

จงสร้างข้อความแจ้งเตือนและคำแนะนำเชิงรุกภาษาไทยในรูปแบบ JSON (Apple Spatial Style):
{{
  "title": "พาดหัวสั้นกระชับเกี่ยวกับนัดหมายและสภาพอากาศ",
  "headline": "พาดหัวเดียวกับ title",
  "urgency_level": "{urgency}",
  "summary_text": "สรุปผลกระทบต่อนัดหมายนี้",
  "reasoning": "เหตุผลความจำเป็นเดียวกับ summary_text",
  "critical_window": "ช่วงเวลาของนัดหมายและพายุ",
  "vehicle_impact": "คำเตือนต่อพาหนะ",
  "recommended_action_type": "{action_type}",
  "departure_adjustment_mins": {early_mins},
  "proactive_recommendation": "คำแนะนำสั้นชัดเจน เช่น ออกเดินทางเร็วขึ้น {early_mins} นาที หรือ สลับไปใช้ BTS/MRT หรือ ปรับเป็น Google Meet",
  "action_checklist": [
    "คำแนะนำเชิงรุกข้อ 1 (เช่น การออกเดินทางเร็วขึ้น {early_mins} นาที)",
    "คำแนะนำเชิงรุกข้อ 2 (เช่น การใช้รถไฟฟ้า BTS/MRT หรือ ประชุมออนไลน์ Google Meet)",
    "คำแนะนำเชิงรุกข้อ 3 (เช่น สิ่งของที่ต้องเตรียม/ป้องกันเอกสาร)"
  ],
  "alternative_routes_or_actions": "เส้นทางเลี่ยงหรือแผนสำรอง"
}}
"""
                resp = self._client.generate_content(
                    prompt,
                    generation_config={"response_mime_type": "application/json"}
                )
                parsed = json.loads(resp.text)
                parsed.setdefault("headline", parsed.get("title", f"📅 แจ้งเตือนนัดหมาย: {title}"))
                parsed.setdefault("reasoning", parsed.get("summary_text", ""))
                parsed.setdefault("departure_adjustment_mins", early_mins)
                parsed.setdefault("recommended_action_type", action_type)
                checklist = parsed.get("action_checklist", [])
                parsed.setdefault("proactive_recommendation", checklist[0] if checklist else f"ออกเดินทางเร็วขึ้น {early_mins} นาที")
                return parsed
            except Exception as e:
                print(f"[GeminiReasoner] Calendar Gemini call failed ({e}), using fallback.")

        # High-Fidelity Deterministic Fallback Reasoner (Apple Spatial Style with Dual Schema)
        concern_type = calendar_eval.get("concern_type", "")

        if action_type == "MODAL_SHIFT" or (est_depth >= 15 and mode in ("compact_sedan", "motorcycle")):
            act_type = "MODAL_SHIFT"
            headline = f"⚠️ ปรับรูปแบบการเดินทาง: เสี่ยงน้ำท่วมขัง {loc_name}"
            title = f"📅 ปรับรูปแบบการเดินทาง: {title}"
            reasoning = f"ระดับน้ำคาดการณ์ {est_depth} ซม. และฝนตกหนัก {precip} มม./ชม. เสี่ยงน้ำเข้าท่อไอเสีย {vehicle_label}"
            summary_text = f"คุณมีนัดเวลา {display_time} ณ {loc_name} ระดับน้ำคาดการณ์ {est_depth} ซม. เสี่ยงน้ำเข้าท่อไอเสีย {vehicle_label}"
            proactive_rec = f"แนะนำสลับไปใช้รถไฟฟ้า BTS/MRT แทนการขับ {vehicle_label} และออกเดินทางเร็วขึ้น {early_mins} นาที"
            checklist = [
                f"ควรออกเดินทางเร็วขึ้นอย่างน้อย {early_mins} นาทีเพื่อเลี่ยงการจราจรติดขัดสะสม",
                "สลับเดินทางด้วยรถไฟฟ้า BTS/MRT เข้าสู่จุดนัดหมาย หรือนำรถจอดอาคาร Park & Ride",
                "พิจารณาติดต่อคู่สนทนาขอปรับรูปแบบเป็นประชุมออนไลน์ (Google Meet) หากสภาพถนนวิกฤต",
                "เตรียมร่ม ซองกันน้ำสำหรับเอกสารสำคัญและคอมพิวเตอร์พกพา"
            ]
            alt = "หากจำเป็นต้องเดินทาง แนะนำใช้ทางด่วนหรือรถไฟฟ้าสายสีชมพู/BTS แทนเส้นทางระดับดิน"

        elif action_type == "REMOTE" or "HEAT" in concern_type or est_depth >= 20:
            if "HEAT" in concern_type or heat_idx >= 40.0:
                act_type = "REMOTE"
                headline = f"☀️ เตือนกิจกรรมตามปฏิทิน: {title}"
                title = f"☀️ เตือนกิจกรรมตามปฏิทิน: {title}"
                reasoning = f"กิจกรรมกลางแจ้ง ณ {loc_name} ตรงกับช่วงดัชนีความร้อนสะสมสูง ({heat_idx:.1f}°C) เสี่ยงฮีทสโตรก"
                summary_text = f"กิจกรรมกลางแจ้งของคุณเวลา {display_time} ณ {loc_name} ตรงกับช่วงดัชนีความร้อนสะสมสูง ({heat_idx:.1f}°C)"
                proactive_rec = "พิจารณาเลื่อนเวลานัดหมาย หรือปรับเปลี่ยนเป็นประชุมออนไลน์ (Google Meet) ในห้องปรับอากาศ"
                checklist = [
                    "พิจารณาเลื่อนเวลาทำกิจกรรมหรือปรับเป็นการประชุมออนไลน์ (Google Meet) ในห้องปรับอากาศ",
                    "ดื่มน้ำสะอาดและเครื่องดื่มเกลือแร่ล่วงหน้าก่อนเริ่มกิจกรรม",
                    "กำหนดจุดพักในร่มทุกๆ 30-45 นาทีเพื่อป้องกันภาวะเพลียแดด"
                ]
                alt = "พิจารณาเลื่อนเวลาทำกิจกรรมเป็นช่วงเช้าก่อน 09:00 น. หรือช่วงเย็นหลัง 16:30 น."
            else:
                act_type = "REMOTE"
                headline = f"⚠️ ปรับประชุมออนไลน์ Google Meet: {title}"
                title = f"📅 แนะนำปรับประชุมออนไลน์: {title}"
                reasoning = f"ระดับน้ำท่วม {est_depth} ซม. และฝนตกหนัก {precip} มม./ชม. บริเวณ {loc_name} วิกฤตเกินกว่าจะสัญจร"
                summary_text = f"คุณมีนัดเวลา {display_time} ณ {loc_name} แต่ระดับน้ำท่วมขัง {est_depth} ซม. และฝนตกหนัก {precip} มม./ชม."
                proactive_rec = "แนะนำติดต่อขอปรับรูปแบบเป็นการประชุมออนไลน์ (Google Meet) ทันทีเพื่อความปลอดภัย"
                checklist = [
                    f"ควรออกเดินทางเร็วขึ้นอย่างน้อย {early_mins} นาทีหากจำเป็นต้องไปหน้างาน",
                    "พิจารณาติดต่อคู่สนทนาขอปรับรูปแบบเป็นประชุมออนไลน์ (Google Meet) เพื่อความปลอดภัย",
                    "สลับใช้ระบบรางรถไฟฟ้า BTS/MRT หากเลี่ยงการเดินทางไม่ได้"
                ]
                alt = "ปรับเป็น Google Meet หรือเลื่อนเวลานัดออกไปหลังน้ำลดระดับ"

        elif "FLOOD" in concern_type or "RAIN" in concern_type or action_type == "EARLY_DEPARTURE":
            act_type = "EARLY_DEPARTURE"
            headline = f"🌧️ เตือนฝนตกและการจราจรสะสม: {title}"
            title = f"📅 เตือนนัดหมายตามปฏิทิน: {title}"
            reasoning = f"โมเดล WeatherNext 3 บ่งชี้ฝนตก {precip} มม./ชม. บริเวณ {loc_name} ส่งผลให้การจราจรติดขัดสะสม"
            summary_text = f"คุณมีนัดเวลา {display_time} ณ {loc_name} แต่โมเดล WeatherNext 3 บ่งชี้ฝนตก {precip} มม./ชม. พื้นผิวจราจรเปียกลื่นและมีความเสี่ยงรถติดสะสมสูง"
            proactive_rec = f"ควรออกเดินทางเร็วขึ้น {early_mins} นาที เพื่อหลีกเลี่ยงการจราจรติดขัดสะสม"
            checklist = [
                f"ควรออกเดินทางเร็วขึ้นอย่างน้อย {early_mins} นาทีเพื่อเลี่ยงการจราจรติดขัดสะสม",
                "พิจารณาติดต่อคู่สนทนาขอปรับรูปแบบเป็นประชุมออนไลน์ (Google Meet) หากสภาพถนนวิกฤต",
                "สลับใช้รถไฟฟ้า BTS/MRT แทนการขับรถบนผิวถนนช่วงฝนตกหนัก",
                "เตรียมร่ม ซองกันน้ำสำหรับเอกสารสำคัญและคอมพิวเตอร์พกพา"
            ]
            alt = "หากจำเป็นต้องเดินทาง แนะนำใช้ทางด่วนหรือรถไฟฟ้าสายสีชมพู/BTS แทนเส้นทางระดับดิน"

        else:
            act_type = "EARLY_DEPARTURE"
            headline = f"📅 สภาพอากาศสำหรับนัดหมาย: {title}"
            title = f"📅 สภาพอากาศสำหรับนัดหมาย: {title}"
            reasoning = f"นัดหมายเวลา {display_time} ณ {loc_name} สภาพอากาศโดยรวมแจ่มใส เดินทางได้ตามปกติ"
            summary_text = f"นัดหมายเวลา {display_time} ณ {loc_name} สภาพอากาศโดยรวมแจ่มใส มีโอกาสฝนเล็กน้อย"
            proactive_rec = "ออกเดินทางตามเวลาปกติ"
            checklist = [
                "ออกเดินทางตามเวลาปกติ",
                "พกร่มพกพาเพื่อความอุ่นใจ"
            ]
            alt = "เดินทางได้ทุกเส้นทางตามแผนงาน"

        return {
            # Go Gateway DTO keys
            "headline": headline,
            "reasoning": reasoning,
            "proactive_recommendation": proactive_rec,
            "departure_adjustment_mins": early_mins,
            "recommended_action_type": act_type,

            # Thai Alert keys
            "title": title,
            "urgency_level": urgency,
            "summary_text": summary_text,
            "critical_window": f"{display_time} (ช่วงเวลาฝนตกหนาแน่น)" if ("FLOOD" in concern_type or "RAIN" in concern_type) else display_time,
            "vehicle_impact": f"ระดับน้ำ {est_depth} ซม. เสี่ยงกระทบต่อ {vehicle_label}" if est_depth > 0 else f"ขับขี่ด้วยความระมัดระวังตามปกติสำหรับ {vehicle_label}",
            "action_checklist": checklist,
            "alternative_routes_or_actions": alt
        }
