#!/usr/bin/env bash
#
# verify.sh — this project's deterministic floor.
#
# THE single source of truth for "is this code OK to commit/merge?". Every gate
# runs THIS one script:
#   - the git pre-commit hook (local, on every commit)
#   - the enforce-floor Claude hook (agent can't commit a repo with no floor)
#   - CI (merge-blocking on PRs — see .claude/ci/)
#
# Keeping it in one place means lint/typecheck/test can never drift between
# "what the agent runs" and "what blocks the merge".
#
# Stack handling is deterministic, not inferred:
#   - Node manager comes from the LOCKFILE (pnpm-lock.yaml / yarn.lock / bun.lockb,
#     else npm). Running npm against a pnpm tree resolves wrong → false greens.
#   - Python tools run THROUGH the project env (`uv run` / `poetry run`) so they
#     hit the venv, never a global pytest that collects 0 tests and reports green.
#   - Monorepos opt in explicitly via VERIFY_ROOTS (no magic tree-walking, which
#     wanders into node_modules/.venv):  VERIFY_ROOTS="backend frontend"
#   - A code stack with NO test runner is a hard failure (not just a warning) —
#     accept the gap deliberately with a marker file:  .claude/verify.allow-no-tests
#
# Two tiers, one script (#14) — so the tiers can never drift apart:
#   verify.sh --quick   lint + typecheck only. Run by the pre-commit hook on the
#                       STAGED SNAPSHOT, so granular save-point commits stay fast.
#   verify.sh           the full floor (lint + typecheck + TESTS). Run by the
#                       pre-push hook and CI — the merge gate is always full.
#
# Exit 0 = green (safe). Non-zero = blocked. init-claude auto-detects your stack;
# edit freely for your project.

set -uo pipefail
fail=0
step() { echo ""; echo "→ $*"; }

MODE=full
[ "${1:-}" = "--quick" ] && MODE=quick

# Directories to verify. Default: repo root. Space-separated; opt-in for monorepos.
# NOTE: space-separated, so an individual path containing a space is unsupported
# (it would split into two roots and get skipped with a warning) — W3.
roots=${VERIFY_ROOTS:-.}

# "No tests" is a floor violation, not a default — a repo can otherwise pass the
# gate by simply never having tests (the exact gap the floor exists to close).
# Hard-fail when a code stack has no test runner, UNLESS the gap is accepted
# deliberately and visibly via a marker file (an owned decision, not a silent
# skip). Resolved once here at the repo root, before any per-root `cd`.
ALLOW_NO_TESTS=0
[ -f .claude/verify.allow-no-tests ] && ALLOW_NO_TESTS=1
no_test_floor() { # called when a stack has no tests; warns, and fails unless opted out
  if [ "$ALLOW_NO_TESTS" -eq 1 ]; then
    echo "    (accepted: .claude/verify.allow-no-tests present — passing without a test floor.)"
  else
    echo "    BLOCKED: create .claude/verify.allow-no-tests to accept this gap deliberately."
    fail=1
  fi
}

node_manager() {   # echo the JS package manager for the cwd, from its lockfile
  if   [ -f pnpm-lock.yaml ]; then echo pnpm
  elif [ -f yarn.lock ];      then echo yarn
  elif [ -f bun.lockb ];      then echo bun
  else echo npm
  fi
}

has_script() {     # $1 = npm script name; true if defined in package.json
  # Pass the name via env, not string-interpolated into the JS, so a script name
  # containing a quote can't break the expression or inject code (W4).
  VERIFY_SCRIPT="$1" node -e "process.exit(require('./package.json').scripts?.[process.env.VERIFY_SCRIPT]?0:1)" 2>/dev/null
}

py_runner() {      # echo "uv run" / "poetry run" / "" for the cwd
  if   [ -f uv.lock ]     && command -v uv     >/dev/null 2>&1; then echo "uv run"
  elif [ -f poetry.lock ] && command -v poetry >/dev/null 2>&1; then echo "poetry run"
  else echo ""
  fi
}

