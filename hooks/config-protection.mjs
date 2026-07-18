#!/usr/bin/env node

/**
 * config-protection hook (PreToolUse → Write/Edit/MultiEdit/NotebookEdit)
 *
 * Blocks modifications to (1) linter/formatter/typecheck/test-runner config
 * files and (2) the verification floor itself. Agents frequently weaken configs
 * to make checks pass instead of fixing code — and the floor's own files
 * (.claude/verify.sh, the pre-commit hook, the allow-no-tests marker) are the
 * highest-leverage gaming target of all (#10).
 *
 * NOTE: package.json / pyproject.toml can also carry lint config but are
 * legitimate to edit (deps, scripts) — they can't be blocked wholesale.
 *
 * Exit 0 = allow, Exit 2 = block
 */

import { basename } from 'node:path';

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

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { raw += chunk; });
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(raw);
    // Write/Edit/MultiEdit use file_path; NotebookEdit uses notebook_path.
    const filePath = input?.tool_input?.file_path || input?.tool_input?.notebook_path || '';
    if (filePath && PROTECTED_PATHS.test(filePath)) {
      process.stderr.write(
        `BLOCKED: ${filePath} is part of the verification floor (verify.sh / pre-commit / ` +
        `allow-no-tests). The floor is not agent-editable — if it genuinely needs to change, ` +
        `ask the user to change it.\n`
      );
      process.exit(2);
    }
    if (filePath && PROTECTED.has(basename(filePath))) {
      process.stderr.write(
        `BLOCKED: Modifying ${basename(filePath)} is not allowed. ` +
        `Fix the source code to satisfy linter/typecheck/test rules instead of weakening the config.\n`
      );
      process.exit(2);
    }
  } catch { /* allow on parse error */ }
  process.exit(0);
});
