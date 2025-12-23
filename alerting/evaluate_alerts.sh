#!/bin/bash
set -euo pipefail

# =========================
# Paths & Files
# =========================
AGENT_LOG="/var/log/locc/agent.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DB="$SCRIPT_DIR/state.db"
THRESHOLDS_CONF="$SCRIPT_DIR/thresholds.conf"
ALERT_LOG="/var/log/locc/alerts.log"

mkdir -p /var/log/locc
touch "$STATE_DB" "$ALERT_LOG"

# =========================
# Dependency checks
# =========================
command -v jq >/dev/null || exit 0
command -v bc >/dev/null || exit 0

# =========================
# Load configuration
# =========================
# shellcheck disable=SC1090
source "$THRESHOLDS_CONF"

# Safe defaults
: "${ALERT_ON_SERVICE_DOWN:=true}"

# =========================
# Helpers
# =========================
now_ts() {
  date +%s
}

sanitize_number() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]] && echo "$1" || echo 0
}

get_alert_state() {
  grep "^$1|" "$STATE_DB" 2>/dev/null | cut -d'|' -f2 || echo "OK"
}

set_alert_state() {
  sed -i "/^$1|/d" "$STATE_DB"
  echo "$1|$2|$3" >> "$STATE_DB"
}

log_alert() {
  echo "$1" >> "$ALERT_LOG"
}

# =========================
# Read latest metrics
# =========================
[[ -f "$AGENT_LOG" ]] || exit 0

LATEST_JSON="$(tail -n 1 "$AGENT_LOG")"

HOSTNAME="$(echo "$LATEST_JSON" | jq -r '.hostname')"
TIMESTAMP="$(echo "$LATEST_JSON" | jq -r '.timestamp')"

CPU_USAGE="$(sanitize_number "$(echo "$LATEST_JSON" | jq -r '.cpu.usage_percent')")"
MEMORY_USAGE="$(sanitize_number "$(echo "$LATEST_JSON" | jq -r '.memory.used_percent')")"
DISK_USAGE="$(sanitize_number "$(echo "$LATEST_JSON" | jq -r '.disk.used_percent')")"
INODE_USAGE="$(sanitize_number "$(echo "$LATEST_JSON" | jq -r '.disk.inode_used_percent')")"

SSH_STATUS="$(echo "$LATEST_JSON" | jq -r '.services.ssh')"
NGINX_STATUS="$(echo "$LATEST_JSON" | jq -r '.services.nginx')"
FAIL2BAN_STATUS="$(echo "$LATEST_JSON" | jq -r '.services.fail2ban')"
UFW_STATUS="$(echo "$LATEST_JSON" | jq -r '.services.ufw')"

NOW="$(now_ts)"

# =========================
# Metric alert evaluation
# =========================
evaluate_threshold() {
  local alert="$1"
  local value="$2"
  local threshold="$3"

  local prev_state
  prev_state="$(get_alert_state "$alert")"

  if (( $(echo "$value > $threshold" | bc -l) )); then
    if [[ "$prev_state" != "ALERT" ]]; then
      log_alert "$alert|ALERT|$HOSTNAME|$value|$threshold|$TIMESTAMP"
      set_alert_state "$alert" "ALERT" "$NOW"

      bash "$SCRIPT_DIR/slack_alert.sh" \
        "$alert" "$HOSTNAME" "$value" "$threshold" "$TIMESTAMP" "ALERT"
    fi
  else
    if [[ "$prev_state" == "ALERT" ]]; then
      log_alert "$alert|RECOVERED|$HOSTNAME|$value|$threshold|$TIMESTAMP"
      set_alert_state "$alert" "OK" "$NOW"

      bash "$SCRIPT_DIR/slack_alert.sh" \
        "$alert" "$HOSTNAME" "$value" "$threshold" "$TIMESTAMP" "RECOVERED"
    fi
  fi
}

# =========================
# Service alert evaluation
# =========================
evaluate_service() {
  local alert="$1"
  local status="$2"

  local prev_state
  prev_state="$(get_alert_state "$alert")"

  if [[ "$status" != "active" ]]; then
    if [[ "$prev_state" != "ALERT" ]]; then
      log_alert "$alert|ALERT|$HOSTNAME|$status|n/a|$TIMESTAMP"
      set_alert_state "$alert" "ALERT" "$NOW"

      bash "$SCRIPT_DIR/slack_alert.sh" \
        "$alert" "$HOSTNAME" "$status" "n/a" "$TIMESTAMP" "ALERT"
    fi
  else
    if [[ "$prev_state" == "ALERT" ]]; then
      log_alert "$alert|RECOVERED|$HOSTNAME|active|n/a|$TIMESTAMP"
      set_alert_state "$alert" "OK" "$NOW"

      bash "$SCRIPT_DIR/slack_alert.sh" \
        "$alert" "$HOSTNAME" "active" "n/a" "$TIMESTAMP" "RECOVERED"
    fi
  fi
}

# =========================
# Metric alerts
# =========================
evaluate_threshold "HIGH_CPU" "$CPU_USAGE" "$CPU_USAGE_WARN"
evaluate_threshold "HIGH_MEMORY" "$MEMORY_USAGE" "$MEMORY_USAGE_WARN"
evaluate_threshold "HIGH_DISK" "$DISK_USAGE" "$DISK_USAGE_WARN"
evaluate_threshold "HIGH_INODE" "$INODE_USAGE" "$INODE_USAGE_WARN"

# =========================
# Service alerts
# =========================
if [[ "$ALERT_ON_SERVICE_DOWN" == "true" ]]; then
  evaluate_service "SSH_DOWN" "$SSH_STATUS"
  evaluate_service "NGINX_DOWN" "$NGINX_STATUS"
  evaluate_service "FAIL2BAN_DOWN" "$FAIL2BAN_STATUS"
  evaluate_service "UFW_DOWN" "$UFW_STATUS"
fi
