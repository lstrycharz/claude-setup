# Project Instructions

<!-- ⚠️  THIS FILE IS AUTO-POPULATED after the first planning session.
     When you run plan mode for the first time, Claude will fill in
     Tech Stack, Commands, Project Structure, and Rules based on the plan.
     Review and adjust as needed. -->

## Session Start

**Fresh project (no PROGRESS.md):**
Run the full test suite to orient yourself on project scope and current state. Do not proceed if tests are failing unless the task is specifically to fix them.

**Resuming work (PROGRESS.md exists):**
1. Read `.claude/PROGRESS.md` for handoff context
2. Run `git log --oneline -10` to see recent commits
3. Run the full test suite — confirm current state is green
4. Read `tasks/todo.md` and `tasks/lessons.md` if they exist
5. Pick the highest-priority incomplete item from PROGRESS.md
6. Begin work — do not re-implement anything marked as Completed

## Tech Stack
<!-- Auto-populated from first plan mode session -->

## Commands
<!-- Auto-populated from first plan mode session.
     Record the real lint / typecheck / test commands here AND wire them into
     .claude/verify.sh — that one script is the floor every gate runs
     (pre-commit hook, enforce-floor hook, CI).

     verify.sh detects the Node manager from the lockfile and runs Python tools
     through the project env (uv run / poetry run). MONOREPO (Python backend +
     Node frontend in one repo): list each sub-project so both suites run —
       VERIFY_ROOTS="backend frontend" .claude/verify.sh
     Defaults to the repo root. -->
- Run the floor: `.claude/verify.sh`  (monorepo: `VERIFY_ROOTS="backend frontend" .claude/verify.sh`)

## Project Structure
<!-- Auto-populated from first plan mode session -->

## Rules
<!-- Auto-populated from first plan mode session. Keep only what's unique to THIS project. -->
<!-- Universal rules (TDD, security, code style) are in global ~/.claude/rules/ -->

## Definition of Done
- Tests written before implementation (red/green/refactor cycle)
- `.claude/verify.sh` passes (lint + typecheck + test) — the deterministic floor
- Types pass
- Tests pass
- No new linting errors
- `code-reviewer` agent run on the diff; findings addressed (per workflow.md chunk loop)
- DB migrations generated if models changed
- No `TODO` or `FIXME` left without a linked issue
- Works locally end-to-end before pushing

## Common Gotchas
<!-- Add project-specific landmines here as you discover them -->

## Core Principles
- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.
- **Own Your Mistakes**: When wrong, say so, fix it, add a lesson. No excuses.
- **Context Is King**: Read existing code before writing new code. Match patterns already in the repo.
