---
name: auto-build
description: >
  Interactive plan-to-runtime bootstrap. Gather requirements, write the project documents,
  derive the task queue, install hooks and worker wrappers, generate runtime state from tasks,
  and stop after setup so the human can invoke /architect-loop explicitly.
user-invocable: true
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - MultiEdit
  - Glob
  - Grep
---

# Auto Build

This skill has **two** responsibilities:

- **Phase A — Planning**: turn an idea into explicit implementation documents
- **Phase B — Runtime bootstrap**: install the autonomous build runtime in the project

This skill **does not** start the autonomous execution loop automatically.  
It ends after setup and tells the user to run `/architect-loop`.

## Non-negotiable rules

1. Create clear, reviewable documents first.
2. Generate a canonical machine-readable task queue.
3. Generate `.autonomy/state.json` **from** `.autonomy/tasks.json`.
4. Never create an empty placeholder state file.
5. Install hooks, settings, supervisor, and wrappers before the build loop starts.
6. Initialize Git before the first worker branch is created.
7. Stop after setup. The human must explicitly invoke `/architect-loop`.

## Output documents

Write these files during planning:

- `docs/SPECIFICATION.md`
- `docs/IMPLEMENTATION.md`
- `docs/TASKS.md`
- `CLAUDE.md`

Use `docs/` consistently.

## Phase A — Planning

### 1. Discovery
Interview the user until these are clear:

- product goal
- target users
- core workflows
- constraints
- stack preferences
- non-functional requirements
- deployment expectations
- testing expectations

### 2. Write `docs/SPECIFICATION.md`
It must cover:

- problem statement
- goals
- non-goals
- user flows
- functional requirements
- non-functional requirements
- external integrations
- success criteria

### 3. Write `docs/IMPLEMENTATION.md`
It must cover:

- chosen stack
- repo layout
- modules and boundaries
- data model
- API shape
- background jobs if any
- validation and error-handling patterns
- testing strategy
- build and run commands
- deployment approach if relevant

### 4. Write `CLAUDE.md`
This is the project operating contract for future sessions.

It must include:

- coding style
- naming conventions
- error handling rules
- testing expectations
- forbidden shortcuts
- architecture boundaries
- task acceptance expectations

### 5. Write `docs/TASKS.md`
Use a format that is easy to parse deterministically.

Required format:

```md
# Task Queue

## T001 - Task title
Summary: one short paragraph
Depends on: none
Acceptance:
- item 1
- item 2

## T002 - Task title
Summary: one short paragraph
Depends on: T001
Acceptance:
- item 1
```

Rules:

- Task IDs are mandatory and stable
- Use `T001`, `T002`, ...
- Dependencies are explicit
- Each task is small enough for one worker attempt
- Put architecture work before leaf implementation work
- Put tests close to the feature they validate

## Phase B — Runtime bootstrap

### 1. Create directories

Create:

- `.autonomy/`
- `.autonomy/prompts/`
- `.autonomy/results/`
- `.autonomy/worktrees/`
- `.claude/`
- `.claude/hooks/`
- `.claude/bin/`
- `logs/`
- `logs/workers/`

### 2. Install runtime files from the skill repo

Assume the installed skill lives at:

```bash
$HOME/.claude/skills/auto-build
```

Copy these files into the target project in this order:

- `$HOME/.claude/skills/auto-build/hooks/architect-no-direct-write.sh` → `.claude/hooks/architect-no-direct-write.sh`
- `$HOME/.claude/skills/auto-build/hooks/pre-bash-guard.sh` → `.claude/hooks/pre-bash-guard.sh`
- `$HOME/.claude/skills/auto-build/hooks/post-edit-lint.sh` → `.claude/hooks/post-edit-lint.sh`
- `$HOME/.claude/skills/auto-build/hooks/stop-guard.sh` → `.claude/hooks/stop-guard.sh`
- `$HOME/.claude/skills/auto-build/hooks/notify-telegram.sh` → `.claude/hooks/notify-telegram.sh`
- `$HOME/.claude/skills/auto-build/templates/autonomy-supervisor.sh` → `.claude/bin/autonomy-supervisor.sh`
- `$HOME/.claude/skills/auto-build/templates/bin/sonnet-worker.sh` → `.claude/bin/sonnet-worker.sh`
- `$HOME/.claude/skills/auto-build/templates/bin/codex-worker.sh` → `.claude/bin/codex-worker.sh`
- `$HOME/.claude/skills/auto-build/templates/bin/gemini-worker.sh` → `.claude/bin/gemini-worker.sh`

