import json
from pathlib import Path

AGENT_LOG = Path("/var/log/locc/agent.json")
ALERT_LOG = Path("/var/log/locc/alerts.log")
HEAL_LOG = Path("/var/log/locc/healing.log")


def read_latest_agent():
    if not AGENT_LOG.exists():
        return {}

    try:
        with AGENT_LOG.open() as f:
            lines = f.readlines()
            if not lines:
                return {}
            return json.loads(lines[-1])
    except Exception:
        return {}


def read_alerts(limit=20):
    if not ALERT_LOG.exists():
        return []

    alerts = []
    with ALERT_LOG.open() as f:
        for line in f.readlines()[-limit:]:
            parts = line.strip().split("|")
            if len(parts) >= 6:
                alerts.append({
                    "alert": parts[0],
                    "state": parts[1],
                    "host": parts[2],
                    "value": parts[3],
                    "threshold": parts[4],
                    "timestamp": parts[5],
                })
    return alerts


def read_healing(limit=20):
    if not HEAL_LOG.exists():
        return []

    entries = []
    with HEAL_LOG.open() as f:
        for line in f.readlines()[-limit:]:
            entries.append(line.strip())
    return entries
