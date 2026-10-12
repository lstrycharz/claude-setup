# Cross-vendor reviewer — calibration ledger

The cross-vendor logic reviewer is **advisory**: a REJECT logs a loud warning and
exits 0. The stated reason (`.claude/bin/review-diff.mjs`) is that we gather
false-positive data first, and only then consider promoting specific categories
to blocking.

That promise only means something if the data gets written down. Without a
tally, "advisory-first" never becomes a decision — it stays advisory by inertia,
which is the same as never having had a plan. This file is the tally.

**`/logic-review` already reaches these conclusions** — it verifies every
`critical_flag` and ends with a real? / fixed? / skipped-why table. It should
append those rows here rather than discarding them.

## Rows

One row per **finding**, not per PR — promotion is per category.

`verdict` is one of:

- `real` — confirmed and worth fixing
- `false-positive` — checked and wrong
- `unverifiable` — couldn't confirm either way (counts as neither)

| date | PR | model | category | finding | verdict | note |
|---|---|---|---|---|---|---|

## Before promoting anything to blocking

Read the rows by **category**, not in aggregate — "the reviewer is 80% right" is
not actionable, "it has never been wrong about a missing timeout" is.

A bar, stated as a judgement rather than a statistic: don't promote a category
until it has **≥20 findings with zero false positives**. Below that, say
"underpowered" out loud and leave it advisory (see `agent-design.md`: no
statistical theater — report n, and name it when n can't support a claim).

Watch for a category the model is *structurally* bad at rather than merely
wrong about. It reads the diff as text, with no repo and no ability to run
anything, so claims that need execution — language semantics, "this can never
match", exit-code behaviour — are a different failure class from the judgement
calls it is actually asked for (swallowed errors, missing timeouts, unvalidated
input crossing a trust boundary). A category in that first class should probably
never block, however good its record looks.
