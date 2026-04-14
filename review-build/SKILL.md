---
name: review-build
description: >
  Full-codebase post-build audit. Review the merged autonomous changes, verify architecture,
  security, correctness, and consistency, and produce a written review report without relying
  on any legacy .gnap paths.
user-invocable: true
disable-model-invocation: true
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Review Build

You are performing a **post-build audit** of the current codebase.

This skill is for:
- reviewing autonomous output after `/architect-loop`
- reviewing the whole codebase before release
- writing a formal audit report
- finding architectural drift, unsafe patterns, and quality regressions

This skill is **not** the main implementation loop.

## Read first

Read:

- `CLAUDE.md`
- `docs/SPECIFICATION.md`
- `docs/IMPLEMENTATION.md`
- `docs/TASKS.md`
- `.autonomy/state.json`
- `.autonomy/gates.json` if present

Do **not** look for `.gnap/` paths.  
This repo uses `.autonomy/` only.

## Review goals

Your review must cover:

1. **Correctness**
   - Does the code implement the documented behavior?
   - Are acceptance criteria clearly satisfied?
   - Are important edge cases handled?

2. **Architecture**
   - Do module boundaries match `docs/IMPLEMENTATION.md`?
   - Is there layer leakage?
   - Are there circular or suspicious dependencies?
   - Did autonomous work introduce inconsistent patterns?

3. **Security**
   - Input validation
   - injection risks
   - secret handling
   - unsafe shell/file operations
   - auth / access control mistakes
   - trust-boundary mistakes

4. **Consistency**
   - naming
   - imports
   - error handling
   - logging style
   - configuration strategy
   - testing style

5. **Performance and operability**
   - obviously wasteful I/O or loops
   - N+1 style issues
   - unnecessary rebuilds or repeated work
   - poor retry/timeouts in network code
   - missing operational safeguards

## Review flow

### Step 1 — Map the autonomous run

Use Git and `.autonomy/state.json` to understand what changed.

Useful commands:

```bash
git log --oneline --decorate --graph -n 30
git diff --stat HEAD~10..HEAD
git diff --name-only HEAD~10..HEAD
```

If the autonomous run is shorter or longer, adjust the commit window accordingly.

### Step 2 — Read the changed files

Read every changed file directly.

Do not rely only on `git diff --stat`.  
Use the file contents.

### Step 3 — Compare against the docs

For each significant change, ask:

- Does it match `docs/SPECIFICATION.md`?
- Does it match `docs/IMPLEMENTATION.md`?
- Does it obey `CLAUDE.md`?
- Does it complete the intended task from `docs/TASKS.md`?

### Step 4 — Run stack-aware validation

If `.autonomy/gates.json` exists, use its commands.

Otherwise infer reasonable read-only validation commands from the stack, such as:

- Node: `npm run lint`, `npm run build`, `npm test`
- Python: `ruff check .`, `python3 -m pytest`
- .NET: `dotnet build`, `dotnet test`
- Go: `go build ./...`, `go test ./...`
- Rust: `cargo build`, `cargo test`

Capture failures clearly.

### Step 5 — Write `docs/REVIEW_REPORT.md`

Create a structured report with these sections:

```md
# Review Report

## Scope
## What was reviewed
## Findings by severity
### Critical
### High
### Medium
### Low
## Architecture notes
## Security notes
## Test/build notes
## Recommended fixes
## Final verdict
```

Severity rules:

- **Critical** = must fix before release
- **High** = serious risk, should be fixed immediately
- **Medium** = meaningful quality or maintainability issue
- **Low** = polish or minor consistency issue

## Fix policy

Default behavior: **report, do not rewrite source code**.

You may write or edit:
- `docs/REVIEW_REPORT.md`
- other review notes under `docs/`

Do not edit application source unless the user explicitly asks for fixes after the audit.

## Final output

Your final response must include:

- the number of files reviewed
- the highest severity found
- whether build/test gates passed
- whether the repo is release-ready, conditionally ready, or not ready
- the path to `docs/REVIEW_REPORT.md`
