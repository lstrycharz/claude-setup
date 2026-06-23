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
[ -f "$SANDBOX/.claude/rules/agent-design.md" ] && pass "rules/agent-design.md installed" || fail "rules/agent-design.md missing"
[ -f "$SANDBOX/.claude/rules/frontend/react.md" ] && pass "rules/frontend/react.md installed" || fail "rules/frontend/react.md missing"
[ -f "$SANDBOX/.claude/playbooks/AGENT_PROJECT_PLAYBOOK.md" ] && pass "playbooks/AGENT_PROJECT_PLAYBOOK.md installed" || fail "playbooks/AGENT_PROJECT_PLAYBOOK.md missing"
[ -f "$SANDBOX/.claude/hooks/config-protection.mjs" ] && pass "hooks/config-protection.mjs installed" || fail "hooks/config-protection.mjs missing"
[ -f "$SANDBOX/.claude/hooks/block-no-verify.mjs" ] && pass "hooks/block-no-verify.mjs installed" || fail "hooks/block-no-verify.mjs missing"
[ -f "$SANDBOX/.claude/hooks/suggest-compact.mjs" ] && pass "hooks/suggest-compact.mjs installed" || fail "hooks/suggest-compact.mjs missing"
[ -f "$SANDBOX/.claude/hooks/enforce-floor.mjs" ] && pass "hooks/enforce-floor.mjs installed" || fail "hooks/enforce-floor.mjs missing"
[ -f "$SANDBOX/.claude-template/verify.sh" ] && pass "template/verify.sh installed" || fail "template/verify.sh missing"
[ -f "$SANDBOX/.claude-template/ci/github-actions.yml" ] && pass "template/ci installed" || fail "template/ci missing"
[ -f "$SANDBOX/.claude-template/configs/eslint.config.mjs.tpl" ] && pass "template/configs installed" || fail "template/configs missing"
[ -f "$SANDBOX/.claude-template/bin/review-diff.mjs" ] && pass "template/bin/review-diff.mjs installed" || fail "template/bin/review-diff.mjs missing"
[ -f "$SANDBOX/.claude-template/review/logic-reviewer.md" ] && pass "template/review prompt installed" || fail "template/review prompt missing"
[ -f "$SANDBOX/.claude-template/ci/reviewer-github.yml" ] && pass "template/ci/reviewer-github.yml installed" || fail "template/ci/reviewer-github.yml missing"
# #3: the GitHub reviewer workflow must be wired to post the findings onto the PR.
grep -q 'pull-requests: write' "$SANDBOX/.claude-template/ci/reviewer-github.yml" && pass "reviewer-github.yml grants PR-comment write permission" || fail "reviewer-github.yml lacks pull-requests: write"
grep -q 'gh pr comment' "$SANDBOX/.claude-template/ci/reviewer-github.yml" && pass "reviewer-github.yml posts a PR comment" || fail "reviewer-github.yml does not post a PR comment"
[ -f "$SANDBOX/.claude-template/ci/reviewer-bitbucket.yml" ] && pass "template/ci/reviewer-bitbucket.yml installed" || fail "template/ci/reviewer-bitbucket.yml missing"
# W6: floor CI images are Node-only — they must at least NOTE Python setup so a
# uv/poetry project doesn't silently no-op its Python checks (false green).
grep -qiE 'python|uv|poetry' "$SANDBOX/.claude-template/ci/github-actions.yml" && pass "ci/github-actions.yml notes Python setup" || fail "ci/github-actions.yml has no Python setup note"
grep -qiE 'python|uv|poetry' "$SANDBOX/.claude-template/ci/bitbucket-pipelines.yml" && pass "ci/bitbucket-pipelines.yml notes Python setup" || fail "ci/bitbucket-pipelines.yml has no Python setup note"
[ -f "$SANDBOX/.claude/commands/code-review.md" ] && pass "commands/code-review.md installed" || fail "commands/code-review.md missing"
[ -f "$SANDBOX/.claude/commands/security-scan.md" ] && pass "commands/security-scan.md installed" || fail "commands/security-scan.md missing"
[ -f "$SANDBOX/.claude/commands/logic-review.md" ] && pass "commands/logic-review.md installed" || fail "commands/logic-review.md missing"
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
  [ "$HOOK_COUNT" = "4" ] && pass "settings.json has exactly 4 PreToolUse hooks" || fail "settings.json has $HOOK_COUNT hooks (expected 4)"
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
[ "$HOOK_COUNT" = "4" ] && pass "no duplicate hooks after re-install (count=4)" || fail "duplicate hooks after re-install (count=$HOOK_COUNT)"

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

