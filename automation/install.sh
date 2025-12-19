#!/bin/bash
set -euo pipefail

AUTOMATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$AUTOMATION_DIR/locc.conf"

LOG_DIR="/var/log/locc"
LOG_FILE="$LOG_DIR/automation.log"

log() {
  echo "$(date -Is) [INSTALL] $1" | tee -a "$LOG_FILE"
}

require_root() {
  [[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }
}

load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Missing locc.conf"
    echo "Copy locc.conf.example → locc.conf and edit it"
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
}

require_root
load_config

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"

export ADMIN_USER
export SSH_PORT
export ADMIN_SSH_PUBLIC_KEY
export INSTALL_NGINX

log "Starting LOCC Phase 2 automation"
log "Admin user: $ADMIN_USER | SSH port: $SSH_PORT"

bash "$AUTOMATION_DIR/users.sh"
bash "$AUTOMATION_DIR/hardening.sh"
bash "$AUTOMATION_DIR/firewall.sh"
bash "$AUTOMATION_DIR/services.sh"

log "Phase 2 automation completed successfully"
