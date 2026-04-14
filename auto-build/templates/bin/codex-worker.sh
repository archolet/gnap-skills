#!/usr/bin/env bash
# Codex worker wrapper
# Contract:
#   .claude/bin/codex-worker.sh --task-id T001 --prompt-file .autonomy/prompts/T001.md

set -euo pipefail

TASK_ID=""
PROMPT_FILE=""

usage() {
  echo "Usage: $0 --task-id <task-id> --prompt-file <path>" >&2
  exit 64
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --task-id)
      TASK_ID="${2:-}"
      shift 2
      ;;
    --prompt-file)
      PROMPT_FILE="${2:-}"
      shift 2
      ;;
    --bare|--permission-mode|--allowedTools|--dangerously-skip-permissions|--dangerouslyDisableSandbox)
      echo "Unsupported flag passed to wrapper: $1" >&2
      exit 64
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

[ -n "$TASK_ID" ] || usage
[ -n "$PROMPT_FILE" ] || usage

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

PROMPT_PATH="$ROOT/$PROMPT_FILE"
[ -f "$PROMPT_PATH" ] || {
  echo "Prompt file not found: $PROMPT_FILE" >&2
  exit 66
}

RESULT_DIR="$ROOT/.autonomy/results"
WORKTREE_DIR="$ROOT/.autonomy/worktrees/$TASK_ID"
BRANCH="worker/$TASK_ID"
LOG_FILE="$ROOT/logs/workers/${TASK_ID}.codex.log"
RESULT_FILE="$RESULT_DIR/${TASK_ID}.codex.result.json"
META_FILE="$RESULT_DIR/${TASK_ID}.codex.meta.json"

mkdir -p "$RESULT_DIR" "$ROOT/logs/workers" "$ROOT/.autonomy/worktrees"

if ! command -v codex >/dev/null 2>&1; then
  echo "codex CLI not found" >&2
  exit 127
fi

BASE_SHA="$(git rev-parse HEAD)"

if git worktree list --porcelain | grep -q "^worktree $WORKTREE_DIR$"; then
  chmod -R u+w "$WORKTREE_DIR" 2>/dev/null || true
  git worktree remove --force "$WORKTREE_DIR" 2>/dev/null || true
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git branch -D "$BRANCH" >/dev/null 2>&1 || true
fi

git worktree add --force -B "$BRANCH" "$WORKTREE_DIR" HEAD >/dev/null

if [ -d "$WORKTREE_DIR/.claude" ]; then
  chmod -R a-w "$WORKTREE_DIR/.claude" || true
fi
if [ -d "$WORKTREE_DIR/.autonomy" ]; then
  chmod -R a-w "$WORKTREE_DIR/.autonomy" || true
fi

TASK_PROMPT="$(cat "$PROMPT_PATH")"

read -r -d '' WORKER_PROMPT <<'EOF' || true
You are a GNAP worker running in an isolated git worktree.

Task ID: $TASK_ID
Worktree: $WORKTREE_DIR
Branch: $BRANCH

Rules:
- Work only inside this worktree.
- Never edit .claude/, .autonomy/, or .git/ paths.
- Change only the files required for this task.
- Run relevant validation commands if feasible.
- Stage and commit your changes before finishing.
- Use a commit message that starts with: worker($TASK_ID):
- Do not spawn subagents.
- Do not call another model CLI.

User task:
$TASK_PROMPT

At the end, return:
- a concise summary
- changed files
- commands you ran
- the final commit SHA
EOF

set +e
(
  cd "$WORKTREE_DIR"
  codex exec --json --full-auto "$WORKER_PROMPT" >"$RESULT_FILE" 2>"$LOG_FILE"
)
EXIT_CODE=$?
set -e

HEAD_SHA="$(git -C "$WORKTREE_DIR" rev-parse HEAD 2>/dev/null || true)"

cat >"$META_FILE" <<EOF
{
  "task_id": "$TASK_ID",
  "worker": "codex",
  "branch": "$BRANCH",
  "worktree": "$WORKTREE_DIR",
  "base_sha": "$BASE_SHA",
  "head_sha": "$HEAD_SHA",
  "exit_code": $EXIT_CODE,
  "result_file": "$RESULT_FILE",
  "log_file": "$LOG_FILE"
}
EOF

exit "$EXIT_CODE"
