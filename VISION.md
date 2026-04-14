# GNAP Skills — Vision

## The goal

Build a practical autonomous development loop where:

- the human stays responsible for strategy
- Claude Opus 1M stays in the terminal as the architect
- implementation work is delegated to smaller or alternate workers
- every accepted code change passes through an explicit review and gate step

This is **not** a claim that one prompt turns Claude Code into a safe daemon.  
It is a claim that a careful runtime model can make autonomous development **much more controlled**.

## The current architectural stance

Earlier versions leaned too heavily on prompt instructions and repository hooks.

That is not enough.

The design in this repo now assumes:

1. **Prompts are guidance**
2. **Hooks are defense-in-depth**
3. **The real operational boundary is the per-task worktree**
4. **The architect’s worker dispatch surface must be fixed and narrow**

That is why the current system uses:

- a canonical task queue
- a canonical mutable state file
- fixed worker wrappers
- isolated git worktrees
- explicit integration through fast-forward merge only

## The runtime roles

### Human
Responsible for:

- product direction
- approvals at planning time
- conflict resolution when the docs are ambiguous
- handling blocked tasks or strategic changes

### Architect (Opus 1M)
Responsible for:

- reading the full plan
- selecting the next task
- choosing the worker
- reviewing the worker result
- running gates
- accepting or rejecting the branch
- maintaining execution state

The architect is **not** supposed to author source code directly in the main checkout.

### Workers
Workers are interchangeable implementation engines.

Current wrappers target:

- Claude Sonnet
- Codex CLI
- Gemini CLI

A worker receives:

- one task
- one prompt file
- one isolated worktree
- one completion contract

A worker should return:

- code changes committed on its worker branch
- a concise summary
- enough evidence for the architect to review the attempt

## The three phases

### Phase A — Planning
The user and Claude collaborate on:

- `docs/SPECIFICATION.md`
- `docs/IMPLEMENTATION.md`
- `docs/TASKS.md`
- `CLAUDE.md`

This phase is interactive and explicit.

### Phase B — Runtime bootstrap
The runtime is installed into the target project:

- `.claude/hooks/*`
- `.claude/settings.json`
- `.claude/bin/*.sh`
- `.autonomy/tasks.json`
- `.autonomy/state.json`
- `.autonomy/gates.json`

Important principle:

- `state.json` is **derived from** `tasks.json`
- it is not a blank placeholder

The runtime ends this phase in:

- `execution.status = "ready"`

It does **not** auto-start the build loop.

### Phase C — Architect loop
The user explicitly invokes `/architect-loop`.

For each task, the architect:

1. selects the next eligible task
2. writes a task prompt file
3. dispatches one wrapper
4. reviews the worker branch
5. runs gates in the worker worktree
6. accepts or rejects the attempt
7. updates state

## Why wrappers matter

A raw call like `claude -p ...` gives too much freedom to the architect session.

A wrapper reduces that freedom.

The wrapper decides:

- how the worktree is created
- which model command is used
- which fixed flags are used
- where results are written
- what arguments are accepted

This is why the architect is required to call:

- `.claude/bin/sonnet-worker.sh`
- `.claude/bin/codex-worker.sh`
- `.claude/bin/gemini-worker.sh`

and nothing else.

## Why worktrees matter

Hooks can help tell the architect what it should not do.

But a direct source-write hook inside the same trust boundary is not enough on its own.

A separate git worktree gives the system a more meaningful boundary:

- worker changes land away from the main checkout
- the main checkout remains unchanged until acceptance
- the architect can review the branch before integration
- bad attempts can be discarded without patching the main tree

This is the key shift in the design.

## Why the architect still matters

The value of Opus 1M here is not “type all the code”.

The value is:

- seeing the whole project
- enforcing consistency across tasks
- comparing worker output against the docs
- holding the build/test gate
- integrating only what passes

A smaller worker may generate code faster.  
The architect keeps the overall system coherent.

## State and recovery

The system tracks its runtime through:

- `.autonomy/tasks.json` — canonical task graph
- `.autonomy/state.json` — mutable execution state
- `.autonomy/gates.json` — gate commands
- `.autonomy/runtime.lock` — active-run marker
- `.autonomy/session_id` — resumable session reference

Recovery is intentionally modest:

- the supervisor can relaunch a named Claude session
- the architect can resume from state
- task completion and attempt history survive Claude exits

What this does **not** mean:

- perfect crash-proofing
- zero lost context in every edge case
- daemon-grade orchestration on every platform

## What is fixed in this version

This version specifically removes or addresses the major earlier flaws:

- no `Agent` tool in the architect skill
- no “do it yourself” carve-out for simple coding tasks
- no raw `claude -p *` allowance in project settings
- no blank `state.json`
- no supervisor dependency on a never-created session identifier
- no brittle heartbeat loop dependency
- no legacy `.gnap/` path in review flow
- hook logic closes common Bash write bypasses such as:
  - `python3 -c`
  - `sed -i`
  - `perl -pi`
  - `git apply`
  - `cp`
  - `mv`

## What remains intentionally limited

This repo is still an engineering tool, not a universal autonomy platform.

Known limits:

1. **External CLI variability**
   - Codex and Gemini behavior can differ by version
   - Their wrappers are useful, but less deterministic than Claude-native flows

2. **Stack-specific gate quality**
   - Good defaults are possible
   - Perfect gate inference across every stack is unrealistic

3. **Human escalation is real**
   - ambiguous architecture decisions still require a person
   - repeated failed attempts should stop, not churn forever

4. **Hooks are not a sufficient boundary by themselves**
   - they reinforce behavior
   - they do not replace proper isolation

5. **Supervisor is operational glue, not a scheduler**
   - it can relaunch a named session
   - it does not magically inject new intent into an unopened project

## What this is

This is a **controlled architect-led autonomous development runtime** with:

- explicit planning
- explicit task state
- narrow worker dispatch
- worktree isolation
- explicit review gates

## What this is not

- not a replacement for human technical leadership
- not proof that unattended coding is solved
- not a secure sandbox for arbitrary external CLIs
- not a production deployment system
- not a background daemon that makes strategic decisions for you

## Standard of success

A successful run looks like this:

- planning docs are clear
- tasks are explicit
- state is recoverable
- the architect never bypasses the worker path
- workers stay isolated per task
- build and test gates are enforced before integration
- the human can inspect progress and intervene when the docs stop being sufficient

That is the level of autonomy this repo is trying to achieve.
