#!/usr/bin/env bash
# PreToolUse hook:
# - Architect role cannot write application source directly
# - Worker role may edit source inside its isolated worktree
# - Runtime control files are immutable in both roles
# - Raw worker CLI calls are forbidden; wrappers are mandatory

set -u

INPUT="$(cat)"
TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
ROLE="${GNAP_ROLE:-architect}"

[ -z "$TOOL" ] && exit 0

normalize_path() {
  local p="${1:-}"
  p="${p#./}"
  printf '%s' "$p"
}

is_control_path() {
  local p
  p="$(normalize_path "${1:-}")"
  case "$p" in
    .claude/settings.json|.claude/hooks/*|.claude/bin/*)
      return 0
      ;;
  esac
  return 1
}

is_allowed_non_source_path() {
  local p
  p="$(normalize_path "${1:-}")"
  case "$p" in
    .autonomy/*|docs/*|logs/*|README.md|CLAUDE.md|LICENSE|CONTRIBUTING.md|CHANGELOG.md|*.md|*.txt|*.json|*.yaml|*.yml|*.toml|*.lock|.gitignore|.editorconfig|Makefile|Procfile)
      return 0
      ;;
  esac
  return 1
}

is_source_path() {
  local p
  p="$(normalize_path "${1:-}")"
  case "$p" in
    src/*|test/*|tests/*|lib/*|app/*|cmd/*|internal/*|pkg/*|migrations/*|alembic/*|db/migrations/*|services/*|components/*|modules/*|infra/*|terraform/*|deploy/*|k8s/*|charts/*|helm/*|.github/workflows/*|Dockerfile|docker-compose*|package.json|package-lock.json|pnpm-lock.yaml|yarn.lock|bun.lockb|tsconfig*.json|vite.config.*|webpack.config.*|jest.config.*|vitest.config.*|pyproject.toml|requirements*.txt|Pipfile|Pipfile.lock|poetry.lock|go.mod|go.sum|Cargo.toml|Cargo.lock|*.csproj|*.sln|*.props|*.targets|*.tf|*.tfvars|*.py|*.pyi|*.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.cs|*.go|*.rs|*.java|*.kt|*.rb|*.php|*.swift|*.scala|*.dart|*.lua|*.sql)
      return 0
      ;;
  esac
  return 1
}

contains_source_target() {
  local s="${1:-}"
  printf '%s' "$s" | grep -qE '(^|[[:space:]"'"'"'`])(\./)?(src/|test/|tests/|lib/|app/|cmd/|internal/|pkg/|migrations/|alembic/|db/migrations/|services/|components/|modules/|infra/|terraform/|deploy/|k8s/|charts/|helm/|\.github/workflows/|Dockerfile|docker-compose|package\.json|package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb|tsconfig|vite\.config|webpack\.config|jest\.config|vitest\.config|pyproject\.toml|requirements|Pipfile|poetry\.lock|go\.mod|go\.sum|Cargo\.toml|Cargo\.lock|[^[:space:]"'"'"']+\.(tf|tfvars|py|pyi|ts|tsx|js|jsx|mjs|cjs|cs|go|rs|java|kt|rb|php|swift|scala|dart|lua|sql))([[:space:]"'"'"'`]|$)'
}

contains_control_target() {
  local s="${1:-}"
  printf '%s' "$s" | grep -qE '(^|[[:space:]"'"'"'`])(\./)?(\.claude/settings\.json|\.claude/hooks/|\.claude/bin/)([[:space:]"'"'"'`]|$)'
}

is_raw_worker_cli() {
  local s="${1:-}"
  printf '%s' "$s" | grep -qE '(^|[;&[:space:]])(claude[[:space:]]+-p|codex[[:space:]]+exec|gemini([[:space:]]+-p|[[:space:]]+--prompt))([[:space:]]|$)'
}

is_wrapper_invocation() {
  local s="${1:-}"
  printf '%s' "$s" | grep -qE '^(bash[[:space:]]+)?\.claude/bin/(sonnet-worker|codex-worker|gemini-worker)\.sh([[:space:]]|$)'
}

is_forbidden_git_write() {
  local s="${1:-}"

  # Allow the one integration path used by architect-loop.
  if printf '%s' "$s" | grep -qE '(^|[;&[:space:]])git[[:space:]]+merge[[:space:]]+--ff-only[[:space:]]+worker/'; then
    return 1
  fi

  printf '%s' "$s" | grep -qE '(^|[;&[:space:]])git[[:space:]]+(apply|am|checkout|switch|restore|cherry-pick|rebase|commit[[:space:]]+--amend|merge)([[:space:]]|$)'
}

is_redirection_write() {
  local s="${1:-}"
  printf '%s' "$s" | grep -qE '(^|[;&[:space:]])(tee|cat[[:space:]]+<<|printf[[:space:]].*>|echo[[:space:]].*>|[^<]>|>>)([[:space:]]|$)'
}

is_inline_mutator() {
  local s="${1:-}"
  printf '%s' "$s" | grep -qE '(write_text|write_bytes|\.write\(|writeFile|writeFileSync|appendFile|appendFileSync|copyFile|copyFileSync|renameSync|rename\(|replace\(|shutil\.copy|shutil\.move|copy2\(|copytree\(|move\(|open\([^)]*,[[:space:]]*["'"'"'](w|a|x|r\+|w\+|a\+)["'"'"'])'
}

is_patch_style_write() {
  local s="${1:-}"
  printf '%s' "$s" | grep -qE '(^|[;&[:space:]])(sed[[:space:]]+-i|perl[[:space:]]+-pi|ruby[[:space:]]+-pi|patch([[:space:]]|$)|cp([[:space:]]|$)|mv([[:space:]]|$)|install([[:space:]]|$)|rsync([[:space:]]|$)|tar[[:space:]].*-C[[:space:]])'
}

block() {
  printf '%s\n' "$1" >&2
  exit 2
}

# Hard deny: subagents are not part of this architecture.
if [ "$TOOL" = "Agent" ]; then
  block "ARCHITECT MODE: Agent/subagent spawning is forbidden. Use a fixed worker wrapper instead."
fi

# Protect runtime control files for both architect and worker roles.
if [ -n "$FILE" ] && is_control_path "$FILE"; then
  block "RUNTIME CONTROLS ARE IMMUTABLE: Do not edit .claude/settings.json, .claude/hooks/, or .claude/bin/ during a build."
fi

if [ "$TOOL" = "Bash" ] && [ -n "$CMD" ] && contains_control_target "$CMD" && \
  { is_redirection_write "$CMD" || is_patch_style_write "$CMD" || is_inline_mutator "$CMD" || is_forbidden_git_write "$CMD"; }; then
  block "RUNTIME CONTROLS ARE IMMUTABLE: Bash may not modify .claude/settings.json, .claude/hooks/, or .claude/bin/."
fi

# Workers are allowed to edit source in their isolated worktrees, but not control files.
if [ "$ROLE" = "worker" ]; then
  exit 0
fi

# Architect cannot use raw worker CLIs. Wrappers only.
if [ "$TOOL" = "Bash" ] && [ -n "$CMD" ]; then
  if is_wrapper_invocation "$CMD"; then
    exit 0
  fi

  if is_raw_worker_cli "$CMD"; then
    block "ARCHITECT MODE: Do not call raw worker CLIs directly. Use .claude/bin/sonnet-worker.sh, .claude/bin/codex-worker.sh, or .claude/bin/gemini-worker.sh."
  fi

  if printf '%s' "$CMD" | grep -qE '(^|[;&[:space:]])git[[:space:]]+worktree[[:space:]]+add([[:space:]]|$)'; then
    block "ARCHITECT MODE: Worktrees are created only by the fixed wrapper scripts."
  fi
fi

# File tool writes: block protected project files first, then allow docs/state files.
if [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ] || [ "$TOOL" = "MultiEdit" ]; then
  if [ -n "$FILE" ] && is_source_path "$FILE"; then
    block "ARCHITECT MODE: You cannot write application or build source directly. Dispatch the task to a worker wrapper."
  fi

  if [ -n "$FILE" ] && is_allowed_non_source_path "$FILE"; then
    exit 0
  fi
fi

# Bash writes that target source in the main checkout are forbidden.
if [ "$TOOL" = "Bash" ] && [ -n "$CMD" ]; then
  if is_forbidden_git_write "$CMD" && contains_source_target "$CMD"; then
    block "ARCHITECT MODE: Source integration must go through reviewed worker branches and git merge --ff-only. Direct git patch/write operations are forbidden."
  fi

  if is_patch_style_write "$CMD" && contains_source_target "$CMD"; then
    block "ARCHITECT MODE: Patch-style source writes via Bash are forbidden in the main checkout. Use a worker wrapper."
  fi

  if is_redirection_write "$CMD" && contains_source_target "$CMD"; then
    block "ARCHITECT MODE: Redirecting output into source files is forbidden. Use a worker wrapper."
  fi

  if is_inline_mutator "$CMD" && contains_source_target "$CMD"; then
    block "ARCHITECT MODE: Inline scripting that writes source (python3 -c/-, node -e, perl, etc.) is forbidden. Use a worker wrapper."
  fi
fi

exit 0
