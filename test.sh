#!/bin/bash
# test.sh — Automated test suite for claude-setup
# Sandboxes via HOME override. Requires: node, git, bash.
# Exit 0 if all pass, 1 if any fail.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SANDBOX="$(mktemp -d -t claude-setup-test-XXXXXX)"
ORIG_HOME="$HOME"

# Colors
if [ -t 1 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; NC=''
fi

PASS=0
FAIL=0
FAILED_TESTS=()

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); }
section() { echo ""; echo -e "${YELLOW}→ $1${NC}"; }

cleanup() {
  export HOME="$ORIG_HOME"
  rm -rf "$SANDBOX"
}
trap cleanup EXIT

# Sandbox everything under $SANDBOX
export HOME="$SANDBOX"
mkdir -p "$SANDBOX"
cd "$SANDBOX"

# Sanity check: Node must be available
if ! command -v node &> /dev/null; then
  echo -e "${RED}Node.js is required to run this test suite.${NC}"
  exit 1
fi

echo "Running claude-setup tests in sandbox: $SANDBOX"
echo "(HOME is overridden; your real ~/.claude is untouched)"

# ============================================================
# SECTION: Fresh install
# ============================================================
section "Fresh install"
"$SCRIPT_DIR/install.sh" > /tmp/install-fresh.log 2>&1 || fail "install.sh exited non-zero on fresh install"

# Test 1: All files installed
[ -f "$SANDBOX/.claude/rules/workflow.md" ] && pass "rules/workflow.md installed" || fail "rules/workflow.md missing"
[ -f "$SANDBOX/.claude/rules/qa.md" ] && pass "rules/qa.md installed" || fail "rules/qa.md missing"
[ -f "$SANDBOX/.claude/rules/testing.md" ] && pass "rules/testing.md installed" || fail "rules/testing.md missing"
[ -f "$SANDBOX/.claude/rules/code-style.md" ] && pass "rules/code-style.md installed" || fail "rules/code-style.md missing"
[ -f "$SANDBOX/.claude/rules/security.md" ] && pass "rules/security.md installed" || fail "rules/security.md missing"
[ -f "$SANDBOX/.claude/rules/frontend/react.md" ] && pass "rules/frontend/react.md installed" || fail "rules/frontend/react.md missing"
[ -f "$SANDBOX/.claude/hooks/config-protection.mjs" ] && pass "hooks/config-protection.mjs installed" || fail "hooks/config-protection.mjs missing"
[ -f "$SANDBOX/.claude/hooks/block-no-verify.mjs" ] && pass "hooks/block-no-verify.mjs installed" || fail "hooks/block-no-verify.mjs missing"
[ -f "$SANDBOX/.claude/hooks/suggest-compact.mjs" ] && pass "hooks/suggest-compact.mjs installed" || fail "hooks/suggest-compact.mjs missing"
[ -f "$SANDBOX/.claude/commands/code-review.md" ] && pass "commands/code-review.md installed" || fail "commands/code-review.md missing"
[ -f "$SANDBOX/.claude/commands/security-scan.md" ] && pass "commands/security-scan.md installed" || fail "commands/security-scan.md missing"
[ -f "$SANDBOX/.claude/agents/code-reviewer.md" ] && pass "agents/code-reviewer.md installed" || fail "agents/code-reviewer.md missing"
[ -f "$SANDBOX/.claude/agents/security-reviewer.md" ] && pass "agents/security-reviewer.md installed" || fail "agents/security-reviewer.md missing"
[ -x "$SANDBOX/bin/init-claude" ] && pass "bin/init-claude installed and executable" || fail "bin/init-claude missing or not executable"

