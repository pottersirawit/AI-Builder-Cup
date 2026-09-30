from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import Dict, Any, List, Optional
import uvicorn

from engine.config import settings
from engine.collectors.weather_next3 import WeatherNext3Collector
from engine.collectors.thaiwater import ThaiWaterCollector
from engine.collectors.bma_radar import BMARadarCollector
from engine.collectors.google_calendar import GoogleCalendarCollector
from engine.geospatial.flood_matcher import FloodRiskMatcher
from engine.geospatial.calendar_matcher import CalendarWeatherMatcher
from engine.ai.gemini_reasoner import GeminiWeatherReasoner

from fastapi.middleware.cors import CORSMiddleware
import time

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Bangkok Weather Resilience & Proactive Alert Engine (WeatherNext 3 + Vertex AI)"
)

# Enable CORS for LIFF Web Application and local developer tools
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize core singletons
weather_collector = WeatherNext3Collector()
thaiwater_collector = ThaiWaterCollector()
radar_collector = BMARadarCollector()
calendar_collector = GoogleCalendarCollector()
flood_matcher = FloodRiskMatcher()
calendar_matcher = CalendarWeatherMatcher(weather_collector, flood_matcher, thaiwater_collector, radar_collector)
ai_reasoner = GeminiWeatherReasoner()

class UserEvaluationRequest(BaseModel):
    user_id: str = "U1001"
    name: str = "คุณสมชาย"
    transport_mode: str = "compact_sedan"  # compact_sedan, motorcycle, pickup, pedestrian
    location_name: str = "ถนนอโศกมนตรี (วัฒนา)"
    latitude: float = 13.7372
    longitude: float = 100.5638
    alert_type: str = "EVENT_DRIVEN"  # EVENT_DRIVEN or DAILY_ROUTINE
    context_notes: Optional[str] = "เลิกงาน 17:30 น. ใช้รถเก๋งเตี้ย เดินทางกลับสุขุมวิท 103"

@app.get("/")
def root():
    return {
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "status": "online",
        "google_ai_model": settings.GEMINI_MODEL,
        "data_mode": {
            "weather": settings.WEATHER_DATA_MODE,
            "thaiwater": settings.THAIWATER_DATA_MODE,
            "radar": settings.BMA_RADAR_DATA_MODE
        }
    }

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.get("/api/v1/flood_hotspots")
def get_flood_hotspots():
    """Returns official Bangkok flood-prone risk points (BKK Risk Map)"""
    return {
        "total_spots": len(flood_matcher.flood_points),
        "spots": flood_matcher.flood_points
    }

@app.get("/api/v1/forecast")
def get_forecast(lat: float = 13.7563, lng: float = 100.5018, hours: int = 12):
    """Fetches 5km hourly WeatherNext 3 forecast for coordinates"""
    forecasts = weather_collector.get_hourly_forecast(lat, lng, hours)
    return {
        "location": {"lat": lat, "lng": lng},
        "model": "WeatherNext 3 (Google DeepMind FGN 5km)",
        "forecasts": forecasts
    }

@app.get("/api/v1/canals")
def get_canals():
    """Retrieves Bangkok drainage canal telemetry"""
    telemetry = thaiwater_collector.get_canal_telemetry()
    return {"canals": telemetry}

@app.get("/api/v1/radar")
def get_radar():
    """Retrieves BMA C-band radar tracking data"""
    return radar_collector.get_radar_summary()

@app.post("/api/v1/evaluate_user")
def evaluate_user(req: UserEvaluationRequest):
    """
    Core End-to-End Pipeline:
    1. Ingests 5km WeatherNext 3 forecast for user coordinates
    2. Ingests BMA/ThaiWater canal levels & C-band radar storm vector
    3. Geospatial matching against BMA 70+ flood hotspots
    4. AI Reasoning (Gemini) generates hyper-personalized proactive advisory
    """
    # 1. Fetch current hour forecast
    forecasts = weather_collector.get_hourly_forecast(req.latitude, req.longitude, hours=6)
    current_forecast = forecasts[0] if forecasts else {}

    # 2. Fetch canal levels & radar
    canals = thaiwater_collector.get_canal_telemetry()
    radar = radar_collector.get_radar_summary()

    # 3. Geospatial Flood Matching
    risk = flood_matcher.evaluate_user_risk(
        user_lat=req.latitude,
        user_lng=req.longitude,
        transport_mode=req.transport_mode,
        hourly_forecast=current_forecast,
        canal_telemetry=canals
    )

    # 4. Gemini AI Reasoning
    user_profile = req.model_dump()
    advisory = ai_reasoner.generate_advisory(
        user_profile=user_profile,
        risk_assessment=risk,
        radar_summary=radar,
        alert_type=req.alert_type
    )

    return {
        "user_id": req.user_id,
        "alert_type": req.alert_type,
        "risk_level": risk["risk_level"],
        "risk_score": risk["risk_score"],
        "risk_assessment": risk,
        "radar_vector": radar["primary_storm_vector"],
        "advisory": advisory
    }

