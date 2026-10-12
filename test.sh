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
  [ -n "${FAKE_PID:-}" ] && kill "$FAKE_PID" 2>/dev/null
  export HOME="$ORIG_HOME"
  rm -rf "$SANDBOX"
}
trap cleanup EXIT

# Sandbox everything under $SANDBOX — including logs, so concurrent runs
# (or two users on one CI box) can't interleave in shared /tmp (#21).
export HOME="$SANDBOX"
mkdir -p "$SANDBOX"
LOGS="$SANDBOX/logs"
mkdir -p "$LOGS"
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
"$SCRIPT_DIR/install.sh" > "$LOGS"/install-fresh.log 2>&1 || fail "install.sh exited non-zero on fresh install"

# Test 1: All files installed
[ -f "$SANDBOX/.claude/rules/workflow.md" ] && pass "rules/workflow.md installed" || fail "rules/workflow.md missing"
[ -f "$SANDBOX/.claude/rules/qa.md" ] && pass "rules/qa.md installed" || fail "rules/qa.md missing"
[ -f "$SANDBOX/.claude/rules/testing.md" ] && pass "rules/testing.md installed" || fail "rules/testing.md missing"
[ -f "$SANDBOX/.claude/rules/code-style.md" ] && pass "rules/code-style.md installed" || fail "rules/code-style.md missing"
[ -f "$SANDBOX/.claude/rules/security.md" ] && pass "rules/security.md installed" || fail "rules/security.md missing"
[ -f "$SANDBOX/.claude/rules/agent-design.md" ] && pass "rules/agent-design.md installed" || fail "rules/agent-design.md missing"
[ -f "$SANDBOX/.claude/rules/frontend/react.md" ] && pass "rules/frontend/react.md installed" || fail "rules/frontend/react.md missing"
[ -f "$SANDBOX/.claude/playbooks/AGENT_PROJECT_PLAYBOOK.md" ] && pass "playbooks/AGENT_PROJECT_PLAYBOOK.md installed" || fail "playbooks/AGENT_PROJECT_PLAYBOOK.md missing"
[ -f "$SCRIPT_DIR/hooks/dispatch.mjs" ] && pass "plugin ships hooks/dispatch.mjs" || fail "hooks/dispatch.mjs missing from plugin"
[ -f "$SCRIPT_DIR/commands/init-floor.md" ] && pass "plugin ships /init-floor command" || fail "commands/init-floor.md missing"
[ -f "$SCRIPT_DIR/commands/update-floor.md" ] && pass "plugin ships /update-floor command" || fail "commands/update-floor.md missing"
# #13: agents ship inside the plugin. A command pointing at ~/.claude/agents/
# sends the model to a path that only exists on a legacy copied install.
if grep -rq '~/.claude/agents/' "$SCRIPT_DIR/commands/"; then
  fail "a command still points at ~/.claude/agents/ (legacy pre-plugin path)"
else
  pass "no command points at the legacy ~/.claude/agents/ path"
fi
[ -f "$SCRIPT_DIR/template/verify.sh" ] && pass "template/verify.sh installed" || fail "template/verify.sh missing"
[ -f "$SCRIPT_DIR/template/.pre-push-hook" ] && pass "template/.pre-push-hook installed" || fail "template/.pre-push-hook missing"
[ -f "$SCRIPT_DIR/template/ci/github-actions.yml" ] && pass "template/ci installed" || fail "template/ci missing"
[ -f "$SCRIPT_DIR/template/configs/eslint.config.mjs.tpl" ] && pass "template/configs installed" || fail "template/configs missing"
[ -f "$SCRIPT_DIR/template/bin/review-diff.mjs" ] && pass "template/bin/review-diff.mjs installed" || fail "template/bin/review-diff.mjs missing"
[ -f "$SCRIPT_DIR/template/review/logic-reviewer.md" ] && pass "template/review prompt installed" || fail "template/review prompt missing"
[ -f "$SCRIPT_DIR/template/ci/reviewer-github.yml" ] && pass "template/ci/reviewer-github.yml installed" || fail "template/ci/reviewer-github.yml missing"
# #3: the GitHub reviewer workflow must be wired to post the findings onto the PR.
grep -q 'pull-requests: write' "$SCRIPT_DIR/template/ci/reviewer-github.yml" && pass "reviewer-github.yml grants PR-comment write permission" || fail "reviewer-github.yml lacks pull-requests: write"
grep -q 'gh pr comment' "$SCRIPT_DIR/template/ci/reviewer-github.yml" && pass "reviewer-github.yml posts a PR comment" || fail "reviewer-github.yml does not post a PR comment"
[ -f "$SCRIPT_DIR/template/ci/reviewer-bitbucket.yml" ] && pass "template/ci/reviewer-bitbucket.yml installed" || fail "template/ci/reviewer-bitbucket.yml missing"
# W6: floor CI images are Node-only — they must at least NOTE Python setup so a
# uv/poetry project doesn't silently no-op its Python checks (false green).
grep -qiE 'python|uv|poetry' "$SCRIPT_DIR/template/ci/github-actions.yml" && pass "ci/github-actions.yml notes Python setup" || fail "ci/github-actions.yml has no Python setup note"
grep -qiE 'python|uv|poetry' "$SCRIPT_DIR/template/ci/bitbucket-pipelines.yml" && pass "ci/bitbucket-pipelines.yml notes Python setup" || fail "ci/bitbucket-pipelines.yml has no Python setup note"
[ -f "$SCRIPT_DIR/commands/code-review.md" ] && pass "commands/code-review.md installed" || fail "commands/code-review.md missing"
[ -f "$SCRIPT_DIR/commands/security-scan.md" ] && pass "commands/security-scan.md installed" || fail "commands/security-scan.md missing"
[ -f "$SCRIPT_DIR/commands/logic-review.md" ] && pass "commands/logic-review.md installed" || fail "commands/logic-review.md missing"
[ -f "$SCRIPT_DIR/agents/code-reviewer.md" ] && pass "agents/code-reviewer.md installed" || fail "agents/code-reviewer.md missing"
[ -f "$SCRIPT_DIR/agents/security-reviewer.md" ] && pass "agents/security-reviewer.md installed" || fail "agents/security-reviewer.md missing"
# The reviewers track the newest Fable via the family alias instead of a pinned
# ID that silently goes stale when a new version ships.
for a in code-reviewer security-reviewer; do
  grep -qx 'model: fable' "$SCRIPT_DIR/agents/$a.md" && pass "$a runs on the newest Fable (model: fable)" || fail "$a pins a fixed model instead of the fable alias"
done
[ -x "$SCRIPT_DIR/bin/init-claude" ] && pass "bin/init-claude present and executable" || fail "bin/init-claude missing or not executable"
[ -x "$SCRIPT_DIR/bin/update-claude" ] && pass "bin/update-claude present and executable" || fail "bin/update-claude missing or not executable"

# install.sh must NOT touch settings.json anymore — the plugin owns the wiring.
[ ! -f "$SANDBOX/.claude/settings.json" ] && pass "install.sh no longer touches settings.json" || fail "install.sh created/modified settings.json (plugin owns hook wiring now)"

# ============================================================
# SECTION: Plugin manifests (hooks/commands/agents ship as a plugin — #13)
# ============================================================
section "Plugin manifests"

node -e "const p=require('$SCRIPT_DIR/.claude-plugin/plugin.json'); process.exit(p.name==='claude-setup' && p.version ? 0 : 1)" \
  && pass "plugin.json has name + version" || fail "plugin.json missing name/version"
node -e "const m=require('$SCRIPT_DIR/.claude-plugin/marketplace.json'); process.exit(m.name && m.plugins && m.plugins.some(p=>p.name==='claude-setup') ? 0 : 1)" \
  && pass "marketplace.json lists the claude-setup plugin" || fail "marketplace.json does not list the plugin"

# The hook wiring lives in the plugin's hooks.json (settings.json is never touched).
node -e "
const h = require('$SCRIPT_DIR/hooks/hooks.json').hooks;
const flat = (e) => (h[e] || []).flatMap(x => x.hooks || []).map(x => x.command || '');
const pre = flat('PreToolUse'), post = flat('PostToolUse');
const ok = pre.some(c => c.includes('dispatch.mjs edit') && c.includes('CLAUDE_PLUGIN_ROOT'))
  && pre.some(c => c.includes('dispatch.mjs bash'))
  && post.some(c => c.includes('dispatch.mjs post-bash'))
  && (h.PreToolUse || []).some(e => e.matcher === 'Write|Edit|MultiEdit|NotebookEdit');
process.exit(ok ? 0 : 1);
" && pass "hooks.json wires edit/bash/post-bash via CLAUDE_PLUGIN_ROOT (incl. MultiEdit matcher)" || fail "hooks.json wiring incomplete"

# ============================================================
# SECTION: Idempotent re-install (rules only)
# ============================================================
section "Idempotent re-install"
"$SCRIPT_DIR/install.sh" > "$LOGS"/install-idem.log 2>&1 && pass "install.sh re-run exits 0 (idempotent rules copy)" || fail "install.sh re-run failed"

# ============================================================
# SECTION: Hook behavior
# ============================================================
section "Hook behavior"

