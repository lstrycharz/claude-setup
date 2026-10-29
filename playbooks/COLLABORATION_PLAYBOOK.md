# Collaboration Playbook (pull-loaded)

Human-facing guidance moved out of the code-scoped workflow rule. Read when deciding how to hand a task to Claude.

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

## Anti-Patterns

Avoid these — they consistently produce poor outcomes:

- **Monolithic requests** — "Build me the entire feature" with no decomposition
- **Blind trust** — accepting AI output without review or testing
- **Context starvation** — not providing enough information about the codebase, patterns, or constraints
- **Big commits** — waiting until everything is done to commit
- **Skipping tests** — "it looks right" is not verification
- **Pushing through failures** — continuing down a broken path instead of stopping and re-planning
