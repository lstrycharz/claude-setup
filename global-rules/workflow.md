# Workflow & Task Management

## Planning
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately — don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

## CLAUDE.md Auto-Population

After the **first planning session** in a new project, check if `.claude/CLAUDE.md` has empty placeholder sections (Tech Stack, Commands, Project Structure, Rules). If it does:

1. **Populate** the empty sections based on decisions made during planning:
   - **Tech Stack** — language, framework, database, frontend, infra, package managers
   - **Commands** — dev, build, test, lint, type check, migrations (whatever applies)
   - **Project Structure** — directory layout with one-line descriptions
   - **Rules** — project-specific rules only (not duplicating global rules)
   - **Session Start** — the actual test commands to run
2. **Show the user** what was written and confirm it's correct
3. **Commit** the populated CLAUDE.md as a save point

This only happens once per project. After that, CLAUDE.md is a living document — update it when the project evolves (new dependencies, changed structure, new gotchas).

## Collaboration Modes

Choose the mode based on task clarity. Default to pair mode when uncertain.

| Mode | When | How | Review |
|------|------|-----|--------|
| **Pair Mode** | Ambiguous problems, design decisions, learning new domains, security/infra changes | Interactive back-and-forth; AI as thought partner | Line-by-line as you go |
| **Delegation Mode** | Well-scoped tasks with clear acceptance criteria | Structured prompt → autonomous execution → human review | Deliverable review against spec |

**Pair Mode** — use for:
- Exploratory work where the path isn't clear
- Architecture and design decisions
- Security-sensitive or infrastructure changes
- Anything touching auth, payments, or PII

**Delegation Mode** — use for:
- Well-defined features with testable acceptance criteria
- Bug fixes with clear reproduction steps
- Refactors where behavior must be preserved
- Tasks where you can verify the output against a spec

**Operating model:** "Delegate, review, own." Well-scoped delegation with clear acceptance criteria is not blind trust — it's a higher-leverage operating mode. You own the output regardless of mode.

## Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

## Chunked Implementation

Never implement a full feature in one pass. Break every task into small chunks and follow this loop:

1. **Implement** one chunk (a single behavior, endpoint, component, etc.)
2. **Test** — run relevant tests, confirm they pass
3. **Commit** — granular commit as a save point
4. Then move to the next chunk.

Rules:
- Each chunk should be small enough to review in under 5 minutes
- Each chunk must leave the codebase in a working state
- If a chunk breaks something, fix it before moving on — never stack broken chunks
- Carry context forward between chunks but keep each one focused

## Delegation Template

When handing off a well-scoped task (delegation mode), structure the prompt:

```
## Task
[One-sentence description of what to build/fix/refactor]

## Context
- Relevant files: [list specific files to read]
- Related patterns: [point to existing code to match]

## Acceptance Criteria
1. [Specific, testable criterion]
2. [Specific, testable criterion]
3. [Specific, testable criterion]

## Constraints
- Follow existing patterns in [file/directory]
- Do not modify [protected areas]
- All tests must pass before marking complete

## Out of Scope
- [Explicitly list what NOT to do]
```

**Pre-delegation checklist:**
- [ ] Task has a clear, bounded scope (one feature, one fix, one refactor)
- [ ] Acceptance criteria are explicit and testable
- [ ] No security-sensitive changes (auth, payments, PII) — those stay in pair mode
- [ ] You can verify the deliverable against the spec

## Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

## Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

**Review depth scales with scope:**

| Scope | Required Verification |
|-------|----------------------|
| Single file fix | Diff review + affected tests pass |
| Feature implementation | Spec review + full test pass + code review |
| Multi-service change | Integration tests + manual QA + spec review |
| Infrastructure / security | Pair mode only — never fully delegate |

## Elegance Check
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes — don't over-engineer
- Challenge your own work before presenting it

## Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Recovery from Failures

When a task goes off-track — whether in pair or delegation mode:

1. **Stop** — don't let errors compound. Revert to last checkpoint (`git stash` or `git reset` to last good commit)
2. **Diagnose** — was the spec ambiguous? Was context missing? Was the task too broad?
3. **Adjust** — tighten the spec, add missing context, break into smaller pieces
4. **Re-attempt** — re-delegate with the improved spec, or switch to pair mode if the task proved too ambiguous

Never push through a failing approach hoping it will work out. The cost of stopping and re-planning is always lower than compounding errors.

## Task Tracking
1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Commit Strategy

Treat commits as **save points**. Commit after every successful chunk, not at the end of a feature.

- Commit after each implement → test loop passes
- Use descriptive messages that explain *why*, not just *what*
- Never batch multiple unrelated changes into one commit
- Benefits: easy rollback if AI suggestions introduce bugs, clear development progression, safe experimentation

## Anti-Patterns

Avoid these — they consistently produce poor outcomes:

- **Monolithic requests** — "Build me the entire feature" with no decomposition
- **Blind trust** — accepting AI output without review or testing
- **Context starvation** — not providing enough information about the codebase, patterns, or constraints
- **Big commits** — waiting until everything is done to commit
- **Skipping tests** — "it looks right" is not verification
- **Pushing through failures** — continuing down a broken path instead of stopping and re-planning
