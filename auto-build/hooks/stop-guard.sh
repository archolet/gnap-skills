#!/usr/bin/env bash
# Stop hook:
# - Prevent stopping while the autonomous loop is actively running and work remains
# - Fall back to tasks.json if state.json is missing or malformed
# - Allow stop when the runtime is only prepared (ready) or explicitly awaiting human input

set -u

STATE_FILE=".autonomy/state.json"
TASKS_FILE=".autonomy/tasks.json"
LOCK_FILE=".autonomy/runtime.lock"

read_json() {
  local file="$1"
  jq -e '.' "$file" >/dev/null 2>&1
}

state_status() {
  jq -r '.execution.status // empty' "$STATE_FILE" 2>/dev/null
}

state_total() {
  jq -r '.stats.total // (.tasks | length) // 0' "$STATE_FILE" 2>/dev/null
}

state_remaining() {
  jq -r '[.tasks[]? | select(.status != "done")] | length' "$STATE_FILE" 2>/dev/null
}

state_done() {
  jq -r '[.tasks[]? | select(.status == "done")] | length' "$STATE_FILE" 2>/dev/null
}

task_total() {
  jq -r '.tasks | length // 0' "$TASKS_FILE" 2>/dev/null
}

task_current() {
  jq -r '.execution.current_task_id // empty' "$STATE_FILE" 2>/dev/null
}

# If we have a valid state file, prefer it.
if [ -f "$STATE_FILE" ] && read_json "$STATE_FILE"; then
  STATUS="$(state_status)"
  TOTAL="$(state_total)"
  REMAINING="$(state_remaining)"
  DONE="$(state_done)"
  CURRENT="$(task_current)"

  case "$STATUS" in
    ready|completed|awaiting_human|failed|paused|"")
      # "ready" means the runtime was installed but the loop has not started.
      # completed/awaiting_human/failed/paused should not trap the user in the session.
      ;;
    *)
      if [ "${REMAINING:-0}" -gt 0 ]; then
        if [ -n "$CURRENT" ]; then
          printf 'Autonomous run is active. %s/%s tasks complete. Current task: %s. Continue the build loop instead of stopping.\n' "$DONE" "$TOTAL" "$CURRENT" >&2
        else
          printf 'Autonomous run is active. %s/%s tasks complete. Continue the build loop instead of stopping.\n' "$DONE" "$TOTAL" >&2
        fi
        exit 2
      fi
      ;;
  esac
fi

# Fallback: if the active runtime lock exists and tasks.json still shows unfinished work,
# treat the loop as running even if state.json is empty or corrupted.
if [ -f "$LOCK_FILE" ] && [ -f "$TASKS_FILE" ] && read_json "$TASKS_FILE"; then
  TOTAL="$(task_total)"
  if [ "${TOTAL:-0}" -gt 0 ]; then
    printf 'Autonomous run lock is present and %s tasks are still defined. Resume /architect-loop instead of stopping.\n' "$TOTAL" >&2
    exit 2
  fi
fi

exit 0
