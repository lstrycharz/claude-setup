#!/usr/bin/env node

/**
 * dispatch.mjs — single entry point for all claude-setup hooks (#19).
 *
 * One Node process per tool event instead of one per hook: Node cold-start is
 * ~40-70ms, and separate hook files added two spawns to every Bash call and
 * every file edit. Same checks, half the latency — and shared helpers
 * (stripQuotes, stdin parsing, the block/allow protocol) live in one place.
 *
 * Usage (wired by install.sh into ~/.claude/settings.json):
 *   node dispatch.mjs bash   PreToolUse → Bash
 *   node dispatch.mjs edit   PreToolUse → Write|Edit|MultiEdit|NotebookEdit
 *
 * bash role:
 *   - no-verify guard: blocks hook-bypass attempts (--no-verify, commit's -n
 *     short form incl. bundled flags, core.hooksPath overrides). Quoted string
 *     segments are stripped first so a command that merely MENTIONS a flag in
 *     a string is not blocked — false positives teach the agent to obfuscate.
 *     A speed bump against the lazy path, not a security boundary (#12).
 *   - enforce-floor: blocks `git commit` in a code project with no wired floor.
 *     STATE-based: resolves the active hooks dir via `git rev-parse --git-path
 *     hooks` (so core.hooksPath can't fake it) and requires the exec bit (git
 *     silently skips a non-executable pre-commit).
 *
 * edit role:
 *   - config-protection: blocks edits to lint/typecheck/test-runner configs and
 *     to the floor's own files (.claude/verify.sh, the allow-no-tests marker,
 *     .git/hooks/*) — agents weaken configs to make checks pass (#10).
 *   - suggest-compact: counts edits per session; past a threshold, nudges to
 *     update PROGRESS.md then /clear (transitioning) or /compact (mid-task).
 *     Emitted as hook JSON output (systemMessage); never blocks.
 *
 * Exit 0 = allow, Exit 2 = block (stderr is fed to the model).
 * Any internal error → allow: never block on our own bug.
 */

import {
  accessSync, constants, existsSync, readFileSync, writeFileSync,
  mkdirSync, readdirSync, statSync, unlinkSync,
} from 'node:fs';
import { basename, join, resolve, isAbsolute } from 'node:path';
import { execSync } from 'node:child_process';

// Replace single/double-quoted segments so flags/commands inside string
// literals don't match (W7).
const stripQuotes = (s) => s.replace(/"(?:[^"\\]|\\.)*"|'[^']*'/g, '""');

// ── bash role: no-verify guard ──────────────────────────────────────────────

const BYPASS_PATTERNS = [
  // --no-verify anywhere on a git command
  /\bgit\b[^&|;\n]*--no-verify\b/,
  // commit's short form -n, including bundled short flags that contain n (-an).
  // Anchored to `commit` so `git log -n 5` / `git push -n` (dry-run) stay allowed.
  /\bgit\b[^&|;\n]*\bcommit\b[^&|;\n]*\s-[a-zA-Z]*n[a-zA-Z]*(?=\s|$)/,
  // disabling hooks wholesale via core.hooksPath (config or -c override)
  /\bgit\b[^&|;\n]*core\.hooksPath/i,
];

function checkNoVerify(input) {
  const command = stripQuotes(input?.tool_input?.command || '');
  if (BYPASS_PATTERNS.some((re) => re.test(command))) {
    return (
      'BLOCKED: bypassing pre-commit hooks is not allowed (--no-verify, commit -n, ' +
      'or core.hooksPath overrides). Hooks exist for a reason (secret scanning, ' +
      'linting, tests). Fix the issue the hook catches instead.\n'
    );
  }
  return null;
}

// ── bash role: enforce-floor ────────────────────────────────────────────────

const MANIFESTS = [
  'package.json', 'pyproject.toml', 'setup.py', 'go.mod',
  'Cargo.toml', 'pom.xml', 'build.gradle', 'build.gradle.kts',
];