# ── Canaries: prove each tool is ENFORCING, not merely exiting 0 ─────────────
#
# Every check above consumes exactly ONE bit from its tool: the exit code. A
# tool that checked NOTHING exits 0 and is indistinguishable from a tool that
# checked everything and was happy — a linter rule switched off in config, a
# tsconfig `include` that stopped matching, a test glob that quietly narrowed.
# And because all three gates (pre-commit, pre-push, CI) run THIS one script,
# they do not independently corroborate that green; they reproduce the same
# blind spot three times and call it agreement.
#
# So: hand each tool a file that is KNOWN bad and require it to complain.
#   fired        → non-zero AND the expected diagnostic  → the tool is enforcing
#   silent       → exit 0 on a broken file               → FLOOR IS LOWERED, red
#   inconclusive → non-zero, no expected diagnostic      → loud warning, not proof
# The third state matters: a missing or crashing binary also exits non-zero, and
# must never be able to masquerade as a passing canary.
#
# The fixture is generated at run time INSIDE the project — linter/compiler
# config resolution walks up from the file, so a /tmp canary would miss the very
# config under test — and is removed on exit. It is created only AFTER the real
# checks have run, so it can never pollute them.
#
# Full tier only: --quick stays fast for commit-time. A lowered floor is caught
# at push/CI, before anything leaves the machine.

CANARY_DIR=""
canary_cleanup() { [ -n "${CANARY_DIR:-}" ] && rm -rf "$CANARY_DIR"; CANARY_DIR=""; return 0; }
# NB: the trap is installed INSIDE the per-root subshell (bash resets traps in
# subshells, so a parent trap would never fire for a fixture the subshell owns).

# Sweep fixtures a killed run left behind. This must happen BEFORE the real
# checks: a surviving fixture is a deliberately broken file, so leaving it in
# place would red the project's own lint with an error about a file nobody
# wrote. Fixed prefix + relative path: the glob cannot escape cwd.
canary_sweep() { rm -rf ./.verify-canary-*; return 0; }

canary_open() {    # create the fixture dir in the CURRENT directory
  canary_sweep
  CANARY_DIR=".verify-canary-$$"
  mkdir -p "$CANARY_DIR" 2>/dev/null || { CANARY_DIR=""; return 1; }
}

bin_or_path() {    # $1=tool → project-local bin, else $PATH, else empty
  if   [ -x "node_modules/.bin/$1" ];   then echo "node_modules/.bin/$1"
  elif command -v "$1" >/dev/null 2>&1; then echo "$1"
  else echo ""
  fi
}

# canary_assert <block|warn> <label> <expected-diagnostic> <skipped-regex|""> <cmd...>
#
# <block> = a LIVENESS proof: the fixture is unparseable, so any tool that is
#   genuinely reading files under this config must object no matter which rules
#   are selected. Exit 0 here means it examined nothing → red.
# <warn>  = a RULE probe: the fixture violates one specific rule. Exit 0 may
#   simply mean the project deliberately does not enable that rule, so it can
#   only advise — a canary that cries wolf is a canary that gets deleted.
#
# <skipped-regex> matches output meaning "never looked at the fixture" (e.g. an
# eslint flat config whose `files` don't cover it), which proves nothing.
canary_assert() {
  local mode="$1" label="$2" expect="$3" skip_re="$4"; shift 4
  local out rc
  out=$("$@" 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    # Literal substring test via case: $expect is quoted so glob/regex
    # metacharacters in it (e.g. "[syntax]") match literally, and there is no
    # pipeline whose SIGPIPE could be misreported under `set -o pipefail`.
    case "$out" in
      *"$expect"*) echo "    ✓ $label is enforcing ($expect)"; return 0 ;;
    esac
    echo "    ⚠️  CANARY INCONCLUSIVE — $label failed but never reported '$expect'."
    echo "       Non-zero can also mean the tool crashed or is missing, so this is"
    echo "       NOT proof it is enforcing. First lines of its output:"
    printf '%s\n' "$out" | head -3 | sed 's/^/         /'
    return 0
  fi
  if [ -n "$skip_re" ] && grep -qEi -- "$skip_re" <<<"$out"; then
    echo "    ⚠️  CANARY INCONCLUSIVE — $label never examined the fixture"
    echo "       (reported it as ignored/unmatched). This run proves nothing."
    echo "       Widen the tool's config to cover the fixture to make it meaningful."
    return 0
  fi
  if [ "$mode" = block ]; then
    echo "    ❌ CANARY DID NOT FIRE — $label exited 0 on a file it cannot even parse."
    echo "       It is not examining files under this config: nothing matched, or"
    echo "       the tool is not really running. Green here would be a silently"
    echo "       lowered floor — three gates agreeing on a check that ran nothing."
    fail=1
  else
    echo "    ⚠️  CANARY ADVISORY — $label did not flag '$expect' on a fixture that"
    echo "       violates it, so that rule appears disabled. If that is deliberate,"
    echo "       delete this canary line in .claude/verify.sh."
  fi
}

