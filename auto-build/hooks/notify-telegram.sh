#!/bin/bash
# Notification hook: Send Telegram alert for important events
# Reads TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID from environment

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  exit 0  # Telegram not configured, skip silently
fi

INPUT=$(cat)
MESSAGE=$(echo "$INPUT" | jq -r '.message // .notification // "Event occurred"' 2>/dev/null)

if [ -n "$MESSAGE" ] && [ "$MESSAGE" != "null" ]; then
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"text\": \"🔔 $MESSAGE\"}" >/dev/null 2>&1
fi

exit 0
