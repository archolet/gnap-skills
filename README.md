# GNAP Skills

Multi-stage Claude Code skills for running an **architect-led autonomous build loop** with explicit runtime controls.

The central idea is simple:

- **Opus 1M stays in your terminal as the architect**
- the architect **does not write application source directly**
- the architect dispatches one task at a time to a **fixed worker wrapper**
- each worker runs in an **isolated git worktree**
- the architect reviews the worker branch, runs gates, and only then integrates it

This repo contains three skills:

- `/auto-build` — planning + runtime bootstrap
- `/architect-loop` — task dispatch, review, gates, integration
- `/review-build` — post-build audit

## What changed in this design

This version is intentionally stricter than earlier iterations.

### The old weak points
Earlier versions had several structural problems:

- raw `claude -p *` was allowed
- `Agent` was still available as a bypass path
- `state.json` could be created empty
- stop protection depended on that empty state file
- the supervisor expected a session identifier that was never created
- a brittle background heartbeat required permissions that did not actually match
- review flow still referenced legacy `.gnap/` paths
- hooks were treated like the main boundary even though the actual hardening needed stronger isolation

### The current design
This version changes the model:

- **Wrappers are mandatory** for worker dispatch
- **Raw worker CLIs are denied** in project permissions
- **Agent/subagent use is denied**
- **State is derived from tasks**, never written as an empty placeholder
- **The supervisor creates and reuses a resumable session reference**
- **No background heartbeat loops**
- **Review flow uses `.autonomy/` only**
- **Worktree isolation is the primary boundary**
- **Hooks are defense-in-depth, not the only guardrail**

## Architecture

```text
Human
└── Opus 1M (architect, main Claude Code session)
    ├── reads docs + task/state/gate files
    ├── dispatches through fixed wrappers only
    ├── reviews worker branches
    ├── runs gates in worker worktrees
    └── merges only approved worker branches with --ff-only

Worker wrappers
├── .claude/bin/sonnet-worker.sh   -> claude -p (fixed flags)
├── .claude/bin/codex-worker.sh    -> codex exec (fixed flags)
└── .claude/bin/gemini-worker.sh   -> gemini -p (fixed flags)

Runtime data
├── .autonomy/tasks.json
├── .autonomy/state.json
├── .autonomy/gates.json
├── .autonomy/runtime.lock
└── .autonomy/session_id
```

## Core principles

1. **The architect is an orchestrator**
   - It selects tasks, reviews diffs, and enforces gates
   - It does not directly author source files in the main checkout

2. **Workers operate in isolated git worktrees**
   - One task, one worktree, one worker attempt
   - Main checkout stays clean until the architect accepts the branch

3. **Integration is narrow**
   - No `git apply`
   - No patch injection into the main checkout
   - Only `git merge --ff-only worker/<task-id>`

4. **State is explicit**
   - task queue: `.autonomy/tasks.json`
   - live execution state: `.autonomy/state.json`
   - gates: `.autonomy/gates.json`

5. **Hooks are not magic**
   - Hooks help enforce architect behavior
   - The primary protection is the wrapper + worktree model
   - Optional Claude Code sandboxing protects the main Bash session where available

## Skills

### `/auto-build`
Use this first in a new or empty project.

It does:

- discovery and planning
- writes:
  - `docs/SPECIFICATION.md`
  - `docs/IMPLEMENTATION.md`
  - `docs/TASKS.md`
  - `CLAUDE.md`
- installs:
  - `.claude/hooks/*`
  - `.claude/settings.json`
  - `.claude/bin/*.sh`
- generates:
  - `.autonomy/tasks.json`
  - `.autonomy/state.json`
  - `.autonomy/gates.json`

It stops after setup and tells you to run `/architect-loop`.

### `/architect-loop`
This is the runtime orchestrator.

It does:

- choose the next eligible task
- create a prompt file under `.autonomy/prompts/`
- dispatch to one wrapper
- review the worker branch
- run lint/build/test gates in the worker worktree
- accept with `git merge --ff-only`
- persist state after every transition

