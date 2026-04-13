#!/bin/bash
# PreToolUse hook: ARCHITECT MODE — block direct source code writing
# Forces delegation to worker models (claude -p, codex exec, gemini -p)
#
# Exit 2 = BLOCK the tool call, stderr message fed back to Claude
# Exit 0 = ALLOW the tool call

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Skip if no tool name detected
[ -z "$TOOL" ] && exit 0

# Always allow writing to non-source files (config, docs, state, hooks)
if [ -n "$FILE" ]; then
  case "$FILE" in
    .autonomy/*|.claude/*|.gnap/*|docs/*|logs/*|\
    CLAUDE.md|README.md|.gitignore|.env*|\
    *.json|*.yaml|*.yml|*.toml|*.md|*.txt|*.sh|\
    Dockerfile|docker-compose*|Makefile|Procfile|\
    pyproject.toml|package.json|go.mod|Cargo.toml|*.csproj|*.sln)
      exit 0 ;;
  esac
fi

# Block Write/Edit/MultiEdit on source code files
if [[ "$TOOL" == "Write" || "$TOOL" == "Edit" || "$TOOL" == "MultiEdit" ]]; then
  if [ -n "$FILE" ]; then
    case "$FILE" in
      src/*|tests/*|test/*|lib/*|app/*|cmd/*|internal/*|pkg/*|\
      *.py|*.ts|*.tsx|*.js|*.jsx|*.cs|*.go|*.rs|*.java|*.rb|\
      migrations/*|alembic/*)
        echo "🚫 ARCHITECT MODE: You cannot write source code directly." >&2
        echo "Dispatch this task to a worker model:" >&2
        echo "  claude -p \"task prompt\" --model claude-sonnet-4-6 --output-format stream-json --max-turns 80 --permission-mode dontAsk --allowedTools \"Read,Grep,Glob,Edit,Write,Bash\"" >&2
        echo "  echo \"task prompt\" | codex exec --full-auto --json" >&2
        echo "  gemini -p \"task prompt\" --yolo" >&2
        exit 2 ;;
    esac
  fi
fi

# Block Bash commands that write source files indirectly
if [[ "$TOOL" == "Bash" ]]; then
  CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
  if [ -n "$CMD" ]; then
    # Detect redirect/pipe to source files
    if echo "$CMD" | grep -qE '>\s*(src/|tests/|test/|lib/|app/|cmd/|internal/|pkg/|migrations/)'; then
      echo "🚫 ARCHITECT MODE: Cannot write to source directories via Bash redirect. Dispatch to a worker model." >&2
      exit 2
    fi
    # Detect tee/cat heredoc to source files
    if echo "$CMD" | grep -qE '(tee|cat\s*>)\s*(src/|tests/|.*\.(py|ts|js|cs|go|rs))'; then
      echo "🚫 ARCHITECT MODE: Cannot write source code via Bash. Dispatch to a worker model." >&2
      exit 2
    fi
  fi
fi

exit 0
