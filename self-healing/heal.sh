#!/bin/bash
set -euo pipefail

# =========================
# Paths & Files
# =========================
ALERT_LOG="/var/log/locc/alerts.log"
HEAL_LOG="/var/log/locc/healing.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_CONF="$SCRIPT_DIR/rules.conf"
STATE_DB="/var/log/locc/heal_state.db"

mkdir -p /var/log/locc
touch "$HEAL_LOG" "$STATE_DB"

# =========================
# Load rules
# =========================
# shellcheck disable=SC1090
source "$RULES_CONF"

# =========================
# Helpers
# =========================
now_ts() {
  date +%s
}

log_heal() {
  echo "$(date -Is) $1" >> "$HEAL_LOG"
}

get_last_heal_ts() {
  grep "^$1|" "$STATE_DB" 2>/dev/null | cut -d'|' -f2 || echo 0
}

update_heal_ts() {
  sed -i "/^$1|/d" "$STATE_DB"
  echo "$1|$2" >> "$STATE_DB"
}

# =========================
# Disk Cleanup Helper
# =========================
cleanup_disk() {
  local paths="$1"
  local max_age="$2"

  for p in $paths; do
    if [[ -d "$p" ]]; then
      log_heal "[DISK] Cleaning $p (*.log older than $max_age days)"
      find "$p" -type f -name "*.log" -mtime +"$max_age" \
        -print -delete >> "$HEAL_LOG" 2>&1
    else
      log_heal "[DISK] Skip non-existent path: $p"
    fi
  done
}

# =========================
# Read latest alert
# =========================
[[ -f "$ALERT_LOG" ]] || exit 0

LATEST_ALERT="$(tail -n 1 "$ALERT_LOG")"

ALERT_NAME="$(echo "$LATEST_ALERT" | cut -d'|' -f1)"
STATE="$(echo "$LATEST_ALERT" | cut -d'|' -f2)"

NOW="$(now_ts)"

# Only heal on ALERT state
[[ "$STATE" == "ALERT" ]] || exit 0

# =========================
# Healing Logic
# =========================
case "$ALERT_NAME" in

  NGINX_DOWN)
    [[ "$AUTO_RESTART_NGINX" == "true" ]] || exit 0

    LAST_TS="$(get_last_heal_ts "$ALERT_NAME")"
    (( NOW - LAST_TS >= RESTART_COOLDOWN )) || exit 0

    log_heal "Attempting restart for nginx"
    if systemctl restart nginx; then
      log_heal "nginx restart successful"
      update_heal_ts "$ALERT_NAME" "$NOW"
    else
      log_heal "nginx restart FAILED"
    fi
    ;;

  FAIL2BAN_DOWN)
    [[ "$AUTO_RESTART_FAIL2BAN" == "true" ]] || exit 0

    LAST_TS="$(get_last_heal_ts "$ALERT_NAME")"
    (( NOW - LAST_TS >= RESTART_COOLDOWN )) || exit 0

    log_heal "Attempting restart for fail2ban"
    if systemctl restart fail2ban; then
      log_heal "fail2ban restart successful"
      update_heal_ts "$ALERT_NAME" "$NOW"
    else
      log_heal "fail2ban restart FAILED"
    fi
    ;;

  HIGH_DISK)
    [[ "$AUTO_CLEANUP_DISK" == "true" ]] || exit 0

    LAST_TS="$(get_last_heal_ts "$ALERT_NAME")"
    (( NOW - LAST_TS >= DISK_CLEANUP_COOLDOWN )) || exit 0

    log_heal "Starting disk cleanup"
    if cleanup_disk "$DISK_CLEANUP_PATHS" "$DISK_LOG_MAX_AGE_DAYS"; then
      log_heal "Disk cleanup executed"
      update_heal_ts "$ALERT_NAME" "$NOW"
    else
      log_heal "Disk cleanup FAILED"
      echo "HIGH_DISK_RECOVERY_FAILED|ALERT|$(hostname)|cleanup_failed|n/a|$(date -Is)" \
        >> "$ALERT_LOG"
    fi
    ;;

  *)
    exit 0
    ;;
esac
