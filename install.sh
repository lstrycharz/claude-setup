#!/bin/bash
# install.sh — install the GLOBAL RULES and playbooks (the always-loaded part).
#
# Everything else — hooks, slash commands, agents, and the project template —
# ships as a Claude Code PLUGIN (#13). Plugins are versioned, install/update/
# uninstall cleanly, and never touch your settings.json. Inside Claude Code:
#
#   /plugin marketplace add lstrycharz/claude-setup
#   /plugin install claude-setup@claude-setup
#
# Global rules are the one thing plugins don't cover (they are auto-loaded into
# every session from ~/.claude/rules), so this script still copies those.
#
# Usage: git clone <repo> && cd claude-setup && ./install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Claude Code global rules..."
echo ""

# Node check — the plugin's hooks run under node. A too-old Node is worse than
# none: the hooks fail to parse, exit 1, and Claude Code treats non-2 exits as
# non-blocking — so every protection hook silently no-ops (#8).
if ! command -v node &> /dev/null; then
  echo "❌ Node.js is required (the plugin's hooks run under node)."
  echo ""
  echo "   Install Node first, then re-run ./install.sh:"
  echo "     macOS:   brew install node"
  echo "     Ubuntu:  use NodeSource or nvm (apt's default nodejs is too old):"
  echo "              https://github.com/nodesource/distributions"
  echo "     Other:   https://nodejs.org/"
  exit 1
fi
NODE_MAJOR=$(node -p 'parseInt(process.versions.node, 10)' 2>/dev/null || echo 0)
if [ "${NODE_MAJOR:-0}" -lt 18 ]; then
  echo "❌ Node.js >= 18 is required (found $(node --version 2>/dev/null || echo unknown))."
  echo "   The hooks use modern syntax an old Node can't parse — they would"
  echo "   silently no-op on every tool call instead of protecting anything."
  echo "   Upgrade via https://github.com/nodesource/distributions or nvm, then re-run."
  exit 1
fi

# 1. Global rules → ~/.claude/rules/
echo "→ Installing global rules to ~/.claude/rules/"
mkdir -p ~/.claude/rules/frontend
cp "$SCRIPT_DIR/global-rules/workflow.md" ~/.claude/rules/
cp "$SCRIPT_DIR/global-rules/qa.md" ~/.claude/rules/
cp "$SCRIPT_DIR/global-rules/testing.md" ~/.claude/rules/
cp "$SCRIPT_DIR/global-rules/code-style.md" ~/.claude/rules/
cp "$SCRIPT_DIR/global-rules/security.md" ~/.claude/rules/
cp "$SCRIPT_DIR/global-rules/agent-design.md" ~/.claude/rules/
cp "$SCRIPT_DIR/global-rules/frontend/react.md" ~/.claude/rules/frontend/

# 2. Playbooks → ~/.claude/playbooks/ (pull-loaded references, not auto-loaded rules)
echo "→ Installing playbooks to ~/.claude/playbooks/"
mkdir -p ~/.claude/playbooks
cp "$SCRIPT_DIR/playbooks/"*.md ~/.claude/playbooks/

# 3. Check for gitleaks (the pre-commit secret scan needs it)
if ! command -v gitleaks &> /dev/null; then
  echo ""
  echo "⚠️  gitleaks not installed. Secret scanning won't work without it."
  # Only prompt when stdin is a terminal — otherwise (CI, piped installs,
  # test.sh) `read` hangs forever waiting for a keypress (#17).
  if [ -t 0 ] && command -v brew &> /dev/null; then
    read -p "   Install via Homebrew? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      brew install gitleaks
    fi
  else
    echo "   Install manually: https://github.com/gitleaks/gitleaks#installing"
  fi
fi

echo ""
echo "✅ Done! Installed:"
echo ""
echo "   ~/.claude/rules/        → Global rules (auto-loaded in every project)"
echo "   ~/.claude/playbooks/    → Long-form references (pulled when needed)"
echo ""
echo "Everything else is the PLUGIN (hooks, /code-review, /init-floor, agents,"
echo "project template). Install it inside Claude Code:"
echo ""
echo "   /plugin marketplace add lstrycharz/claude-setup"
echo "   /plugin install claude-setup@claude-setup"
echo ""
echo "Then in a new project:  /init-floor"
echo "Upgrading from a pre-plugin install? Run ./uninstall.sh once to remove the"
echo "old copied hooks/commands/agents and their settings.json wiring."
