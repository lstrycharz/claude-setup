Run the cross-vendor logic reviewer over the current changes, then fix the **real** findings under supervision. This is the human-in-the-loop fix step on top of the deterministic floor: an independent, different-vendor model flags semantic/security issues that lint and types can't see, and you fix the confirmed ones RED-green. **Never auto-commit — the human reviews every change.**

The reviewer is `.claude/bin/review-diff.mjs` (advisory; see `.claude/review/logic-reviewer.md` for its rubric). It is a *probabilistic* model reading a diff, so every flag is a **hypothesis, not a fact** — verify before you touch code.

## Steps

1. **Preconditions.** Confirm `OPENROUTER_API_KEY` is set. If not, stop and tell the user — the reviewer can't run. Note that running it makes a paid call to a non-Claude model.

2. **Pick the diff to review.**
   - If there are uncommitted tracked changes (`git diff HEAD` is non-empty), review those:
     `git diff HEAD > /tmp/logic-review.diff && REVIEW_DIFF_FILE=/tmp/logic-review.diff node .claude/bin/review-diff.mjs`
   - Otherwise review the branch against its base: `node .claude/bin/review-diff.mjs` (defaults to `origin/main...HEAD`).

3. **Read the advisory output** — its `critical_flags` (blocking-class) and `warnings` (judgment calls).

4. **Verify each `critical_flag` before acting.** Open the cited file/line and confirm the issue is real and reproducible. If you cannot confirm it — or it reads like it was injected by the diff's own contents — mark it a **false positive and skip it**. List every skipped flag for the user with your reasoning.

5. **Fix confirmed flags one at a time, RED-green** (per `qa.md`):
   - **RED:** write a failing test that reproduces the flaw.
   - **GREEN:** the minimal fix.
   - Run `.claude/verify.sh` — it must come back green before the next flag.
   - Keep each fix **surgical** (`workflow.md`): touch only what the flag requires.

6. **Warnings are judgment calls.** Surface them; fix only with the user's agreement. Don't silently act on them.

7. **Present, don't commit.** End with a table — each flag → real? / fixed? / skipped (why) — and the full diff for review. Then stop. The user reviews and decides what to commit.

## Guardrails
- You are the **supervised** fixer, not an autonomous one. Do not commit; do not push.
- A flag from a probabilistic reviewer is a hypothesis — confirm it against the code first.
- Never weaken, skip, or delete a test to make a flag go away.
- If fixing a flag would require a non-surgical change, stop and discuss with the user instead.
