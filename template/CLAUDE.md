# Project Instructions

## Session Start
Before making any changes, run the full test suite to orient yourself on project scope and current state. Do not proceed if tests are failing unless the task is specifically to fix them.

<!-- Uncomment and fill in your test commands -->
<!-- - Backend: `uv run pytest -x` -->
<!-- - Frontend: `pnpm test` -->
<!-- - Run both if the task could touch either side. -->

## Tech Stack

<!-- Replace with your actual stack. Delete sections that don't apply. -->
- Language: <!-- e.g. Python 3.12, TypeScript 5.x -->
- Framework: <!-- e.g. FastAPI, Next.js, Django -->
- Database: <!-- e.g. PostgreSQL + SQLAlchemy, MongoDB + Mongoose -->
- Frontend: <!-- e.g. React + TypeScript (strict mode), Vue 3 -->
- Infra: <!-- e.g. Docker, AWS ECS, Vercel -->
- Package manager: <!-- e.g. pnpm (frontend), uv (backend) -->

## Commands
<!-- Fill in your actual build/dev/test/lint commands -->
- **Dev**: <!-- e.g. `pnpm dev` (port 3000) -->
- **Build**: <!-- e.g. `pnpm build` -->
- **Test**: <!-- e.g. `uv run pytest -x` / `pnpm test` -->
- **Lint**: <!-- e.g. `ruff check` / `eslint .` -->
- **Type check**: <!-- e.g. `mypy --strict` / `tsc --noEmit` -->
- **Migrations**: <!-- e.g. `alembic upgrade head` -->

## Project Structure
<!-- Map your actual repo layout -->
<!--
- `/src/api` — route handlers (keep thin, delegate to services)
- `/src/services` — business logic
- `/src/models` — ORM models
- `/src/schemas` — request/response schemas
- `/tests` — mirrors `/src` structure
- `/migrations` — database migrations
- `/tasks` — planning and tracking docs
-->

## Rules
<!-- Project-specific rules. Keep only what's unique to THIS project. -->
<!-- Universal rules (TDD, security, code style) are in global ~/.claude/rules/ -->
- Never modify migration files after they've been merged
- All API endpoints need input validation via schema layer
- No wildcard imports
- Always use timezone-aware datetimes (UTC internally)

## Definition of Done
<!-- Customize to your CI/tooling -->
- Tests written before implementation (red/green/refactor cycle)
- Types pass
- Tests pass
- No new linting errors
- DB migrations generated if models changed
- No `TODO` or `FIXME` left without a linked issue
- Works locally end-to-end before pushing

## Common Gotchas
<!-- Add project-specific landmines here as you discover them -->
<!--
1. Example: Stripe webhooks require raw body, not JSON parsed
2. Example: Production read replicas have 5-min lag
-->

## Core Principles
- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.
- **Own Your Mistakes**: When wrong, say so, fix it, add a lesson. No excuses.
- **Context Is King**: Read existing code before writing new code. Match patterns already in the repo.
