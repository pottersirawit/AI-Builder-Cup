from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List
import requests
from engine.config import settings

class ThaiWaterCollector:
    """
    Collector adapter for ThaiWater Standard API (Hydro and Agro Informatics Institute - HII)
    and Bangkok Drainage Dept (BMA) canal telemetry.
    """

    def __init__(self, mode: str = None):
        self.mode = mode or settings.THAIWATER_DATA_MODE
        self.api_key = settings.THAIWATER_API_KEY
        self.base_url = settings.THAIWATER_BASE_URL

    def get_canal_telemetry(self) -> List[Dict[str, Any]]:
        """
        Retrieves real-time canal water levels for major Bangkok drainage canals.
        Returns station info, current level (m MSL), bank height, and flood risk status.
        """
        if self.mode == "live" and self.api_key:
            return self._fetch_live_telemetry()
        return self._generate_simulated_telemetry()

    def _fetch_live_telemetry(self) -> List[Dict[str, Any]]:
        headers = {"Authorization": f"Bearer {self.api_key}"}
        try:
            resp = requests.get(f"{self.base_url}/Runoff?province=กรุงเทพมหานคร", headers=headers, timeout=5)
            if resp.status_code == 200:
                data = resp.json()
                stations = []
                for item in data.get("data", []):
                    stations.append({
                        "station_id": item.get("station_id"),
                        "canal_name": item.get("canal_name"),
                        "district": item.get("district"),
                        "water_level_m": item.get("water_level_msl"),
                        "bank_height_m": item.get("bank_height_msl"),
                        "margin_to_overflow_m": item.get("bank_height_msl") - item.get("water_level_msl"),
                        "status": item.get("status", "NORMAL")
                    })
                return stations
        except Exception as e:
            print(f"[ThaiWaterCollector] Live fetch failed ({e}), using mock.")

        return self._generate_simulated_telemetry()

    def _generate_simulated_telemetry(self) -> List[Dict[str, Any]]:
        """
        Simulated canal telemetry for key BMA canals during rainy condition.
        """
        now = datetime.now(timezone(timedelta(hours=7))).isoformat()
        return [
            {
                "station_id": "BMA-CANAL-01",
                "canal_name": "คลองแสนแสบ (Khlong Saen Saep)",
                "location": "ประตูระบายน้ำวิทยุ-อโศก",
                "water_level_m": 0.85,
                "bank_height_m": 1.10,
                "margin_to_overflow_m": 0.25, # เหลือ 25 ซม. เสมอตลิ่ง
                "status": "WARNING",
                "pumps_active": 6,
                "updated_at": now
            },
            {
                "station_id": "BMA-CANAL-02",
                "canal_name": "คลองลาดพร้าว (Khlong Lat Phrao)",
                "location": "วัดลาดพร้าว",
                "water_level_m": 1.05,
                "bank_height_m": 1.20,
                "margin_to_overflow_m": 0.15, # เสี่ยงล้นตลิ่ง
                "status": "CRITICAL",
                "pumps_active": 8,
                "updated_at": now
            },
            {
                "station_id": "BMA-CANAL-03",
                "canal_name": "คลองเปรมประชากร (Khlong Prem Prachakon)",
                "location": "ดอนเมือง - หลักสี่",
                "water_level_m": 0.60,
                "bank_height_m": 1.00,
                "margin_to_overflow_m": 0.40,
                "status": "NORMAL",
                "pumps_active": 4,
                "updated_at": now
            },
            {
                "station_id": "BMA-CANAL-04",
                "canal_name": "คลองประเวศบุรีรมย์ (Khlong Prawet)",
                "location": "สถานีสูบน้ำพระโขนง",
                "water_level_m": 0.70,
                "bank_height_m": 1.05,
                "margin_to_overflow_m": 0.35,
                "status": "WATCH",
                "pumps_active": 5,
                "updated_at": now
            }
        ]
