#!/bin/bash
# install.sh — Set up Claude Code global rules, template, and tools
# Usage: git clone <repo> && cd claude-setup && ./install.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Claude Code setup..."
echo ""

# 1. Global rules → ~/.claude/rules/
echo "→ Installing global rules to ~/.claude/rules/"
mkdir -p ~/.claude/rules/frontend
cp "$SCRIPT_DIR/global-rules/workflow.md" ~/.claude/rules/
cp "$SCRIPT_DIR/global-rules/qa.md" ~/.claude/rules/
cp "$SCRIPT_DIR/global-rules/testing.md" ~/.claude/rules/
cp "$SCRIPT_DIR/global-rules/code-style.md" ~/.claude/rules/
cp "$SCRIPT_DIR/global-rules/security.md" ~/.claude/rules/
cp "$SCRIPT_DIR/global-rules/frontend/react.md" ~/.claude/rules/frontend/

# 2. Project template → ~/.claude-template/
echo "→ Installing project template to ~/.claude-template/"
mkdir -p ~/.claude-template
cp "$SCRIPT_DIR/template/CLAUDE.md" ~/.claude-template/
cp "$SCRIPT_DIR/template/CLAUDE.local.md" ~/.claude-template/
cp "$SCRIPT_DIR/template/settings.json" ~/.claude-template/
cp "$SCRIPT_DIR/template/settings.local.json" ~/.claude-template/
cp "$SCRIPT_DIR/template/dot-gitignore" ~/.claude-template/.gitignore
cp "$SCRIPT_DIR/template/.project-gitignore" ~/.claude-template/
cp "$SCRIPT_DIR/template/.pre-commit-hook" ~/.claude-template/

# 3. CLI tools → ~/bin/
echo "→ Installing init-claude to ~/bin/"
mkdir -p ~/bin
cp "$SCRIPT_DIR/bin/init-claude" ~/bin/
chmod +x ~/bin/init-claude

# 4. Ensure ~/bin is in PATH
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
  SHELL_RC=""
  if [ -f ~/.zshrc ]; then
    SHELL_RC=~/.zshrc
  elif [ -f ~/.bashrc ]; then
    SHELL_RC=~/.bashrc
  elif [ -f ~/.bash_profile ]; then
    SHELL_RC=~/.bash_profile
  fi

  if [ -n "$SHELL_RC" ]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
    echo "→ Added ~/bin to PATH in $SHELL_RC"
    echo "  Run: source $SHELL_RC"
  else
    echo "⚠️  ~/bin is not in PATH. Add manually: export PATH=\"\$HOME/bin:\$PATH\""
  fi
fi

# 5. Hooks → ~/.claude/hooks/
echo "→ Installing hooks to ~/.claude/hooks/"
mkdir -p ~/.claude/hooks
cp "$SCRIPT_DIR/hooks/"*.mjs ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.mjs

# 6. Commands → ~/.claude/commands/
echo "→ Installing commands to ~/.claude/commands/"
mkdir -p ~/.claude/commands
cp "$SCRIPT_DIR/commands/"*.md ~/.claude/commands/

# 7. Agents → ~/.claude/agents/
echo "→ Installing agents to ~/.claude/agents/"
mkdir -p ~/.claude/agents
for agent in "$SCRIPT_DIR/agents/"*.md; do
  cp "$agent" ~/.claude/agents/
done

# 8. Configure hooks and env in ~/.claude/settings.json
echo "→ Configuring hooks and env in ~/.claude/settings.json"
mkdir -p ~/.claude/metrics
node -e "
const fs = require('fs');
const path = require('path');
const settingsPath = path.join(process.env.HOME, '.claude', 'settings.json');
const hooksDir = path.join(process.env.HOME, '.claude', 'hooks');

let settings = {};
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8')); } catch {}

if (!settings.env) settings.env = {};
settings.env.ENABLE_TOOL_SEARCH = 'true';

// Hook files this script manages — used to identify our entries during merge.
// Matching by filename (not full path) so detection survives path changes.
const OUR_HOOK_FILES = ['config-protection.mjs', 'suggest-compact.mjs', 'block-no-verify.mjs'];
const isOurHook = (h) =>
  h && h.type === 'command' && typeof h.command === 'string' &&
  OUR_HOOK_FILES.some(name => h.command.includes(name));

// Our desired PreToolUse configuration, keyed by matcher pattern.
const OUR_MATCHERS = {
  'Write|Edit': [
    { type: 'command', command: 'node ' + hooksDir + '/config-protection.mjs' },
    { type: 'command', command: 'node ' + hooksDir + '/suggest-compact.mjs' }
  ],
  'Bash': [
    { type: 'command', command: 'node ' + hooksDir + '/block-no-verify.mjs' }
  ]
};

// Merge instead of replace: preserve other hook events (PostToolUse, Stop, etc.),
// other PreToolUse matchers, and any user-added hooks on our matchers.
// Idempotent: re-running the installer does not duplicate our hooks.
if (!settings.hooks) settings.hooks = {};
if (!Array.isArray(settings.hooks.PreToolUse)) settings.hooks.PreToolUse = [];

for (const [matcher, ourHooks] of Object.entries(OUR_MATCHERS)) {
  const entry = settings.hooks.PreToolUse.find(e => e.matcher === matcher);
  if (entry) {
    // Strip our previously-installed hooks, keep any user-added hooks on this matcher.
    entry.hooks = (entry.hooks || []).filter(h => !isOurHook(h)).concat(ourHooks);
  } else {
    settings.hooks.PreToolUse.push({ matcher, hooks: [...ourHooks] });
  }
}

// Drop any matcher entries left with empty hook arrays (cleanup from prior versions).
settings.hooks.PreToolUse = settings.hooks.PreToolUse.filter(
  e => Array.isArray(e.hooks) && e.hooks.length > 0
);

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
"

# 9. Check for gitleaks
if ! command -v gitleaks &> /dev/null; then
  echo ""
  echo "⚠️  gitleaks not installed. Secret scanning won't work without it."
  if command -v brew &> /dev/null; then
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
echo "✅ Done! Your setup:"
echo ""
echo "   ~/.claude/rules/        → Global rules (auto-loaded in every project)"
echo "   ~/.claude/hooks/        → Hooks (config-protection, block-no-verify, suggest-compact)"
echo "   ~/.claude/commands/     → Slash commands (/code-review, /security-scan)"
echo "   ~/.claude/agents/       → Subagents (code-reviewer, security-reviewer)"
echo "   ~/.claude-template/     → Project template (used by init-claude)"
echo "   ~/bin/init-claude       → Scaffold new projects"
echo ""
echo "For a new project:"
echo "   cd my-project && init-claude"