class CalendarSyncRequest(BaseModel):
    user_id: str = "U1001"
    name: str = "คุณสมชาย"
    transport_mode: str = "compact_sedan"

@app.get("/api/v1/calendar/auth/url")
def get_calendar_auth_url(user_id: str = "U1001", redirect_uri: Optional[str] = None):
    """Generates Google OAuth 2.0 consent URL with CSRF state token."""
    url, state = calendar_collector.oauth_manager.generate_auth_url(user_id, redirect_uri)
    return {
        "status": "ready",
        "authorization_url": url,
        "auth_url": url,
        "state": state,
        "user_id": user_id,
        "mode": "configured" if calendar_collector.oauth_manager.is_configured else "mock"
    }

@app.get("/api/v1/calendar/auth/callback")
def handle_calendar_auth_callback(code: str, state: str):
    """Exchanges Google authorization code for access and refresh tokens."""
    try:
        tokens = calendar_collector.oauth_manager.exchange_code(code, state)
        return {
            "status": "connected",
            "user_id": tokens["user_id"],
            "scope": tokens.get("scope"),
            "expires_in": int(max(0, tokens.get("expires_at", 0) - time.time()))
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/v1/calendar/auth/status")
def get_calendar_auth_status(user_id: str = "U1001"):
    """Checks whether the specified user has an active Google Calendar session."""
    tokens = calendar_collector.oauth_manager.store.get_tokens(user_id)
    if not tokens:
        return {"user_id": user_id, "is_connected": False, "mode": "unauthenticated"}

    is_expired = time.time() >= tokens.get("expires_at", 0)
    return {
        "user_id": user_id,
        "is_connected": True,
        "is_expired": is_expired,
        "scope": tokens.get("scope", ""),
        "expires_at": tokens.get("expires_at")
    }

@app.post("/api/v1/calendar/auth/disconnect")
def disconnect_calendar(payload: Optional[Dict[str, Any]] = None):
    """Disconnects user session and purges stored credentials."""
    user_id = payload.get("user_id", "U1001") if payload else "U1001"
    calendar_collector.oauth_manager.store.delete_tokens(user_id)
    return {"status": "disconnected", "user_id": user_id}

@app.get("/api/v1/calendar/events")
def get_calendar_events(user_id: Optional[str] = None):
    """Fetches upcoming events from user's Google Calendar"""
    events = calendar_collector.get_upcoming_events(user_id=user_id)
    return {"total_events": len(events), "events": events}

@app.post("/api/v1/calendar/sync_and_evaluate")
def sync_and_evaluate_calendar(req: CalendarSyncRequest):
    """
    Syncs Google Calendar events and performs proactive weather risk evaluation:
    1. Fetches upcoming scheduled events for user_id
    2. Overlays 5km WeatherNext 3 forecast at each event's venue and hour
    3. Checks flood hotspots and heat index
    4. Generates Gemini proactive advisories for any event with weather hazards (dual-schema)
    """
    events = calendar_collector.get_upcoming_events(user_id=req.user_id)
    evaluations = calendar_matcher.evaluate_calendar_events(events, transport_mode=req.transport_mode)

    proactive_advisories = []
    user_profile = {"name": req.name, "transport_mode": req.transport_mode, "user_id": req.user_id}

    for ev_eval in evaluations:
        if ev_eval.get("has_weather_concern"):
            advisory = ai_reasoner.generate_calendar_advisory(user_profile, ev_eval)
            
            early_mins = ev_eval.get("recommended_early_departure_minutes", 30)
            action_type = ev_eval.get("recommended_action_type", "EARLY_DEPARTURE")
            concern_type = ev_eval.get("concern_type", "WEATHER_HAZARD")

            # Enrich advisory with Go Gateway expected fields if missing
            advisory_enriched = dict(advisory)
            advisory_enriched.setdefault("headline", advisory.get("title", f"เตือนสภาพอากาศ: {ev_eval['event']['title']}"))
            advisory_enriched.setdefault("reasoning", advisory.get("summary_text", "ตรวจพบสภาพอากาศแปรปรวนในเส้นทางของคุณ"))
            checklist = advisory.get("action_checklist", [])
            advisory_enriched.setdefault("proactive_recommendation", checklist[0] if checklist else f"ออกเดินทางเร็วขึ้น {early_mins} นาที")
            advisory_enriched.setdefault("departure_adjustment_mins", early_mins)
            advisory_enriched.setdefault("recommended_action_type", action_type)

            proactive_advisories.append({
                "event_id": ev_eval["event"]["event_id"],
                "event_title": ev_eval["event"]["title"],
                "urgency": ev_eval["urgency"],
                "concern_type": concern_type,
                "advisory": advisory_enriched
            })

    return {
        "user_id": req.user_id,
        "total_events_checked": len(events),
        "events_with_weather_hazards": len(proactive_advisories),
        "evaluations": evaluations,
        "proactive_advisories": proactive_advisories
    }

if __name__ == "__main__":
    uvicorn.run("engine.main:app", host="0.0.0.0", port=8000, reload=True)
