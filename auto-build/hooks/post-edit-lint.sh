#!/bin/bash
# PostToolUse hook: Auto-lint after file edits
# Exit 0 always (PostToolUse can't block, only observe)
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  exit 0
fi

case "$FILE" in
  *.py)
    command -v ruff >/dev/null 2>&1 && {
      ruff check --fix --quiet "$FILE" 2>/dev/null
      ruff format --quiet "$FILE" 2>/dev/null
    }
    ;;
  *.ts|*.tsx|*.js|*.jsx)
    command -v npx >/dev/null 2>&1 && npx prettier --write "$FILE" 2>/dev/null
    ;;
  *.cs)
    command -v dotnet >/dev/null 2>&1 && dotnet format --include "$FILE" 2>/dev/null
    ;;
  *.go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$FILE" 2>/dev/null
    ;;
esac

exit 0
