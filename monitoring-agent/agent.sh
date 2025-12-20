#!/usr/bin/env bash
set -euo pipefail

# =========================
# Config
# =========================

AGENT_VERSION="1.0"
LOG_DIR="/var/log/locc"
AGENT_LOG="$LOG_DIR/agent.json"

mkdir -p "$LOG_DIR"

# =========================
# Source metrics
# =========================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load metrics library
# shellcheck disable=SC1091
source "$SCRIPT_DIR/metrics.sh"

# =========================
# Collect metrics
# =========================

TIMESTAMP="$(date --iso-8601=seconds)"
HOSTNAME="$(hostname)"

UPTIME_SECONDS="$(get_uptime_seconds)"

CPU_USAGE="$(get_cpu_usage_percent)"
read LOAD_1 LOAD_5 LOAD_15 <<< "$(get_load_average)"

read MEM_TOTAL MEM_USED MEM_FREE MEM_USED_PERCENT <<< "$(get_memory_stats)"

read DISK_TOTAL DISK_USED DISK_USED_PERCENT <<< "$(get_disk_stats)"
INODE_USED_PERCENT="$(get_inode_usage_percent)"

TOP_CPU_JSON="$(get_top_cpu_processes_json)"
TOP_MEM_JSON="$(get_top_memory_processes_json)"


SSH_STATUS="$(get_service_status ssh)"
NGINX_STATUS="$(get_service_status nginx)"
FAIL2BAN_STATUS="$(get_service_status fail2ban)"
UFW_STATUS="$(get_service_status ufw)"

# =========================
# Build JSON (NDJSON)
# =========================

JSON_PAYLOAD="$(
jq -c -n \
  --arg timestamp "$TIMESTAMP" \
  --arg hostname "$HOSTNAME" \
  --arg agent_version "$AGENT_VERSION" \
  --argjson uptime "$UPTIME_SECONDS" \
  --argjson cpu_usage "$CPU_USAGE" \
  --argjson load1 "$LOAD_1" \
  --argjson load5 "$LOAD_5" \
  --argjson load15 "$LOAD_15" \
  --argjson mem_total "$MEM_TOTAL" \
  --argjson mem_used "$MEM_USED" \
  --argjson mem_free "$MEM_FREE" \
  --argjson mem_used_pct "$MEM_USED_PERCENT" \
  --argjson disk_total "$DISK_TOTAL" \
  --argjson disk_used "$DISK_USED" \
  --argjson disk_used_pct "$DISK_USED_PERCENT" \
  --argjson inode_pct "$INODE_USED_PERCENT" \
  --argjson top_cpu "$TOP_CPU_JSON" \
  --argjson top_mem "$TOP_MEM_JSON" \
  --arg ssh "$SSH_STATUS" \
  --arg nginx "$NGINX_STATUS" \
  --arg fail2ban "$FAIL2BAN_STATUS" \
  --arg ufw "$UFW_STATUS" \
'
{
  timestamp: $timestamp,
  hostname: $hostname,
  agent_version: $agent_version,

  system: {
    uptime_seconds: $uptime
  },

  cpu: {
    usage_percent: $cpu_usage,
    load_avg: {
      "1m": $load1,
      "5m": $load5,
      "15m": $load15
    }
  },

  memory: {
    total_mb: $mem_total,
    used_mb: $mem_used,
    free_mb: $mem_free,
    used_percent: $mem_used_pct
  },

  disk: {
    mount: "/",
    total_gb: $disk_total,
    used_gb: $disk_used,
    used_percent: $disk_used_pct,
    inode_used_percent: $inode_pct
  },

  processes: {
    top_cpu: $top_cpu,
    top_memory: $top_mem
  },

  services: {
    ssh: $ssh,
    nginx: $nginx,
    fail2ban: $fail2ban,
    ufw: $ufw
  }
}
')"

# =========================
# Write log (one line only)
# =========================

echo "$JSON_PAYLOAD" >> "$AGENT_LOG"
