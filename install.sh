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

# 5. Check for gitleaks
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
echo "   ~/.claude-template/     → Project template (used by init-claude)"
echo "   ~/bin/init-claude       → Scaffold new projects"
echo ""
echo "For a new project:"
echo "   cd my-project && init-claude"
