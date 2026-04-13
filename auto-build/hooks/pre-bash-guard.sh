#!/bin/bash
# PreToolUse hook: Block destructive bash commands
# Exit 2 = block the command, stderr fed back to Claude
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$CMD" ]; then
  exit 0
fi

# Destructive patterns
if echo "$CMD" | grep -qE 'rm\s+-rf\s+/|rm\s+-rf\s+~|chmod\s+777|sudo\s|git\s+reset\s+--hard|git\s+push.*--force|git\s+clean.*-f|git\s+branch\s+-D\s+(main|master)|DROP\s+TABLE|DROP\s+DATABASE'; then
  echo "BLOCKED: Destructive command detected: $(echo "$CMD" | head -c 100)" >&2
  exit 2
fi

exit 0
