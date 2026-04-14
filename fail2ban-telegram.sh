#!/bin/bash
# /usr/local/bin/fail2ban-telegram.sh
# Sends Fail2ban ban/unban events to Shuffle SOAR webhook
# Shuffle then forwards to Telegram with formatting
#
# Usage: fail2ban-telegram.sh <ip> <jail> <action>
# Example: fail2ban-telegram.sh 1.2.3.4 sshd banned
#
# Install:
#   sudo chmod +x /usr/local/bin/fail2ban-telegram.sh

IP="$1"
JAIL="$2"
ACTION="$3"
TIME=$(date '+%Y-%m-%d %H:%M:%S')

SHUFFLE_WEBHOOK="http://10.0.0.30:3001/api/v1/hooks/webhook_REPLACE_WITH_YOUR_WEBHOOK_ID"

curl -s -X POST "$SHUFFLE_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "{\"ip\":\"$IP\",\"jail\":\"$JAIL\",\"time\":\"$TIME\",\"action\":\"$ACTION\"}"
