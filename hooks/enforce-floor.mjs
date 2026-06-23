#!/usr/bin/env node

/**
 * enforce-floor hook (PreToolUse → Bash)
 *
 * Blocks `git commit` in a CODE project that has no deterministic floor wired
 * (no .git/hooks/pre-commit). The pre-commit hook is what runs verify.sh —
 * lint + typecheck + test — so "no pre-commit hook" means commits ship with
 * nothing checking them. That is exactly how unverified code slips through.
 *
 * Targeted to avoid friction:
 *   - Only fires on `git commit` (not other git commands).
 *   - Only fires when a code project is detected (package.json / pyproject.toml
 *     / go.mod / Cargo.toml / pom.xml / build.gradle). Docs/config repos with
 *     no manifest are left alone.
 *   - Only fires when .git/hooks/pre-commit is missing. Once init-claude (or the
 *     user) installs it, this hook is invisible.
 *
 * The fix it points to is `init-claude`, which installs the pre-commit hook and
 * scaffolds verify.sh. This hook does NOT run tests itself — it only guarantees
 * the gate exists; the pre-commit hook runs the actual checks.
 *
 * Exit 0 = allow, Exit 2 = block.
 */

import { existsSync } from 'node:fs'
import { join } from 'node:path'
import { execSync } from 'node:child_process'

const MANIFESTS = [
  'package.json', 'pyproject.toml', 'setup.py', 'go.mod',
  'Cargo.toml', 'pom.xml', 'build.gradle', 'build.gradle.kts',
]

let raw = ''
process.stdin.setEncoding('utf8')
process.stdin.on('data', (chunk) => { raw += chunk })
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(raw)
    const command = input?.tool_input?.command || ''
    const cwd = input?.cwd || process.cwd()

    // Only gate actual commits. Anchor `git` to the start of the command or just
    // after a separator so "git commit" inside an echo/string/comment isn't
    // mistaken for a real commit (W7 false-positive block).
    if (!/(?:^|[&|;])\s*git\b[^&|;]*\bcommit\b/.test(command)) process.exit(0)

    // Resolve the repo root + git dir. Not a git repo → nothing to gate.
    let gitDir
    let repoRoot
    try {
      gitDir = execSync('git rev-parse --git-dir', { cwd, stdio: ['ignore', 'pipe', 'ignore'] })
        .toString().trim()
      repoRoot = execSync('git rev-parse --show-toplevel', { cwd, stdio: ['ignore', 'pipe', 'ignore'] })
        .toString().trim()
    } catch { process.exit(0) }

    if (!repoRoot) process.exit(0)
    const isCodeProject = MANIFESTS.some((m) => existsSync(join(repoRoot, m)))
    if (!isCodeProject) process.exit(0) // docs/config repo — no floor required

    const absGitDir = gitDir.startsWith('/') ? gitDir : join(repoRoot, gitDir)
    if (existsSync(join(absGitDir, 'hooks', 'pre-commit'))) process.exit(0) // floor wired

    process.stderr.write(
      'BLOCKED: no deterministic floor in this repo — .git/hooks/pre-commit is missing, ' +
      'so commits run no lint/typecheck/test gate.\n' +
      'Install the floor before committing:  init-claude  (scaffolds verify.sh + the pre-commit hook).\n' +
      'If this repo genuinely needs no floor, remove the enforce-floor hook from ~/.claude/settings.json.\n'
    )
    process.exit(2)
  } catch { /* allow on parse/runtime error — never block on our own bug */ }
  process.exit(0)
})
