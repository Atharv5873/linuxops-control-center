#!/bin/bash
set -euo pipefail

LOG="/var/log/locc/automation.log"

: "${SSH_PORT:?}"

log() {
  echo "$(date -Is) [FIREWALL] $1" | tee -a "$LOG"
}

apt update -y
apt install -y ufw fail2ban

ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT/tcp"

ufw --force enable

systemctl enable fail2ban
systemctl start fail2ban

log "Firewall enabled and Fail2Ban running"
