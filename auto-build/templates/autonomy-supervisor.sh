#!/bin/bash
# Supervisor: Keeps Claude Code running, auto-restarts on crash
# Usage: tmux new -s architect 'bash autonomy-supervisor.sh /path/to/project'

set -euo pipefail

PROJECT_DIR="${1:-.}"
MAX_RESTARTS=5
RESTART_COUNT=0
LOG_DIR="$PROJECT_DIR/logs"

mkdir -p "$LOG_DIR"
cd "$PROJECT_DIR" || { echo "Project dir not found: $PROJECT_DIR"; exit 1; }

# Prevent macOS sleep
caffeinate -dims &
CAFF_PID=$!
trap "kill $CAFF_PID 2>/dev/null" EXIT

echo "[supervisor] Starting autonomous build in $PROJECT_DIR"
echo "[supervisor] Max restarts: $MAX_RESTARTS"
echo "[supervisor] Logs: $LOG_DIR/supervisor.log"

while [ $RESTART_COUNT -lt $MAX_RESTARTS ]; do
  ATTEMPT=$((RESTART_COUNT + 1))
  echo "[supervisor] === Attempt $ATTEMPT/$MAX_RESTARTS ===" | tee -a "$LOG_DIR/supervisor.log"
  echo "[supervisor] $(date)" | tee -a "$LOG_DIR/supervisor.log"

  # Check if all tasks are already done
  if [ -f ".autonomy/state.json" ]; then
    PENDING=$(jq '[.tasks[] | select(.status!="done")] | length' .autonomy/state.json 2>/dev/null || echo "0")
    if [ "$PENDING" -eq 0 ]; then
      echo "[supervisor] All tasks already complete. Nothing to do." | tee -a "$LOG_DIR/supervisor.log"

      # Send Telegram notification if configured
      if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
          -H "Content-Type: application/json" \
          -d "{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"text\": \"🎉 All tasks complete!\"}" >/dev/null
      fi
      break
    fi
  fi

  # Start Claude Code
  if [ -f ".autonomy/session_id" ]; then
    SESSION_ID=$(cat .autonomy/session_id)
    echo "[supervisor] Resuming session: $SESSION_ID" | tee -a "$LOG_DIR/supervisor.log"
    claude --resume "$SESSION_ID" 2>&1 | tee -a "$LOG_DIR/claude.log"
  else
    echo "[supervisor] Starting new session" | tee -a "$LOG_DIR/supervisor.log"
    claude 2>&1 | tee -a "$LOG_DIR/claude.log"
  fi

  EXIT_CODE=$?
  echo "[supervisor] Claude exited with code $EXIT_CODE" | tee -a "$LOG_DIR/supervisor.log"

  # Check if tasks completed during this run
  if [ -f ".autonomy/state.json" ]; then
    REMAINING=$(jq '[.tasks[] | select(.status!="done")] | length' .autonomy/state.json 2>/dev/null || echo "999")
    if [ "$REMAINING" -eq 0 ]; then
      echo "[supervisor] All tasks complete!" | tee -a "$LOG_DIR/supervisor.log"
      break
    fi
    echo "[supervisor] $REMAINING tasks remaining" | tee -a "$LOG_DIR/supervisor.log"
  fi

  RESTART_COUNT=$((RESTART_COUNT + 1))

  if [ $RESTART_COUNT -lt $MAX_RESTARTS ]; then
    echo "[supervisor] Restarting in 30 seconds..." | tee -a "$LOG_DIR/supervisor.log"

    # Telegram: notify restart
    if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
      curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"text\": \"🔄 Claude crashed (exit $EXIT_CODE). Restarting ($ATTEMPT/$MAX_RESTARTS)...\"}" >/dev/null
    fi

    sleep 30
  fi
done

if [ $RESTART_COUNT -ge $MAX_RESTARTS ]; then
  echo "[supervisor] Max restarts reached. Giving up." | tee -a "$LOG_DIR/supervisor.log"

  if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -H "Content-Type: application/json" \
      -d "{\"chat_id\": \"${TELEGRAM_CHAT_ID}\", \"text\": \"🛑 Max restarts reached. Human intervention needed.\"}" >/dev/null
  fi
fi

echo "[supervisor] Done." | tee -a "$LOG_DIR/supervisor.log"
