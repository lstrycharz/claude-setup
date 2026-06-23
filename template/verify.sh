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
#
# Exit 0 = green (safe). Non-zero = blocked. init-claude auto-detects your stack;
# edit freely for your project.

set -uo pipefail
fail=0
step() { echo ""; echo "→ $*"; }

# Directories to verify. Default: repo root. Space-separated; opt-in for monorepos.
roots=${VERIFY_ROOTS:-.}

node_manager() {   # echo the JS package manager for the cwd, from its lockfile
  if   [ -f pnpm-lock.yaml ]; then echo pnpm
  elif [ -f yarn.lock ];      then echo yarn
  elif [ -f bun.lockb ];      then echo bun
  else echo npm
  fi
}

has_script() {     # $1 = npm script name; true if defined in package.json
  node -e "process.exit(require('./package.json').scripts?.['$1']?0:1)" 2>/dev/null
}

py_runner() {      # echo "uv run" / "poetry run" / "" for the cwd
  if   [ -f uv.lock ]     && command -v uv     >/dev/null 2>&1; then echo "uv run"
  elif [ -f poetry.lock ] && command -v poetry >/dev/null 2>&1; then echo "poetry run"
  else echo ""
  fi
}

# ── Node / TypeScript (cwd has package.json) ────────────────────────────────
verify_node() {
  local pm; pm=$(node_manager)
  step "node ($pm)"
  has_script lint      && { step "lint";      $pm run lint      || fail=1; }
  has_script typecheck && { step "typecheck"; $pm run typecheck || fail=1; }
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
  fi
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
    step "pytest"; $run pytest -q    || fail=1
  else
    # No uv/poetry lockfile — fall back to host tools, but never go silently green.
    if command -v ruff   >/dev/null 2>&1; then step "ruff";   ruff check . || fail=1; fi
    if command -v mypy   >/dev/null 2>&1; then step "mypy";   mypy . || fail=1; fi
    if command -v pytest >/dev/null 2>&1; then step "pytest"; pytest -q || fail=1
    else
      echo ""
      echo "⚠️  no uv/poetry lockfile and pytest not on PATH — Python project has no test floor (see qa.md)."
    fi
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
    fail=0
    [ -f package.json ] && verify_node
    if [ -f pyproject.toml ] || [ -f setup.py ] || ls ./*.py >/dev/null 2>&1; then
      verify_python
    fi
    exit "$fail"
  ) || fail=1
done

echo ""
if [ "$fail" -eq 0 ]; then echo "✅ verify: green"; else echo "❌ verify: failed — fix before committing"; fi
exit "$fail"
