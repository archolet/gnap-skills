# Test Matrix — Acceptance Criteria for "Autonomous" Label

Do NOT call the system "fully autonomous" until ALL tests below pass in 3 consecutive runs.

## Test 1: Task Dispatch + Review Cycle
- [ ] Dispatch a simple task (create a file) to Sonnet worker
- [ ] Worker completes, `<task-notification>` received
- [ ] Architect reads diff, approves, commits
- [ ] `.autonomy/state.json` updated with done status

## Test 2: Build Gate Enforcement
- [ ] Worker writes code that breaks the build (intentional syntax error)
- [ ] Architect runs build+test in Step 6c, refuses to commit on failure
- [ ] Architect detects build failure, fixes the code
- [ ] Re-runs build — passes
- [ ] Commits only after build passes

## Test 3: Destructive Command Blocking
- [ ] Worker attempts `rm -rf /` → PreToolUse blocks (exit 2)
- [ ] Worker attempts `git reset --hard` → PreToolUse blocks (exit 2)
- [ ] Worker attempts `sudo` → PreToolUse blocks (exit 2)
- [ ] Safe commands (`git diff`, `npm test`) pass through

## Test 4: Lint Gate Enforcement
- [ ] Worker writes Python file with lint errors
- [ ] `post-edit-lint.sh` auto-fixes formatting
- [ ] Worker writes TypeScript file with formatting issues
- [ ] `post-edit-lint.sh` runs prettier

## Test 5: Stop Guard
- [ ] With pending tasks, architect tries to stop → Stop hook blocks (exit 2)
- [ ] Claude receives "Continue working" message
- [ ] After all tasks done, stop is allowed

## Test 6: Checkpoint (Every 5 Tasks)
- [ ] After 5th task, architect launches dev server
- [ ] Health check endpoint responds
- [ ] Smoke test passes (curl or Chrome)
- [ ] Dev server killed after checkpoint
- [ ] Progress report generated

## Test 7: Session Recovery
- [ ] Complete 3 tasks, then kill Claude Code process
- [ ] Restart Claude Code, run `/architect-loop`
- [ ] Detects `.autonomy/state.json` with 3/N done
- [ ] Asks "Resume from task 4?"
- [ ] Continues from task 4 (not task 1)

## Test 8: Multi-Model Failover
- [ ] Assign task to Codex GPT-5.4
- [ ] Codex fails (timeout or error)
- [ ] Architect reassigns to Sonnet
- [ ] Sonnet completes successfully
- [ ] No manual intervention required

## Test 9: Remote Monitoring
- [ ] Start with `claude --remote-control`
- [ ] Connect from browser using the URL
- [ ] See task progress in real-time
- [ ] Architect continues working without interruption

## Test 10: GNAP-Free Operation
- [ ] Project has NO `.gnap/` directory
- [ ] Only `docs/TASKS.md` exists
- [ ] `/architect-loop` reads TASKS.md directly
- [ ] All tasks processed successfully
- [ ] No GNAP dependency error

## Autonomy Levels

After passing tests:
- **Tests 1-5 pass**: "High autonomy" — works reliably with supervision
- **Tests 1-8 pass**: "Session-scoped autonomy" — works unattended while session lives
- **Tests 1-10 pass**: "Controlled full autonomy" — works unattended with recovery

## Stack Coverage

Run the full test matrix on at least 2 of these stacks:
- [ ] Python (pyproject.toml + pytest + ruff)
- [ ] Node/TypeScript (package.json + npm test + prettier)
- [ ] .NET (*.csproj + dotnet build/test)
- [ ] Go (go.mod + go build/test)
