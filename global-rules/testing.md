# Testing Rules

## Python (pytest)
- One assert per test preferred
- Use fixtures for shared setup — no test inheritance
- Name tests: `test_{function}_{scenario}_{expected_result}`
- Use `factory_boy` for model factories, not raw object creation
- Mock at the boundary (HTTP, DB) — not internal functions

## TypeScript (vitest / jest)
- Co-locate test files: `Component.test.tsx` next to `Component.tsx`
- Use `testing-library` — test behavior, not implementation
- No snapshot tests unless explicitly justified
- Prefer `userEvent` over `fireEvent`

## General
- Tests must be deterministic — no flaky tests allowed
- If you break a test, fix it. Don't skip it.
- New features require tests. Bug fixes require regression tests.
