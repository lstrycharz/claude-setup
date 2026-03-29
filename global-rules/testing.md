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

## E2E (Playwright / Puppeteer)
- Use for user-facing features with interactive flows (forms, navigation, multi-step processes)
- Not required for every change — use when unit/integration tests can't catch the failure mode
- Test the critical user path, not every permutation
- E2E tests live in a dedicated `e2e/` or `tests/e2e/` directory
- Keep E2E tests fast — test the happy path and 1-2 critical edge cases
- If a bug was only catchable via E2E (layout, state, flow), add an E2E regression test

## General
- Tests must be deterministic — no flaky tests allowed
- If you break a test, fix it. Don't skip it.
- New features require tests. Bug fixes require regression tests.
