#!/usr/bin/env node

/**
 * block-no-verify hook (PreToolUse → Bash)
 *
 * Blocks --no-verify flag on git commands to protect pre-commit hooks
 * (e.g. gitleaks secret scanning) from being bypassed.
 *
 * Exit 0 = allow, Exit 2 = block
 */

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { raw += chunk; });
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(raw);
    const command = input?.tool_input?.command || '';
    if (/\bgit\b.*--no-verify/.test(command)) {
      process.stderr.write(
        'BLOCKED: --no-verify is not allowed. Pre-commit hooks exist for a reason ' +
        '(secret scanning, linting). Fix the issue that the hook catches instead.\n'
      );
      process.exit(2);
    }
  } catch { /* allow on parse error */ }
  process.exit(0);
});
