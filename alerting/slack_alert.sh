#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SLACK_CONF="$SCRIPT_DIR/slack.conf"

# -------------------------
# Load config
# -------------------------
if [[ ! -f "$SLACK_CONF" ]]; then
  echo "Slack config missing, skipping Slack alert"
  exit 0
fi

source "$SLACK_CONF"

: "${SLACK_WEBHOOK_URL:?}"

# -------------------------
# Load config
# -------------------------
if [[ ! -f "$SLACK_CONF" ]]; then
  echo "Slack config missing, skipping Slack alert"
  exit 0
fi

# -------------------------
# Alert payload
# -------------------------
ALERT_NAME="$1"
HOSTNAME="$2"
CURRENT_VALUE="$3"
THRESHOLD="$4"
TIMESTAMP="$5"

MESSAGE="🚨 *$ALERT_NAME*
• Host: \`$HOSTNAME\`
• Value: $CURRENT_VALUE (threshold: $THRESHOLD)
• Time: $TIMESTAMP"

payload=$(jq -n \
  --arg text "$MESSAGE" \
  --arg username "$SLACK_USERNAME" \
  --arg channel "$SLACK_CHANNEL" \
  '{
    text: $text,
    username: $username,
    channel: $channel
  }')

curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "$SLACK_WEBHOOK_URL" >/dev/null
