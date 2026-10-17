import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env file from project root
ROOT_DIR = Path(__file__).resolve().parent.parent
load_dotenv(ROOT_DIR / ".env")

class Settings:
    PROJECT_NAME: str = "Bangkok Weather Resilience AI Engine"
    VERSION: str = "1.0.0"

    # AI Configuration
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
    GEMINI_FAST_MODEL: str = os.getenv("GEMINI_FAST_MODEL", "gemini-2.5-flash-lite")
    GOOGLE_CLOUD_PROJECT: str = os.getenv("GOOGLE_CLOUD_PROJECT", "")
    GOOGLE_CLOUD_LOCATION: str = os.getenv("GOOGLE_CLOUD_LOCATION", "asia-southeast1")

    # Data Modes
    WEATHER_DATA_MODE: str = os.getenv("WEATHER_DATA_MODE", "mock")
    THAIWATER_DATA_MODE: str = os.getenv("THAIWATER_DATA_MODE", "mock")
    BMA_RADAR_DATA_MODE: str = os.getenv("BMA_RADAR_DATA_MODE", "mock")

    # API Keys & Endpoints
    GOOGLE_MAPS_WEATHER_API_KEY: str = os.getenv("GOOGLE_MAPS_WEATHER_API_KEY", "")
    THAIWATER_API_KEY: str = os.getenv("THAIWATER_API_KEY", "")
    THAIWATER_BASE_URL: str = "https://standard.thaiwater.net/api/v1"

    # Redis & DB
    REDIS_HOST: str = os.getenv("REDIS_HOST", "localhost")
    REDIS_PORT: int = int(os.getenv("REDIS_PORT", "6379"))

    # File paths
    FLOOD_POINTS_FILE: Path = ROOT_DIR / "data" / "bkk_flood_risk_points.json"

settings = Settings()