# config-protection blocks
OUT=$(echo '{"tool_input":{"file_path":".eslintrc.json"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" edit 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "config-protection blocks .eslintrc.json" || fail "config-protection did NOT block .eslintrc.json"

# config-protection allows
OUT=$(echo '{"tool_input":{"file_path":"src/app.ts"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" edit 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "config-protection allows src/app.ts" || fail "config-protection wrongly blocked src/app.ts"

# #10: typecheck/test-runner configs are the same gaming vector as lint configs
OUT=$(echo '{"tool_input":{"file_path":"tsconfig.json"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" edit 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "config-protection blocks tsconfig.json" || fail "config-protection did NOT block tsconfig.json"
OUT=$(echo '{"tool_input":{"file_path":"vitest.config.ts"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" edit 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "config-protection blocks vitest.config.ts" || fail "config-protection did NOT block vitest.config.ts"

# #10: the floor itself is not agent-editable (path-based, not basename-based)
OUT=$(echo '{"tool_input":{"file_path":"myproj/.claude/verify.sh"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" edit 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "config-protection blocks .claude/verify.sh" || fail "config-protection did NOT block .claude/verify.sh"
OUT=$(echo '{"tool_input":{"file_path":"myproj/.claude/verify.allow-no-tests"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" edit 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "config-protection blocks the allow-no-tests marker" || fail "config-protection did NOT block the allow-no-tests marker"
OUT=$(echo '{"tool_input":{"file_path":"myproj/.git/hooks/pre-commit"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" edit 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "config-protection blocks .git/hooks/ files" || fail "config-protection did NOT block .git/hooks/ files"
# …but a verify.sh OUTSIDE .claude/ is an ordinary file
OUT=$(echo '{"tool_input":{"file_path":"scripts/verify.sh"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" edit 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "config-protection allows a verify.sh outside .claude/" || fail "config-protection wrongly blocked scripts/verify.sh"

# block-no-verify blocks
OUT=$(echo '{"tool_input":{"command":"git commit --no-verify"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "block-no-verify blocks --no-verify" || fail "block-no-verify did NOT block --no-verify"

# block-no-verify allows
OUT=$(echo '{"tool_input":{"command":"git commit -m test"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "block-no-verify allows normal commit" || fail "block-no-verify wrongly blocked normal commit"

# #6: commit's short form -n is the same flag — must be blocked
OUT=$(echo '{"tool_input":{"command":"git commit -n -m test"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "block-no-verify blocks commit -n (short form)" || fail "block-no-verify did NOT block commit -n"
OUT=$(echo '{"tool_input":{"command":"git commit -an -m test"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "block-no-verify blocks bundled -an" || fail "block-no-verify did NOT block bundled -an"
# #6: core.hooksPath overrides disable hooks wholesale — must be blocked
OUT=$(echo '{"tool_input":{"command":"git -c core.hooksPath=/dev/null commit -m x"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "block-no-verify blocks core.hooksPath -c override" || fail "block-no-verify did NOT block core.hooksPath override"
OUT=$(echo '{"tool_input":{"command":"git config core.hooksPath /tmp/nohooks"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "block-no-verify blocks git config core.hooksPath" || fail "block-no-verify did NOT block git config core.hooksPath"
# regression guards: legitimate flags that merely resemble -n stay allowed
OUT=$(echo '{"tool_input":{"command":"git commit --amend -m fix"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "block-no-verify allows commit --amend" || fail "block-no-verify wrongly blocked --amend"
OUT=$(echo '{"tool_input":{"command":"git log -n 5"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "block-no-verify allows git log -n 5" || fail "block-no-verify wrongly blocked git log -n"
# quoted mentions of a flag are data, not a bypass — must NOT block (false
# positives teach the agent to obfuscate commands)
OUT=$(echo '{"tool_input":{"command":"echo \"git commit -n is the short form\""}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "block-no-verify ignores flags inside quoted strings" || fail "block-no-verify false-blocked a quoted mention"

# suggest-compact never blocks
OUT=$(echo '{"tool_input":{"file_path":"src/app.ts"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" edit 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "suggest-compact never blocks" || fail "suggest-compact wrongly blocked"

# enforce-floor: allows non-commit git commands
OUT=$(echo '{"tool_input":{"command":"git status"}}' | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "enforce-floor allows non-commit git" || fail "enforce-floor wrongly blocked git status"

# enforce-floor: blocks commit in a code repo (package.json) with no pre-commit hook
EF_REPO="$SANDBOX/ef-nofloor"; mkdir -p "$EF_REPO"; ( cd "$EF_REPO" && git init -q && echo '{}' > package.json )
OUT=$(echo "{\"tool_input\":{\"command\":\"git commit -m x\"},\"cwd\":\"$EF_REPO\"}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "enforce-floor blocks commit when no floor wired" || fail "enforce-floor did NOT block missing floor"
# The block message is the ONLY remediation the agent gets — it must name the
# route that exists today (/init-floor), not the pre-plugin one (a bare
# `init-claude` on PATH, and an opt-out via ~/.claude/settings.json that no
# longer holds our wiring since #13).
# Capture STDERR specifically — that is where the remediation text goes (the
# $OUT captures above discard it, so asserting on them would pass vacuously).
EF_MSG=$(echo "{\"tool_input\":{\"command\":\"git commit -m x\"},\"cwd\":\"$EF_REPO\"}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>&1 >/dev/null)
echo "$EF_MSG" | grep -q '/init-floor' && pass "enforce-floor block message points at /init-floor" || fail "enforce-floor block message does not mention /init-floor"
echo "$EF_MSG" | grep -q 'settings.json' && fail "enforce-floor block message still points at ~/.claude/settings.json (plugin owns the wiring)" || pass "enforce-floor block message no longer points at settings.json"

# enforce-floor: "git commit" inside an echo/string is NOT a real commit (W7)
OUT=$(echo "{\"tool_input\":{\"command\":\"echo 'see git commit docs'\"},\"cwd\":\"$EF_REPO\"}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "enforce-floor ignores 'git commit' inside a string/echo" || fail "enforce-floor false-blocked a string mentioning git commit"
# enforce-floor: still blocks a real chained commit (regression guard for the anchor)
OUT=$(echo "{\"tool_input\":{\"command\":\"true && git commit -m x\"},\"cwd\":\"$EF_REPO\"}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "enforce-floor still blocks a chained 'git commit'" || fail "enforce-floor missed a chained git commit"

# #6: bypass shapes that dodged the old regex must still be gated
OUT=$(echo "{\"tool_input\":{\"command\":\"(git commit -m x)\"},\"cwd\":\"$EF_REPO\"}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "enforce-floor gates a subshell commit" || fail "enforce-floor missed a subshell commit"
OUT=$(printf '{"tool_input":{"command":"echo hi\\ngit commit -m x"},"cwd":"%s"}' "$EF_REPO" | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "enforce-floor gates a newline-separated commit" || fail "enforce-floor missed a newline-separated commit"
OUT=$(echo "{\"tool_input\":{\"command\":\"GIT_AUTHOR_NAME=x git commit -m y\"},\"cwd\":\"$EF_REPO\"}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "enforce-floor gates an env-var-prefixed commit" || fail "enforce-floor missed an env-var-prefixed commit"

# #6: a NON-executable pre-commit is silently skipped by git — not a wired floor
EF_NOEXEC="$SANDBOX/ef-noexec"; mkdir -p "$EF_NOEXEC"; ( cd "$EF_NOEXEC" && git init -q && echo '{}' > package.json )
touch "$EF_NOEXEC/.git/hooks/pre-commit"   # exists, but no exec bit
OUT=$(echo "{\"tool_input\":{\"command\":\"git commit -m x\"},\"cwd\":\"$EF_NOEXEC\"}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "enforce-floor blocks when pre-commit exists but is not executable" || fail "enforce-floor accepted a non-executable pre-commit"

# enforce-floor: allows commit once the pre-commit hook exists
touch "$EF_REPO/.git/hooks/pre-commit"; chmod +x "$EF_REPO/.git/hooks/pre-commit"
OUT=$(echo "{\"tool_input\":{\"command\":\"git commit -m x\"},\"cwd\":\"$EF_REPO\"}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "enforce-floor allows commit when floor wired" || fail "enforce-floor blocked despite floor present"

# enforce-floor: allows commit in a non-code repo (no manifest)
EF_DOCS="$SANDBOX/ef-docs"; mkdir -p "$EF_DOCS"; ( cd "$EF_DOCS" && git init -q && echo hi > README.md )
OUT=$(echo "{\"tool_input\":{\"command\":\"git commit -m x\"},\"cwd\":\"$EF_DOCS\"}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "enforce-floor allows commit in non-code repo" || fail "enforce-floor wrongly blocked non-code repo"

# ── #12: post-bash commit-watchdog — state-based, spelling-proof ──
EF_POST="$SANDBOX/ef-post"; mkdir -p "$EF_POST"
( cd "$EF_POST" && git init -q && git config user.email t@e.com && git config user.name T \
  && echo '{}' > package.json && git add -A && git commit -q -m first )
post_event() { echo "{\"session_id\":\"posttest\",\"tool_input\":{\"command\":\"anything\"},\"cwd\":\"$EF_POST\"}"; }

# non-git cwd → silent
OUT=$(echo "{\"session_id\":\"posttest\",\"tool_input\":{\"command\":\"x\"},\"cwd\":\"$SANDBOX\"}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" post-bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "watchdog: silent outside a git repo" || fail "watchdog fired outside a git repo"

# first sighting initializes the HEAD cache — no flag
OUT=$(post_event | node "$SCRIPT_DIR/hooks/dispatch.mjs" post-bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "watchdog: first sighting initializes silently" || fail "watchdog flagged on first sighting"

# a fresh commit lands with NO floor wired → flagged, however it was spelled
( cd "$EF_POST" && echo x > f.txt && git add f.txt && git commit -q -m second )
OUT=$(post_event | node "$SCRIPT_DIR/hooks/dispatch.mjs" post-bash 2>&1; echo "EXIT:$?")
if echo "$OUT" | grep -q "EXIT:2" && echo "$OUT" | grep -qi "FLOOR VIOLATION"; then
  pass "watchdog: flags a fresh commit that landed without a floor (state-based)"
else
  fail "watchdog: missed a floorless commit"
fi

# same state again (HEAD unchanged) → silent, no repeat nagging
OUT=$(post_event | node "$SCRIPT_DIR/hooks/dispatch.mjs" post-bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "watchdog: does not re-flag an unchanged HEAD" || fail "watchdog re-flagged without a new commit"

# floor wired → a fresh commit is silent
touch "$EF_POST/.git/hooks/pre-commit"; chmod +x "$EF_POST/.git/hooks/pre-commit"
( cd "$EF_POST" && echo y >> f.txt && git add f.txt && git commit -q -m third )
OUT=$(post_event | node "$SCRIPT_DIR/hooks/dispatch.mjs" post-bash 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "watchdog: silent when the floor is wired" || fail "watchdog flagged despite a wired floor"

# ============================================================
# SECTION: review gate — the code-reviewer pass is enforced, not remembered
# ============================================================
# workflow.md makes a code-reviewer pass mandatory per chunk, but nothing
# enforced it: the review that caught every real bug in practice was the one
# step left to the model's memory. Edits tally changed code lines per session
# and repo; starting the code-reviewer resets the tally; a commit over the gate
# is blocked.
section "review gate"

RG="$SANDBOX/rg-repo"; mkdir -p "$RG/src"; ( cd "$RG" && git init -q && echo '{}' > package.json )
touch "$RG/.git/hooks/pre-commit"; chmod +x "$RG/.git/hooks/pre-commit"   # floor wired: only the gate decides
RG_DOCS="$SANDBOX/rg-docs"; mkdir -p "$RG_DOCS"; ( cd "$RG_DOCS" && git init -q )
lines() { node -e "process.stdout.write(JSON.stringify(Array.from({length:$1},(_,i)=>'line'+i).join('\\n')))"; }
# gate_write <session> <file> <n-lines>   gate_commit <session> [cwd] [command]   gate_agent <session> <type>
gate_write() { echo "{\"session_id\":\"$1\",\"cwd\":\"$RG\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$2\",\"content\":$(lines "$3")}}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" post-edit >/dev/null 2>&1; }
gate_commit() { echo "{\"session_id\":\"$1\",\"cwd\":\"${2:-$RG}\",\"tool_input\":{\"command\":\"${3:-git commit -m x}\"}}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" bash 2>&1 >/dev/null; echo "EXIT:$?"; }
gate_agent() { echo "{\"session_id\":\"$1\",\"cwd\":\"$RG\",\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"$2\",\"prompt\":\"review\"}}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" agent >/dev/null 2>&1; }

gate_write rg1 "$RG/src/a.js" 25
OUT=$(gate_commit rg1)
if echo "$OUT" | grep -q "EXIT:2" && echo "$OUT" | grep -q "code-reviewer"; then
  pass "review gate: blocks a commit of 25 unreviewed code lines, naming the code-reviewer"
else
  fail "review gate: let 25 unreviewed code lines be committed"
fi
gate_agent rg1 "claude-setup:code-reviewer"
B=$(gate_commit rg1)
echo "$OUT$B" | tr -d '\n' | grep -q "EXIT:2.*EXIT:0" && pass "review gate: a code-reviewer run unblocks the commit" \
  || fail "review gate: code-reviewer run did not unblock (or nothing was blocked)"

gate_write rg2 "$RG/src/a.js" 25; gate_agent rg2 "Explore"
OUT=$(gate_commit rg2)
echo "$OUT" | grep -q "EXIT:2" && pass "review gate: another subagent does not count as a review" || fail "review gate: a non-reviewer subagent reset the gate"

gate_write rg3 "$RG/src/a.js" 5
A=$(gate_commit rg3); gate_write rg3 "$RG/src/b.js" 20; B=$(gate_commit rg3)
echo "$A$B" | tr -d '\n' | grep -q "EXIT:0.*EXIT:2" && pass "review gate: small edits pass, and they accumulate to the gate" \
  || fail "review gate: small edits blocked, or small edits never accumulate"

gate_write rg4 "$RG/README.md" 200; gate_write rg4 "$RG_DOCS/notes.js" 200
A=$(gate_commit rg4); gate_write rg4 "$RG/src/a.js" 25; B=$(gate_commit rg4)
echo "$A$B" | tr -d '\n' | grep -q "EXIT:0.*EXIT:2" && pass "review gate: docs and non-code-repo edits don't count" \
  || fail "review gate: docs/non-code edits counted, or code edits stopped counting"

# The session cwd needn't be the repo: \`cd repo && git commit\` from elsewhere is still gated.
gate_write rg5 "$RG/src/a.js" 25
OUT=$(gate_commit rg5 "$SANDBOX" "cd $RG && git commit -m x")
echo "$OUT" | grep -q "EXIT:2" && pass "review gate: a commit from outside the repo's cwd is still gated" || fail "review gate: dodged by committing from another cwd"

# W2: tallying BEFORE the edit counted failed ("old_string not found") and
# denied edits, and every retry again. Only a completed edit counts.
gate_pre() { echo "{\"session_id\":\"$1\",\"cwd\":\"$RG\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$RG/src/a.js\",\"content\":$(lines 25)}}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" edit >/dev/null 2>&1; }
gate_pre rg7; A=$(gate_commit rg7); gate_write rg7 "$RG/src/a.js" 25; B=$(gate_commit rg7)
echo "$A$B" | tr -d '\n' | grep -q "EXIT:0.*EXIT:2" && pass "review gate: only completed edits count (attempts/retries don't)" \
  || fail "review gate: an edit attempt counted before it happened, or completed edits don't count"

# W3: every edit shape tallies what it changed (read the tally itself).
tally() { cat "$SANDBOX/.claude/metrics/.review-$1" 2>/dev/null || echo 0; }
post_edit() { echo "{\"session_id\":\"$1\",\"cwd\":\"$RG\",\"tool_name\":\"$2\",\"tool_input\":$3}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" post-edit >/dev/null 2>&1; }
post_edit rg8 Edit "{\"file_path\":\"$RG/src/a.js\",\"old_string\":\"a\\nb\",\"new_string\":\"a\\nb\\nc\"}"
[ "$(tally rg8)" = 3 ] && pass "review gate: Edit counts its larger side" || fail "review gate: Edit tallied $(tally rg8), expected 3"
post_edit rg9 MultiEdit "{\"file_path\":\"$RG/src/a.js\",\"edits\":[{\"old_string\":\"x\",\"new_string\":\"x\\ny\"},{\"old_string\":\"p\\nq\\nr\",\"new_string\":\"p\"}]}"
[ "$(tally rg9)" = 5 ] && pass "review gate: MultiEdit sums its edits" || fail "review gate: MultiEdit tallied $(tally rg9), expected 5"
post_edit rg10 NotebookEdit "{\"notebook_path\":\"$RG/nb.ipynb\",\"new_source\":\"import x\\nx.run()\"}"
[ "$(tally rg10)" = 2 ] && pass "review gate: NotebookEdit counts its new source" || fail "review gate: NotebookEdit tallied $(tally rg10), expected 2"
post_edit rg11 Write "{\"file_path\":\"$RG/src/a.js\",\"content\":\"a\\nb\\n\"}"
[ "$(tally rg11)" = 2 ] && pass "review gate: a trailing newline is not an extra line" || fail "review gate: 'a\\\\nb\\\\n' tallied $(tally rg11), expected 2"

# W1: a docs-repo commit isn't gated by code edits elsewhere — reviewing the docs
# diff would reset the tally and let the real code commit through unreviewed.
# Committing into a code repo via cd/-C from that cwd is still gated.
gate_write rg12 "$RG/src/a.js" 25
A=$(gate_commit rg12 "$RG_DOCS"); B=$(gate_commit rg12 "$RG_DOCS" "cd $RG && git commit -m x"); C=$(gate_commit rg12 "$RG_DOCS" "git -C $RG commit -m x")
echo "$A$B$C" | tr -d '\n' | grep -q "EXIT:0.*EXIT:2.*EXIT:2" && pass "review gate: docs-repo commits pass; cd/-C into the code repo is still gated" \
  || fail "review gate: blocked a docs-repo commit, or cd/-C dodges the gate"

# The tally is the gate's state — Claude can't zero it with an edit.
OUT=$(echo "{\"tool_input\":{\"file_path\":\"$SANDBOX/.claude/metrics/.review-rg1\"}}" | node "$SCRIPT_DIR/hooks/dispatch.mjs" edit 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "review gate: the tally file is protected from edits" || fail "review gate: the tally file can be edited to zero"

node -e "
const h = require('$SCRIPT_DIR/hooks/hooks.json').hooks.PostToolUse || [];
process.exit(h.some(e => /\bEdit\b/.test(e.matcher) && /\bWrite\b/.test(e.matcher) && /\bMultiEdit\b/.test(e.matcher) && /\bNotebookEdit\b/.test(e.matcher) && e.hooks.some(x => x.command.includes('dispatch.mjs post-edit'))) ? 0 : 1)" \
  && pass "review gate: completed edits are wired to the post-edit role" || fail "review gate: post-edit role not wired — nothing would ever be tallied"

node -e "
const h = require('$SCRIPT_DIR/hooks/hooks.json').hooks.PreToolUse || [];
process.exit(h.some(e => /\bAgent\b/.test(e.matcher) && /\bTask\b/.test(e.matcher) && e.hooks.some(x => x.command.includes('dispatch.mjs agent'))) ? 0 : 1)" \
  && pass "review gate: Agent|Task calls are wired to the agent role" || fail "review gate: subagent calls not wired — reviews would never register"

# ============================================================
# SECTION: verify.sh stack & runner detection
# ============================================================
# These run verify.sh against synthetic repos with PATH-shimmed package
# managers (fake pnpm/uv/poetry/npm that just log + exit 0). We assert which
# runner verify.sh reached for — no real toolchain required. The contract:
#   - pick the Node manager from the lockfile (false-green if npm runs a pnpm tree)
#   - run Python tools THROUGH the env (uv run / poetry run), never bare on $PATH
#     (a global pytest collecting 0 tests outside the venv is a silent false-green)
#   - honour VERIFY_ROOTS so a backend/+frontend/ monorepo gets BOTH suites run
section "verify.sh stack & runner detection"

VERIFY="$SCRIPT_DIR/template/verify.sh"
SHIMDIR="$SANDBOX/shims"
SHIMLOG="$SANDBOX/shim.log"

# Fake executable that records "name + args" and exits 0
mkshim() {
  cat > "$SHIMDIR/$1" <<EOF
#!/bin/bash
echo "$1 \$*" >> "$SHIMLOG"
exit 0
EOF
  chmod +x "$SHIMDIR/$1"
}
reset_shims() { rm -rf "$SHIMDIR"; mkdir -p "$SHIMDIR"; : > "$SHIMLOG"; }

# Canary shims. A tool that is ENFORCING flags the known-bad fixture (non-zero +
# the expected diagnostic); a tool that has gone SILENT (rule disabled, no files
# matched) exits 0 on it. mkshim() above is already the silent case.
mkshim_enforcing() { # $1=name $2=diagnostic it prints when handed the canary
  cat > "$SHIMDIR/$1" <<EOF
#!/bin/bash
echo "$1 \$*" >> "$SHIMLOG"
for a in "\$@"; do
  case "\$a" in *verify-canary*) echo "\$a:1:1: $2 canary violation"; exit 1;; esac
done
exit 0
EOF
  chmod +x "$SHIMDIR/$1"
}
mkshim_crashing() { # $1=name — non-zero but NO expected diagnostic (crash/missing dep)
  cat > "$SHIMDIR/$1" <<EOF
#!/bin/bash
echo "$1 \$*" >> "$SHIMLOG"
for a in "\$@"; do
  case "\$a" in *verify-canary*) echo "Traceback: tool exploded"; exit 2;; esac
done
exit 0
EOF
  chmod +x "$SHIMDIR/$1"
}
run_verify() { # $1=repo dir, $2=VERIFY_ROOTS (optional), $3=extra flag (e.g. --quick)
  ( cd "$1" && PATH="$SHIMDIR:$PATH" VERIFY_ROOTS="${2:-.}" bash "$VERIFY" ${3:-} >/dev/null 2>&1 )
}

# --- Node: pnpm-lock.yaml → pnpm, not npm ---
reset_shims; mkshim pnpm; mkshim npm
R="$SANDBOX/v-pnpm"; mkdir -p "$R"
printf '{ "scripts": { "lint": "x", "test": "x" } }\n' > "$R/package.json"
touch "$R/pnpm-lock.yaml"
run_verify "$R"
grep -q '^pnpm ' "$SHIMLOG" && pass "verify: uses pnpm when pnpm-lock.yaml present" || fail "verify: did not use pnpm for a pnpm repo"
grep -q '^npm '  "$SHIMLOG" && fail "verify: fell back to npm despite pnpm-lock.yaml" || pass "verify: does not invoke npm when pnpm is the manager"

# --- Node: no lockfile → npm default ---
reset_shims; mkshim pnpm; mkshim npm
R="$SANDBOX/v-npm"; mkdir -p "$R"
printf '{ "scripts": { "test": "x" } }\n' > "$R/package.json"
run_verify "$R"
grep -q '^npm '  "$SHIMLOG" && pass "verify: defaults to npm when no lockfile" || fail "verify: did not default to npm"

# --- Node: yarn.lock → yarn ---
reset_shims; mkshim yarn; mkshim npm
R="$SANDBOX/v-yarn"; mkdir -p "$R"
printf '{ "scripts": { "test": "x" } }\n' > "$R/package.json"
touch "$R/yarn.lock"
run_verify "$R"
grep -q '^yarn ' "$SHIMLOG" && pass "verify: uses yarn when yarn.lock present" || fail "verify: did not use yarn for a yarn repo"

# --- Python: uv.lock → 'uv run', never bare pytest ---
reset_shims; mkshim uv; mkshim pytest; mkshim ruff; mkshim mypy
R="$SANDBOX/v-uv"; mkdir -p "$R"
printf '[project]\nname = "x"\n' > "$R/pyproject.toml"
touch "$R/uv.lock"
run_verify "$R"
grep -q '^uv run'  "$SHIMLOG" && pass "verify: runs Python tools via 'uv run' when uv.lock present" || fail "verify: did not use 'uv run' for a uv project"
grep -q '^pytest ' "$SHIMLOG" && fail "verify: ran bare pytest (false-green risk) despite uv.lock" || pass "verify: does not run bare pytest when uv is the runner"

# --- Python: poetry.lock → 'poetry run' ---
reset_shims; mkshim poetry; mkshim pytest
R="$SANDBOX/v-poetry"; mkdir -p "$R"
printf '[tool.poetry]\nname = "x"\n' > "$R/pyproject.toml"
touch "$R/poetry.lock"
run_verify "$R"
grep -q '^poetry run' "$SHIMLOG" && pass "verify: runs Python tools via 'poetry run' when poetry.lock present" || fail "verify: did not use 'poetry run' for a poetry project"

# --- Monorepo: VERIFY_ROOTS runs BOTH sub-stacks (Gap 1) ---
reset_shims; mkshim uv; mkshim pnpm; mkshim pytest; mkshim npm
R="$SANDBOX/v-mono"; mkdir -p "$R/backend" "$R/frontend"
printf '[project]\nname = "x"\n' > "$R/backend/pyproject.toml"
touch "$R/backend/uv.lock"
printf '{ "scripts": { "test": "x" } }\n' > "$R/frontend/package.json"
touch "$R/frontend/pnpm-lock.yaml"
run_verify "$R" "backend frontend"
grep -q '^uv run' "$SHIMLOG"   && pass "verify: VERIFY_ROOTS runs the backend (uv) suite" || fail "verify: skipped backend suite under VERIFY_ROOTS"
grep -q '^pnpm '  "$SHIMLOG"   && pass "verify: VERIFY_ROOTS runs the frontend (pnpm) suite" || fail "verify: skipped frontend suite under VERIFY_ROOTS"

# --- #1: a code stack with no test floor hard-fails, unless explicitly opted out ---
reset_shims; mkshim npm
R="$SANDBOX/v-notest"; mkdir -p "$R"
printf '{ "scripts": { "lint": "x" } }\n' > "$R/package.json"   # lint only, no test script
run_verify "$R"; rc=$?
[ "$rc" -ne 0 ] && pass "verify: missing test floor hard-fails (blocks)" || fail "verify: missing test floor passed — should block"
mkdir -p "$R/.claude"; touch "$R/.claude/verify.allow-no-tests"   # deliberate, visible opt-out
run_verify "$R"; rc=$?
[ "$rc" -eq 0 ] && pass "verify: .claude/verify.allow-no-tests opts out of the hard-fail" || fail "verify: opt-out marker did not pass"

# --- #14: --quick runs lint/typecheck but NOT tests (the push/CI tier's job) ---
reset_shims; mkshim npm
R="$SANDBOX/v-quick"; mkdir -p "$R"
printf '{ "scripts": { "lint": "x", "test": "x" } }\n' > "$R/package.json"
run_verify "$R" "." "--quick"
grep -q '^npm run lint' "$SHIMLOG" && pass "verify --quick: runs lint" || fail "verify --quick: did not run lint"
grep -q '^npm run test' "$SHIMLOG" && fail "verify --quick: ran tests (they belong to the push tier)" || pass "verify --quick: skips tests"
# quick passes a repo with NO test script — the full tier still hard-fails it
reset_shims; mkshim npm
R="$SANDBOX/v-quick-notest"; mkdir -p "$R"
printf '{ "scripts": { "lint": "x" } }\n' > "$R/package.json"
run_verify "$R" "." "--quick"; rc=$?
[ "$rc" -eq 0 ] && pass "verify --quick: no-test repo passes quick tier" || fail "verify --quick: blocked a no-test repo at commit time"
run_verify "$R"; rc=$?
[ "$rc" -ne 0 ] && pass "verify (full): no-test repo still hard-fails" || fail "verify (full): no-test repo passed"

# --- #7: a manifest verify.sh can't verify must NOT false-green the floor ---
reset_shims
R="$SANDBOX/v-go"; mkdir -p "$R"
printf 'module example.com/x\n' > "$R/go.mod"
run_verify "$R"; rc=$?
[ "$rc" -ne 0 ] && pass "verify: unsupported stack (go.mod) blocks instead of false-greening" || fail "verify: go.mod repo passed with zero checks (false green)"
mkdir -p "$R/.claude"; touch "$R/.claude/verify.allow-no-tests"
run_verify "$R"; rc=$?
[ "$rc" -eq 0 ] && pass "verify: unsupported stack can be accepted via allow-no-tests marker" || fail "verify: opt-out marker did not pass an unsupported stack"

# ============================================================
# SECTION: canaries — prove the tools are ENFORCING, not just exiting 0
# ============================================================
# A check that exits 0 because it checked nothing is indistinguishable from a
# check that passed, and the single-script design means all three gates agree
# on that false green simultaneously. The canary hands each tool a known-bad
# fixture and requires it to complain.
section "verify.sh canaries (silently-lowered floor)"

PYCAN="$SANDBOX/v-canary-py"
setup_pycan() { rm -rf "$PYCAN"; mkdir -p "$PYCAN"; printf '[project]\nname = "x"\n' > "$PYCAN/pyproject.toml"; }

# --- enforcing tool: canary fires, floor is green ---
reset_shims; mkshim_enforcing ruff "invalid-syntax"; mkshim_enforcing mypy "[syntax]"; mkshim pytest
setup_pycan; run_verify "$PYCAN"; rc=$?
[ "$rc" -eq 0 ] && pass "canary: green when the tools flag the known-bad fixture" || fail "canary: false red when tools are enforcing"
grep -q 'verify-canary' "$SHIMLOG" && pass "canary: the fixture is actually handed to the tool" || fail "canary: tool was never invoked on a fixture"

# --- silent tool: exits 0 on a known-bad file → the floor is lowered → RED ---
reset_shims; mkshim ruff; mkshim_enforcing mypy "[syntax]"; mkshim pytest
setup_pycan; run_verify "$PYCAN"; rc=$?
[ "$rc" -ne 0 ] && pass "canary: RED when a tool exits 0 on the known-bad fixture" || fail "canary: silent tool passed — this is the bug the canary exists to catch"

# --- non-zero but no expected diagnostic: inconclusive, must NOT be a silent pass ---
reset_shims; mkshim_crashing ruff; mkshim_enforcing mypy "[syntax]"; mkshim pytest
setup_pycan; OUT=$( cd "$PYCAN" && PATH="$SHIMDIR:$PATH" bash "$VERIFY" 2>&1 ); rc=$?
echo "$OUT" | grep -qi "inconclusive" && pass "canary: a crashing tool is reported inconclusive, not counted as fired" || fail "canary: a crash masqueraded as a passing canary"
[ "$rc" -eq 0 ] && pass "canary: inconclusive does not become a false red" || fail "canary: inconclusive turned the floor red"

# --- quick tier stays fast: no canary work at commit time ---
reset_shims; mkshim ruff; mkshim mypy; mkshim pytest
setup_pycan; run_verify "$PYCAN" "." "--quick"; rc=$?
[ "$rc" -eq 0 ] && pass "canary: --quick stays green (canaries are a full-tier check)" || fail "canary: --quick was slowed/failed by canaries"
grep -q 'verify-canary' "$SHIMLOG" && fail "canary: --quick ran canaries (commit-time tax)" || pass "canary: --quick runs no canaries"

# --- the fixture never survives the run ---
reset_shims; mkshim_enforcing ruff "invalid-syntax"; mkshim_enforcing mypy "[syntax]"; mkshim pytest
setup_pycan; run_verify "$PYCAN"
ls -d "$PYCAN"/.verify-canary-* >/dev/null 2>&1 && fail "canary: fixture left behind in the project" || pass "canary: fixture cleaned up after the run"

# --- TypeScript: a silent tsc (matched no files / strict off) turns the floor RED ---
reset_shims; mkshim npm; mkshim tsc
TSCAN="$SANDBOX/v-canary-ts"; mkdir -p "$TSCAN"
printf '{ "scripts": { "typecheck": "tsc --noEmit", "test": "x" } }\n' > "$TSCAN/package.json"
printf '{ "compilerOptions": { "strict": true } }\n' > "$TSCAN/tsconfig.json"
run_verify "$TSCAN"; rc=$?
[ "$rc" -ne 0 ] && pass "canary: RED when tsc exits 0 on a known-bad type" || fail "canary: silent tsc passed"

# --- ESLint: enforcing / silent / ignored-fixture (flat-config files matching) ---
mk_node_canary_repo() { # $1=dir
  rm -rf "$1"; mkdir -p "$1"
  printf '{ "scripts": { "test": "x" } }\n' > "$1/package.json"
  printf 'export default [];\n' > "$1/eslint.config.mjs"
}
ESCAN="$SANDBOX/v-canary-es"

reset_shims; mkshim npm; mkshim_enforcing eslint "Parsing error"
mk_node_canary_repo "$ESCAN"; run_verify "$ESCAN"; rc=$?
[ "$rc" -eq 0 ] && pass "canary: green when eslint flags the known-bad fixture" || fail "canary: false red on an enforcing eslint"
grep -q 'verify-canary' "$SHIMLOG" && pass "canary: eslint was actually handed the fixture" || fail "canary: eslint canary never ran"

reset_shims; mkshim npm; mkshim eslint
mk_node_canary_repo "$ESCAN"; run_verify "$ESCAN"; rc=$?
[ "$rc" -ne 0 ] && pass "canary: RED when eslint exits 0 on the known-bad fixture" || fail "canary: silent eslint passed"

# An eslint that SKIPS the fixture (no matching flat config / ignored) proves
# nothing either way — it must be inconclusive, never a false red.
reset_shims; mkshim npm
cat > "$SHIMDIR/eslint" <<'EOF'
#!/bin/bash
echo "eslint $*" >> "$SHIMLOG_PLACEHOLDER"
echo "warning: File ignored because of a matching ignore pattern."
exit 0
EOF
sed -i '' "s|\$SHIMLOG_PLACEHOLDER|$SHIMLOG|" "$SHIMDIR/eslint" 2>/dev/null || sed -i "s|\$SHIMLOG_PLACEHOLDER|$SHIMLOG|" "$SHIMDIR/eslint"
chmod +x "$SHIMDIR/eslint"
mk_node_canary_repo "$ESCAN"
OUT=$( cd "$ESCAN" && PATH="$SHIMDIR:$PATH" bash "$VERIFY" 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && pass "canary: an eslint that skips the fixture is not a false red" || fail "canary: false red when eslint never examined the fixture"
echo "$OUT" | grep -qi "inconclusive" && pass "canary: a skipped eslint fixture is reported inconclusive" || fail "canary: skipped fixture was silently treated as proof"

# S3: the Node quick tier must also skip canary work (early return).
reset_shims; mkshim npm; mkshim eslint
mk_node_canary_repo "$ESCAN"; run_verify "$ESCAN" "." "--quick"; rc=$?
[ "$rc" -eq 0 ] && pass "canary: node --quick stays green (no canaries at commit time)" || fail "canary: node --quick was failed by canaries"
grep -q 'verify-canary' "$SHIMLOG" && fail "canary: node --quick ran canaries (commit-time tax)" || pass "canary: node --quick runs no canaries"

# A rule probe that does not fire is ADVISORY only — never a red (a project may
# legitimately disable that rule; a false red gets the whole canary deleted).
reset_shims; mkshim npm
cat > "$SHIMDIR/eslint" <<'EOF'
#!/bin/bash
for a in "$@"; do
  case "$a" in *canary_syntax*) echo "Parsing error: unexpected token"; exit 1;; esac
done
exit 0
EOF
chmod +x "$SHIMDIR/eslint"
mk_node_canary_repo "$ESCAN"
OUT=$( cd "$ESCAN" && PATH="$SHIMDIR:$PATH" bash "$VERIFY" 2>&1 ); rc=$?
[ "$rc" -eq 0 ] && pass "canary: a disabled RULE is advisory, not a red" || fail "canary: a disabled rule false-redded the floor"
echo "$OUT" | grep -qi "ADVISORY" && pass "canary: the disabled rule is surfaced as an advisory" || fail "canary: disabled rule was silent"

# --- actionlint: lint GitHub Actions workflows when present (catch bugs locally) ---
reset_shims; mkshim actionlint
R="$SANDBOX/v-wf"; mkdir -p "$R/.github/workflows"
printf 'name: x\non: push\n' > "$R/.github/workflows/ci.yml"
run_verify "$R"; rc=$?
grep -q '^actionlint' "$SHIMLOG" && pass "verify: runs actionlint on workflows when present" || fail "verify: did not run actionlint on a repo with workflows"
[ "$rc" -eq 0 ] && pass "verify: green when actionlint is happy" || fail "verify: failed despite actionlint passing"
# actionlint reports a problem → verify fails
rm -rf "$SHIMDIR"; mkdir -p "$SHIMDIR"; : > "$SHIMLOG"
printf '#!/bin/bash\nexit 1\n' > "$SHIMDIR/actionlint"; chmod +x "$SHIMDIR/actionlint"
run_verify "$R"; rc=$?
[ "$rc" -ne 0 ] && pass "verify: fails when actionlint reports a workflow problem" || fail "verify: ignored an actionlint failure"

# ============================================================
# SECTION: cross-vendor logic reviewer (review-diff.mjs)
# ============================================================
# The reviewer's logic lives in pure, exported functions; the network call is a
# thin IO shell. We unit-test the pure core by importing it (no API, no toolchain)
# and exercise the one catastrophic path (missing key) through the binary itself.
section "cross-vendor logic reviewer"

REV="$SCRIPT_DIR/template/bin/review-diff.mjs"
# Import the module and run a snippet of JS against it; exit code = the assertion.
rev() { node --input-type=module -e "const m=await import('file://$REV'); $1" 2>/dev/null; }

# --- payload safety: temperature 0, JSON mode, untrusted-data framing ---
rev "const p=m.buildPayload({systemPrompt:'s',diff:'d',model:'x'}); process.exit(p.temperature===0?0:1)" \
  && pass "reviewer: payload pins temperature 0" || fail "reviewer: payload does not pin temperature 0"
rev "const p=m.buildPayload({systemPrompt:'s',diff:'d',model:'x'}); process.exit(p.response_format?.type==='json_object'?0:1)" \
  && pass "reviewer: payload requests JSON output mode" || fail "reviewer: payload does not request JSON mode"
rev "const p=m.buildPayload({systemPrompt:'s',diff:'DIFFBODY',model:'x'}); const u=p.messages.find(x=>x.role==='user').content; process.exit(u.includes('UNTRUSTED')&&u.includes('DIFFBODY')?0:1)" \
  && pass "reviewer: diff is framed as untrusted data (injection guard)" || fail "reviewer: diff not framed as untrusted data"
# OpenRouter's default load-balancing is price-weighted across ~15 providers of
# mixed speed; a slow pick blew the timeout on #34/#35. Ask for the fastest —
# but only of OpenRouter: a local OpenAI-compatible server may reject the field.
rev "const p=m.buildPayload({systemPrompt:'s',diff:'d',model:'x',openrouter:true}); process.exit(p.provider?.sort==='throughput'?0:1)" \
  && pass "reviewer: OpenRouter requests are routed to the fastest providers" || fail "reviewer: OpenRouter requests use price-weighted routing"
# Throughput routing alone picked a provider that defaults reasoning OFF (#36:
# "2s via Azure, 0 reasoning tokens") — faster because it stopped thinking.
# Ask for reasoning explicitly instead of inheriting each provider's default.
rev "const p=m.buildPayload({systemPrompt:'s',diff:'d',model:'x',openrouter:true}); process.exit(p.reasoning?.enabled===true?0:1)" \
  && pass "reviewer: OpenRouter requests ask for reasoning explicitly" || fail "reviewer: reasoning left to each provider's default"
# ...but must not REQUIRE it: the default model (deepseek/deepseek-chat) has no
# provider that accepts `reasoning`, so require_parameters makes it unroutable.
rev "const p=m.buildPayload({systemPrompt:'s',diff:'d',model:'x',openrouter:true}); process.exit(p.provider?.require_parameters!==true?0:1)" \
  && pass "reviewer: a model without reasoning support stays routable" || fail "reviewer: require_parameters makes non-reasoning models unroutable"
rev "const p=m.buildPayload({systemPrompt:'s',diff:'d',model:'x'}); process.exit(p.provider===undefined&&p.reasoning===undefined?0:1)" \
  && pass "reviewer: non-OpenRouter endpoints get no provider/reasoning fields" || fail "reviewer: OpenRouter-only fields sent to another endpoint"
# Successful code reviews already spent 70–90s in the model; 120s left no margin.
REVIEW_TIMEOUT_MS= rev "process.exit(m.TIMEOUT_MS===300000?0:1)" \
  && pass "reviewer: default model timeout is 300s" || fail "reviewer: default model timeout is not 300s"
# Both ledger false positives were claims about code just outside a 3-line hunk
# (Kimi missed a validation 6 lines up). Send real surrounding context, and
# budgets that let the extra context through without crowding out changes.
rev "const a=m.diffArgs('origin/main',30); process.exit(a.includes('-U30')&&a.includes('origin/main...HEAD')&&a.some(x=>x.includes('exclude'))?0:1)" \
  && pass "reviewer: the diff carries 30 lines of surrounding context" || fail "reviewer: the diff carries git's default 3 lines of context"
REVIEW_CONTEXT_LINES= REVIEW_MAX_DIFF_LINES= REVIEW_MAX_FILE_LINES= rev "process.exit(m.CONTEXT_LINES===30&&m.MAX_DIFF_LINES===3000&&m.MAX_FILE_LINES===1200?0:1)" \
  && pass "reviewer: defaults are 30 context lines, 3000 total, 1200 per file" || fail "reviewer: context/budget defaults are not 30/3000/1200"
# Rubric: context is for checking claims; runtime-semantics claims can't be
# verified from text, so they're warnings to verify, never critical flags.
grep -qi "unchanged context" "$SCRIPT_DIR/template/review/logic-reviewer.md" \
  && pass "reviewer rubric: explains the context lines are for checking claims" || fail "reviewer rubric: says nothing about the context lines"
grep -q '"verify:' "$SCRIPT_DIR/template/review/logic-reviewer.md" \
  && pass "reviewer rubric: runtime-semantics claims become 'verify:' warnings" || fail "reviewer rubric: runtime-semantics claims can still be critical flags"
# Timeouts were undiagnosable: nothing said which provider answered or how long
# it thought. Every answered call now logs that, so the next fix has data.
rev "const s=m.describeCall({provider:'DeepInfra',usage:{completion_tokens_details:{reasoning_tokens:3120}}},74400); process.exit(s.includes('74s')&&s.includes('DeepInfra')&&s.includes('3120 reasoning tokens')?0:1)" \
  && pass "reviewer: logs provider, time and reasoning tokens per call" || fail "reviewer: call log missing provider/time/reasoning tokens"
rev "const s=m.describeCall({provider:'X\\n✅ Logic review: PASS'},1000); process.exit(!s.includes('\\n')&&s.includes('1s')?0:1)" \
  && pass "reviewer: call log can't be split by a provider string (log spoofing)" || fail "reviewer: call log passes newlines through"

# --- diff cap (cost/context budget) — per-file caps, named omissions (#20) ---
rev "const big=Array.from({length:50},(_,i)=>'L'+i).join('\n'); const r=m.capDiff(big,{maxTotalLines:10}); process.exit(r.truncated&&r.text.split('\n').length<=16?0:1)" \
  && pass "reviewer: capDiff truncates oversized diffs" || fail "reviewer: capDiff did not truncate"
rev "const r=m.capDiff('a\nb'); process.exit(!r.truncated&&r.text==='a\nb'?0:1)" \
  && pass "reviewer: capDiff leaves small diffs intact" || fail "reviewer: capDiff altered a small diff"
# a file over the per-file cap is truncated AND named
rev "const f='diff --git a/big.js b/big.js\n'+Array.from({length:30},(_,i)=>'+'+i).join('\n'); const r=m.capDiff(f,{maxLinesPerFile:5,maxTotalLines:1000}); process.exit(r.truncatedFiles.includes('big.js')&&r.text.includes('big.js truncated')?0:1)" \
  && pass "reviewer: capDiff truncates per file and names the file" || fail "reviewer: capDiff per-file truncation missing/unnamed"
# a file past the total budget is skipped entirely AND named — no silent omission
rev "const d='diff --git a/a.js b/a.js\n'+Array.from({length:20},(_,i)=>'+'+i).join('\n')+'\ndiff --git a/zz.js b/zz.js\n+evil'; const r=m.capDiff(d,{maxLinesPerFile:100,maxTotalLines:10}); process.exit(r.skippedFiles.includes('zz.js')&&r.text.includes('NOT included')&&r.text.includes('zz.js')?0:1)" \
  && pass "reviewer: capDiff names files skipped by the total budget (evasion guard)" || fail "reviewer: capDiff silently dropped a file"
# untouched multi-file diffs report every file included
rev "const d='diff --git a/a.js b/a.js\n+x\ndiff --git a/b.js b/b.js\n+y'; const r=m.capDiff(d); process.exit(!r.truncated&&r.fileCount===2&&r.skippedFiles.length===0?0:1)" \
  && pass "reviewer: capDiff reports file count with zero omissions when under budget" || fail "reviewer: capDiff miscounted an under-budget diff"

# --- verdict parsing (structured output, not regex) ---
rev "const v=m.parseVerdict({choices:[{message:{content:JSON.stringify({status:'PASS',critical_flags:[],warnings:[]})}}]}); process.exit(v.status==='PASS'?0:1)" \
  && pass "reviewer: parses a PASS verdict" || fail "reviewer: failed to parse PASS verdict"
rev "const v=m.parseVerdict({choices:[{message:{content:JSON.stringify({status:'REJECT',critical_flags:['boom'],warnings:[]})}}]}); process.exit(v.status==='REJECT'&&v.critical_flags[0]==='boom'?0:1)" \
  && pass "reviewer: parses a REJECT verdict with critical flags" || fail "reviewer: failed to parse REJECT verdict"
rev "const v=m.parseVerdict({choices:[{message:{tool_calls:[{function:{arguments:JSON.stringify({status:'PASS'})}}]}}]}); process.exit(v.status==='PASS'?0:1)" \
  && pass "reviewer: parses tool-call arguments when content is empty" || fail "reviewer: failed to parse tool-call arguments"
rev "let t=false; try{m.parseVerdict({choices:[{message:{content:'not json at all'}}]})}catch{t=true} process.exit(t?0:1)" \
  && pass "reviewer: malformed model output throws (not silently passed)" || fail "reviewer: malformed output did not throw"
# "verdict is not valid JSON" alone was undiagnosable (research-synthesis-agent
# PR #1, Kimi via CoreWeave). Say what came back: one line, capped.
rev "let e=''; try{m.parseVerdict({choices:[{message:{content:'\\\`\\\`\\\`json\\n{\"status\":'+'x'.repeat(500)}}]})}catch(x){e=x.message} process.exit(e.includes('json {')&&!e.includes('\\n')&&e.length<200?0:1)" \
  && pass "reviewer: an unparseable verdict shows what came back (one line, capped)" || fail "reviewer: unparseable verdict hides what the model returned"
# Kimi via CoreWeave put ~48KB of its thinking in \`content\`, verdict last
# (research-synthesis-agent PR #1). Take the JSON object that ENDS the reply —
# thinking can't come after the answer — and validate it as strictly as ever.
rev "const V=JSON.stringify({status:'REJECT',critical_flags:['a {b} c'],warnings:[]}); const v=m.parseVerdict({choices:[{message:{content:'Let me think. {x: 1} looks fine {not json}.\\n\\n'+V}}]}); process.exit(v.status==='REJECT'&&v.critical_flags[0]==='a {b} c'?0:1)" \
  && pass "reviewer: a verdict after the model's thinking is still read" || fail "reviewer: verdict after thinking is unparseable"
rev "const V=JSON.stringify({status:'REJECT',critical_flags:['a {b} c'],warnings:[]}); const v=m.parseVerdict({choices:[{message:{content:'\\x60\\x60\\x60json\\n'+V+'\\n\\x60\\x60\\x60'}}]}); process.exit(v.status==='REJECT'&&v.critical_flags[0]==='a {b} c'?0:1)" \
  && pass "reviewer: a fenced JSON verdict is still read" || fail "reviewer: fenced JSON verdict is unparseable"
rev "let t=false; try{m.parseVerdict({choices:[{message:{content:'thinking... {\\x22status\\x22:\\x22PASS\\x22} then more prose'}}]})}catch{t=true} process.exit(t?0:1)" \
  && pass "reviewer: a JSON object mid-thinking is NOT taken as the verdict" || fail "reviewer: took a mid-thinking object as the verdict"
# ...and one that ENDS the reply but isn't a verdict still fails the status gate.
rev "let t=false; try{m.parseVerdict({choices:[{message:{content:'prose ends with {}'}}]})}catch(x){t=x.message.includes('invalid status')} process.exit(t?0:1)" \
  && pass "reviewer: a trailing non-verdict object is rejected by the status gate" || fail "reviewer: trailing non-verdict object accepted"
# The backward scan is O(n) parses of O(n) suffixes: nested-object junk took 80s
# on 240KB, after the fetch timeout has already stopped protecting us. Bounded.
rev "const c=Array(30000).fill('{\\x22a\\x22:').join('')+'}'; const t=Date.now(); try{m.parseVerdict({choices:[{message:{content:c}}]})}catch{} process.exit(Date.now()-t<3000?0:1)" \
  && pass "reviewer: adversarial brace-heavy output can't stall the parse" || fail "reviewer: brace-heavy output stalls the verdict parse"

# --- advisory gate: REJECT must NOT block ---
rev "const e=m.advisoryExit({status:'REJECT',critical_flags:['x'],warnings:[]}); process.exit(e.code===0?0:1)" \
  && pass "reviewer: advisory mode never blocks on REJECT (exit 0)" || fail "reviewer: advisory REJECT did not exit 0"
rev "const e=m.advisoryExit({status:'REJECT',critical_flags:['boomflag'],warnings:[]}); process.exit(e.level==='WARN'&&e.lines.join(' ').includes('boomflag')?0:1)" \
  && pass "reviewer: advisory REJECT logs a loud warning with the flags" || fail "reviewer: advisory REJECT did not surface flags"
rev "const e=m.advisoryExit({status:'PASS',critical_flags:[],warnings:[]}); process.exit(e.code===0&&e.level==='OK'?0:1)" \
  && pass "reviewer: PASS exits 0 (OK)" || fail "reviewer: PASS did not exit 0/OK"

# --- catastrophic path: missing API key fails loud (the one non-zero exit) ---
OUT=$(OPENROUTER_API_KEY="" node "$REV" </dev/null 2>&1; echo "EXIT:$?")
if echo "$OUT" | grep -q "EXIT:1" && echo "$OUT" | grep -q "OPENROUTER_API_KEY"; then
  pass "reviewer: exits 1 with a key-missing message (catastrophic config error)"
else
  fail "reviewer: did not fail loud on missing API key"
fi

# --- #9: an un-computable diff is a loud config error, NOT "no changes" ---
NOGIT="$SANDBOX/rev-nogit"; mkdir -p "$NOGIT"
OUT=$( cd "$NOGIT" && OPENROUTER_API_KEY=dummy REVIEW_BASE_REF=origin/nonexistent node "$REV" </dev/null 2>&1; echo "EXIT:$?" )
if echo "$OUT" | grep -q "EXIT:1" && echo "$OUT" | grep -qi "could not compute diff"; then
  pass "reviewer: git failure exits 1 loudly (no silent false PASS)"
else
  fail "reviewer: git failure did not fail loud (silent false PASS risk)"
fi

# --- W2: numeric env vars validated (NaN/0 must not silently empty the diff) ---
rev "process.exit(m.numEnv('abc',1000)===1000?0:1)" \
  && pass "reviewer: numEnv falls back on non-numeric (NaN guard)" || fail "reviewer: numEnv accepted NaN"
rev "process.exit(m.numEnv('0',1000)===1000?0:1)" \
  && pass "reviewer: numEnv falls back on <1" || fail "reviewer: numEnv accepted 0"
rev "process.exit(m.numEnv('50',1000)===50?0:1)" \
  && pass "reviewer: numEnv accepts a valid positive int" || fail "reviewer: numEnv rejected a valid int"

# --- W1: OPENROUTER_BASE_URL scheme check (reject file://, malformed) ---
rev "process.exit(m.validateBaseUrl('https://openrouter.ai/api/v1')==='https://openrouter.ai/api/v1'?0:1)" \
  && pass "reviewer: validateBaseUrl accepts https" || fail "reviewer: validateBaseUrl rejected https"
rev "process.exit(m.validateBaseUrl('http://localhost:11434/v1')==='http://localhost:11434/v1'?0:1)" \
  && pass "reviewer: validateBaseUrl allows http for local endpoints" || fail "reviewer: validateBaseUrl rejected local http"
rev "process.exit(m.validateBaseUrl('https://x/')==='https://x'?0:1)" \
  && pass "reviewer: validateBaseUrl trims trailing slash" || fail "reviewer: validateBaseUrl did not trim trailing slash"
rev "let t=false;try{m.validateBaseUrl('file:///etc/passwd')}catch{t=true};process.exit(t?0:1)" \
  && pass "reviewer: validateBaseUrl rejects non-http(s) schemes" || fail "reviewer: validateBaseUrl allowed file://"
rev "let t=false;try{m.validateBaseUrl('not a url')}catch{t=true};process.exit(t?0:1)" \
  && pass "reviewer: validateBaseUrl rejects malformed URLs" || fail "reviewer: validateBaseUrl allowed a malformed URL"

# --- W5: model-controlled strings can't inject newlines into the log ---
rev "const e=m.advisoryExit({status:'REJECT',critical_flags:['boom\n✅ Logic review: PASS'],warnings:[]}); process.exit(e.lines.every(l=>!l.includes('\n'))&&e.lines.some(l=>l.includes('boom'))?0:1)" \
  && pass "reviewer: advisory output strips newlines from model flags (log-injection guard)" || fail "reviewer: model flag newline leaked into log output"

# --- #3: renderComment produces a PR-comment body (Markdown, stable marker) ---
rev "const c=m.renderComment({status:'PASS',critical_flags:[],warnings:[]}); process.exit(c.includes('logic-reviewer')&&/PASS/.test(c)?0:1)" \
  && pass "reviewer: renderComment marks PASS with a stable marker" || fail "reviewer: renderComment PASS missing marker/status"
rev "const c=m.renderComment({status:'REJECT',critical_flags:['boomflag'],warnings:[]}); process.exit(/REJECT/.test(c)&&c.includes('boomflag')&&/not\b.*block|advisory/i.test(c)?0:1)" \
  && pass "reviewer: renderComment shows REJECT flags + advisory disclaimer" || fail "reviewer: renderComment REJECT missing flags/disclaimer"
rev "const c=m.renderComment({status:'REJECT',critical_flags:['a\nb'],warnings:[]}); process.exit(c.split('\n').filter(l=>l.startsWith('- ')).length===1?0:1)" \
  && pass "reviewer: renderComment collapses newlines in a flag to one bullet" || fail "reviewer: renderComment let a flag span multiple bullets"
# #20: skipped files are NAMED in the PR comment, with an included/total count
rev "const c=m.renderComment({status:'PASS',critical_flags:[],warnings:[]},{truncated:true,skippedFiles:['zz.js'],truncatedFiles:['big.js'],fileCount:3}); process.exit(/NOT reviewed/.test(c)&&c.includes('zz.js')&&c.includes('big.js')&&c.includes('2/3')?0:1)" \
  && pass "reviewer: renderComment names skipped + truncated files with counts" || fail "reviewer: renderComment hid a review omission"

# --- Deprecated/unknown model: detect it and warn distinctly (not a generic blip) ---
rev "process.exit(m.isModelError(400,'deepseek/x is not a valid model ID')===true?0:1)" \
  && pass "reviewer: isModelError flags a 400 'not a valid model' as a model problem" || fail "reviewer: isModelError missed an invalid-model 400"
rev "process.exit(m.isModelError(404,'model not found')===true?0:1)" \
  && pass "reviewer: isModelError flags a 404 model-not-found" || fail "reviewer: isModelError missed a 404 model error"
rev "process.exit(m.isModelError(403,'this model requires a different plan')===true?0:1)" \
  && pass "reviewer: isModelError flags a 403 model-gated error" || fail "reviewer: isModelError missed a 403 model error"
rev "process.exit(m.isModelError(403,'invalid api key')===false?0:1)" \
  && pass "reviewer: isModelError ignores a 403 with no model mention (auth, not model)" || fail "reviewer: isModelError misclassified an auth 403"
rev "process.exit(m.isModelError(500,'internal server error')===false?0:1)" \
  && pass "reviewer: isModelError does NOT treat a 500 as a model problem" || fail "reviewer: isModelError misclassified a 500"
rev "process.exit(m.isModelError(400,'max_tokens exceeds model limit')===false?0:1)" \
  && pass "reviewer: isModelError ignores a generic 400 that merely mentions 'model'" || fail "reviewer: isModelError misclassified a generic 400"
rev "const c=m.renderModelWarning('deepseek/deepseek-v4-pro','not a valid model ID'); process.exit(c.includes('deepseek/deepseek-v4-pro')&&c.includes('LOGIC_REVIEWER_MODEL')&&c.includes('logic-reviewer')?0:1)" \
  && pass "reviewer: renderModelWarning names the model + how to fix it" || fail "reviewer: renderModelWarning missing model/fix/marker"

# --- a reviewer that produced no verdict must SAY so on the PR ---
# The post step only touches the PR when a comment file exists. Exit 0 with no
# file left the previous comment in place — a stale PASS that reads as current.
# A local fake endpoint: /garbage returns an unparseable verdict, anything else
# never answers (so the client's timeout fires).
FAKE_PORT_FILE="$SANDBOX/fake-model.port"
node -e "
const s=require('http').createServer((q,r)=>{
  if(q.url.startsWith('/garbage')){r.writeHead(200,{'content-type':'application/json'});r.end(JSON.stringify({choices:[{message:{content:'not json'}}]}));}
});
s.listen(0,'127.0.0.1',()=>require('fs').writeFileSync(process.argv[1],String(s.address().port)));
" "$FAKE_PORT_FILE" &
FAKE_PID=$!
for _ in $(seq 50); do [ -s "$FAKE_PORT_FILE" ] && break; sleep 0.1; done
FAKE_PORT=$(cat "$FAKE_PORT_FILE" 2>/dev/null)
# No port → requests hit port 80, fail as a NETWORK error, and both cases below
# would pass via the wrong path. Say so instead of passing vacuously.
[ -n "$FAKE_PORT" ] || fail "reviewer: fake model endpoint did not start (no-verdict tests below are void)"
printf 'diff --git a/a.js b/a.js\n+x\n' > "$SANDBOX/rev.diff"
# rev_unreviewed <base-path> → runs the reviewer against the fake; prints EXIT:<code>
rev_unreviewed() {
  rm -f "$SANDBOX/rev-comment.md"
  OPENROUTER_API_KEY=dummy OPENROUTER_BASE_URL="http://127.0.0.1:$FAKE_PORT/$1" REVIEW_TIMEOUT_MS=300 \
    REVIEW_DIFF_FILE="$SANDBOX/rev.diff" REVIEW_COMMENT_FILE="$SANDBOX/rev-comment.md" \
    node "$REV" </dev/null >/dev/null 2>&1
  echo "EXIT:$?"
}
OUT=$(rev_unreviewed hang)
if [ "$OUT" = "EXIT:0" ] && grep -q "<!-- logic-reviewer -->" "$SANDBOX/rev-comment.md" 2>/dev/null \
   && grep -q "Not reviewed — the model could not be reached" "$SANDBOX/rev-comment.md"; then
  pass "reviewer: a timeout leaves a 'Not reviewed' PR comment (exit 0, advisory)"
else
  fail "reviewer: a timeout left no PR comment — a stale verdict reads as current"
fi
OUT=$(rev_unreviewed garbage)
if [ "$OUT" = "EXIT:0" ] && grep -q "<!-- logic-reviewer -->" "$SANDBOX/rev-comment.md" 2>/dev/null \
   && grep -q "Not reviewed — the model returned an unparseable verdict" "$SANDBOX/rev-comment.md"; then
  pass "reviewer: an unparseable verdict leaves a 'Not reviewed' PR comment (exit 0, advisory)"
else
  fail "reviewer: an unparseable verdict left no PR comment — a stale verdict reads as current"
fi
kill "$FAKE_PID" 2>/dev/null; wait "$FAKE_PID" 2>/dev/null

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

"$SCRIPT_DIR/bin/init-claude" > "$LOGS"/init-claude-1.log 2>&1 || fail "init-claude failed in fresh project"

[ -d "$PROJECT/.claude" ] && pass "init-claude creates .claude/" || fail "init-claude did not create .claude/"
[ -f "$PROJECT/.claude/CLAUDE.md" ] && pass "init-claude copies CLAUDE.md" || fail "init-claude did not copy CLAUDE.md"
[ -f "$PROJECT/.gitignore" ] && pass "init-claude creates .gitignore when missing" || fail "init-claude did not create .gitignore"
[ -x "$PROJECT/.git/hooks/pre-commit" ] && pass "init-claude installs pre-commit hook" || fail "init-claude did not install pre-commit hook"
[ -x "$PROJECT/.git/hooks/pre-push" ] && pass "init-claude installs pre-push hook (full floor)" || fail "init-claude did not install pre-push hook"

# .project-gitignore should NOT be in .claude/
[ -f "$PROJECT/.claude/.project-gitignore" ] && fail ".project-gitignore leaked into .claude/" || pass ".project-gitignore cleaned up from .claude/"
[ -f "$PROJECT/.claude/.pre-commit-hook" ] && fail ".pre-commit-hook leaked into .claude/" || pass ".pre-commit-hook cleaned up from .claude/"
[ -f "$PROJECT/.claude/.pre-push-hook" ] && fail ".pre-push-hook leaked into .claude/" || pass ".pre-push-hook cleaned up from .claude/"
# dot-gitignore (its in-repo storage name) must be restored to .gitignore
[ -f "$PROJECT/.claude/.gitignore" ] && pass "init-claude restores .claude/.gitignore from dot-gitignore" || fail ".claude/.gitignore missing after scaffold"
[ -f "$PROJECT/.claude/dot-gitignore" ] && fail "dot-gitignore leaked into .claude/ unrenamed" || pass "no unrenamed dot-gitignore in .claude/"

# ============================================================
# SECTION: init-claude respects existing .gitignore
# ============================================================
section "init-claude respects existing .gitignore"

PROJECT2="$SANDBOX/project-with-gitignore"
mkdir -p "$PROJECT2"
cd "$PROJECT2"
echo "existing content" > .gitignore
git init > /dev/null 2>&1

"$SCRIPT_DIR/bin/init-claude" > "$LOGS"/init-claude-2.log 2>&1 || fail "init-claude failed with existing .gitignore"

GITIGNORE_CONTENT=$(cat "$PROJECT2/.gitignore")
[ "$GITIGNORE_CONTENT" = "existing content" ] && pass "init-claude preserves existing .gitignore" || fail "init-claude overwrote existing .gitignore"

# ============================================================
# SECTION: init-claude recognizes uv/poetry as a Python test floor (S1)
# ============================================================
# A uv/poetry project reaches pytest through its env, not bare PATH. init-claude
# must mirror verify.sh's runner detection, else every well-configured uv project
# gets a spurious "no test floor" Known Issue written into PROGRESS.md.
section "init-claude recognizes uv/poetry test floor"

PYUV="$SANDBOX/py-uv-project"
mkdir -p "$PYUV"
cd "$PYUV"
git init > /dev/null 2>&1
git config user.email test@example.com
git config user.name Test
printf '[project]\nname = "x"\nrequires-python = ">=3.12"\n' > pyproject.toml
touch uv.lock
# A "well-configured" project means one that HAS TESTS. The fixture previously
# asserted that on uv.lock alone, which is what let the detection bug through:
# uv.lock proves a lockfile exists, never that a single test does.
mkdir -p tests && printf 'def test_real():\n    assert True\n' > tests/test_real.py
# Shim uv on PATH (pytest deliberately NOT present — it lives in uv's env).
mkdir -p "$SANDBOX/initshims"
printf '#!/bin/bash\nexit 0\n' > "$SANDBOX/initshims/uv"; chmod +x "$SANDBOX/initshims/uv"
# Restricted PATH: coreutils + the uv shim, but NOT the host dirs where pytest
# lives (/usr/local/bin, /opt/homebrew/bin) — otherwise host pytest masks the bug.
PATH="$SANDBOX/initshims:/usr/bin:/bin" "$SCRIPT_DIR/bin/init-claude" > "$LOGS"/init-uv.log 2>&1
if [ -f "$PYUV/.claude/PROGRESS.md" ] && grep -qi "test floor gap" "$PYUV/.claude/PROGRESS.md"; then
  fail "init-claude false-flags a uv project that has tests as a missing test floor"
else
  pass "init-claude recognizes a uv project with tests as a Python test floor"
fi

# ruff.toml target-version must follow the project, not the template default.
if grep -q 'target-version = "py312"' "$PYUV/ruff.toml" 2>/dev/null; then
  pass "init-claude pins ruff target-version from requires-python"
else
  fail "init-claude left the template ruff target-version (got: $(grep -m1 target-version "$PYUV/ruff.toml" 2>/dev/null))"
fi
cd "$SANDBOX"

# ── Regression: a Python project with NO tests must be flagged, even when a
# pytest binary happens to exist on PATH. `uv init` creates no uv.lock, so this
# fell through to `command -v pytest` and a global pytest silently passed it.
PYNOTESTS="$SANDBOX/py-no-tests"
mkdir -p "$PYNOTESTS"
cd "$PYNOTESTS"
git init > /dev/null 2>&1
git config user.email test@example.com
git config user.name Test
printf '[project]\nname = "x"\nrequires-python = ">=3.12"\n' > pyproject.toml
# Put a pytest shim ON PATH — the machine has pytest, the project has no tests.
printf '#!/bin/bash\nexit 0\n' > "$SANDBOX/initshims/pytest"; chmod +x "$SANDBOX/initshims/pytest"
PATH="$SANDBOX/initshims:/usr/bin:/bin" "$SCRIPT_DIR/bin/init-claude" > "$LOGS"/init-py-no-tests.log 2>&1
if grep -qi "test floor gap" "$PYNOTESTS/.claude/PROGRESS.md" 2>/dev/null; then
  pass "init-claude flags a Python project with no tests despite pytest on PATH"
else
  fail "init-claude missed a missing test floor because pytest was on PATH"
fi
if grep -qi "TEST FLOOR GAP" "$LOGS"/init-py-no-tests.log; then
  pass "init-claude prints the test floor gap to the console"
else
  fail "init-claude stayed silent about a missing test floor"
fi
cd "$SANDBOX"

# ============================================================
# SECTION: init-claude blocks on existing .claude/
# ============================================================
section "init-claude blocks on existing .claude/"

cd "$PROJECT"  # .claude/ already exists from earlier test
if "$SCRIPT_DIR/bin/init-claude" > "$LOGS"/init-claude-3.log 2>&1; then
  fail "init-claude did not block when .claude/ already exists"
else
  pass "init-claude exits non-zero when .claude/ already exists"
fi

# ============================================================
# SECTION: init-claude scaffolds into an app-created .claude/
# ============================================================
# The Claude Code app creates .claude/.cc-writes/ to track its own file writes,
# so .claude/ exists in ANY folder a session has been open in. A bare
# directory-existence check therefore refused to scaffold a brand-new project —
# and broke the documented path exactly: /init-floor is a slash command, so a
# session must be open in the project, which is what creates .cc-writes.
section "init-claude scaffolds into an app-created .claude/"

CCW="$SANDBOX/proj-ccwrites"
rm -rf "$CCW"; mkdir -p "$CCW/.claude/.cc-writes"
( cd "$CCW" && git init -q && git config user.email t@e.com && git config user.name T ) || fail "ccwrites fixture setup failed"
printf '[project]\nname = "x"\n' > "$CCW/pyproject.toml"
if ( cd "$CCW" && "$SCRIPT_DIR/bin/init-claude" ) > "$LOGS"/init-ccwrites.log 2>&1; then
  pass "init-claude scaffolds when .claude/ holds only the app's .cc-writes/"
else
  fail "init-claude refused a project whose .claude/ holds only .cc-writes/"
fi
[ -f "$CCW/.claude/CLAUDE.md" ] && pass "  -> CLAUDE.md scaffolded into the existing .claude/" || fail "  -> CLAUDE.md missing"
[ -f "$CCW/.claude/verify.sh" ] && pass "  -> verify.sh scaffolded into the existing .claude/" || fail "  -> verify.sh missing"
[ -d "$CCW/.claude/.cc-writes" ] && pass "  -> the app's .cc-writes/ left intact" || fail "  -> .cc-writes/ was destroyed"
# `cp -r "$TEMPLATE" .claude` NESTS the template when .claude/ already exists.
ls -d "$CCW"/.claude/*template* >/dev/null 2>&1 && fail "  -> template nested inside .claude/ instead of merged" || pass "  -> template contents merged, not nested"
[ -f "$CCW/.claude/.gitignore" ] && pass "  -> dot-gitignore renamed to .gitignore" || fail "  -> .claude/.gitignore missing"
[ -x "$CCW/.git/hooks/pre-commit" ] && pass "  -> pre-commit hook installed" || fail "  -> pre-commit hook missing"
[ -x "$CCW/.git/hooks/pre-push" ] && pass "  -> pre-push hook installed" || fail "  -> pre-push hook missing"

# Regression: a REAL scaffold must still be refused, and must say what clashes.
SCAF="$SANDBOX/proj-scaffolded"
rm -rf "$SCAF"; mkdir -p "$SCAF/.claude"
printf '# my customised instructions\n' > "$SCAF/.claude/CLAUDE.md"
( cd "$SCAF" && git init -q ) || fail "scaffolded fixture setup failed"
if ( cd "$SCAF" && "$SCRIPT_DIR/bin/init-claude" ) > "$LOGS"/init-scaffolded.log 2>&1; then
  fail "init-claude overwrote an existing scaffold"
else
  pass "init-claude still refuses a real scaffold (CLAUDE.md present)"
fi
grep -q "would be overwritten" "$LOGS"/init-scaffolded.log && grep -qE "^ +CLAUDE\.md$" "$LOGS"/init-scaffolded.log \
  && pass "  -> refusal lists CLAUDE.md as the clash (not just a passing mention)" \
  || fail "  -> refusal did not list the clashing file"
grep -q "update-claude" "$LOGS"/init-scaffolded.log && pass "  -> refusal points at update-claude" || fail "  -> refusal gave no path forward"
grep -q "customised" "$SCAF/.claude/CLAUDE.md" && pass "  -> the user's CLAUDE.md is untouched" || fail "  -> the user's CLAUDE.md was modified"

# W1: the app also writes settings.local.json (first "don't ask again"). That is
# USER-OWNED and gitignored by our own .claude/.gitignore — it must NOT block
# scaffolding, and must NOT be overwritten.
LOCAL="$SANDBOX/proj-settingslocal"
rm -rf "$LOCAL"; mkdir -p "$LOCAL/.claude/.cc-writes"
printf '{ "permissions": { "allow": ["Bash(mine)"] } }\n' > "$LOCAL/.claude/settings.local.json"
printf '# my personal notes\n' > "$LOCAL/.claude/CLAUDE.local.md"
( cd "$LOCAL" && git init -q ) || fail "settings.local fixture setup failed"
printf '[project]\nname = "x"\n' > "$LOCAL/pyproject.toml"
if ( cd "$LOCAL" && "$SCRIPT_DIR/bin/init-claude" ) > "$LOGS"/init-local.log 2>&1; then
  pass "init-claude scaffolds despite an app-written settings.local.json"
else
  fail "init-claude refused because of settings.local.json (user-owned, should not block)"
fi
grep -q "Bash(mine)" "$LOCAL/.claude/settings.local.json" && pass "  -> the user's settings.local.json is preserved" || fail "  -> settings.local.json was overwritten"
grep -q "personal notes" "$LOCAL/.claude/CLAUDE.local.md" && pass "  -> the user's CLAUDE.local.md is preserved" || fail "  -> CLAUDE.local.md was overwritten"
[ -f "$LOCAL/.claude/verify.sh" ] && pass "  -> the rest of the scaffold still landed" || fail "  -> scaffold incomplete"

# W3: a clash inside a template SUBDIRECTORY must refuse, not silently merge.
SUBC="$SANDBOX/proj-subclash"
rm -rf "$SUBC"; mkdir -p "$SUBC/.claude/ci"
printf 'my pipeline\n' > "$SUBC/.claude/ci/github-actions.yml"
( cd "$SUBC" && git init -q ) || fail "subclash fixture setup failed"
if ( cd "$SUBC" && "$SCRIPT_DIR/bin/init-claude" ) > "$LOGS"/init-subclash.log 2>&1; then
  fail "init-claude overwrote a file inside .claude/ci/"
else
  pass "init-claude refuses a clash inside a template subdirectory"
fi
grep -q "my pipeline" "$SUBC/.claude/ci/github-actions.yml" && pass "  -> the user's ci file is untouched" || fail "  -> the user's ci file was overwritten"

# W3: a pre-existing .claude/.gitignore (the dot-gitignore rename target).
GIC="$SANDBOX/proj-gitignoreclash"
rm -rf "$GIC"; mkdir -p "$GIC/.claude"
printf 'mine\n' > "$GIC/.claude/.gitignore"
( cd "$GIC" && git init -q ) || fail "gitignore fixture setup failed"
if ( cd "$GIC" && "$SCRIPT_DIR/bin/init-claude" ) > "$LOGS"/init-gic.log 2>&1; then
  fail "init-claude clobbered an existing .claude/.gitignore"
else
  pass "init-claude refuses when .claude/.gitignore already exists"
fi
grep -q "mine" "$GIC/.claude/.gitignore" && pass "  -> the user's .claude/.gitignore is untouched" || fail "  -> it was overwritten"

# W2: a plain FILE where the template needs a directory used to pass the guard,
# make cp fail per-file, and still report success.
DVF="$SANDBOX/proj-dirvsfile"
rm -rf "$DVF"; mkdir -p "$DVF/.claude"
printf 'not a directory\n' > "$DVF/.claude/ci"
( cd "$DVF" && git init -q ) || fail "dirvsfile fixture setup failed"
if ( cd "$DVF" && "$SCRIPT_DIR/bin/init-claude" ) > "$LOGS"/init-dvf.log 2>&1; then
  fail "init-claude reported success with a file blocking .claude/ci/"
else
  pass "init-claude refuses a file where a template directory must go"
fi

# W2: .claude itself as a regular file must be refused, not reported scaffolded.
CFILE="$SANDBOX/proj-claudeisfile"
rm -rf "$CFILE"; mkdir -p "$CFILE"; printf 'oops\n' > "$CFILE/.claude"
( cd "$CFILE" && git init -q ) || fail "claude-is-file fixture setup failed"
if ( cd "$CFILE" && "$SCRIPT_DIR/bin/init-claude" ) > "$LOGS"/init-cfile.log 2>&1; then
  fail "init-claude reported success when .claude is a regular file"
else
  pass "init-claude refuses when .claude is a regular file"
fi

cd "$SANDBOX"

# ============================================================
# SECTION: update-claude (upgrade an existing project)
# ============================================================
# Updates the infrastructure files (reviewer code/prompt, ci, configs) in place,
# but never clobbers files you customize (verify.sh, CLAUDE.md, settings.local).
section "update-claude upgrades an existing project"

# Blocks where there is no .claude/ (that's init-claude's job, not this).
UC_NONE="$SANDBOX/uc-no-claude"; mkdir -p "$UC_NONE"
if ( cd "$UC_NONE" && "$SCRIPT_DIR/bin/update-claude" ) > "$LOGS"/uc-none.log 2>&1; then
  fail "update-claude ran without a .claude/ (should block)"
else
  pass "update-claude blocks when there is no .claude/"
fi

cd "$PROJECT"   # has .claude/ scaffolded from the init-claude tests
# Refreshes infrastructure files (overwrites stale reviewer code + prompt).
echo "OLD-SENTINEL" > .claude/bin/review-diff.mjs
echo "OLD-PROMPT"   > .claude/review/logic-reviewer.md
"$SCRIPT_DIR/bin/update-claude" > "$LOGS"/uc-run.log 2>&1
grep -q "OLD-SENTINEL" .claude/bin/review-diff.mjs && fail "update-claude did not refresh review-diff.mjs" || pass "update-claude refreshes the reviewer code"
grep -q "OLD-PROMPT" .claude/review/logic-reviewer.md && fail "update-claude did not refresh the prompt" || pass "update-claude refreshes the reviewer prompt"

# Preserves a customized verify.sh — never clobbers your project's commands.
echo "MY-CUSTOM-VERIFY" > .claude/verify.sh
"$SCRIPT_DIR/bin/update-claude" > "$LOGS"/uc-run2.log 2>&1
grep -q "MY-CUSTOM-VERIFY" .claude/verify.sh && pass "update-claude preserves a customized verify.sh" || fail "update-claude clobbered a customized verify.sh"

# Restores verify.sh if it is missing.
rm -f .claude/verify.sh
"$SCRIPT_DIR/bin/update-claude" > "$LOGS"/uc-run3.log 2>&1
[ -f .claude/verify.sh ] && pass "update-claude restores a missing verify.sh" || fail "update-claude did not restore verify.sh"
cd "$SANDBOX"

# ============================================================
# SECTION: reviewer calibration ledger
# ============================================================
# advisory-first only graduates to a decision if the false-positive data it
# claims to gather is actually written down. The ledger is ACCUMULATED DATA, so
# the load-bearing property is that /update-floor must never wipe it —
# update-claude overwrites .claude/{bin,review,ci,configs}, which is exactly
# why the ledger does not live in review/.
section "reviewer calibration ledger"

[ -f "$SCRIPT_DIR/template/review-ledger.md" ] && pass "template ships review-ledger.md" || fail "template/review-ledger.md missing"
[ -f "$SCRIPT_DIR/REVIEW_LEDGER.md" ] && pass "the harness keeps its own REVIEW_LEDGER.md" || fail "REVIEW_LEDGER.md missing"
grep -q "review-ledger" "$SCRIPT_DIR/commands/logic-review.md" && pass "/logic-review records verdicts in the ledger" || fail "/logic-review does not mention the ledger"
grep -q "Not reviewed" "$SCRIPT_DIR/commands/logic-review.md" && pass "/logic-review reports a no-verdict run as not reviewed" || fail "/logic-review would treat a no-verdict run as clean"

LEDG="$SANDBOX/proj-ledger"
rm -rf "$LEDG"; mkdir -p "$LEDG"
( cd "$LEDG" && git init -q ) || fail "ledger fixture setup failed"
printf '{ "scripts": { "test": "x" } }\n' > "$LEDG/package.json"
( cd "$LEDG" && "$SCRIPT_DIR/bin/init-claude" ) > "$LOGS"/init-ledger.log 2>&1
[ -f "$LEDG/.claude/review-ledger.md" ] && pass "init-claude lands the ledger at .claude/review-ledger.md" || fail "ledger not scaffolded into .claude/"
# It must NOT be inside review/, which update-claude overwrites wholesale.
[ -f "$LEDG/.claude/review/review-ledger.md" ] && fail "ledger sits in review/ — update-floor would wipe it" || pass "ledger is outside review/ (the overwrite path)"

# The regression that matters: accumulated rows survive /update-floor.
# Append only to a ledger that was really scaffolded, so this cannot pass by
# the printf creating the file itself.
[ -f "$LEDG/.claude/review-ledger.md" ] || fail "preservation test is vacuous: ledger was never scaffolded"
printf '| 2026-01-01 | #999 | model-x | correctness | sentinel row | false-positive | kept? |\n' >> "$LEDG/.claude/review-ledger.md"
( cd "$LEDG" && "$SCRIPT_DIR/bin/update-claude" ) > "$LOGS"/update-ledger.log 2>&1
grep -q "sentinel row" "$LEDG/.claude/review-ledger.md" && pass "update-claude preserves accumulated ledger rows" || fail "update-claude wiped the ledger (accumulated data lost)"
cd "$SANDBOX"

# ============================================================
# SECTION: Uninstall (rules + legacy pre-plugin cleanup)
# ============================================================
# uninstall.sh removes the global rules and migrates machines off the OLD
# copied install: legacy hook/command/agent files plus their settings.json
# wiring — while preserving the user's own settings and hooks.
section "Uninstall (rules + legacy pre-plugin cleanup)"

cd "$SANDBOX"
SETTINGS="$SANDBOX/.claude/settings.json"
# Seed what a pre-plugin machine still has.
mkdir -p "$SANDBOX/.claude/hooks" "$SANDBOX/.claude/commands" "$SANDBOX/.claude/agents" "$SANDBOX/bin"
touch "$SANDBOX/.claude/hooks/dispatch.mjs" "$SANDBOX/.claude/hooks/config-protection.mjs"
touch "$SANDBOX/.claude/commands/code-review.md" "$SANDBOX/.claude/commands/security-scan.md" "$SANDBOX/.claude/commands/logic-review.md"
touch "$SANDBOX/.claude/agents/code-reviewer.md" "$SANDBOX/.claude/agents/security-reviewer.md"
touch "$SANDBOX/bin/init-claude" "$SANDBOX/bin/update-claude"
cat > "$SETTINGS" <<'EOF'
{
  "permissions": { "allow": ["Bash(npm test)"] },
  "model": "haiku",
  "hooks": {
    "PostToolUse": [
      { "matcher": "Edit", "hooks": [{ "type": "command", "command": "echo custom" }] },
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "node /old/hooks/dispatch.mjs post-bash" }] }
    ],
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": "node /old/hooks/dispatch.mjs bash" }] }
    ]
  }
}
EOF
"$SCRIPT_DIR/install.sh" > "$LOGS"/install-before-uninstall.log 2>&1  # rules present

# Run uninstall with auto-"no" for the template prompt
echo "n" | "$SCRIPT_DIR/uninstall.sh" > "$LOGS"/uninstall.log 2>&1 || fail "uninstall.sh exited non-zero"

[ ! -f "$SANDBOX/.claude/hooks/dispatch.mjs" ] && pass "uninstall removed legacy dispatch.mjs" || fail "uninstall left legacy dispatch.mjs"
[ ! -f "$SANDBOX/.claude/hooks/config-protection.mjs" ] && pass "uninstall removed legacy per-file hook" || fail "uninstall left legacy per-file hook"
[ ! -f "$SANDBOX/.claude/commands/code-review.md" ] && pass "uninstall removed legacy code-review.md" || fail "uninstall left legacy code-review.md"
[ ! -f "$SANDBOX/.claude/agents/code-reviewer.md" ] && pass "uninstall removed legacy code-reviewer.md" || fail "uninstall left legacy code-reviewer.md"
[ ! -f "$SANDBOX/.claude/rules/workflow.md" ] && pass "uninstall removed rules/workflow.md" || fail "uninstall left rules/workflow.md"
[ ! -f "$SANDBOX/.claude/rules/agent-design.md" ] && pass "uninstall removed rules/agent-design.md" || fail "uninstall left rules/agent-design.md"
[ ! -f "$SANDBOX/.claude/playbooks/AGENT_PROJECT_PLAYBOOK.md" ] && pass "uninstall removed the playbook" || fail "uninstall left the playbook"
[ ! -f "$SANDBOX/bin/init-claude" ] && pass "uninstall removed legacy bin/init-claude" || fail "uninstall left legacy bin/init-claude"
[ ! -f "$SANDBOX/bin/update-claude" ] && pass "uninstall removed legacy bin/update-claude" || fail "uninstall left legacy bin/update-claude"

# Settings: ours stripped from every event, the user's own config preserved.
TMPRESULTS2=$(mktemp)
node -e "
const s = require('$SETTINGS');
const checks = [
  [s.permissions && s.permissions.allow && s.permissions.allow[0] === 'Bash(npm test)', 'uninstall preserved custom permission'],
  [s.model === 'haiku', 'uninstall preserved custom model'],
  [JSON.stringify(s.hooks || {}).includes('echo custom'), 'uninstall preserved the user hook'],
  [!JSON.stringify(s.hooks || {}).includes('dispatch.mjs'), 'uninstall stripped our legacy wiring from every event']
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