canary_node() {
  canary_open || return 0
  local es tsc_bin skip
  # "never examined the fixture" messages — proves nothing, must not be a red.
  skip='ignored|matching configuration|No files matching'
  es=$(bin_or_path eslint)
  # NB: test each glob separately — `ls a* b*` exits non-zero when EITHER is
  # unmatched, which silently skipped the canary for flat-config-only projects.
  if [ -n "$es" ] && { ls eslint.config.* >/dev/null 2>&1 || ls .eslintrc* >/dev/null 2>&1; }; then
    step "canary: eslint"
    # --no-ignore so the dot-prefixed fixture dir isn't skipped as ignored.
    printf 'const canarySyntaxError = ;\n' > "$CANARY_DIR/canary_syntax.js"
    canary_assert block eslint "Parsing error" "$skip" \
      "$es" --no-ignore "$CANARY_DIR/canary_syntax.js"
    printf 'const canaryUnusedVariable = 1;\n' > "$CANARY_DIR/canary_rule.js"
    canary_assert warn eslint "no-unused-vars" "$skip" \
      "$es" --no-ignore "$CANARY_DIR/canary_rule.js"
  fi
  tsc_bin=$(bin_or_path tsc)
  if [ -n "$tsc_bin" ] && [ -f tsconfig.json ]; then
    step "canary: tsc"
    printf 'const canarySyntaxError: number = ;\n' > "$CANARY_DIR/canary_syntax.ts"
    # Inherit THIS project's compilerOptions — a canary built with tsc's defaults
    # would not notice this project's settings — but compile ONLY the fixture:
    #   - relative `extends`, so no $PWD interpolation to break on odd paths
    #   - both `files` and `include` pinned, because a base config using `files`
    #     would otherwise drag the whole project into the canary compile
    #   - composite/incremental off: they make `-p ... --noEmit` fail TS6304 in
    #     project-reference repos, which would be permanent warning noise
    cat > "$CANARY_DIR/tsconfig.json" <<'JSON'
{ "extends": "../tsconfig.json",
  "compilerOptions": { "noEmit": true, "composite": false, "incremental": false },
  "files": ["canary_syntax.ts"],
  "include": [] }
JSON
    canary_assert block tsc "error TS" "" "$tsc_bin" -p "$CANARY_DIR/tsconfig.json"
  fi
  canary_cleanup
}

canary_python() {  # $1 = the runner the real checks used ("uv run" / "poetry run" / "")
  local run="$1"
  canary_open || return 0
  # Unparseable on purpose: a syntax error fires no matter which rules are
  # selected, so this is a liveness proof that cannot false-red a project with
  # a deliberately narrow `select` (verified: ruff reports invalid-syntax and
  # exits 1 even under select = ["E501"]).
  printf 'def canary_syntax_error(\n' > "$CANARY_DIR/canary_syntax.py"
  if [ -n "$run" ] || command -v ruff >/dev/null 2>&1; then
    step "canary: ruff"
    canary_assert block ruff "invalid-syntax" "" $run ruff check "$CANARY_DIR/canary_syntax.py"
    printf 'import os\n' > "$CANARY_DIR/canary_rule.py"   # F401: imported but unused
    canary_assert warn ruff "F401" "" $run ruff check "$CANARY_DIR/canary_rule.py"
  fi
  if [ -n "$run" ] || command -v mypy >/dev/null 2>&1; then
    step "canary: mypy"
    canary_assert block mypy "[syntax]" "" $run mypy "$CANARY_DIR/canary_syntax.py"
  fi
  canary_cleanup
}

# ── Node / TypeScript (cwd has package.json) ────────────────────────────────
verify_node() {
  local pm; pm=$(node_manager)
  step "node ($pm)"
  has_script lint      && { step "lint";      $pm run lint      || fail=1; }
  has_script typecheck && { step "typecheck"; $pm run typecheck || fail=1; }
  # Tests belong to the full tier (pre-push / CI); quick = commit-time speed.
  [ "$MODE" = "quick" ] && return
  if has_script test; then
    step "test"; $pm run test || fail=1
  else
    # Missing-tests is a DECISION, not a default. Surface it loudly so it's owned,
    # not silently skipped (see ~/.claude/rules/qa.md). It does not hard-fail here
    # — the agent rule + init-claude flag force the human decision — but it must
    # never be invisible.
    echo ""
    echo "⚠️  NO 'test' SCRIPT in package.json — this project has no test floor."
    echo "    Wire a test runner or explicitly accept the gap with the user (qa.md)."
    no_test_floor
  fi
  # Full tier only — the early return above already excluded --quick.
  canary_node
}

