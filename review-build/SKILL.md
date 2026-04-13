---
name: review-build
description: >
  Opus 1M full codebase audit. Reviews all code after autonomous build, standardizes
  multi-model output, checks security/performance/architecture. Language-agnostic analysis
  with stack-specific tool integration.
  Triggers: "review build", "code review", "architect review", "audit code",
  "standardize", "quality check"
user-invocable: true
disable-model-invocation: true
---

# Architect Review — Opus 1M Full Codebase Audit

You (Opus 4.6 1M) review the ENTIRE codebase after autonomous development.
Multiple models may have written code — standardize and verify everything.

## When to Use

- After `/architect-loop` completes all tasks
- After any significant autonomous development session
- Before a release or deployment

## Review Flow

### Step 1: Map All Changes

```bash
# See all commits from autonomous development
git log --oneline --since="24 hours ago"
git diff --stat HEAD~N  # N = number of commits to review
```

Read every changed file with the Read tool. You have 1M context — use it.

Also check `.autonomy/state.json` for task results and any failures.

### Step 2: Read Review History (if available)

Check if any review files exist:
```bash
ls .autonomy/reviews/ 2>/dev/null || echo "No review history"
ls .gnap/reviews/ 2>/dev/null || echo "No GNAP reviews"
```

Read any available review reports from previous sessions.

### Step 3: Specialist Analysis

For EVERY changed file, check:

**3a. Security:**
- Hardcoded secrets/passwords?
- SQL injection risks?
- Input validation present?
- Unsafe file operations?

**3b. Code Standards:**
- Naming conventions consistent across ALL files?
- Import ordering correct? (stdlib → third-party → local)
- Docstrings consistent? (same style everywhere)
- Error handling pattern uniform? (every module same approach)
- Magic numbers/strings? (should be constants)

**3c. Architecture:**
- Module boundaries respected? (no layer skipping)
- Circular dependencies?
- Matches IMPLEMENTATION.md design?
- Follows CLAUDE.md rules?
- DRY violations? (duplicate code across files)

**3d. Performance:**
- Unnecessary loops?
- Loading entire files into memory?
- N+1 query problems?
- Unnecessary I/O?

### Step 4: Auto-Fix (Stack-Aware)

```bash
# Detect stack and run appropriate tools:

# Python:
#   ruff check --fix src/ tests/ && ruff format src/ tests/
#   mypy src/ --ignore-missing-imports

# .NET:
#   dotnet build && dotnet test
#   dotnet format --verify-no-changes

# Node/TypeScript:
#   npm run lint -- --fix && npm run build
#   npm test

# Go:
#   go vet ./... && golangci-lint run
#   go test ./...
```

Fix issues you find:
- Naming inconsistencies → standardize
- Missing docstrings → add
- Duplicate code → refactor
- Import ordering → fix
- Error handling → standardize

### Step 5: Report and Commit

Present findings in this format:

```
## Architect Review Report

### Critical Issues (fixed)
- [file:line] Issue description → fix applied

### Warnings (presented to user)
- [file:line] Warning description

### Improvement Suggestions
- Suggestion description

### Statistics
- Total files reviewed: N
- Files modified: N
- Issues fixed: N
- Test status: PASSED/FAILED
- Lint status: CLEAN/N errors
```

If fixes were applied:
```bash
git add -A
git commit -m "architect review: standardization + quality fixes"
```

## Rules

1. **Don't change logic** — Only standardization and quality fixes. Don't touch business logic.
2. **Don't break tests** — All existing tests must keep passing. Never commit test-breaking changes.
3. **Explain every fix** — State why in the commit message.
4. **No big refactors** — This is review, not refactoring. Small targeted fixes only.
5. **Reference IMPLEMENTATION.md** — Architectural decisions are documented there.