# enforce-floor: allows non-commit git commands
OUT=$(echo '{"tool_input":{"command":"git status"}}' | node "$SANDBOX/.claude/hooks/enforce-floor.mjs" 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "enforce-floor allows non-commit git" || fail "enforce-floor wrongly blocked git status"

# enforce-floor: blocks commit in a code repo (package.json) with no pre-commit hook
EF_REPO="$SANDBOX/ef-nofloor"; mkdir -p "$EF_REPO"; ( cd "$EF_REPO" && git init -q && echo '{}' > package.json )
OUT=$(echo "{\"tool_input\":{\"command\":\"git commit -m x\"},\"cwd\":\"$EF_REPO\"}" | node "$SANDBOX/.claude/hooks/enforce-floor.mjs" 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "enforce-floor blocks commit when no floor wired" || fail "enforce-floor did NOT block missing floor"

# enforce-floor: "git commit" inside an echo/string is NOT a real commit (W7)
OUT=$(echo "{\"tool_input\":{\"command\":\"echo 'see git commit docs'\"},\"cwd\":\"$EF_REPO\"}" | node "$SANDBOX/.claude/hooks/enforce-floor.mjs" 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "enforce-floor ignores 'git commit' inside a string/echo" || fail "enforce-floor false-blocked a string mentioning git commit"
# enforce-floor: still blocks a real chained commit (regression guard for the anchor)
OUT=$(echo "{\"tool_input\":{\"command\":\"true && git commit -m x\"},\"cwd\":\"$EF_REPO\"}" | node "$SANDBOX/.claude/hooks/enforce-floor.mjs" 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:2" && pass "enforce-floor still blocks a chained 'git commit'" || fail "enforce-floor missed a chained git commit"

# enforce-floor: allows commit once the pre-commit hook exists
touch "$EF_REPO/.git/hooks/pre-commit"; chmod +x "$EF_REPO/.git/hooks/pre-commit"
OUT=$(echo "{\"tool_input\":{\"command\":\"git commit -m x\"},\"cwd\":\"$EF_REPO\"}" | node "$SANDBOX/.claude/hooks/enforce-floor.mjs" 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "enforce-floor allows commit when floor wired" || fail "enforce-floor blocked despite floor present"

# enforce-floor: allows commit in a non-code repo (no manifest)
EF_DOCS="$SANDBOX/ef-docs"; mkdir -p "$EF_DOCS"; ( cd "$EF_DOCS" && git init -q && echo hi > README.md )
OUT=$(echo "{\"tool_input\":{\"command\":\"git commit -m x\"},\"cwd\":\"$EF_DOCS\"}" | node "$SANDBOX/.claude/hooks/enforce-floor.mjs" 2>/dev/null; echo "EXIT:$?")
echo "$OUT" | grep -q "EXIT:0" && pass "enforce-floor allows commit in non-code repo" || fail "enforce-floor wrongly blocked non-code repo"

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
run_verify() { # $1=repo dir, $2=VERIFY_ROOTS (optional)
  ( cd "$1" && PATH="$SHIMDIR:$PATH" VERIFY_ROOTS="${2:-.}" bash "$VERIFY" >/dev/null 2>&1 )
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

# --- diff cap (cost/context budget) ---
rev "const big=Array.from({length:50},(_,i)=>'L'+i).join('\n'); const r=m.capDiff(big,10); process.exit(r.truncated&&r.text.split('\n').length<=12?0:1)" \
  && pass "reviewer: capDiff truncates oversized diffs" || fail "reviewer: capDiff did not truncate"
rev "const r=m.capDiff('a\nb',1000); process.exit(!r.truncated&&r.text==='a\nb'?0:1)" \
  && pass "reviewer: capDiff leaves small diffs intact" || fail "reviewer: capDiff altered a small diff"

# --- verdict parsing (structured output, not regex) ---
rev "const v=m.parseVerdict({choices:[{message:{content:JSON.stringify({status:'PASS',critical_flags:[],warnings:[]})}}]}); process.exit(v.status==='PASS'?0:1)" \
  && pass "reviewer: parses a PASS verdict" || fail "reviewer: failed to parse PASS verdict"
rev "const v=m.parseVerdict({choices:[{message:{content:JSON.stringify({status:'REJECT',critical_flags:['boom'],warnings:[]})}}]}); process.exit(v.status==='REJECT'&&v.critical_flags[0]==='boom'?0:1)" \
  && pass "reviewer: parses a REJECT verdict with critical flags" || fail "reviewer: failed to parse REJECT verdict"
rev "const v=m.parseVerdict({choices:[{message:{tool_calls:[{function:{arguments:JSON.stringify({status:'PASS'})}}]}}]}); process.exit(v.status==='PASS'?0:1)" \
  && pass "reviewer: parses tool-call arguments when content is empty" || fail "reviewer: failed to parse tool-call arguments"
rev "let t=false; try{m.parseVerdict({choices:[{message:{content:'not json at all'}}]})}catch{t=true} process.exit(t?0:1)" \
  && pass "reviewer: malformed model output throws (not silently passed)" || fail "reviewer: malformed output did not throw"

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

# --- Deprecated/unknown model: detect it and warn distinctly (not a generic blip) ---
rev "process.exit(m.isModelError(400,'deepseek/x is not a valid model ID')===true?0:1)" \
  && pass "reviewer: isModelError flags a 400 'not a valid model' as a model problem" || fail "reviewer: isModelError missed an invalid-model 400"
rev "process.exit(m.isModelError(404,'model not found')===true?0:1)" \
  && pass "reviewer: isModelError flags a 404 model-not-found" || fail "reviewer: isModelError missed a 404 model error"
rev "process.exit(m.isModelError(500,'internal server error')===false?0:1)" \
  && pass "reviewer: isModelError does NOT treat a 500 as a model problem" || fail "reviewer: isModelError misclassified a 500"
rev "const c=m.renderModelWarning('deepseek/deepseek-v4-pro','not a valid model ID'); process.exit(c.includes('deepseek/deepseek-v4-pro')&&c.includes('LOGIC_REVIEWER_MODEL')&&c.includes('logic-reviewer')?0:1)" \
  && pass "reviewer: renderModelWarning names the model + how to fix it" || fail "reviewer: renderModelWarning missing model/fix/marker"

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
printf '[project]\nname = "x"\n' > pyproject.toml
touch uv.lock
# Shim uv on PATH (pytest deliberately NOT present — it lives in uv's env).
mkdir -p "$SANDBOX/initshims"
printf '#!/bin/bash\nexit 0\n' > "$SANDBOX/initshims/uv"; chmod +x "$SANDBOX/initshims/uv"
# Restricted PATH: coreutils + the uv shim, but NOT the host dirs where pytest
# lives (/usr/local/bin, /opt/homebrew/bin) — otherwise host pytest masks the bug.
PATH="$SANDBOX/initshims:/usr/bin:/bin" "$SANDBOX/bin/init-claude" > /tmp/init-uv.log 2>&1
if [ -f "$PYUV/.claude/PROGRESS.md" ] && grep -qi "test floor gap" "$PYUV/.claude/PROGRESS.md"; then
  fail "init-claude false-flags a uv project (uv.lock + uv) as a missing test floor"
else
  pass "init-claude recognizes uv.lock as a Python test floor"
fi
cd "$SANDBOX"

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
[ ! -f "$SANDBOX/.claude/commands/logic-review.md" ] && pass "uninstall removed logic-review.md" || fail "uninstall left logic-review.md"
[ ! -f "$SANDBOX/.claude/agents/code-reviewer.md" ] && pass "uninstall removed code-reviewer.md" || fail "uninstall left code-reviewer.md"
[ ! -f "$SANDBOX/.claude/rules/workflow.md" ] && pass "uninstall removed workflow.md" || fail "uninstall left workflow.md"
[ ! -f "$SANDBOX/.claude/rules/agent-design.md" ] && pass "uninstall removed agent-design.md" || fail "uninstall left agent-design.md"
[ ! -f "$SANDBOX/.claude/playbooks/AGENT_PROJECT_PLAYBOOK.md" ] && pass "uninstall removed AGENT_PROJECT_PLAYBOOK.md" || fail "uninstall left AGENT_PROJECT_PLAYBOOK.md"
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
