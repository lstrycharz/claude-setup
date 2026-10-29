---
# Code files and stack manifests — every language the floor (verify.sh,
# dispatch.mjs MANIFESTS) knows about, plus notebooks for analysis work.
paths:
  - "**/*.{py,ipynb,ts,tsx,js,jsx,mjs,cjs,sh,sql,go,rs,java,kt,rb}"
  - "**/{package.json,pyproject.toml,setup.py,go.mod,Cargo.toml,pom.xml,build.gradle,build.gradle.kts}"
---
# Workflow & Task Management

## Brief before building
Every non-trivial task starts from three things: the task, the guardrails (what must not change, what not to touch), and what done looks like. With those, work it out and show results; don't stop for plan approval.

Use plan mode only when the approach is genuinely uncertain, the change spans several files or systems, or the code is unfamiliar. Skip it when the change fits in one sentence. Plan mode adds a round-trip, and a clear done-condition prevents more drift than a plan does.

If something goes sideways, stop and re-plan rather than pushing through.

## Define done before starting

Before writing any code on a non-trivial task, write down what "done" looks like.

Format:

```
## Done when
- [ ] [Specific, observable outcome]
- [ ] [Specific, observable outcome]
- [ ] Tests pass
- [ ] [Any other constraint that must hold]
```

Rules:
- Each item must be **observable** — something you could check by running a command or hitting an endpoint, not "code is clean"
- The list should fit in 5–7 items. If it's longer, the task is too big — break it down first
- Once written, the list does not get weakened mid-task. If something turns out to be wrong, **discuss with the user** before changing it

This is the single highest-leverage discipline against scope drift. Writing the done-condition before coding catches more wasted work than any prompt change.

Turn the done-list into a check Claude can run (a test, a script, a command whose output passes or fails). A runnable check lets the work loop until it passes; a prose check needs a human. For a long autonomous run, write the goal the same way before starting: one measurable end state, the command that proves it, and what must not change.

## CLAUDE.md auto-population
After the first session in a new project, fill any empty placeholder sections in `.claude/CLAUDE.md` (Tech Stack, Commands, Project Structure, Rules) from what was decided, show the user, and commit it. After that it is a living document: keep it an index of what is always true, and point to other files by path with when to read them, rather than importing them.

## Subagents
Use subagents for wide searches, research that would flood the main context, and genuinely independent parallel work. Don't spawn them for small tasks, because each one multiplies cost and time.

## Chunked Implementation

Never implement a full feature in one pass. Break every task into small chunks and follow this loop:

1. **Implement** one chunk (a single behavior, endpoint, component, etc.)
2. **Test** — run relevant tests, confirm they pass
3. **Review** — before declaring the chunk done, run the `code-reviewer` agent on the chunk's diff. **Mandatory** for any chunk that adds/changes logic, spans multiple files, or ships without test coverage. Fix the findings before committing. Skip only for trivial edits (single line, comment, config value). A fresh adversarial pass catches what re-reading your own diff does not — and catches it now, not in post-merge review.
4. **Commit** — granular commit as a save point
5. Then move to the next chunk.

Rules:
- Each chunk should be small enough to review in under 5 minutes
- Each chunk must leave the codebase in a working state
- If a chunk breaks something, fix it before moving on — never stack broken chunks
- Carry context forward between chunks but keep each one focused

### Vertical Slices, Not Horizontal Layers

When breaking a feature into chunks, the **first chunk must be a vertical slice** — a thin path through every layer the feature touches (schema → service → API → UI), not an entire layer.

**Why:** AI defaults to coding horizontally — all schema changes first, then all services, then all UI. With that approach you don't get end-to-end feedback until the last layer lands. With a vertical slice, chunk 1 produces something you can run, test, and observe immediately.

**Bad (horizontal):**
- Chunk 1: all DB migrations
- Chunk 2: all service methods
- Chunk 3: all API routes
- Chunk 4: all UI components

**Good (vertical / tracer bullet):**
- Chunk 1: one minimal slice end-to-end (one migration + one service method + one route + one UI element that calls it). Demoable.
- Chunk 2: extend with the next behavior end-to-end
- Chunk 3: edge cases and polish

Tracer bullet test: after chunk 1, can you hit the feature as a user and see something happen? If no, the slice was too horizontal — break the chunking again.

Skip this discipline only when the task is genuinely single-layer (e.g., a pure refactor, a database migration alone, a UI-only tweak).

## Feature Acceptance Tracking

For multi-session features or features with 3+ acceptance criteria, create a `tasks/acceptance.md` file:

```
# Feature: [name]

## Acceptance Criteria
- [ ] [Criterion 1] — status: not started
- [ ] [Criterion 2] — status: not started
- [ ] [Criterion 3] — status: not started

## Notes
<!-- Edge cases, decisions made, things tried and rejected -->
```

Rules:
- Never remove or weaken acceptance criteria — only mark them complete
- Each criterion must have a passing test before being checked off
- Update `.claude/PROGRESS.md` when criteria are completed
- If a criterion turns out to be wrong, discuss with the user before modifying

## Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

## Rules as a Ratchet

Rules in `CLAUDE.md`, `tasks/lessons.md`, and project-level rule files are not a style guide — they're a pilot's checklist. Discipline:

- **Earn each line.** Every rule must trace to a specific past failure or a hard external constraint (regulatory, security, tooling). If you can't name what went wrong that prompted this rule, it's noise — remove it.
- **Add only after a failure.** Don't preemptively brainstorm rules. Wait for an actual mistake; then encode the rule that prevents it.
- **Remove when redundant.** If the model now does the right thing without the rule, retire it. Stale rules dilute attention.
- **Keep CLAUDE.md short.** Aim for under 60 useful lines. More rules = each rule matters less.

Same discipline applies to hooks and tools: every component should have a named behaviour it delivers. If you can't say what failure mode it prevents, it shouldn't be there.

## Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Never let the session that wrote the work be its only judge: use a test, a check script, or — for code, and mandatory per the chunk loop above — the fresh-context `code-reviewer` agent
- Run tests, check logs, demonstrate correctness
- **For user-facing features**: verify the feature works end-to-end as a user would experience it (browser preview, CLI output, API response — whatever applies)

**Review depth scales with scope:**

| Scope | Required Verification |
|-------|----------------------|
| Single file fix | Diff review + affected tests pass |
| Feature implementation | Spec review + full test pass + **E2E verification** + code review |
| Multi-service change | Integration tests + **E2E verification** + manual QA + spec review |
| Infrastructure / security | Interactive with the user, line by line — never fully autonomous |

**E2E verification means:** run the app, hit the feature as a user would, confirm it works. For web apps, use browser preview or Playwright. For APIs, make actual HTTP requests. For CLIs, run the command. "Tests pass" and "it actually works" are different claims — verify both.

## Surgical Changes

Every line you change should trace directly back to the task. Don't scope-creep.

**Do:**
- Touch only the code required to complete the task
- Match the existing style (naming, formatting, patterns) even if you'd write it differently in a greenfield project
- Remove only the code that your changes made dead — nothing else
- If you notice unrelated dead code or pre-existing issues, **mention them** (spawn a task, file a note) rather than silently fixing them
- When your change **adds files** (docs, tests, fixtures, generated output), verify they don't leak into build or runtime artifacts — check `.dockerignore`, `.gitignore`, and any packaging globs. New docs and tests should not ship in the production image.

**Don't:**
- Reformat adjacent code, rewrite comments, or "clean up" imports that weren't part of the task
- Refactor things that aren't broken
- "Improve" variable names, function signatures, or file structure that the task didn't ask for
- Delete pre-existing dead code "while you're in there"

**The test:** after your change, `git diff` should read like a minimal, focused patch. Someone reviewing the diff should be able to tell exactly what task you were working on without being told.

Skip this discipline only when the task is explicitly a refactor or cleanup — in which case the scope of that refactor should be defined upfront.

## Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Recovery from Failures

When a task goes off-track:

1. **Stop** — don't let errors compound. Revert to last checkpoint (`git stash` or `git reset` to last good commit)
2. **Diagnose** — was the spec ambiguous? Was context missing? Was the task too broad?
3. **Adjust** — tighten the spec, add missing context, break into smaller pieces
4. **Re-attempt** — with the improved spec; if the task proved too ambiguous, work it interactively with the user instead

Never push through a failing approach hoping it will work out. The cost of stopping and re-planning is always lower than compounding errors.

## Session Continuity

Maintain `.claude/PROGRESS.md` as the cross-session handoff document. This file bridges context windows so each new session can resume without losing progress.

**Update PROGRESS.md when:**
- Completing a feature or significant chunk of work
- Before running `/compact` (and give it a focus, e.g. `/compact keep the done-list and open blockers`)
- Before ending a session
- When discovering a blocker or regression

**Format:**
- **Completed** — what's done, with commit SHAs or short descriptions
- **In Progress** — current work, where you left off, relevant file paths
- **Blocked** — what's stuck and what's needed
- **Next Up** — prioritized queue of remaining work
- **Known Issues** — bugs or regressions found during this session

PROGRESS.md is the high-level state that survives across sessions; in-session steps live in Claude's own task list.

**Session resume protocol (when PROGRESS.md exists):**
1. Read `.claude/PROGRESS.md`
2. Run `git log --oneline -10`
3. Run the test suite
4. Check `tasks/lessons.md` if it exists
5. Select highest-priority incomplete work from PROGRESS.md
6. Start coding — do not redo completed work

## Commit Strategy

Treat commits as **save points**. Commit after every successful chunk, not at the end of a feature.

- Commit after each implement → test loop passes
- Use descriptive messages that explain *why*, not just *what*
- Never batch multiple unrelated changes into one commit
- Benefits: easy rollback if AI suggestions introduce bugs, clear development progression, safe experimentation
