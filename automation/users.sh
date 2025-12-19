#!/bin/bash
set -euo pipefail

LOG="/var/log/locc/automation.log"

: "${ADMIN_USER:?}"
: "${ADMIN_SSH_PUBLIC_KEY:?}"

log() {
  echo "$(date -Is) [USERS] $1" | tee -a "$LOG"
}

# Create user if not exists
if id "$ADMIN_USER" &>/dev/null; then
  log "User $ADMIN_USER already exists"
else
  useradd -m -s /bin/bash "$ADMIN_USER"
  log "User $ADMIN_USER created"
fi

usermod -aG sudo "$ADMIN_USER"

SSH_DIR="/home/$ADMIN_USER/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

touch "$AUTH_KEYS"

# Inject SSH key if missing
if ! grep -q "$ADMIN_SSH_PUBLIC_KEY" "$AUTH_KEYS"; then
  echo "$ADMIN_SSH_PUBLIC_KEY" >> "$AUTH_KEYS"
  log "SSH public key added for $ADMIN_USER"
else
  log "SSH key already present for $ADMIN_USER"
fi

chmod 600 "$AUTH_KEYS"
chown -R "$ADMIN_USER:$ADMIN_USER" "$SSH_DIR"