# ── Python (cwd has pyproject.toml / setup.py / *.py) ───────────────────────
verify_python() {
  local run; run=$(py_runner)
  if [ -n "$run" ]; then
    # Tools live in the project env; let the runner resolve them (don't gate on
    # host $PATH — that's how a global pytest sneaks in and false-greens).
    step "python ($run)"
    step "ruff";   $run ruff check . || fail=1
    step "mypy";   $run mypy .       || fail=1
    if [ "$MODE" != "quick" ]; then
      step "pytest"; $run pytest -q    || fail=1
    fi
  else
    # No uv/poetry lockfile — fall back to host tools, but never go silently green.
    if command -v ruff   >/dev/null 2>&1; then step "ruff";   ruff check . || fail=1; fi
    if command -v mypy   >/dev/null 2>&1; then step "mypy";   mypy . || fail=1; fi
    if [ "$MODE" = "quick" ]; then
      : # tests belong to the full tier
    elif command -v pytest >/dev/null 2>&1; then step "pytest"; pytest -q || fail=1
    else
      echo ""
      echo "⚠️  no uv/poetry lockfile and pytest not on PATH — Python project has no test floor (see qa.md)."
      no_test_floor
    fi
  fi
  if [ "$MODE" != "quick" ]; then
    canary_python "$run"
  fi
}

for root in $roots; do
  if [ ! -d "$root" ]; then
    echo "⚠️  VERIFY_ROOTS lists '$root' but it is not a directory — skipping."
    continue
  fi
  [ "$root" = "." ] || step "── root: $root ──"
  (
    cd "$root" || exit 0
    # Traps belong HERE, not in the parent: bash resets traps in subshells, and
    # this subshell is what owns the fixture. A surviving fixture is a
    # deliberately-broken file that would red the project's real lint and could
    # be committed. INT/TERM must EXIT — a handler that merely returns makes
    # bash resume the script, i.e. an un-interruptible verify.sh.
    trap 'canary_cleanup' EXIT
    trap 'canary_cleanup; exit 130' INT
    trap 'canary_cleanup; exit 143' TERM
    canary_sweep          # before any real check — see canary_sweep()
    fail=0
    ran_stack=0
    [ -f package.json ] && { verify_node; ran_stack=1; }
    if [ -f pyproject.toml ] || [ -f setup.py ] || ls ./*.py >/dev/null 2>&1; then
      verify_python
      ran_stack=1
    fi
    # A manifest we can't verify must NOT pass silently: enforce-floor gates
    # go/rust/java repos on this script, and running zero checks then exiting 0
    # is a false-green floor — the exact gap this file exists to close (#7).
    if [ "$ran_stack" -eq 0 ]; then
      for m in go.mod Cargo.toml pom.xml build.gradle build.gradle.kts; do
        if [ -f "$m" ]; then
          echo ""
          echo "⚠️  $m detected but verify.sh has no runner for this stack — the floor would run NOTHING."
          echo "    Add your stack's lint/test commands here (mirror verify_node/verify_python)."
          no_test_floor
          break
        fi
      done
    fi
    exit "$fail"
  ) || fail=1
done

# Lint GitHub Actions workflows if present — catch workflow bugs (bad context
# scoping, typos) LOCALLY, before CI does. Optional, like ruff/mypy: run it if
# installed, otherwise say so loudly rather than skip silently.
if ls .github/workflows/*.y*ml >/dev/null 2>&1; then
  if command -v actionlint >/dev/null 2>&1; then
    step "actionlint"; actionlint || fail=1
  else
    echo ""
    echo "ℹ️  .github/workflows present but actionlint not installed — workflows not linted."
    echo "    Install it to catch workflow bugs locally: brew install actionlint"
  fi
fi

echo ""
if [ "$fail" -eq 0 ]; then echo "✅ verify: green"; else echo "❌ verify: failed — fix before committing"; fi
exit "$fail"
