#!/bin/bash
# Install gnap-skills to ~/.claude/skills/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

echo "Installing gnap-skills to $SKILLS_DIR..."

mkdir -p "$SKILLS_DIR"

# Copy each skill
for skill in architect-loop auto-build review-build; do
  if [ -d "$SCRIPT_DIR/$skill" ]; then
    rm -rf "$SKILLS_DIR/$skill"
    cp -r "$SCRIPT_DIR/$skill" "$SKILLS_DIR/$skill"
    echo "  ✅ $skill installed"
  fi
done

echo ""
echo "Installed skills:"
echo "  /architect-loop  — Opus 1M orchestrator loop"
echo "  /auto-build      — Plan + build from scratch"
echo "  /review-build    — Post-build codebase audit"
echo ""
echo "Usage:"
echo "  cd your-project && claude"
echo "  > /auto-build"
echo ""
echo "Requirements:"
echo "  - Claude Code with Opus 4.6 1M (Max subscription)"
echo "  - tmux + caffeinate (for long sessions)"
echo "  - Optional: codex CLI, gemini CLI, Telegram bot"
