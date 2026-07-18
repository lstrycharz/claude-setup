#!/usr/bin/env node

/**
 * suggest-compact hook (PreToolUse → Edit/Write)
 *
 * Counts file-edit tool calls per session. After a threshold (default 50),
 * suggests running /clear (preferred when transitioning tasks) or
 * /compact (when staying mid-task) to free up context window.
 *
 * Why /clear over /compact when transitioning: /compact stuffs the
 * conversation into a summary that becomes part of the next session's
 * context. Sediment compounds. /clear returns to a known baseline,
 * with assets (PROGRESS.md, todo.md, code itself) carrying state.
 *
 * The session id comes from the hook's stdin JSON (session_id) — that is
 * where Claude Code provides it; an env var is only a fallback (#11).
 * The nudge is emitted as hook JSON output ({"systemMessage": …}) so it is
 * actually surfaced — stderr on exit 0 is shown to no one.
 *
 * Exit 0 always (never blocks).
 */

import { readFileSync, writeFileSync, mkdirSync, readdirSync, statSync, unlinkSync } from 'node:fs';
import { join } from 'node:path';

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

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { raw += chunk; });
process.stdin.on('end', () => {
  let sessionId = 'default';
  try {
    const input = JSON.parse(raw);
    sessionId = String(input?.session_id || process.env.CLAUDE_SESSION_ID || 'default');
  } catch { /* fall back to env/default */
    sessionId = String(process.env.CLAUDE_SESSION_ID || 'default');
  }
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

  let message = '';
  if (count === THRESHOLD) {
    message = `[suggest-compact] ${THRESHOLD} edit calls reached. Update .claude/PROGRESS.md, then run /clear (preferred when transitioning tasks) or /compact (if staying mid-task).`;
  } else if (count > THRESHOLD && (count - THRESHOLD) % REMINDER_INTERVAL === 0) {
    message = `[suggest-compact] ${count} edit calls. Update .claude/PROGRESS.md, then /clear (transitioning) or /compact (mid-task).`;
  }
  if (message) {
    // Hook JSON output: systemMessage is surfaced to the user without blocking.
    process.stdout.write(JSON.stringify({ systemMessage: message }) + '\n');
  }

  process.exit(0);
});
