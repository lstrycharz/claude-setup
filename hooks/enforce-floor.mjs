#!/usr/bin/env node

/**
 * enforce-floor hook (PreToolUse → Bash)
 *
 * Blocks `git commit` in a CODE project that has no deterministic floor wired
 * (no executable pre-commit hook in the ACTIVE hooks dir). The pre-commit hook
 * is what runs verify.sh — lint + typecheck + test — so "no pre-commit hook"
 * means commits ship with nothing checking them. That is exactly how unverified
 * code slips through.
 *
 * Targeted to avoid friction:
 *   - Only fires on `git commit` (not other git commands).
 *   - Only fires when a code project is detected (package.json / pyproject.toml
 *     / go.mod / Cargo.toml / pom.xml / build.gradle). Docs/config repos with
 *     no manifest are left alone.
 *   - Only fires when the floor is missing. Once init-claude (or the user)
 *     installs it, this hook is invisible.
 *
 * The floor check is STATE-based, not string-based (#6, #12):
 *   - resolves the active hooks dir via `git rev-parse --git-path hooks`, so a
 *     core.hooksPath override can't fake a wired floor by leaving a stale file
 *     in .git/hooks;
 *   - requires the exec bit — git silently skips a non-executable pre-commit,
 *     so bare existence is not "wired".
 *
 * Commit detection strips quoted strings first (so "see git commit docs" in an
 * echo/string isn't a commit — W7) and anchors `git` to the command start or a
 * separator, including newlines and subshell opens, allowing env-var/command/env
 * prefixes.
 *
 * Exit 0 = allow, Exit 2 = block.
 */

import { accessSync, constants, existsSync } from 'node:fs'
import { join, resolve, isAbsolute } from 'node:path'
import { execSync } from 'node:child_process'

const MANIFESTS = [
  'package.json', 'pyproject.toml', 'setup.py', 'go.mod',
  'Cargo.toml', 'pom.xml', 'build.gradle', 'build.gradle.kts',
]

// Replace single/double-quoted segments so a commit mentioned inside a string
// literal can't match (W7).
const stripQuotes = (s) => s.replace(/"(?:[^"\\]|\\.)*"|'[^']*'/g, '""')

// `git … commit` at the command start or after a separator ([&|;(] or newline),
// optionally prefixed by VAR=val assignments, `command`, `builtin`, or `env`.
const COMMIT_RE =
  /(?:^|[&|;(\n])\s*(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*(?:command\s+|builtin\s+|env\s+(?:-\S+\s+|[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*)?git\b[^&|;\n]*\bcommit\b/

let raw = ''
process.stdin.setEncoding('utf8')
process.stdin.on('data', (chunk) => { raw += chunk })
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(raw)
    const command = input?.tool_input?.command || ''
    const cwd = input?.cwd || process.cwd()

    if (!COMMIT_RE.test(stripQuotes(command))) process.exit(0)

    // Resolve the repo root. Not a git repo → nothing to gate.
    let repoRoot
    try {
      repoRoot = execSync('git rev-parse --show-toplevel', { cwd, stdio: ['ignore', 'pipe', 'ignore'] })
        .toString().trim()
    } catch { process.exit(0) }

    if (!repoRoot) process.exit(0)
    const isCodeProject = MANIFESTS.some((m) => existsSync(join(repoRoot, m)))
    if (!isCodeProject) process.exit(0) // docs/config repo — no floor required

    // The ACTIVE hooks dir (respects core.hooksPath). --git-path output is
    // relative to cwd when not absolute.
    let hooksDir
    try {
      hooksDir = execSync('git rev-parse --git-path hooks', { cwd, stdio: ['ignore', 'pipe', 'ignore'] })
        .toString().trim()
    } catch { process.exit(0) }
    const absHooksDir = isAbsolute(hooksDir) ? hooksDir : resolve(cwd, hooksDir)

    try {
      accessSync(join(absHooksDir, 'pre-commit'), constants.X_OK)
      process.exit(0) // floor wired and executable
    } catch { /* missing or not executable — block below */ }

    process.stderr.write(
      'BLOCKED: no deterministic floor in this repo — no EXECUTABLE pre-commit hook in the ' +
      'active hooks dir (' + absHooksDir + '), so commits run no lint/typecheck/test gate.\n' +
      'Install the floor before committing:  init-claude  (scaffolds verify.sh + the pre-commit hook).\n' +
      'If the file exists but is not executable: chmod +x it. If core.hooksPath points elsewhere, wire the hook there.\n' +
      'If this repo genuinely needs no floor, remove the enforce-floor hook from ~/.claude/settings.json.\n'
    )
    process.exit(2)
  } catch { /* allow on parse/runtime error — never block on our own bug */ }
  process.exit(0)
})
