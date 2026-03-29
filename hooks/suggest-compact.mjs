#!/usr/bin/env node

/**
 * suggest-compact hook (PreToolUse → Edit/Write)
 *
 * Counts tool calls per session. After a threshold (default 50),
 * suggests running /compact to free up context window.
 *
 * Exit 0 always (never blocks).
 */

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const THRESHOLD = 50;
const REMINDER_INTERVAL = 25;
const HOME = process.env.HOME || process.env.USERPROFILE || '/tmp';
const METRICS_DIR = join(HOME, '.claude', 'metrics');
const SESSION_ID = (process.env.CLAUDE_SESSION_ID || 'default').replace(/[^a-zA-Z0-9_-]/g, '');
const COUNTER_FILE = join(METRICS_DIR, `.compact-counter-${SESSION_ID}`);

try {
  mkdirSync(METRICS_DIR, { recursive: true });
} catch { /* ignore */ }

let count = 1;
try {
  const prev = parseInt(readFileSync(COUNTER_FILE, 'utf8').trim(), 10);
  if (Number.isFinite(prev) && prev > 0) count = prev + 1;
} catch { /* first call */ }

try {
  writeFileSync(COUNTER_FILE, String(count));
} catch { /* ignore */ }

if (count === THRESHOLD) {
  process.stderr.write(
    `[suggest-compact] ${THRESHOLD} tool calls reached. Update .claude/PROGRESS.md, then run /compact if transitioning between tasks.\n`
  );
} else if (count > THRESHOLD && (count - THRESHOLD) % REMINDER_INTERVAL === 0) {
  process.stderr.write(
    `[suggest-compact] ${count} tool calls. Update .claude/PROGRESS.md, then run /compact if context feels stale.\n`
  );
}

process.exit(0);
