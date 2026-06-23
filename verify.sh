#!/usr/bin/env bash
#
# verify.sh — THIS repo's own deterministic floor (the harness eating its own
# dog food). Same contract it ships to every other project: one script that is
# lint/syntax + test, run identically by the pre-commit hook, CI, and by hand.
#
#   - "lint/typecheck" here = syntax-check every script we ship (node --check on
#     .mjs, bash -n on shell), because a broken hook/template silently breaks
#     every downstream project that installs it.
#   - "test" = the full test.sh suite.
#
# Exit 0 = green. Non-zero = blocked. NB: test.sh calls install/uninstall in a
# sandboxed HOME, it does NOT call this script — so there is no recursion.

set -uo pipefail
fail=0
step() { echo ""; echo "→ $*"; }

step "node --check (shipped .mjs)"
while IFS= read -r f; do
  node --check "$f" && echo "  ok $f" || { echo "  FAIL $f"; fail=1; }
done < <(git ls-files '*.mjs')

step "bash -n (shipped shell scripts)"
while IFS= read -r f; do
  bash -n "$f" && echo "  ok $f" || { echo "  FAIL $f"; fail=1; }
done < <(git ls-files '*.sh' 'bin/init-claude' 'template/.pre-commit-hook')

step "test suite (test.sh)"
bash test.sh || fail=1

echo ""
if [ "$fail" -eq 0 ]; then echo "✅ verify: green"; else echo "❌ verify: failed — fix before committing"; fi
exit "$fail"
