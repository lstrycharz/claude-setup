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
# Exit 0 = green (safe). Non-zero = blocked. init-claude auto-detects your stack
# and runs the right tools below; edit freely for your project.

set -uo pipefail
fail=0
step() { echo ""; echo "→ $*"; }

# ── Node / TypeScript ───────────────────────────────────────────────────────
if [ -f package.json ]; then
  step "lint";      npm run lint --if-present      || fail=1
  step "typecheck"; npm run typecheck --if-present || fail=1
  step "test";      npm test --if-present          || fail=1

  # Missing-tests is a DECISION, not a default. Surface it loudly so it's owned,
  # not silently skipped (see ~/.claude/rules/qa.md). It does not hard-fail here
  # — the agent rule + init-claude flag force the human decision — but it must
  # never be invisible.
  if ! node -e "process.exit(require('./package.json').scripts?.test?0:1)" 2>/dev/null; then
    echo ""
    echo "⚠️  NO 'test' SCRIPT in package.json — this project has no test floor."
    echo "    Wire a test runner or explicitly accept the gap with the user (qa.md)."
  fi
fi

# ── Python ──────────────────────────────────────────────────────────────────
if [ -f pyproject.toml ] || [ -f setup.py ] || ls ./*.py >/dev/null 2>&1; then
  if command -v ruff   >/dev/null 2>&1; then step "ruff";   ruff check . || fail=1; fi
  if command -v mypy   >/dev/null 2>&1; then step "mypy";   mypy . || fail=1; fi
  if command -v pytest >/dev/null 2>&1; then step "pytest"; pytest -q || fail=1
  else
    echo ""
    echo "⚠️  pytest not found — Python project has no test floor (see qa.md)."
  fi
fi

echo ""
if [ "$fail" -eq 0 ]; then echo "✅ verify: green"; else echo "❌ verify: failed — fix before committing"; fi
exit "$fail"
