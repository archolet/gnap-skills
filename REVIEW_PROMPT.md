# Deep Analysis Request — V4.1

## Who You Are

You are a hostile external auditor. Your job is to break this system, find every flaw, and determine if this approach has any real-world value or if it's an overengineered illusion.

## The Repository

https://github.com/archolet/gnap-skills

Read every file. No exceptions. Start with VISION.md, then README.md, then every SKILL.md, every hook script, every wrapper script, every template, TESTING.md.

## What This System Claims To Do

1. You open a terminal, run Claude Code (Opus 4.6 1M context)
2. You type `/auto-build` — Claude interviews you about your project, generates SPECIFICATION.md, IMPLEMENTATION.md, TASKS.md, CLAUDE.md, installs hooks + wrappers + state files
3. You type `/architect-loop` — Claude becomes an "architect" that dispatches coding tasks to worker models (Sonnet, Codex GPT-5.4, Gemini) via fixed wrapper scripts
4. Each worker runs in an isolated git worktree
5. The architect reviews every diff, runs build/test gates, and only merges approved code via `git merge --ff-only`
6. The architect CANNOT write source code directly — a PreToolUse hook blocks it
7. Workers CANNOT modify control files (.claude/, .autonomy/) — chmod + hook enforcement
8. State is tracked in `.autonomy/state.json`, derived from `tasks.json` (never empty placeholder)
9. A supervisor script can restart Claude on crash
10. Rejection feedback is stored per-task so workers don't repeat mistakes
11. Control plane integrity is verified via sha256 hashes before each task
12. An append-only event ledger tracks every action

## History

This system went through 4 major review cycles with GPT-5.4 Pro. Each cycle found critical bugs:

**Review 1**: Path variables wrong, personal paths hardcoded, no disable-model-invocation
**Review 2**: GNAP dependency 404, TaskCompleted hook dead code, permissions incomplete
**Review 3**: "Do it YOURSELF" still in skill, python3 -c bypass, Agent tool bypass, empty state.json, supervisor session_id never created, review-build .gnap references
**Review 4** (GPT-5.4 wrote V4): Complete rewrite — wrappers, worktrees, role-based hooks

**During testing**: Two more bugs found — GNAP_ROLE env inherited by workers (blocked them), worktree chmod permission denied on cleanup

## What I Want You To Do

### 1. Architecture Critique

Is "Opus 1M as terminal architect + subprocess workers + hooks + worktrees" a viable approach? Or is it fundamentally flawed?

Specific concerns:
- Opus 1M has 1M tokens but sessions can idle-timeout after ~5 minutes
- Workers run as `claude -p` subprocesses — do project hooks apply to them?
- The architect's "enforcement" is hooks in `.claude/settings.json` — these are in the same trust boundary as the architect itself
- Git worktree isolation is file-level, not process-level — workers share the same user, same filesystem permissions

### 2. Security Audit

The system claims "the architect cannot write source code." Attack this claim:

- `architect-no-direct-write.sh` is 173 lines of bash regex. Find bypasses.
- `settings.json` has 33 allow rules and 30 deny rules. Find gaps.
- Workers run with `GNAP_ROLE=worker` env var. What if a worker modifies this?
- The integrity manifest uses sha256 hashes. Who verifies them? The architect — who could just skip the check.
- Control files are chmod readonly in worktrees. What if the worker runs `chmod u+w`?

### 3. State Management Audit

- `state.json` is "derived from tasks.json" — but is this enforced or just documented?
- The event ledger is "append-only" — but what prevents truncation or modification?
- `runtime.lock` exists while running — but what prevents two sessions from ignoring it?
- Checkpoint summaries go to `.autonomy/checkpoints/` — but what if context is already full when the checkpoint is needed?

### 4. Wrapper Script Audit

Read `sonnet-worker.sh`, `codex-worker.sh`, `gemini-worker.sh` line by line:

- The worker prompt is built inline with heredoc. Can the task prompt inject shell commands?
- `--allowedTools` is set per wrapper. Is the tool list appropriate or too permissive?
- Worker result is captured to a JSON file. What if the result is malformed?
- The wrapper runs `chmod -R a-w` on `.claude/` and `.autonomy/` in the worktree. Does this actually protect anything?
- Exit code handling: what happens on exit 130 (Ctrl+C), 137 (OOM kill), 124 (timeout)?

### 5. Skill Coherence Audit

- Does `auto-build/SKILL.md` actually produce everything `architect-loop/SKILL.md` expects?
- Are the JSON schemas between tasks.json, state.json, gates.json, and integrity.json consistent?
- Does the review checklist in architect-loop cover everything that could go wrong?
- Are there instructions that contradict each other across the three skills?

### 6. Real-World Viability

- This system was tested on a 13-task Python CLI project. Would it work on a 100-task React+Node+PostgreSQL project?
- The wrapper creates a new worktree per task. With 100 tasks, that's 100 worktrees. Git handles this?
- Workers run `claude -p` with `--max-turns 80`. What if a task needs more?
- The smoke test system depends on `gates.json`. What if the detected stack is wrong?
- Context management says "write checkpoint summaries." But who reads them on resume? Does the architect actually use them?

### 7. What's Missing?

What critical features does this system NOT have that it SHOULD have for real autonomous development?

Think about:
- Monitoring / observability beyond the event ledger
- Cost tracking (each claude -p call costs tokens)
- Rollback mechanism (what if merged code breaks something 5 tasks later?)
- Dependency management (what if a worker adds a vulnerable package?)
- Secret management (what if a worker hardcodes an API key?)
- Rate limiting (what if the system burns through subscription quota?)

### 8. Comparison

How does this compare to existing tools?
- Claude Code Agent Teams
- Codex Cloud Tasks
- Cursor Composer
- Devin
- OpenHands
- SWE-agent

Is this system solving a problem that's already solved better elsewhere? Or does it offer something unique?

### 9. Scores

Rate 1-10:
- Architectural coherence
- Security posture
- Production readiness
- Documentation quality
- Innovation / uniqueness
- Real-world viability

### 10. Final Verdict

Three possible verdicts:
- **VIABLE**: The approach is sound, issues are fixable, worth continuing
- **QUESTIONABLE**: Some value but fundamental concerns that may not be resolvable
- **ABANDON**: The approach is flawed at its core, no amount of hardening will make it work

Choose one and defend it with specific evidence from the repository.

## Rules For Your Analysis

1. Be specific — file names, line numbers, exact code
2. No "it depends" — commit to positions
3. Attack the strongest claims first — if "architect cannot write source" is false, say so clearly
4. Don't be impressed by documentation volume — judge by whether the code actually does what the docs say
5. Assume the system is running on a macOS machine with Claude Code Max subscription, Codex CLI, and Gemini CLI installed
6. The human is NOT monitoring the system during execution — it must be self-correcting or fail safely
