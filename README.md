# GNAP Skills — Autonomous Multi-Agent Development for Claude Code

Three Claude Code skills that turn Opus 4.6 1M into a software architect orchestrating multiple AI models. Includes enforcement hooks, session recovery, crash supervisor, and multi-stack support.

## Architecture

```
Human (strategic decisions, final approval)
  └── Opus 4.6 1M (architect — YOUR terminal session)
      ├── Claude Sonnet 4.6 (fast developer — claude -p subprocess)
      ├── Claude Opus 4.6 200K (strong developer — claude -p subprocess)
      ├── Codex GPT-5.4 xhigh (OpenAI developer — codex exec)
      └── Gemini 3.1 flash-lite (Google developer — gemini -p)
```

**Key principle**: Opus 1M is the orchestrator, NOT a separate daemon. It dispatches tasks to worker models, reviews every line of code with full 1M context, enforces build/test gates, and approves or rejects.

## Skills

### `/architect-loop` — The Core Orchestrator
Opus 1M reads the task list, dispatches to appropriate worker model, waits for completion, reviews code with 1M context, builds, tests, and approves or rejects.

**Features:**
- Hardened worker dispatch (--max-turns, --permission-mode dontAsk, granular --allowedTools)
- Build/test gate enforcement (TaskCompleted hook — exit 2 blocks completion)
- Destructive command blocking (PreToolUse hook)
- Auto-lint after edits (PostToolUse hook)
- Stop prevention while tasks pending (Stop hook)
- Session recovery from `.autonomy/state.json`
- Checkpoints every 5 tasks (app launch + smoke test)
- Remote monitoring via `--remote-control`
- Telegram notifications

### `/auto-build` — Plan + Build Pipeline
End-to-end project creation from empty folder to running code.

**Phases:**
- A: Interactive discovery → SPECIFICATION.md → IMPLEMENTATION.md → TASKS.md
- B: Runtime setup → hooks, settings.json, CLAUDE.md, .autonomy/ state
- C: Autonomous build → triggers `/architect-loop`

### `/review-build` — Post-Build Audit
Full codebase review after autonomous build. Security, performance, standards, architecture checks. Stack-agnostic with per-language tool integration.

## Installation

```bash
git clone https://github.com/archolet/gnap-skills.git
cd gnap-skills
bash scripts/install.sh
```

Or manually:
```bash
cp -r architect-loop auto-build review-build ~/.claude/skills/
```

## Quick Start

```bash
# New project from scratch
mkdir my-project && cd my-project
tmux new -s architect
caffeinate -dims &
claude --remote-control
> /auto-build
# ... interactive planning ...
# ... autonomous build starts ...
```

```bash
# Existing project with TASKS.md
cd my-project
claude --remote-control
> /architect-loop
```

## Requirements

### Required
- Claude Code v2.1+ with Opus 4.6 1M model (Max subscription)
- tmux (persistent terminal sessions)
- caffeinate (macOS — prevents sleep)
- jq (JSON processing in hooks)

### Optional (multi-model orchestration)
- Codex CLI (`npm install -g @openai/codex`) — OpenAI developer perspective
- Gemini CLI (`npm install -g @google/gemini-cli`) — Google developer perspective
- Chrome MCP extension — browser-based checkpoint testing
- Telegram Bot — remote notifications (`TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID` env vars)

### Notes
- Skills work with Claude models only (Sonnet + Opus 200K as workers)
- Codex and Gemini add multi-vendor perspective but are NOT required
- No external pip packages required — all orchestration is via Claude Code + hooks
- Windows: Use WSL2 for tmux/caffeinate; hooks use bash

## Enforcement Hooks

Unlike prompt-based instructions, hooks are **deterministic** — they ENFORCE rules rather than suggest them.

| Hook | Script | Action | Exit Code |
|------|--------|--------|-----------|
| PreToolUse | `pre-bash-guard.sh` | Block `rm -rf`, `sudo`, `git reset --hard` | 2 = BLOCK |
| PostToolUse | `post-edit-lint.sh` | Auto-lint Python/TS/C#/Go files | 0 (observe only) |
| TaskCompleted | `task-quality-gate.sh` | Build + test must pass | 2 = BLOCK completion |
| Stop | `stop-guard.sh` | Don't stop while tasks pending | 2 = CONTINUE |
| Notification | `notify-telegram.sh` | Send Telegram alerts | 0 |

