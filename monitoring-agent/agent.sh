#!/bin/bash
set -euo pipefail

AGENT_VERSION="1.0"
LOG_DIR="/var/log/locc"
LOG_FILE="$LOG_DIR/agent.json"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load metrics library
# shellcheck disable=SC1091
source "$SCRIPT_DIR/metrics.sh"

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

# =========================
# Collect Metrics
# =========================

TIMESTAMP="$(date -Is)"
HOSTNAME="$(get_hostname)"
UPTIME_SECONDS="$(get_uptime_seconds)"

CPU_USAGE="$(get_cpu_usage_percent)"
read LOAD_1 LOAD_5 LOAD_15 <<< "$(get_load_average)"

read MEM_TOTAL MEM_USED MEM_FREE MEM_USED_PERCENT <<< "$(get_memory_stats)"

read DISK_TOTAL DISK_USED DISK_USED_PERCENT <<< "$(get_disk_stats)"
INODE_USED_PERCENT="$(get_inode_usage_percent)"

# =========================
# Process Metrics
# =========================

TOP_CPU_JSON=$(get_top_cpu_processes | awk -F'|' '
  BEGIN { printf "[" }
  {
    printf "{\"pid\":%s,\"name\":\"%s\",\"cpu_percent\":%s}", $1, $2, $3
    if (NR < 3) printf ","
  }
  END { printf "]" }
')

TOP_MEM_JSON=$(get_top_memory_processes | awk -F'|' '
  BEGIN { printf "[" }
  {
    printf "{\"pid\":%s,\"name\":\"%s\",\"mem_percent\":%s}", $1, $2, $3
    if (NR < 3) printf ","
  }
  END { printf "]" }
')

# =========================
# Service Health
# =========================

SSH_STATUS="$(get_service_status ssh)"
NGINX_STATUS="$(get_service_status nginx)"
FAIL2BAN_STATUS="$(get_service_status fail2ban)"
UFW_STATUS="$(get_service_status ufw)"

# =========================
# Write JSON (JSONL)
# =========================

cat <<EOF >> "$LOG_FILE"
{
  "timestamp": "$TIMESTAMP",
  "hostname": "$HOSTNAME",
  "agent_version": "$AGENT_VERSION",

  "system": {
    "uptime_seconds": $UPTIME_SECONDS
  },

  "cpu": {
    "usage_percent": $CPU_USAGE,
    "load_avg": {
      "1m": $LOAD_1,
      "5m": $LOAD_5,
      "15m": $LOAD_15
    }
  },

  "memory": {
    "total_mb": $MEM_TOTAL,
    "used_mb": $MEM_USED,
    "free_mb": $MEM_FREE,
    "used_percent": $MEM_USED_PERCENT
  },

  "disk": {
    "mount": "/",
    "total_gb": $DISK_TOTAL,
    "used_gb": $DISK_USED,
    "used_percent": $DISK_USED_PERCENT,
    "inode_used_percent": $INODE_USED_PERCENT
  },

  "processes": {
    "top_cpu": $TOP_CPU_JSON,
    "top_memory": $TOP_MEM_JSON
  },

  "services": {
    "ssh": "$SSH_STATUS",
    "nginx": "$NGINX_STATUS",
    "fail2ban": "$FAIL2BAN_STATUS",
    "ufw": "$UFW_STATUS"
  }
}
EOF