Mark scripts executable **before** installing the settings file:

```bash
chmod 755 .claude/hooks/*.sh .claude/bin/*.sh
```

Copy the settings file last:

- `$HOME/.claude/skills/auto-build/templates/settings.json` → `.claude/settings.json`

### 3. Parse `docs/TASKS.md` into `.autonomy/tasks.json`

The parsed structure must be deterministic and complete.

Required shape:

```json
{
  "version": 2,
  "generated_at": "2026-04-13T12:00:00Z",
  "source": "docs/TASKS.md",
  "tasks": [
    {
      "id": "T001",
      "title": "Task title",
      "summary": "One short paragraph",
      "dependencies": [],
      "acceptance_criteria": ["item 1", "item 2"]
    }
  ]
}
```

### 4. Derive `.autonomy/state.json` from `.autonomy/tasks.json`

Do **not** write a blank placeholder.

The state file must be derived by mapping every parsed task into an execution record.

Required shape:

```json
{
  "version": 2,
  "generated_at": "2026-04-13T12:00:00Z",
  "execution": {
    "status": "ready",
    "session_ref": null,
    "current_task_id": null,
    "started_at": null,
    "updated_at": "2026-04-13T12:00:00Z",
    "last_checkpoint_at": null
  },
  "stats": {
    "total": 10,
    "done": 0,
    "failed": 0,
    "in_progress": 0
  },
  "tasks": [
    {
      "id": "T001",
      "title": "Task title",
      "status": "pending",
      "dependencies": [],
      "attempt_count": 0,
      "worker": null,
      "branch": "worker/T001",
      "worktree": ".autonomy/worktrees/T001",
      "accepted_commit": null,
      "last_error": null,
      "last_summary_file": null,
      "last_result_file": null,
      "last_log_file": null
    }
  ]
}
```

### 5. Write `.autonomy/gates.json`

Detect the stack from the repo and write the gate file.

Examples:

#### Node / TypeScript
```json
{
  "stack": "node",
  "lint": ["npm run lint"],
  "build": ["npm run build"],
  "test": ["npm test"],
  "smoke": []
}
```

#### Python
```json
{
  "stack": "python",
  "lint": ["ruff check ."],
  "build": [],
  "test": ["python3 -m pytest"],
  "smoke": []
}
```

#### .NET
```json
{
  "stack": "dotnet",
  "lint": [],
  "build": ["dotnet build"],
  "test": ["dotnet test"],
  "smoke": []
}
```

#### Go
```json
{
  "stack": "go",
  "lint": [],
  "build": ["go build ./..."],
  "test": ["go test ./..."],
  "smoke": []
}
```

If the project has custom commands, prefer the commands documented in `docs/IMPLEMENTATION.md`.

### 6. Initialize Git

If the project is not already a Git repo:

```bash
git init
git add .
git commit -m "bootstrap: planning docs and autonomy runtime"
```

If the repo already exists, ensure the working tree is clean before declaring bootstrap complete.

### 7. Validate bootstrap

Before finishing, verify:

- `docs/SPECIFICATION.md` exists
- `docs/IMPLEMENTATION.md` exists
- `docs/TASKS.md` exists
- `CLAUDE.md` exists
- `.autonomy/tasks.json` exists and has at least one task
- `.autonomy/state.json` exists and `stats.total > 0`
- `.autonomy/state.json` has one state record per task
- `.autonomy/gates.json` exists
- `.claude/settings.json` exists
- `.claude/hooks/*.sh` exist
- `.claude/bin/sonnet-worker.sh` exists
- `.claude/bin/codex-worker.sh` exists
- `.claude/bin/gemini-worker.sh` exists
- `.claude/bin/autonomy-supervisor.sh` exists
- all scripts are executable

### 8. End state

At the end of this skill:

- `execution.status` must be `"ready"`
- `.autonomy/runtime.lock` must **not** exist yet
- `.autonomy/session_id` may be absent; the supervisor creates it when needed
- do **not** invoke `/architect-loop` automatically

## Final response to the user

When setup is complete, report:

- task count
- detected stack
- gate commands
- that the runtime is installed
- that the next command is `/architect-loop`

Do not say that autonomous build already started if it has not.
