# GNAP Skills — Vision & Architecture

## What Are We Building?

An autonomous software development system where **you open a terminal, describe a project, and AI builds it** — with multiple AI models from different vendors working together under a single architect.

The core idea: **Claude Opus 4.6 (1M context)** sits in your terminal as the **software architect**. It doesn't write code. Instead, it:

1. Plans the project (specs, implementation docs, task breakdown)
2. Dispatches coding tasks to **worker models** (Sonnet, Codex GPT-5.4, Gemini)
3. Reviews every line of code the workers produce (with full 1M context)
4. Runs build + test — refuses to accept broken code
5. Commits only what passes quality gates
6. Moves to the next task until the project is complete

## Why Multiple Models?

No single AI model is perfect. Each has blind spots:

- **Claude Sonnet 4.6** — Fast, good at boilerplate, but can be shallow on complex logic
- **Claude Opus 4.6 200K** — Strong reasoning, but limited context compared to 1M
- **Codex GPT-5.4** — Different vendor, different training, catches things Claude misses
- **Gemini 3.1** — Third perspective, good at operational/infrastructure concerns

The architect (Opus 1M) sees ALL their code. It catches inconsistencies between what different models wrote. It standardizes naming, error handling, and patterns across the entire codebase.

## Why Not Just Let One Model Do Everything?

We tried. In our first test, Opus 1M ignored the delegation instructions and wrote all 14 tasks itself. Result: 60 tests passed, code worked. But:

- Only one perspective — no cross-model review
- All quota consumed by one model
- In real projects (200+ files), context fills up
- One model's biases become the whole codebase's biases

## The Three-Phase Flow

```
Phase A: Planning (interactive, human involved)
  ├── /auto-build skill triggers
  ├── Interactive Q&A about the project
  ├── SPECIFICATION.md generated
  ├── IMPLEMENTATION.md generated
  ├── TASKS.md generated (ordered, with dependencies)
  ├── CLAUDE.md generated (project rules)
  └── Human approves each document

Phase B: Runtime Setup (automatic)
  ├── TASKS.md parsed into .autonomy/tasks.json
  ├── Enforcement hooks installed (.claude/hooks/)
  ├── settings.json configured
  ├── Git initialized
  └── "Run /architect-loop to start" — STOPS HERE

Phase C: Autonomous Build (human triggers /architect-loop)
  ├── Opus 1M reads task queue
  ├── Selects appropriate worker model for each task
  ├── Dispatches via claude -p / codex exec / gemini -p
  ├── CANNOT write source code directly (hook blocks it)
  ├── Reviews every diff with 1M context
  ├── Runs build + test (MUST pass before commit)
  ├── Every 5 tasks: launches app + smoke test
  ├── Session state saved to .autonomy/state.json
  └── Telegram notifications for progress
```

## Enforcement, Not Suggestions

Previous versions used prompt-level instructions: "please run build after each task." The model could ignore them — and did.

Current version uses **deterministic hooks**:

| What | How | Enforcement |
|------|-----|-------------|
| Architect can't write source code | `architect-no-direct-write.sh` | PreToolUse exit 2 = BLOCKED |
| No destructive commands | `pre-bash-guard.sh` | PreToolUse exit 2 = BLOCKED |
| Auto-lint after edits | `post-edit-lint.sh` | PostToolUse (automatic) |
| Can't stop with pending tasks | `stop-guard.sh` | Stop exit 2 = CONTINUE |
| Build gate | architect-loop Step 6c | Architect explicitly runs build+test |

The architect **physically cannot** write to `src/` or `tests/` directories. If it tries, the hook blocks it and says: "Dispatch to a worker model."

## Session Recovery

If Claude Code crashes:
- `.autonomy/state.json` records which tasks are done
- On restart, `/architect-loop` reads the state file
- Asks: "Previous session: 5/14 done. Resume?"
- Continues from where it left off

## Autonomy Levels

| Level | What it means | Requirements |
|-------|---------------|--------------|
| **High** | Works with periodic human checks | Skills + hooks installed |
| **Session-scoped** | Unattended while session lives | + tmux + caffeinate |
| **Controlled full** | Survives crashes, auto-restarts | + supervisor + state recovery |

We don't claim "fully autonomous, zero problems." We claim: **high autonomy with deterministic safety rails, multi-model perspective, and measurable quality gates.**

## What This Is NOT

- **Not a replacement for human architects** — The human makes strategic decisions
- **Not production-ready** — It's a development tool, not a deployment system
- **Not magic** — Complex projects still need human judgment at key points
- **Not guaranteed to work on every stack** — Tested on Python, .NET; others need validation
- **Not a daemon** — The architect IS the Claude terminal session, not a background process

## Known Limitations

1. **Idle timeout** — Claude Code may disconnect after ~5 minutes of no input (tmux helps)
2. **Context accumulation** — 1M tokens is a lot but can fill on very large projects
3. **Worker quality varies** — Some models produce better code for certain languages
4. **No true crash-proof** — Supervisor restarts, but some state may be lost
5. **Single machine** — Runs on one macOS machine, not distributed
