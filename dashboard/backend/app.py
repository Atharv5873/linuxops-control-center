from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.readers import read_latest_agent, read_alerts, read_healing

app = FastAPI(
    title="LinuxOps Control Center Dashboard API",
    description="Read-only API exposing monitoring, alerting, and self-healing data",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET"],
    allow_headers=["*"],
)


@app.get("/api/health")
def get_health():
    """
    Returns the latest monitoring snapshot.
    """
    data = read_latest_agent()
    return {
        "status": "ok" if data else "no-data",
        "data": data,
    }


@app.get("/api/alerts")
def get_alerts(limit: int = 20):
    """
    Returns recent alert events (ALERT / RECOVERED / RECOVERY_FAILED).
    """
    return {
        "count": limit,
        "alerts": read_alerts(limit),
    }


@app.get("/api/healing")
def get_healing(limit: int = 20):
    """
    Returns recent self-healing activity logs.
    """
    return {
        "count": limit,
        "events": read_healing(limit),
    }


@app.get("/api/summary")
def get_summary():
    """
    High-level summary for dashboards.
    """
    health = read_latest_agent()
    alerts = read_alerts(5)
    healing = read_healing(5)

    return {
        "health_available": bool(health),
        "recent_alerts": alerts,
        "recent_healing": healing,
    }
