#!/bin/bash
set -euo pipefail

LOG="/var/log/locc/automation.log"
SSHD_CONFIG="/etc/ssh/sshd_config"

: "${SSH_PORT:?}"

log() {
  echo "$(date -Is) [HARDENING] $1" | tee -a "$LOG"
}

cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

apply_setting() {
  local key="$1"
  local value="$2"

  if grep -q "^$key" "$SSHD_CONFIG"; then
    sed -i "s/^$key.*/$key $value/" "$SSHD_CONFIG"
  else
    echo "$key $value" >> "$SSHD_CONFIG"
  fi
}

apply_setting "Port" "$SSH_PORT"
apply_setting "PermitRootLogin" "no"
apply_setting "PasswordAuthentication" "no"
apply_setting "X11Forwarding" "no"
apply_setting "MaxAuthTries" "3"

systemctl restart ssh

log "SSH hardened and restarted on port $SSH_PORT"
