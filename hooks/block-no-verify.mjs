#!/usr/bin/env node

/**
 * block-no-verify hook (PreToolUse → Bash)
 *
 * Blocks attempts to bypass pre-commit hooks on git commands:
 *   - the --no-verify flag (and commit's short form -n, incl. bundled flags)
 *   - core.hooksPath overrides (git -c core.hooksPath=… / git config core.hooksPath),
 *     which disable hooks wholesale without any per-commit flag (#6)
 *
 * Quoted string segments are stripped before matching, so a commit message or
 * echo that merely MENTIONS a flag is not blocked — false positives teach the
 * agent to obfuscate commands, the opposite of what this hook is for.
 *
 * This is a speed bump against an agent taking the lazy path, not a security
 * boundary — see the enforce-floor hook and the pre-commit hook itself for the
 * state-based gate.
 *
 * Exit 0 = allow, Exit 2 = block
 */

// Replace single/double-quoted segments so flags inside string literals don't match.
const stripQuotes = (s) => s.replace(/"(?:[^"\\]|\\.)*"|'[^']*'/g, '""');

const BYPASS_PATTERNS = [
  // --no-verify anywhere on a git command
  /\bgit\b[^&|;\n]*--no-verify\b/,
  // commit's short form -n, including bundled short flags that contain n (-an).
  // Anchored to `commit` so `git log -n 5` / `git push -n` (dry-run) stay allowed.
  /\bgit\b[^&|;\n]*\bcommit\b[^&|;\n]*\s-[a-zA-Z]*n[a-zA-Z]*(?=\s|$)/,
  // disabling hooks wholesale via core.hooksPath (config or -c override)
  /\bgit\b[^&|;\n]*core\.hooksPath/i,
];

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { raw += chunk; });
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(raw);
    const command = stripQuotes(input?.tool_input?.command || '');
    if (BYPASS_PATTERNS.some((re) => re.test(command))) {
      process.stderr.write(
        'BLOCKED: bypassing pre-commit hooks is not allowed (--no-verify, commit -n, ' +
        'or core.hooksPath overrides). Hooks exist for a reason (secret scanning, ' +
        'linting, tests). Fix the issue the hook catches instead.\n'
      );
      process.exit(2);
    }
  } catch { /* allow on parse error */ }
  process.exit(0);
});
