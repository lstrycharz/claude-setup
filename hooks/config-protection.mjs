#!/usr/bin/env node

/**
 * config-protection hook (PreToolUse → Write/Edit)
 *
 * Blocks modifications to linter/formatter config files.
 * Agents frequently weaken configs to make checks pass instead of fixing code.
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
]);

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { raw += chunk; });
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(raw);
    const filePath = input?.tool_input?.file_path || '';
    if (filePath && PROTECTED.has(basename(filePath))) {
      process.stderr.write(
        `BLOCKED: Modifying ${basename(filePath)} is not allowed. ` +
        `Fix the source code to satisfy linter/formatter rules instead of weakening the config.\n`
      );
      process.exit(2);
    }
  } catch { /* allow on parse error */ }
  process.exit(0);
});
