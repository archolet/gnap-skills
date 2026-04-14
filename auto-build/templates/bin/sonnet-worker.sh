#!/usr/bin/env bash
# Claude Sonnet worker wrapper
# Contract:
#   .claude/bin/sonnet-worker.sh --task-id T001 --prompt-file .autonomy/prompts/T001.md

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
LOG_FILE="$ROOT/logs/workers/${TASK_ID}.sonnet.log"
RESULT_FILE="$RESULT_DIR/${TASK_ID}.sonnet.result.json"
META_FILE="$RESULT_DIR/${TASK_ID}.sonnet.meta.json"
SESSION_FILE="$RESULT_DIR/${TASK_ID}.sonnet.session"

mkdir -p "$RESULT_DIR" "$ROOT/logs/workers" "$ROOT/.autonomy/worktrees"

if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI not found" >&2
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

# Build worker prompt via temp file (safe interpolation without heredoc injection risk)
TASK_PROMPT="$(cat "$PROMPT_PATH")"
WORKER_PROMPT_FILE="$(mktemp "${TMPDIR:-/tmp}/gnap-worker-XXXXXX")"

printf '%s\n' "You are a GNAP worker running in an isolated git worktree." > "$WORKER_PROMPT_FILE"
printf '\n%s\n' "Task ID: ${TASK_ID}" >> "$WORKER_PROMPT_FILE"
printf '%s\n' "Worktree: ${WORKTREE_DIR}" >> "$WORKER_PROMPT_FILE"
printf '%s\n' "Branch: ${BRANCH}" >> "$WORKER_PROMPT_FILE"
printf '\n%s\n' "Rules:" >> "$WORKER_PROMPT_FILE"
printf '%s\n' "- Work only inside this worktree." >> "$WORKER_PROMPT_FILE"
printf '%s\n' "- Never edit .claude/, .autonomy/, or .git/ paths." >> "$WORKER_PROMPT_FILE"
printf '%s\n' "- Change only the files required for this task." >> "$WORKER_PROMPT_FILE"
printf '%s\n' "- Run relevant validation commands if feasible." >> "$WORKER_PROMPT_FILE"
printf '%s\n' "- Stage and commit your changes before finishing." >> "$WORKER_PROMPT_FILE"
printf '%s\n' "- Use a commit message that starts with: worker(${TASK_ID}):" >> "$WORKER_PROMPT_FILE"
printf '%s\n' "- Do not spawn subagents." >> "$WORKER_PROMPT_FILE"
printf '%s\n' "- Do not call another model CLI." >> "$WORKER_PROMPT_FILE"
printf '%s\n' "- If you change production code, you MUST write or update tests." >> "$WORKER_PROMPT_FILE"
printf '\n%s\n' "User task:" >> "$WORKER_PROMPT_FILE"
printf '%s\n' "${TASK_PROMPT}" >> "$WORKER_PROMPT_FILE"
printf '\n%s\n' "At the end, return:" >> "$WORKER_PROMPT_FILE"
printf '%s\n' "- a concise summary" >> "$WORKER_PROMPT_FILE"
printf '%s\n' "- changed files" >> "$WORKER_PROMPT_FILE"
printf '%s\n' "- commands you ran" >> "$WORKER_PROMPT_FILE"
printf '%s\n' "- the final commit SHA" >> "$WORKER_PROMPT_FILE"

WORKER_PROMPT="$(cat "$WORKER_PROMPT_FILE")"
rm -f "$WORKER_PROMPT_FILE"

set +e
(
  cd "$WORKTREE_DIR"
  env GNAP_ROLE=worker \
    claude -p "$WORKER_PROMPT" \
      --model claude-sonnet-4-6 \
      --output-format json \
      --max-turns 80 \
      --permission-mode dontAsk \
      --allowedTools "Read,Grep,Glob,Write,Edit,MultiEdit,Bash(git status *),Bash(git diff *),Bash(git add *),Bash(git commit *),Bash(git rev-parse *),Bash(ls *),Bash(cat *),Bash(find *),Bash(jq *),Bash(npm *),Bash(npx *),Bash(pnpm *),Bash(yarn *),Bash(bun *),Bash(python *),Bash(python3 *),Bash(pytest *),Bash(uv *),Bash(ruff *),Bash(mypy *),Bash(dotnet *),Bash(go *),Bash(cargo *),Bash(./gradlew *),Bash(gradle *),Bash(mvn *),Bash(cmake *),Bash(make *)" \
    >"$RESULT_FILE" 2>"$LOG_FILE"
)
EXIT_CODE=$?
set -e

SESSION_REF="$(jq -r '.session_id // .sessionId // empty' "$RESULT_FILE" 2>/dev/null || true)"
HEAD_SHA="$(git -C "$WORKTREE_DIR" rev-parse HEAD 2>/dev/null || true)"

if [ -n "$SESSION_REF" ]; then
  printf '%s\n' "$SESSION_REF" > "$SESSION_FILE"
fi

cat >"$META_FILE" <<EOF
{
  "task_id": "$TASK_ID",
  "worker": "sonnet",
  "branch": "$BRANCH",
  "worktree": "$WORKTREE_DIR",
  "base_sha": "$BASE_SHA",
  "head_sha": "$HEAD_SHA",
  "exit_code": $EXIT_CODE,
  "result_file": "$RESULT_FILE",
  "log_file": "$LOG_FILE",
  "session_file": "$SESSION_FILE"
}
EOF

exit "$EXIT_CODE"
