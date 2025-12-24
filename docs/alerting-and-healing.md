# Alerting and Self-Healing Design

This document explains how LOCC detects failures and safely attempts recovery without causing instability or alert fatigue.

---

## Alerting Philosophy

LOCC uses **event-driven alerting**, not continuous notification spam.

Alerts represent **state transitions**, not raw metric values.

---

## Alert Lifecycle

Each alert follows a strict lifecycle:

1. **ALERT**
   - A threshold or service failure is detected
2. **RECOVERED**
   - The condition returns to normal
3. **RECOVERY_FAILED**
   - Automated healing was attempted but failed

This ensures alerts are meaningful and actionable.

---

## Threshold Evaluation

The alerting engine evaluates data emitted by the monitoring agent.

Examples:
- CPU usage exceeds configured threshold
- Disk usage crosses critical level
- A critical service becomes inactive

Thresholds are configurable via:

```bash
alerting/thresholds.conf
```


---

## State Tracking

To prevent alert flapping and repetition:
- Each alert maintains persistent state
- Alerts are only emitted on state change
- Cooldowns are enforced between alerts

State is stored in a local state database:

```
alerting/state.db
```


---

## Notification Channel

Currently implemented:
- Slack (via Incoming Webhooks)

Notifications are sent only for meaningful events:
- ALERT
- RECOVERED
- RECOVERY_FAILED

---

## Self-Healing Trigger Model

Self-healing **does not monitor metrics directly**.

Instead, it reacts exclusively to alerts logged by the alerting engine.

Flow:

```
Monitoring → Alerting → alerts.log → Self-Healing
```


This separation prevents unsafe feedback loops.

---

## Healing Actions

Currently supported healing actions:
- Restarting failed services (e.g., nginx, fail2ban)
- Guarded disk cleanup for high disk usage

Each action is:
- Rule-controlled
- Cooldown-protected
- Fully logged

---

## Safety Guards

To prevent harm:
- No repeated restarts in short intervals
- No blind loops
- No direct metric polling
- No healing without an alert trigger

All healing actions are logged to:


```bash
/var/log/locc/healing.log
```


---

## Failure Escalation

If healing fails:
- A `*_RECOVERY_FAILED` alert is generated
- No further automated action is taken
- Manual intervention is required

---

## Summary

LOCC’s alerting and healing design prioritizes:
- Signal over noise
- Safety over aggressiveness
- Clear audit trails
- Predictable behavior under failure
