#!/bin/bash
set -euo pipefail

AGENT_LOG="/var/log/locc/agent.json"
STATE_DB="$(dirname "$0")/state.db"
THRESHOLDS_CONF="$(dirname "$0")/thresholds.conf"
ALERT_LOG="/var/log/locc/alerts.log"

mkdir -p /var/log/locc
touch "$STATE_DB" "$ALERT_LOG"

# -------------------------
# Load thresholds
# -------------------------
# shellcheck disable=SC1090
source "$THRESHOLDS_CONF"

# -------------------------
# Helpers
# -------------------------
now_ts() {
  date +%s
}

get_last_alert_ts() {
  grep "^$1|" "$STATE_DB" 2>/dev/null | cut -d'|' -f2 || echo 0
}

update_alert_ts() {
  sed -i "/^$1|/d" "$STATE_DB"
  echo "$1|$2" >> "$STATE_DB"
}

log_alert() {
  echo "$(date -Is) $1" >> "$ALERT_LOG"
}

# -------------------------
# Read latest metrics
# -------------------------
if [[ ! -f "$AGENT_LOG" ]]; then
  exit 0
fi

LATEST_JSON="$(tail -n 1 "$AGENT_LOG")"

HOSTNAME="$(echo "$LATEST_JSON" | jq -r '.hostname')"
TIMESTAMP="$(echo "$LATEST_JSON" | jq -r '.timestamp')"

CPU_USAGE="$(echo "$LATEST_JSON" | jq -r '.cpu.usage_percent')"
MEMORY_USAGE="$(echo "$LATEST_JSON" | jq -r '.memory.used_percent')"
DISK_USAGE="$(echo "$LATEST_JSON" | jq -r '.disk.used_percent')"
INODE_USAGE="$(echo "$LATEST_JSON" | jq -r '.disk.inode_used_percent')"

SSH_STATUS="$(echo "$LATEST_JSON" | jq -r '.services.ssh')"
NGINX_STATUS="$(echo "$LATEST_JSON" | jq -r '.services.nginx')"
FAIL2BAN_STATUS="$(echo "$LATEST_JSON" | jq -r '.services.fail2ban')"
UFW_STATUS="$(echo "$LATEST_JSON" | jq -r '.services.ufw')"

NOW="$(now_ts)"

# -------------------------
# Alert evaluation function
# -------------------------
evaluate_threshold() {
  local alert_name="$1"
  local current_value="$2"
  local threshold="$3"

  LAST_TS="$(get_last_alert_ts "$alert_name")"

  if (( $(echo "$current_value > $threshold" | bc -l) )); then
    if (( NOW - LAST_TS >= ALERT_COOLDOWN )); then
      log_alert "$alert_name|$HOSTNAME|$current_value|$threshold|$TIMESTAMP"
      update_alert_ts "$alert_name" "$NOW"
      
      bash "$(dirname "$0")/slack_alert.sh" \
        "$alert_name" \
        "$HOSTNAME" \
        "$current_value" \
        "$threshold" \
        "$TIMESTAMP"
    fi
  fi
}

# -------------------------
# CPU / Memory / Disk alerts
# -------------------------
evaluate_threshold "HIGH_CPU" "$CPU_USAGE" "$CPU_USAGE_WARN"
evaluate_threshold "HIGH_MEMORY" "$MEMORY_USAGE" "$MEMORY_USAGE_WARN"
evaluate_threshold "HIGH_DISK" "$DISK_USAGE" "$DISK_USAGE_WARN"
evaluate_threshold "HIGH_INODE" "$INODE_USAGE" "$INODE_USAGE_WARN"

# -------------------------
# Service alerts
# -------------------------
if [[ "$ALERT_ON_SERVICE_DOWN" == "true" ]]; then
  [[ "$SSH_STATUS" != "active" ]] && evaluate_threshold "SSH_DOWN" 1 0
  [[ "$NGINX_STATUS" != "active" ]] && evaluate_threshold "NGINX_DOWN" 1 0
  [[ "$FAIL2BAN_STATUS" != "active" ]] && evaluate_threshold "FAIL2BAN_DOWN" 1 0
  [[ "$UFW_STATUS" != "active" ]] && evaluate_threshold "UFW_DOWN" 1 0
fi
