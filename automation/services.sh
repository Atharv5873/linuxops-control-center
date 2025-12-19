#!/bin/bash
set -euo pipefail

LOG="/var/log/locc/automation.log"

: "${INSTALL_NGINX:?}"

log() {
  echo "$(date -Is) [SERVICES] $1" | tee -a "$LOG"
}

if [[ "$INSTALL_NGINX" == "true" ]]; then
  apt install -y nginx
  systemctl enable nginx
  systemctl start nginx

  if systemctl is-active --quiet nginx; then
    log "Nginx installed and running"
  else
    log "Nginx failed to start"
    exit 1
  fi
else
  log "Nginx installation skipped"
fi