// `git … commit` at the command start or after a separator ([&|;(] or newline),
// optionally prefixed by VAR=val assignments, `command`, `builtin`, or `env`.
const COMMIT_RE =
  /(?:^|[&|;(\n])\s*(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*(?:command\s+|builtin\s+|env\s+(?:-\S+\s+|[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*)?git\b[^&|;\n]*\bcommit\b/;

function checkFloor(input) {
  const command = input?.tool_input?.command || '';
  const cwd = input?.cwd || process.cwd();

  if (!COMMIT_RE.test(stripQuotes(command))) return null;

  let repoRoot;
  try {
    repoRoot = execSync('git rev-parse --show-toplevel', { cwd, stdio: ['ignore', 'pipe', 'ignore'] })
      .toString().trim();
  } catch { return null; } // not a git repo — nothing to gate

  if (!repoRoot) return null;
  const isCodeProject = MANIFESTS.some((m) => existsSync(join(repoRoot, m)));
  if (!isCodeProject) return null; // docs/config repo — no floor required

  // The ACTIVE hooks dir (respects core.hooksPath). --git-path output is
  // relative to cwd when not absolute.
  let hooksDir;
  try {
    hooksDir = execSync('git rev-parse --git-path hooks', { cwd, stdio: ['ignore', 'pipe', 'ignore'] })
      .toString().trim();
  } catch { return null; }
  const absHooksDir = isAbsolute(hooksDir) ? hooksDir : resolve(cwd, hooksDir);

  try {
    accessSync(join(absHooksDir, 'pre-commit'), constants.X_OK);
    return null; // floor wired and executable
  } catch { /* missing or not executable — block */ }

  return (
    'BLOCKED: no deterministic floor in this repo — no EXECUTABLE pre-commit hook in the ' +
    'active hooks dir (' + absHooksDir + '), so commits run no lint/typecheck/test gate.\n' +
    'Install the floor before committing:  init-claude  (scaffolds verify.sh + the pre-commit hook).\n' +
    'If the file exists but is not executable: chmod +x it. If core.hooksPath points elsewhere, wire the hook there.\n' +
    'If this repo genuinely needs no floor, remove the claude-setup Bash hook from ~/.claude/settings.json.\n'
  );
}

// ── edit role: config-protection ────────────────────────────────────────────

const PROTECTED = new Set([
  '.eslintrc', '.eslintrc.js', '.eslintrc.cjs', '.eslintrc.json',
  '.eslintrc.yml', '.eslintrc.yaml',
  'eslint.config.js', 'eslint.config.mjs', 'eslint.config.cjs',
  'eslint.config.ts', 'eslint.config.mts',
  '.prettierrc', '.prettierrc.js', '.prettierrc.cjs', '.prettierrc.json',
  '.prettierrc.yml', '.prettierrc.yaml',
  'prettier.config.js', 'prettier.config.mjs', 'prettier.config.cjs',
  'biome.json', 'biome.jsonc',
  '.stylelintrc', '.stylelintrc.json', '.stylelintrc.js',
  'ruff.toml', '.ruff.toml',
  '.editorconfig',
  // typecheck floor — weakening tsconfig/mypy is the same game as weakening eslint
  'tsconfig.json', 'tsconfig.base.json', 'mypy.ini',
  // test floor — excluding failing tests via runner config is the same game too
  'pytest.ini',
  'vitest.config.ts', 'vitest.config.js', 'vitest.config.mts', 'vitest.config.mjs',
  'jest.config.js', 'jest.config.ts', 'jest.config.cjs', 'jest.config.mjs',
]);

// Path-based protection for the floor itself — basename matching isn't enough
// here (verify.sh is only special inside .claude/, git hooks only inside .git/).
const PROTECTED_PATHS =
  /(^|[\\/])\.claude[\\/]verify\.(sh|allow-no-tests)$|(^|[\\/])\.git[\\/]hooks[\\/]/;

function checkConfigProtection(input) {
  // Write/Edit/MultiEdit use file_path; NotebookEdit uses notebook_path.
  const filePath = input?.tool_input?.file_path || input?.tool_input?.notebook_path || '';
  if (!filePath) return null;
  if (PROTECTED_PATHS.test(filePath)) {
    return (
      `BLOCKED: ${filePath} is part of the verification floor (verify.sh / pre-commit / ` +
      `allow-no-tests). The floor is not agent-editable — if it genuinely needs to change, ` +
      `ask the user to change it.\n`
    );
  }
  if (PROTECTED.has(basename(filePath))) {
    return (
      `BLOCKED: Modifying ${basename(filePath)} is not allowed. ` +
      `Fix the source code to satisfy linter/typecheck/test rules instead of weakening the config.\n`
    );
  }
  return null;
}

// ── edit role: suggest-compact (advisory, never blocks) ─────────────────────

const THRESHOLD = 50;
const REMINDER_INTERVAL = 25;
const MAX_COUNTER_AGE_MS = 7 * 24 * 60 * 60 * 1000; // prune counters older than 7 days
const HOME = process.env.HOME || process.env.USERPROFILE || '/tmp';
const METRICS_DIR = join(HOME, '.claude', 'metrics');

function pruneOldCounters() {
  try {
    const now = Date.now();
    for (const f of readdirSync(METRICS_DIR)) {
      if (!f.startsWith('.compact-counter-')) continue;
      const p = join(METRICS_DIR, f);
      try {
        if (now - statSync(p).mtimeMs > MAX_COUNTER_AGE_MS) unlinkSync(p);
      } catch { /* ignore */ }
    }
  } catch { /* ignore */ }
}

function suggestCompact(input) {
  // Session id comes from the hook's stdin JSON — that is where Claude Code
  // provides it; the env var is only a fallback (#11).
  let sessionId = String(input?.session_id || process.env.CLAUDE_SESSION_ID || 'default');
  sessionId = sessionId.replace(/[^a-zA-Z0-9_-]/g, '');
  const counterFile = join(METRICS_DIR, `.compact-counter-${sessionId}`);

  try { mkdirSync(METRICS_DIR, { recursive: true }); } catch { /* ignore */ }
  pruneOldCounters();

  let count = 1;
  try {
    const prev = parseInt(readFileSync(counterFile, 'utf8').trim(), 10);
    if (Number.isFinite(prev) && prev > 0) count = prev + 1;
  } catch { /* first call */ }

  try { writeFileSync(counterFile, String(count)); } catch { /* ignore */ }

  if (count === THRESHOLD) {
    return `[suggest-compact] ${THRESHOLD} edit calls reached. Update .claude/PROGRESS.md, then run /clear (preferred when transitioning tasks) or /compact (if staying mid-task).`;
  }
  if (count > THRESHOLD && (count - THRESHOLD) % REMINDER_INTERVAL === 0) {
    return `[suggest-compact] ${count} edit calls. Update .claude/PROGRESS.md, then /clear (transitioning) or /compact (mid-task).`;
  }
  return null;
}

// ── dispatch ────────────────────────────────────────────────────────────────

const ROLES = {
  bash: { blockers: [checkNoVerify, checkFloor], advisory: [] },
  edit: { blockers: [checkConfigProtection], advisory: [suggestCompact] },
};

const role = ROLES[process.argv[2]];
if (!role) {
  // Misconfigured wiring must be visible, but must not block the agent.
  process.stderr.write(`dispatch.mjs: unknown role '${process.argv[2]}' (expected bash|edit)\n`);
  process.exit(0);
}

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { raw += chunk; });
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(raw);
    for (const check of role.blockers) {
      const message = check(input);
      if (message) {
        process.stderr.write(message);
        process.exit(2);
      }
    }
    for (const check of role.advisory) {
      const message = check(input);
      if (message) {
        // Hook JSON output: systemMessage is surfaced to the user without blocking.
        process.stdout.write(JSON.stringify({ systemMessage: message }) + '\n');
      }
    }
  } catch { /* allow on parse/runtime error — never block on our own bug */ }
  process.exit(0);
});
