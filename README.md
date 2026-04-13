# GNAP Skills — Autonomous Multi-Agent Development for Claude Code

Three Claude Code skills that turn Opus 4.6 1M into a software architect orchestrating multiple AI models.

## Skills

### `/architect-loop` — The Core
Opus 1M becomes the orchestrator. Dispatches tasks to junior developers (Sonnet, Codex GPT-5.4, Gemini), reviews their code with 1M context, builds, tests, and approves or rejects.

```
You (human) → strategic decisions
  └── Opus 4.6 1M (architect, this terminal)
      ├── Claude Sonnet 4.6 (fast developer)
      ├── Claude Opus 4.6 200K (strong developer)  
      ├── Codex GPT-5.4 xhigh (OpenAI developer)
      └── Gemini 3.1 flash-lite (Google developer)
```

### `/auto-build` — Plan + Build
End-to-end project creation. Interactive discovery → SPECIFICATION.md → IMPLEMENTATION.md → TASKS.md → architect-loop.

### `/review-build` — Post-Build Audit
Full codebase review after autonomous build. Security, performance, standards, architecture checks.

## Installation

```bash
# Clone to Claude Code skills directory
git clone https://github.com/archolet/gnap-skills.git /tmp/gnap-skills-install

# Copy skills
cp -r /tmp/gnap-skills-install/architect-loop ~/.claude/skills/
cp -r /tmp/gnap-skills-install/auto-build ~/.claude/skills/
cp -r /tmp/gnap-skills-install/review-build ~/.claude/skills/

# Install GNAP Orchestrator CLI (optional, for daemon mode)
pip install gnap-orchestrator
```

## Usage

```bash
# Start a new project from scratch
mkdir my-project && cd my-project
claude
> /auto-build

# Or run architect loop on existing tasks
claude
> /architect-loop

# Post-build review
claude  
> /review-build
```

## Requirements

- Claude Code with Opus 4.6 1M model
- Codex CLI (`npm install -g @openai/codex`)
- Gemini CLI (`npm install -g @google/gemini-cli`)
- tmux + caffeinate (for long-running sessions)

## How It Works

### Architect Loop Flow
1. Reads task list from `.gnap/tasks.json` or `docs/TASKS.md`
2. Selects appropriate model for each task
3. Dispatches via `run_in_background` (Bash)
4. Heartbeat keeps session alive during wait
5. `<task-notification>` wakes architect when task completes
6. Architect reviews code with full 1M context
7. Builds, tests, approves or rejects
8. Every 5 tasks: launches app, tests in Chrome
9. Telegram notifications for progress

### Multi-Vendor Architecture
- **Anthropic**: Claude Sonnet (speed), Opus (power)
- **OpenAI**: Codex GPT-5.4 xhigh (different perspective, session memory)
- **Google**: Gemini 3.1 flash-lite (third perspective, no quota limits)

## License

MIT
