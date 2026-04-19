#!/bin/bash
# uninstall.sh — Safely remove what install.sh installed
# Preserves user customizations (permissions, env, other hooks, custom rules)

set -e

echo "Uninstalling Claude Code setup..."
echo ""

OUR_HOOKS=(config-protection.mjs block-no-verify.mjs suggest-compact.mjs)
OUR_COMMANDS=(code-review.md security-scan.md)
OUR_AGENTS=(code-reviewer.md security-reviewer.md)
OUR_RULES=(workflow.md qa.md testing.md code-style.md security.md)

# 1. Remove our hooks
echo "→ Removing hooks from ~/.claude/hooks/"
for h in "${OUR_HOOKS[@]}"; do
  [ -f ~/.claude/hooks/"$h" ] && rm -f ~/.claude/hooks/"$h" && echo "  removed $h"
done

# 2. Remove our commands
echo "→ Removing commands from ~/.claude/commands/"
for c in "${OUR_COMMANDS[@]}"; do
  [ -f ~/.claude/commands/"$c" ] && rm -f ~/.claude/commands/"$c" && echo "  removed $c"
done

# 3. Remove our agents
echo "→ Removing agents from ~/.claude/agents/"
for a in "${OUR_AGENTS[@]}"; do
  [ -f ~/.claude/agents/"$a" ] && rm -f ~/.claude/agents/"$a" && echo "  removed $a"
done

# 4. Remove our rules (top-level + frontend/react.md)
echo "→ Removing rules from ~/.claude/rules/"
for r in "${OUR_RULES[@]}"; do
  [ -f ~/.claude/rules/"$r" ] && rm -f ~/.claude/rules/"$r" && echo "  removed $r"
done
[ -f ~/.claude/rules/frontend/react.md ] && rm -f ~/.claude/rules/frontend/react.md && echo "  removed frontend/react.md"

# Remove frontend/ dir only if empty
[ -d ~/.claude/rules/frontend ] && rmdir ~/.claude/rules/frontend 2>/dev/null && echo "  removed empty frontend/ dir" || true

# Remove rules/ dir only if empty (user may have custom rules)
[ -d ~/.claude/rules ] && rmdir ~/.claude/rules 2>/dev/null && echo "  removed empty rules/ dir" || true

# 5. Remove init-claude
echo "→ Removing ~/bin/init-claude"
[ -f ~/bin/init-claude ] && rm -f ~/bin/init-claude && echo "  removed init-claude"

# 6. Strip our hooks from ~/.claude/settings.json — preserve everything else
if [ -f ~/.claude/settings.json ]; then
  echo "→ Stripping our hooks from ~/.claude/settings.json (preserving your other settings)"
  node -e "
const fs = require('fs');
const path = require('path');
const settingsPath = path.join(process.env.HOME, '.claude', 'settings.json');

let settings;
try {
  settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
} catch (e) {
  console.error('  [warn] could not parse settings.json:', e.message);
  process.exit(0);
}

const OUR_HOOK_FILES = ['config-protection.mjs', 'suggest-compact.mjs', 'block-no-verify.mjs'];
const isOurHook = (h) =>
  h && h.type === 'command' && typeof h.command === 'string' &&
  OUR_HOOK_FILES.some(name => h.command.includes(name));

// Remove our hooks from each event's matcher entries
if (settings.hooks && typeof settings.hooks === 'object') {
  for (const event of Object.keys(settings.hooks)) {
    const entries = settings.hooks[event];
    if (!Array.isArray(entries)) continue;
    for (const entry of entries) {
      if (Array.isArray(entry.hooks)) {
        entry.hooks = entry.hooks.filter(h => !isOurHook(h));
      }
    }
    // Drop matchers left with empty hook arrays
    settings.hooks[event] = entries.filter(e => Array.isArray(e.hooks) && e.hooks.length > 0);
    // Drop the event entirely if no matchers remain
    if (settings.hooks[event].length === 0) delete settings.hooks[event];
  }
  // Drop the hooks key entirely if no events remain
  if (Object.keys(settings.hooks).length === 0) delete settings.hooks;
}

// We don't remove ENABLE_TOOL_SEARCH — it's a generally useful setting the user
// may want to keep. If they don't, they can delete it manually.

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
console.log('  settings.json cleaned');
"
fi

# 7. Prompt before removing ~/.claude-template/
if [ -d ~/.claude-template ]; then
  echo ""
  read -p "→ Remove ~/.claude-template/ (used by init-claude)? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf ~/.claude-template
    echo "  removed ~/.claude-template/"
  else
    echo "  kept ~/.claude-template/ (remove manually if you want: rm -rf ~/.claude-template)"
  fi
fi

echo ""
echo "✅ Uninstall complete."
echo ""
echo "What was preserved:"
echo "  - Any custom rules, hooks, commands, or agents you added"
echo "  - Your ~/.claude/settings.json (custom permissions, env, other hooks)"
echo "  - ~/.claude/metrics/ (cost tracking, if any)"
echo ""
echo "Things this script does NOT touch:"
echo "  - Per-project .claude/ directories (remove manually per project)"
echo "  - Per-project .git/hooks/pre-commit files (remove manually per project)"
echo "  - gitleaks (installed via Homebrew: brew uninstall gitleaks)"
echo "  - ENABLE_TOOL_SEARCH in settings.json (remove manually if you want)"
