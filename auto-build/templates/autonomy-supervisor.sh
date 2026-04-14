#!/usr/bin/env bash
# Supervisor:
# - Launch or resume a named Claude session for this project
# - Recover from unexpected exits while the autonomous loop is active
# - Avoid set -e/pipeline traps around `claude | tee`
# - Store a resumable session reference in .autonomy/session_id

set -u
set -o pipefail

PROJECT_DIR="${1:-.}"
MAX_RESTARTS="${GNAP_MAX_RESTARTS:-5}"
RESTART_DELAY="${GNAP_RESTART_DELAY:-30}"
CLAUDE_BIN="${GNAP_CLAUDE_BIN:-claude}"

cd "$PROJECT_DIR" >/dev/null 2>&1 || {
  printf '[supervisor] Project dir not found: %s\n' "$PROJECT_DIR" >&2
  exit 1
}

STATE_FILE=".autonomy/state.json"
TASKS_FILE=".autonomy/tasks.json"
LOCK_FILE=".autonomy/runtime.lock"
SESSION_FILE=".autonomy/session_id"
LOG_DIR="logs"
SUP_LOG="$LOG_DIR/supervisor.log"
CLAUDE_LOG="$LOG_DIR/claude.log"

mkdir -p .autonomy "$LOG_DIR"

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log() {
  printf '[supervisor] %s %s\n' "$(timestamp)" "$*" | tee -a "$SUP_LOG" >/dev/null
}

send_telegram() {
  local text="${1:-}"
  [ -z "${TELEGRAM_BOT_TOKEN:-}" ] && return 0
  [ -z "${TELEGRAM_CHAT_ID:-}" ] && return 0

  curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"${TELEGRAM_CHAT_ID}\",\"text\":\"${text}\"}" >/dev/null 2>&1 || true
}

json_ok() {
  local file="$1"
  [ -f "$file" ] && jq -e '.' "$file" >/dev/null 2>&1
}

state_status() {
  json_ok "$STATE_FILE" || return 1
  jq -r '.execution.status // empty' "$STATE_FILE" 2>/dev/null
}

remaining_tasks() {
  if json_ok "$STATE_FILE"; then
    jq -r '[.tasks[]? | select(.status != "done")] | length' "$STATE_FILE" 2>/dev/null && return 0
  fi

  if json_ok "$TASKS_FILE"; then
    jq -r '.tasks | length // 0' "$TASKS_FILE" 2>/dev/null && return 0
  fi

  printf '0\n'
}

ensure_session_ref() {
  if [ -s "$SESSION_FILE" ]; then
    cat "$SESSION_FILE"
    return 0
  fi

  local slug
  slug="$(basename "$PWD" | tr -cs '[:alnum:]._- ' '-' | tr ' ' '-' | tr -s '-')"
  local ref="autonomy-${slug}-$(date -u +%Y%m%dT%H%M%SZ)-$$-$RANDOM"
  printf '%s\n' "$ref" > "$SESSION_FILE"
  printf '%s\n' "$ref"
}

is_active_run() {
  if [ -f "$LOCK_FILE" ]; then
    return 0
  fi

  case "$(state_status 2>/dev/null || true)" in
    running|worker_running|checkpoint)
      return 0
      ;;
  esac

  return 1
}

start_caffeinate() {
  if command -v caffeinate >/dev/null 2>&1; then
    caffeinate -dims &
    CAFFE_PID="$!"
  else
    CAFFE_PID=""
  fi
}

cleanup() {
  if [ -n "${CAFFE_PID:-}" ]; then
    kill "$CAFFE_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

start_caffeinate

SESSION_REF="$(ensure_session_ref)"
RESTART_COUNT=0

log "Project: $PWD"
log "Session ref: $SESSION_REF"
log "Max restarts: $MAX_RESTARTS"
send_telegram "GNAP supervisor attached to ${SESSION_REF}"

while [ "$RESTART_COUNT" -lt "$MAX_RESTARTS" ]; do
  REMAINING="$(remaining_tasks)"
  STATUS="$(state_status 2>/dev/null || true)"

  if [ "${REMAINING:-0}" -eq 0 ]; then
    log "No remaining tasks. Exiting."
    send_telegram "GNAP complete for ${SESSION_REF}"
    exit 0
  fi

  # If the runtime has not started yet, launch once with --name and do not loop forever
  # if the user closes it before /architect-loop begins.
  if [ "$RESTART_COUNT" -eq 0 ] && ! is_active_run; then
    log "Runtime is prepared but not active. Launching named session once."
    set +e
    "$CLAUDE_BIN" --name "$SESSION_REF" 2>&1 | tee -a "$CLAUDE_LOG"
    EXIT_CODE=${PIPESTATUS[0]}
    set -e
    log "Claude exited with code $EXIT_CODE before autonomous loop became active."
    exit "$EXIT_CODE"
  fi

  ATTEMPT=$((RESTART_COUNT + 1))
  log "Starting attempt $ATTEMPT/$MAX_RESTARTS (status=${STATUS:-unknown}, remaining=${REMAINING})"

  set +e
  "$CLAUDE_BIN" --resume "$SESSION_REF" 2>&1 | tee -a "$CLAUDE_LOG"
  EXIT_CODE=${PIPESTATUS[0]}
  set -e

  REMAINING="$(remaining_tasks)"
  STATUS="$(state_status 2>/dev/null || true)"
  log "Claude exited with code $EXIT_CODE (status=${STATUS:-unknown}, remaining=${REMAINING})"

  if [ "${REMAINING:-0}" -eq 0 ]; then
    log "All tasks are complete."
    send_telegram "GNAP complete for ${SESSION_REF}"
    exit 0
  fi

  if ! is_active_run; then
    log "No active runtime lock/state marker found. Not restarting automatically."
    exit "$EXIT_CODE"
  fi

  RESTART_COUNT=$ATTEMPT
  if [ "$RESTART_COUNT" -ge "$MAX_RESTARTS" ]; then
    break
  fi

  send_telegram "GNAP session ${SESSION_REF} exited (code ${EXIT_CODE}). Restart ${RESTART_COUNT}/${MAX_RESTARTS} in ${RESTART_DELAY}s."
  sleep "$RESTART_DELAY"
done

log "Max restarts reached. Human intervention required."
send_telegram "GNAP session ${SESSION_REF} reached max restarts. Human intervention required."
exit 1
