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
 *   node dispatch.mjs bash        PreToolUse  → Bash
 *   node dispatch.mjs edit        PreToolUse  → Write|Edit|MultiEdit|NotebookEdit
 *   node dispatch.mjs post-bash   PostToolUse → Bash
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
 * post-bash role (#12 — the spelling-proof floor check):
 *   - commit-watchdog: after every Bash call, detects (via pure fs reads, no
 *     process spawn on the happy path) whether HEAD moved to a FRESHLY CREATED
 *     commit in a code repo whose floor is not wired. The PreToolUse regexes
 *     can be dodged by spelling (subshells, scripts, encodings) — but the
 *     commit either exists or it doesn't. Exit 2 here doesn't undo the commit
 *     (the tool already ran); it feeds the model a remediation instruction.
 *
 * Exit 0 = allow, Exit 2 = block / feed remediation to the model (stderr).
 * Any internal error → allow: never block on our own bug.
 */

import {
  accessSync, constants, existsSync, readFileSync, writeFileSync,
  mkdirSync, readdirSync, statSync, unlinkSync,
} from 'node:fs';
import { basename, dirname, join, resolve, isAbsolute } from 'node:path';
import { execSync } from 'node:child_process';
import { createHash } from 'node:crypto';

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
    'Install the floor before committing:  /init-floor  (scaffolds verify.sh + the pre-commit hook; ' +
    'from a terminal: bash "$CLAUDE_PLUGIN_ROOT/bin/init-claude").\n' +
    'If the file exists but is not executable: chmod +x it. If core.hooksPath points elsewhere, wire the hook there.\n' +
    'If this repo genuinely needs no floor, disable or uninstall the claude-setup plugin (/plugin).\n'
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

// ── post-bash role: commit-watchdog (#12) ───────────────────────────────────
// State-based and spelling-proof: instead of parsing the command, observe
// whether HEAD moved. Pure fs reads per call (walk up to .git, resolve HEAD);
// git is spawned only on the rare suspicious path (HEAD actually moved in a
// code repo).

const FRESH_COMMIT_WINDOW_S = 300; // older HEAD movement = checkout/branch switch, not a new commit

function findGitDir(startDir) {
  let dir = resolve(startDir);
  for (;;) {
    const dotGit = join(dir, '.git');
    try {
      const st = statSync(dotGit);
      if (st.isDirectory()) return { repoRoot: dir, gitDir: dotGit };
      // Worktree/submodule: .git is a file containing "gitdir: <path>".
      const m = /^gitdir:\s*(.+)\s*$/.exec(readFileSync(dotGit, 'utf8'));
      if (m) return { repoRoot: dir, gitDir: resolve(dir, m[1].trim()) };
      return null;
    } catch { /* not here — keep walking up */ }
    const parent = dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

function resolveHead(gitDir) {
  try {
    const head = readFileSync(join(gitDir, 'HEAD'), 'utf8').trim();
    const m = /^ref:\s*(.+)$/.exec(head);
    if (!m) return head; // detached HEAD: the sha itself
    const ref = m[1].trim();
    try {
      return readFileSync(join(gitDir, ref), 'utf8').trim();
    } catch {
      const packed = readFileSync(join(gitDir, 'packed-refs'), 'utf8');
      for (const line of packed.split('\n')) {
        if (line.endsWith(' ' + ref)) return line.slice(0, 40);
      }
      return null;
    }
  } catch { return null; }
}

function checkCommitWithoutFloor(input) {
  const cwd = input?.cwd || process.cwd();
  const found = findGitDir(cwd);
  if (!found) return null;
  const { repoRoot, gitDir } = found;
  if (!MANIFESTS.some((m) => existsSync(join(repoRoot, m)))) return null;

  const sha = resolveHead(gitDir);
  if (!sha) return null;

  let sessionId = String(input?.session_id || process.env.CLAUDE_SESSION_ID || 'default')
    .replace(/[^a-zA-Z0-9_-]/g, '') || 'default';
  const repoKey = createHash('sha256').update(repoRoot).digest('hex').slice(0, 16);
  const cacheFile = join(METRICS_DIR, `.head-${sessionId}-${repoKey}`);

  let prev = null;
  try { prev = readFileSync(cacheFile, 'utf8').trim(); } catch { /* first sighting */ }
  try { mkdirSync(METRICS_DIR, { recursive: true }); writeFileSync(cacheFile, sha); } catch { /* ignore */ }
  if (!prev || prev === sha) return null; // first sighting, or HEAD didn't move

  // HEAD moved during this session. Only flag when the floor is unwired…
  let hooksDir;
  try {
    hooksDir = execSync('git rev-parse --git-path hooks', { cwd, stdio: ['ignore', 'pipe', 'ignore'] })
      .toString().trim();
  } catch { return null; }
  const absHooksDir = isAbsolute(hooksDir) ? hooksDir : resolve(cwd, hooksDir);
  try { accessSync(join(absHooksDir, 'pre-commit'), constants.X_OK); return null; } catch { /* unwired */ }

  // …and the new HEAD is a freshly CREATED commit (a checkout/branch switch
  // moves HEAD to old commits — that's not a floor violation).
  let committedAt = 0;
  try {
    committedAt = parseInt(
      execSync('git log -1 --format=%ct', { cwd, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim(),
      10,
    );
  } catch { return null; }
  if (!Number.isFinite(committedAt) || Date.now() / 1000 - committedAt > FRESH_COMMIT_WINDOW_S) return null;

  return (
    'FLOOR VIOLATION: a commit was just created in ' + repoRoot + ' but no EXECUTABLE ' +
    'pre-commit hook is wired, so it ran no lint/typecheck gate. This check is state-based — ' +
    'how the command was spelled does not matter.\n' +
    'Remediate NOW: (1) run `bash .claude/verify.sh` and fix any failures; ' +
    '(2) wire the floor (init-claude, or chmod +x the pre-commit hook); ' +
    '(3) amend the commit if fixes were needed.\n'
  );
}

// ── dispatch ────────────────────────────────────────────────────────────────

const ROLES = {
  bash: { blockers: [checkNoVerify, checkFloor], advisory: [] },
  edit: { blockers: [checkConfigProtection], advisory: [suggestCompact] },
  'post-bash': { blockers: [checkCommitWithoutFloor], advisory: [] },
};

const role = ROLES[process.argv[2]];
if (!role) {
  // Misconfigured wiring must be visible, but must not block the agent.
  process.stderr.write(`dispatch.mjs: unknown role '${process.argv[2]}' (expected bash|edit|post-bash)\n`);
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
