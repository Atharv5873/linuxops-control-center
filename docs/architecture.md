# Architecture Overview

## High-Level Flow
```mermaid
flowchart TD
    %% ===== User Layer =====
    Admin[👤 System Administrator]

    %% ===== Entry Layer =====
    Admin -->|One-click install| Install[install.sh]

    %% ===== Automation Layer =====
    Install --> Setup[Server Automation Engine]
    Setup --> Users[User & SSH Management]
    Setup --> Hardening[System Hardening]
    Setup --> Firewall[UFW + Fail2Ban]
    Setup --> Services[Service Installation]

    %% ===== Runtime Layer =====
    subgraph Runtime["Runtime Layer (Linux Server)"]
        TimerAgent[systemd Timer]
        Agent[Monitoring Agent]
        Logs[Structured Logs<br>/var/log/locc]
    end

    TimerAgent -->|Every 60s| Agent
    Agent --> Logs

    %% ===== Alerting Layer =====
    Logs --> AlertEngine[Alerting Engine]
    AlertEngine -->|ALERT / RECOVERED| AlertLog[alerts.log]
    AlertEngine --> Slack[Slack Notifications]

    %% ===== Self-Healing Layer =====
    AlertLog --> Healing[Self-Healing Engine]
    Healing --> Restart[Service Restart]
    Healing --> Cleanup[Disk Cleanup]
    Healing --> HealLog[healing.log]

    %% ===== Dashboard Layer =====
    Logs --> API[FastAPI Backend]
    AlertLog --> API
    HealLog --> API
    API --> Dashboard[Web Dashboard]

    %% ===== Cloud Layer =====
    subgraph Cloud["Cloud Infrastructure"]
        VM[AWS EC2 / On-Prem VM]
    end

    VM --- Setup
```

## Component Responsibilities
- Automation Engine
- Monitoring Agent
- Alerting Engine
- Self-Healing Engine
- Dashboard

## Design Principles
- Alert-driven healing
- systemd over cron
- Read-only observability
