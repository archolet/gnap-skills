#!/bin/bash
# Stop hook: Don't let Claude stop if there are pending tasks
# Exit 2 = prevent stop, stderr fed back to Claude
# Exit 0 = allow stop

STATE=".autonomy/state.json"

if [ ! -f "$STATE" ]; then
  exit 0  # No autonomy state — allow stop
fi

PENDING=$(cat "$STATE" | jq '[.tasks[] | select(.status=="pending" or .status=="in_progress")] | length' 2>/dev/null)

if [ -n "$PENDING" ] && [ "$PENDING" -gt 0 ]; then
  DONE=$(cat "$STATE" | jq '[.tasks[] | select(.status=="done")] | length' 2>/dev/null)
  TOTAL=$(cat "$STATE" | jq '.tasks | length' 2>/dev/null)
  echo "Still $PENDING tasks remaining ($DONE/$TOTAL done). Continue working on the next task." >&2
  exit 2
fi

exit 0