# Test 2: Settings merge (fresh)
SETTINGS="$SANDBOX/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
  HAS_ENV=$(node -e "const s=require('$SETTINGS'); process.exit(s.env && s.env.ENABLE_TOOL_SEARCH === 'true' ? 0 : 1)" && echo yes || echo no)
  [ "$HAS_ENV" = "yes" ] && pass "settings.json has ENABLE_TOOL_SEARCH=true" || fail "settings.json missing ENABLE_TOOL_SEARCH"

  HOOK_COUNT=$(node -e "
const s = require('$SETTINGS');
const pre = (s.hooks && s.hooks.PreToolUse) || [];
let count = 0;
for (const e of pre) if (Array.isArray(e.hooks)) count += e.hooks.length;
console.log(count);
")
  [ "$HOOK_COUNT" = "3" ] && pass "settings.json has exactly 3 PreToolUse hooks" || fail "settings.json has $HOOK_COUNT hooks (expected 3)"
else
  fail "settings.json not created"
fi

# ============================================================
# SECTION: Settings merge preserves existing
# ============================================================
section "Settings merge preserves existing keys"

# Reset sandbox, pre-seed custom settings
rm -rf "$SANDBOX/.claude" "$SANDBOX/bin" "$SANDBOX/.claude-template"
mkdir -p "$SANDBOX/.claude"
cat > "$SETTINGS" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(npm test)"]
  },
  "model": "haiku",
  "hooks": {
    "PostToolUse": [
      { "matcher": "Edit", "hooks": [{ "type": "command", "command": "echo custom" }] }
    ]
  }
}
EOF

"$SCRIPT_DIR/install.sh" > /tmp/install-preserve.log 2>&1 || fail "install.sh exited non-zero with pre-seeded settings"

# Check preservation — write results to tmp file to avoid subshell counter issue
TMPRESULTS=$(mktemp)
node -e "
const s = require('$SETTINGS');
const checks = [
  [s.permissions && s.permissions.allow && s.permissions.allow[0] === 'Bash(npm test)', 'custom permission preserved'],
  [s.model === 'haiku', 'custom model preserved'],
  [s.hooks && s.hooks.PostToolUse && s.hooks.PostToolUse.length > 0, 'custom PostToolUse preserved'],
  [s.hooks && s.hooks.PreToolUse && s.hooks.PreToolUse.length > 0, 'our PreToolUse hooks added'],
  [s.env && s.env.ENABLE_TOOL_SEARCH === 'true', 'ENABLE_TOOL_SEARCH added']
];
for (const [ok, label] of checks) console.log(ok ? 'PASS:' : 'FAIL:', label);
" > "$TMPRESULTS"
while IFS= read -r line; do
  if [[ "$line" == PASS:* ]]; then pass "${line#PASS: }"; else fail "${line#FAIL: }"; fi
done < "$TMPRESULTS"
rm -f "$TMPRESULTS"

# ============================================================
# SECTION: Idempotent re-install
# ============================================================
section "Idempotent re-install (no duplicate hooks)"

"$SCRIPT_DIR/install.sh" > /tmp/install-idem.log 2>&1 || fail "install.sh exited non-zero on re-run"