### `/review-build`
Use this after autonomous implementation is complete.

It does:

- read the docs and runtime state
- inspect recent diffs and changed files
- run validation commands
- write `docs/REVIEW_REPORT.md`

## Repository layout

```text
gnap-skills/
├── README.md
├── VISION.md
├── TESTING.md
├── REVIEW_PROMPT.md
├── architect-loop/
│   └── SKILL.md
├── auto-build/
│   ├── SKILL.md
│   ├── hooks/
│   │   ├── architect-no-direct-write.sh
│   │   ├── pre-bash-guard.sh
│   │   ├── post-edit-lint.sh
│   │   ├── stop-guard.sh
│   │   └── notify-telegram.sh
│   └── templates/
│       ├── settings.json
│       ├── autonomy-supervisor.sh
│       └── bin/
│           ├── sonnet-worker.sh
│           ├── codex-worker.sh
│           └── gemini-worker.sh
└── review-build/
    └── SKILL.md
```

## Installation

```bash
git clone https://github.com/archolet/gnap-skills.git
cd gnap-skills
bash scripts/install.sh
```

Or copy the three skills manually into `~/.claude/skills/`.

## Typical workflow

### 1. Bootstrap a project
```bash
mkdir my-project
cd my-project
claude
/auto-build
```

At the end of `/auto-build`, the project should contain:

- docs
- runtime state
- hooks
- worker wrappers

### 2. Start the architect loop
```bash
claude
/architect-loop
```

### 3. Optional supervisor
For unattended recovery of an already-started autonomous run:

```bash
bash .claude/bin/autonomy-supervisor.sh .
```

Important nuance:

- the supervisor creates a named/resumable session reference in `.autonomy/session_id`
- the first autonomous run still needs the architect session to be started intentionally
- once the runtime is active, the supervisor can relaunch the named session if Claude exits unexpectedly

### 4. Run a post-build audit
```bash
claude
/review-build
```

## Worker wrappers

The architect never runs raw worker CLIs directly.

Allowed dispatch surface:

```bash
.claude/bin/sonnet-worker.sh --task-id T001 --prompt-file .autonomy/prompts/T001.md
.claude/bin/codex-worker.sh --task-id T001 --prompt-file .autonomy/prompts/T001.md
.claude/bin/gemini-worker.sh --task-id T001 --prompt-file .autonomy/prompts/T001.md
```

### Why wrappers exist
They enforce a fixed contract:

- create/recreate the task worktree
- run the worker in that worktree
- keep control files out of scope
- capture results under `.autonomy/results/`
- reject unsupported passthrough flags
- keep the architect from widening worker permissions ad hoc

## Security model

### What this system does claim
- the architect cannot directly write source in normal operation
- workers are isolated per task in dedicated git worktrees
- raw worker CLI calls are blocked in the main project settings
- subagents are denied
- runtime control files are treated as immutable during a build
- build/test acceptance happens before integration

### What this system does not claim
- perfect containment across every external CLI
- protection equivalent to an OS-level mandatory access control system
- zero-risk unattended operation on every stack
- that hooks alone are a sufficient security boundary

## State files

### `.autonomy/tasks.json`
Canonical parsed task queue.

### `.autonomy/state.json`
Live execution state. Generated from `tasks.json`, not from an empty template.

### `.autonomy/gates.json`
Stack-aware lint/build/test/smoke commands.

### `.autonomy/runtime.lock`
Present only while the autonomous loop is actively running.

### `.autonomy/session_id`
A resumable session reference created by the supervisor.

## Requirements

### Required
- Claude Code
- `jq`
- `git`
- Bash
- a clean Git worktree model

### Optional
- Codex CLI
- Gemini CLI
- `caffeinate` on macOS
- Telegram bot credentials for notifications

## Current posture

This repo is aimed at **controlled autonomous development**, not blind “run forever” autonomy.

The design is intentionally conservative:

- explicit docs first
- explicit task graph
- explicit runtime state
- explicit wrapper surface
- explicit review and gate steps

Read `VISION.md` for the design rationale and `TESTING.md` for the validation matrix.