### How hooks are installed
`/auto-build` Phase B copies hook scripts to your project's `.claude/hooks/` and generates `.claude/settings.json` with hook configuration. Hooks are project-specific and version-controlled.

## Worker Hardening

Worker `claude -p` calls use strict limits:

```bash
claude -p "$PROMPT" \
  --model claude-sonnet-4-6 \
  --output-format stream-json \
  --max-turns 80 \
  --permission-mode dontAsk \
  --allowedTools "Read,Grep,Glob,Edit,Write,Bash(git diff *),Bash(npm test *),..."
```

- `--max-turns 80` — prevent infinite loops
- `--permission-mode dontAsk` — deny instead of hang on permission requests
- `--allowedTools` — granular: `Bash(git diff *)` not just `Bash`
- `--output-format stream-json` — parent can monitor worker events in real-time

## Session Recovery

State is persisted to `.autonomy/state.json` after every task:

```json
{
  "current_task_index": 5,
  "tasks": [
    {"id": "T001", "status": "done", "commit_sha": "abc123", "build_result": "pass"}
  ],
  "stats": {"done": 5, "total": 35}
}
```

If Claude Code crashes and restarts, `/architect-loop` reads this file and resumes from the last completed task.

## Crash Recovery (Supervisor)

For unattended operation:

```bash
tmux new -s architect
bash auto-build/templates/autonomy-supervisor.sh ~/Desktop/my-project
```

The supervisor:
- Wraps Claude Code with `caffeinate`
- Auto-restarts on crash (up to 5 times)
- Checks `.autonomy/state.json` for progress
- Sends Telegram alerts on restart/completion
- Exits when all tasks are done

## Remote Monitoring

```bash
claude --remote-control
```

Connect from phone or browser via the URL Claude Code provides. Monitor task progress without sitting at the desk.

## Autonomy Levels

| Level | Description | Requirements |
|-------|-------------|--------------|
| **High** | Works reliably with periodic human checks | Skills + hooks installed |
| **Session-scoped** | Unattended while Claude Code session lives | + tmux + caffeinate |
| **Controlled full** | Survives crashes, resumes automatically | + supervisor + state recovery |

See [TESTING.md](TESTING.md) for the full acceptance test matrix.

## Multi-Stack Support

Hooks auto-detect project stack:

| Stack | Build | Test | Lint |
|-------|-------|------|------|
| Node/TypeScript | `npm run build` | `npm test` | prettier |
| Python | — | `pytest` | ruff |
| .NET | `dotnet build` | `dotnet test` | dotnet format |
| Go | `go build ./...` | `go test ./...` | gofmt |
| Rust | `cargo build` | `cargo test` | — |

## File Structure

```
gnap-skills/
├── README.md                          # This file
├── TESTING.md                         # Acceptance test matrix
├── architect-loop/
│   └── SKILL.md                       # Core orchestrator skill
├── auto-build/
│   ├── SKILL.md                       # Plan + build pipeline
│   ├── hooks/                         # Enforcement hook scripts
│   │   ├── pre-bash-guard.sh          # Block destructive commands
│   │   ├── post-edit-lint.sh          # Auto-lint after edits
│   │   ├── task-quality-gate.sh       # Build+test gate
│   │   ├── stop-guard.sh             # Prevent premature stop
│   │   └── notify-telegram.sh        # Telegram notifications
│   ├── templates/                     # Project bootstrap templates
│   │   ├── settings.json             # Hook configuration
│   │   ├── detect-stack.sh           # Stack auto-detection
│   │   └── autonomy-supervisor.sh    # Crash recovery supervisor
│   └── references/                    # Planning guides (8 files)
├── review-build/
│   └── SKILL.md                       # Post-build audit skill
└── scripts/
    └── install.sh                     # One-command installation
```

## License

MIT
