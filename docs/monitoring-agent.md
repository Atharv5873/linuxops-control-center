# Monitoring Agent

The Monitoring Agent is a lightweight, stateless Linux monitoring component responsible for collecting system metrics and emitting them as structured logs.

It acts as the **single source of truth** for alerting, self-healing, and dashboard visualization.

---

## Design Goals

- Minimal footprint
- No long-running daemon
- Native Linux primitives only
- Fault-tolerant metric collection
- Machine-readable output

---

## Execution Model

The agent is executed as a **systemd oneshot service**, triggered periodically by a **systemd timer**.

### Why systemd timers instead of cron?
- Better error handling
- Explicit lifecycle management
- Native integration with Linux
- Predictable execution behavior

---

## Collected Metrics

### System Metadata
- Hostname
- Agent version
- System uptime

### CPU
- CPU usage percentage
- Load average (1m, 5m, 15m)

### Memory
- Total memory
- Used memory
- Free memory
- Memory usage percentage

### Disk
- Root filesystem usage
- Disk usage percentage
- Inode usage percentage

### Processes
- Top CPU-consuming processes
- Top memory-consuming processes

### Services
- ssh
- nginx
- fail2ban
- ufw

---

## Output Format

Metrics are written as **append-only JSON lines**:

```
/var/log/locc/agent.json
```


Each line represents a full snapshot of system state at a point in time.

### Why JSON logs?
- Easy to parse
- Human-readable
- Compatible with alerting and dashboards
- Safe for append-only writes

---

## Fault Tolerance

- Partial metric failures do not stop execution
- Missing data is handled gracefully
- The agent never exits in a broken state

This ensures monitoring continues even under degraded conditions.

---

## Role in the System

The monitoring agent **does not make decisions**.

It only:
- Observes
- Collects
- Emits data

All decisions are delegated to downstream components (alerting and healing).

---

## Summary

The monitoring agent provides reliable, low-overhead observability using native Linux tooling, forming the foundation of the LOCC automation pipeline.