HOOK_COUNT=$(node -e "
const s = require('$SETTINGS');
const pre = (s.hooks && s.hooks.PreToolUse) || [];
let count = 0;
for (const e of pre) if (Array.isArray(e.hooks)) count += e.hooks.length;
console.log(count);
")
[ "$HOOK_COUNT" = "3" ] && pass "no duplicate hooks after re-install (count=3)" || fail "duplicate hooks after re-install (count=$HOOK_COUNT)"

# ============================================================
# SECTION: Hook behavior
# ============================================================
section "Hook behavior"

# config-protection blocks
OUT=$(echo '{"tool_input":{"file_path":".eslintrc.json"}}' | node "$SANDBOX/.claude/hooks/config-protection.mjs" 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "config-protection blocks .eslintrc.json" || fail "config-protection did NOT block .eslintrc.json"

# config-protection allows
OUT=$(echo '{"tool_input":{"file_path":"src/app.ts"}}' | node "$SANDBOX/.claude/hooks/config-protection.mjs" 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "config-protection allows src/app.ts" || fail "config-protection wrongly blocked src/app.ts"

# block-no-verify blocks
OUT=$(echo '{"tool_input":{"command":"git commit --no-verify"}}' | node "$SANDBOX/.claude/hooks/block-no-verify.mjs" 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "block-no-verify blocks --no-verify" || fail "block-no-verify did NOT block --no-verify"

# block-no-verify allows
OUT=$(echo '{"tool_input":{"command":"git commit -m test"}}' | node "$SANDBOX/.claude/hooks/block-no-verify.mjs" 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "block-no-verify allows normal commit" || fail "block-no-verify wrongly blocked normal commit"

# suggest-compact never blocks
OUT=$(echo '{"tool_input":{"file_path":"src/app.ts"}}' | node "$SANDBOX/.claude/hooks/suggest-compact.mjs" 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "suggest-compact never blocks" || fail "suggest-compact wrongly blocked"

# ============================================================
# SECTION: Malformed settings.json
# ============================================================
section "Malformed settings.json recovery"

rm -rf "$SANDBOX/.claude" "$SANDBOX/bin"
mkdir -p "$SANDBOX/.claude"
echo "NOT VALID JSON {{{" > "$SETTINGS"

if "$SCRIPT_DIR/install.sh" > /tmp/install-malformed.log 2>&1; then
  # Silent recovery - settings.json should now be valid
  if node -e "require('$SETTINGS')" 2>/dev/null; then
    pass "install.sh recovers from malformed settings.json (silently replaces with valid)"
  else
    fail "install.sh did not produce valid settings.json after malformed input"
  fi
else
  # Loud failure would also be acceptable - mark as pass
  pass "install.sh exits non-zero on malformed settings.json (acceptable behavior)"
fi

# ============================================================
# SECTION: init-claude behavior
# ============================================================
section "init-claude in sub-project"

PROJECT="$SANDBOX/myproject"
mkdir -p "$PROJECT"
cd "$PROJECT"
git init > /dev/null 2>&1
git config user.email test@example.com
git config user.name Test

"$SANDBOX/bin/init-claude" > /tmp/init-claude-1.log 2>&1 || fail "init-claude failed in fresh project"

[ -d "$PROJECT/.claude" ] && pass "init-claude creates .claude/" || fail "init-claude did not create .claude/"
[ -f "$PROJECT/.claude/CLAUDE.md" ] && pass "init-claude copies CLAUDE.md" || fail "init-claude did not copy CLAUDE.md"
[ -f "$PROJECT/.gitignore" ] && pass "init-claude creates .gitignore when missing" || fail "init-claude did not create .gitignore"
[ -x "$PROJECT/.git/hooks/pre-commit" ] && pass "init-claude installs pre-commit hook" || fail "init-claude did not install pre-commit hook"

# .project-gitignore should NOT be in .claude/
[ -f "$PROJECT/.claude/.project-gitignore" ] && fail ".project-gitignore leaked into .claude/" || pass ".project-gitignore cleaned up from .claude/"
[ -f "$PROJECT/.claude/.pre-commit-hook" ] && fail ".pre-commit-hook leaked into .claude/" || pass ".pre-commit-hook cleaned up from .claude/"

# ============================================================
# SECTION: init-claude respects existing .gitignore
# ============================================================
section "init-claude respects existing .gitignore"

PROJECT2="$SANDBOX/project-with-gitignore"
mkdir -p "$PROJECT2"
cd "$PROJECT2"
echo "existing content" > .gitignore
git init > /dev/null 2>&1

"$SANDBOX/bin/init-claude" > /tmp/init-claude-2.log 2>&1 || fail "init-claude failed with existing .gitignore"

GITIGNORE_CONTENT=$(cat "$PROJECT2/.gitignore")
[ "$GITIGNORE_CONTENT" = "existing content" ] && pass "init-claude preserves existing .gitignore" || fail "init-claude overwrote existing .gitignore"

# ============================================================
# SECTION: init-claude blocks on existing .claude/
# ============================================================
section "init-claude blocks on existing .claude/"

cd "$PROJECT"  # .claude/ already exists from earlier test
if "$SANDBOX/bin/init-claude" > /tmp/init-claude-3.log 2>&1; then
  fail "init-claude did not block when .claude/ already exists"
else
  pass "init-claude exits non-zero when .claude/ already exists"
fi

# ============================================================
# SECTION: Uninstall
# ============================================================
section "Uninstall"

cd "$SANDBOX"
# Keep our custom seeded settings for this test — verify they survive uninstall
# (they are still in $SETTINGS from the malformed recovery test, which wiped them)
# Re-seed custom settings + run install to get back to known state
cat > "$SETTINGS" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(npm test)"]
  },
  "model": "haiku",
  "hooks": {
    "PostToolUse": [
      { "matcher": "Edit", "hooks": [{ "type": "command", "command": "echo custom" }] }
    ]
  }
}
EOF
"$SCRIPT_DIR/install.sh" > /tmp/install-before-uninstall.log 2>&1

# Run uninstall with auto-"no" for the template prompt
echo "n" | "$SCRIPT_DIR/uninstall.sh" > /tmp/uninstall.log 2>&1 || fail "uninstall.sh exited non-zero"

# Verify our files are gone
[ ! -f "$SANDBOX/.claude/hooks/config-protection.mjs" ] && pass "uninstall removed config-protection.mjs" || fail "uninstall left config-protection.mjs"
[ ! -f "$SANDBOX/.claude/hooks/block-no-verify.mjs" ] && pass "uninstall removed block-no-verify.mjs" || fail "uninstall left block-no-verify.mjs"
[ ! -f "$SANDBOX/.claude/hooks/suggest-compact.mjs" ] && pass "uninstall removed suggest-compact.mjs" || fail "uninstall left suggest-compact.mjs"
[ ! -f "$SANDBOX/.claude/commands/code-review.md" ] && pass "uninstall removed code-review.md" || fail "uninstall left code-review.md"
[ ! -f "$SANDBOX/.claude/agents/code-reviewer.md" ] && pass "uninstall removed code-reviewer.md" || fail "uninstall left code-reviewer.md"
[ ! -f "$SANDBOX/.claude/rules/workflow.md" ] && pass "uninstall removed workflow.md" || fail "uninstall left workflow.md"
[ ! -f "$SANDBOX/bin/init-claude" ] && pass "uninstall removed bin/init-claude" || fail "uninstall left bin/init-claude"

# Verify custom settings preserved — tmp file to avoid subshell
TMPRESULTS2=$(mktemp)
node -e "
const s = require('$SETTINGS');
const checks = [
  [s.permissions && s.permissions.allow && s.permissions.allow[0] === 'Bash(npm test)', 'uninstall preserved custom permission'],
  [s.model === 'haiku', 'uninstall preserved custom model'],
  [s.hooks && s.hooks.PostToolUse && s.hooks.PostToolUse.length > 0, 'uninstall preserved PostToolUse hooks'],
  [!s.hooks || !s.hooks.PreToolUse || s.hooks.PreToolUse.length === 0, 'uninstall removed all PreToolUse hooks']
];
for (const [ok, label] of checks) console.log(ok ? 'PASS:' : 'FAIL:', label);
" > "$TMPRESULTS2"
while IFS= read -r line; do
  if [[ "$line" == PASS:* ]]; then pass "${line#PASS: }"; else fail "${line#FAIL: }"; fi
done < "$TMPRESULTS2"
rm -f "$TMPRESULTS2"

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "============================================================"
echo -e "Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo "============================================================"

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
  exit 1
fi

exit 0
