#!/usr/bin/env bash
#
# install-deps.sh — install JS dependencies in CI with the project's OWN
# package manager and lockfile.
#
# verify.sh picks the package manager from the lockfile (node_manager()),
# because npm against a pnpm tree resolves different versions — a false green.
# The CI templates used to run `npm install` on every repo anyway, so a
# pnpm/yarn/bun project was tested in CI against versions it never locked.
# This mirrors verify.sh's detection, and installs FROZEN: lockfile drift fails
# instead of silently resolving something new.
#
# INSTALL_DEPS_DRY_RUN=1 prints the command without running it (tests).

set -euo pipefail

if [ ! -f package.json ]; then
  echo "install-deps: no package.json — nothing to install"
  exit 0
fi

if [ -f pnpm-lock.yaml ]; then
  cmd="corepack enable && pnpm install --frozen-lockfile"
elif [ -f yarn.lock ]; then
  # Yarn 2+ ("berry") spells it --immutable. Recognise it by .yarnrc.yml or by
  # packageManager — the scaffolded .gitignore hides .yarnrc.yml from CI.
  if [ -f .yarnrc.yml ] || grep -qE '"packageManager"[[:space:]]*:[[:space:]]*"yarn@[2-9]' package.json; then
    cmd="corepack enable && yarn install --immutable"
  else cmd="corepack enable && yarn install --frozen-lockfile"
  fi
elif [ -f bun.lock ] || [ -f bun.lockb ]; then
  cmd="bun install --frozen-lockfile"
elif [ -f package-lock.json ]; then
  cmd="npm ci"
else
  cmd="npm install"   # no lockfile: nothing to be faithful to
fi

# corepack installs pnpm/yarn — at the version in "packageManager", or at its
# OWN default when that's missing, which can be a different major than yours.
if [ "${cmd%% *}" = corepack ] && ! grep -q '"packageManager"' package.json; then
  echo "⚠️  package.json has no \"packageManager\" field, so corepack uses its own default version, not yours." >&2
  echo "    Pin it, e.g.:  npm pkg set packageManager=\"pnpm@\$(pnpm -v)\"" >&2
fi

echo "→ $cmd"
[ "${INSTALL_DEPS_DRY_RUN:-}" = 1 ] && exit 0

if [ "${cmd%% *}" = bun ] && ! command -v bun >/dev/null 2>&1; then
  echo "❌ bun lockfile, but bun isn't installed here — add a setup step (e.g. oven-sh/setup-bun) before this one."
  exit 1
fi
if [ "${cmd%% *}" = corepack ] && ! command -v corepack >/dev/null 2>&1; then
  echo "❌ corepack isn't installed here (Node 25+ no longer bundles it) — use Node 22, or add: npm install -g corepack"
  exit 1
fi
eval "$cmd"
