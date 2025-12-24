# LinuxOps Control Center — Dashboard

The **LinuxOps Control Center (LOCC) Dashboard** is a **read-only, real-time observability UI** for the LOCC platform.

It visualizes **live system health, alerts, and self-healing actions** produced by the host-level **monitoring, alerting, and remediation engines**.

This dashboard is **intentionally decoupled from system control** and serves purely as an **observability and demonstration layer**.


---

## Directory Structure
```
dashboard/
├── backend/
│   ├── app.py              # FastAPI backend
│   ├── readers.py          # Log readers for agent, alerts, healing
│   ├── requirements.txt    # Python dependencies
│   └── venv/               # Local virtual environment (dev only)
├── frontend/
│   ├── index.html          # Dashboard UI
│   ├── styles.css          # Dark-theme DevOps styling
│   └── app.js              # Frontend logic & charts
├── Dockerfile              # Container image for dashboard
├── docker-compose.yml      # Docker Compose setup
└── README.md               # This file
```

---

## 🧠 What This Dashboard Does

The dashboard visualizes **real system data** produced by LOCC components:

- Monitoring Agent
- Alerting Engine
- Self-Healing Engine

It reads data directly from:

- `/var/log/locc/agent.json`
- `/var/log/locc/alerts.log`
- `/var/log/locc/healing.log`

No mock data. No simulations.

---

## ✨ What’s Been Implemented

### 1 Modern Frontend (HTML / CSS / JS)

**System Health**
- Live CPU, Memory, Disk, and Uptime metrics
- Animated progress bars with gradient effects
- Pulsing live-status indicator

**Service Status**
- SSH, NGINX, Fail2Ban, UFW
- Green = Active, Red = Inactive

**Charts**
- Real-time line charts for:
  - CPU usage
  - Memory usage
  - Disk usage
- Built using **Chart.js (CDN)**
- Keeps last 20 data points
- Auto-refresh every 5 seconds

**Processes**
- Top CPU-consuming processes
- Top Memory-consuming processes

**Alerts**
- Comprehensive alert table
- Color-coded states:
  - 🔴 ALERT
  - 🟢 RECOVERED
  - 🟠 RECOVERY_FAILED

**Self-Healing Logs**
- Terminal-style log view
- Monospace font
- Color-coded actions
- Scrollable history

---

### 2 UI / UX Design

- Dark, modern DevOps aesthetic
- Gradient accents and animated cards
- Hover effects and subtle transitions
- Responsive layout (desktop, tablet, mobile)
- Custom scrollbars for logs
- Clean typography and spacing

---

### 3 JavaScript Architecture

- Modular and well-organized code
- Graceful error handling (API failures, missing logs)
- Efficient chart updates (no re-rendering overhead)
- Auto-refresh every 5 seconds
- Browser Visibility API support (pauses updates when tab is hidden)

---

## How It Works

### Backend
- **FastAPI** exposes read-only endpoints:
  - `/api/health`
  - `/api/alerts`
  - `/api/healing`
- Backend safely parses logs without crashing on malformed data

### Frontend
- Static HTML/CSS/JS
- Fetches data from backend APIs
- Renders live metrics, tables, and charts

---

## Running with Docker (Recommended)

The dashboard is containerized for safe and easy deployment.

### Start the dashboard
```bash
docker compose up --build
```

### Open in browser
```
http://localhost:8000
```

The container mounts `/var/log/locc` **read-only**, ensuring:

- **No host modification**
- **No privileged access**
- **No system control from the UI**

---

## Security & Design Principles

- **Read-only access**
- **No authentication required** (local demo)
- **No system control actions**
- **No privileged containers**
- **No framework lock-in**

This mirrors how **observability dashboards are deployed in real production environments**.
