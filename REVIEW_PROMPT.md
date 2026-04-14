# Review Request — V4.2 Post-Audit Fixes

## Context

You (GPT-5.4 Pro) reviewed this repo four times. An external hostile auditor then tore it apart and gave a QUESTIONABLE verdict. Their key findings:

1. `python3 - *` in allow list = unrestricted code execution via stdin → **FIXED: moved to deny list**
2. Unquoted heredoc in wrappers = shell injection risk → **FIXED: changed to <<'EOF'**
3. integrity.json never created by auto-build = dead feature → **FIXED: removed entirely**
4. Checkpoints written but never read on resume = dead feature → **FIXED: resume now reads checkpoints**
5. Security framing was dishonest → **FIXED: reframed as "workflow tool, not security tool"**
6. Codex/Gemini outside hook system → **ACKNOWLEDGED: documented honestly as limitation**

## What Changed in This Version

### Bug fixes applied
- `python - *` and `python3 - *` moved from `permissions.allow` to `permissions.deny`
- Worker wrapper heredocs changed from `<<EOF` to `<<'EOF'` (prevents variable expansion and EOF injection)
- Integrity manifest section removed from architect-loop (was never implemented by auto-build)
- Resume behavior now reads `.autonomy/checkpoints/` on restart

### Framing changes
- VISION.md: "What is fixed" → "What this version does" — explicitly says "workflow tool, not security tool"
- README.md: "Security model" → "Workflow discipline (not a security model)" — honest about what hooks can and cannot do
- Hooks described as "speed bumps, not walls" everywhere

### What we kept (auditor agreed these have value)
- Worktree-per-task discipline
- ff-only merge integration rule
- Task queue in JSON with state tracking
- Wrapper-based dispatch (standardization)
- Rejection feedback memory
- Event ledger (for observability, not claimed as tamper-proof)
- Checkpoint summaries (now actually read on resume)

## Our Goal

We are NOT building a security system. We are building a **workflow tool for autonomous code generation that produces high-quality code**.

The actual goal:
1. **Autonomous** — the system runs without human intervention for hours
2. **Multi-model** — different AI models provide different perspectives
3. **Quality-focused** — every piece of code is reviewed before integration
4. **Structured** — explicit task queue, explicit state, explicit gates
5. **Recoverable** — crashes don't lose progress
6. **Honest** — we know what hooks can't do and we say so

## What We Want From You

### 1. Audit the fixes
Did we actually fix what we said we fixed? Check the specific files:
- `auto-build/templates/settings.json` — is `python - *` really in deny now?
- `auto-build/templates/bin/sonnet-worker.sh` — is the heredoc really quoted?
- `architect-loop/SKILL.md` — is integrity.json really gone? Does resume read checkpoints?
- `VISION.md` and `README.md` — is the framing genuinely honest now?

### 2. Focus on code quality
The hostile auditor focused on security (fair — we were claiming security). Now that we've dropped security claims, focus on what matters: **does this system produce high-quality code?**

Specifically:
- Is the review checklist in architect-loop comprehensive enough to catch real bugs?
- Are the gates (build, test, lint) sufficient for code quality?
- Does the rejection feedback loop actually improve subsequent attempts?
- Is the checkpoint + drift detection useful for maintaining architectural consistency?
- Would the structured worker result (files_created, functions_added, etc.) help the architect make better review decisions?

### 3. Improve autonomous code quality
What changes would make the CODE OUTPUT better (not the system itself)?

Ideas to evaluate:
- Should workers be required to write tests alongside every feature?
- Should the architect run a "code smell" check beyond lint?
- Should there be a mandatory naming consistency scan per checkpoint?
- Should workers receive the full CLAUDE.md as part of every prompt?
- Should the architect compare each new file against existing files for style consistency?
- Should gates include coverage delta (new code must be covered)?

### 4. What's the realistic scope?
Given that this is a workflow tool (not a security tool), what's the realistic scope of projects it can handle? Be specific:
- What project sizes (files, tasks)?
- What stacks work best?
- What types of tasks does it handle well vs. poorly?
- How many tasks before context/quality degrades?

### 5. Updated scores
Re-score with the corrected framing (workflow tool, not security tool):
- Workflow coherence (was "architectural coherence")
- Code quality potential
- Production readiness (for the workflow, not security)
- Documentation honesty
- Real-world viability

### 6. Updated verdict
With the corrected framing and fixes applied:
- **VIABLE**: worth using as a workflow tool for autonomous code generation
- **QUESTIONABLE**: still has fundamental workflow problems
- **ABANDON**: even as a workflow tool, this doesn't work

We expect VIABLE or QUESTIONABLE. If still QUESTIONABLE, tell us exactly what 3 things would flip it to VIABLE.
