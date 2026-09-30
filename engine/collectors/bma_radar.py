from datetime import datetime, timezone, timedelta
from typing import Dict, Any

class BMARadarCollector:
    """
    Collector adapter for BMA Nong Chok & Nong Khaem C-band rain radars.
    Provides reflectivity (dBZ), storm vector, and estimated arrival times.
    """

    def __init__(self, mode: str = "mock"):
        self.mode = mode

    def get_radar_summary(self) -> Dict[str, Any]:
        now = datetime.now(timezone(timedelta(hours=7)))
        return {
            "radar_stations": [
                {"name": "Nong Chok Radar (หนองจอก)", "status": "ONLINE", "band": "C-band"},
                {"name": "Nong Khaem Radar (หนองแขม)", "status": "ONLINE", "band": "C-band"}
            ],
            "max_reflectivity_dbz": 52.5, # Heavy rain > 45 dBZ
            "storm_cell_count": 2,
            "primary_storm_vector": {
                "movement_direction_deg": 240, # Moving from NE to SW
                "speed_kmh": 22.0,
                "current_center_lat": 13.8500,
                "current_center_lng": 100.6800,
                "estimated_arrival_minutes": {
                    "จตุจักร / ลาดพร้าว": 20,
                    "วัฒนา / สุขุมวิท": 35,
                    "บางนา / อุดมสุข": 45,
                    "สาทร / สีลม": 55
                }
            },
            "timestamp": now.isoformat()
        }
