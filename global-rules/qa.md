# QA — Red/Green TDD (Strict)

**Every code change follows the Red-Green-Refactor cycle. No exceptions.**

## The Cycle

### 1. RED — Write a failing test first
- Before writing or modifying any implementation code, write a test that defines the expected behavior.
- Run the test. Confirm it **fails**. If it doesn't fail, the test is wrong or the behavior already exists.
- Each test should cover **one** behavior or requirement. Keep it small.

### 2. GREEN — Write the minimum code to pass
- Write only enough implementation code to make the failing test pass.
- Do not add functionality that isn't demanded by a failing test.
- Do not refactor yet. Ugly is fine. Just get to green.

### 3. REFACTOR — Clean up under green tests
- Improve structure, naming, duplication — whatever needs it.
- Run all tests after every change. Stay green.
- If a refactor breaks a test, fix it before moving on.

Then go back to RED for the next behavior.

## Rules

- **No implementation without a failing test first.** This includes bug fixes, new features, and refactors that change behavior.
- **Run tests after every step.** Red must be red. Green must be green. Refactor must stay green.
- **One behavior per cycle.** If a task requires multiple behaviors, break it into multiple red-green-refactor loops.
- **Test names describe behavior**, not implementation. Prefer `rejects_expired_tokens` over `test_check_function`.
- **Do not skip the red step.** If you think you know what the code should be, write the test that proves it first.

## Applying to Common Tasks

| Task | How to TDD it |
|---|---|
| New feature | RED: test the desired behavior → GREEN: implement → REFACTOR |
| Bug fix | RED: write a test that reproduces the bug (fails) → GREEN: fix it → REFACTOR |
| Refactor | Ensure tests exist for current behavior first. Then refactor under green. If tests are missing, add them (red-green) before touching implementation. |
| Deleting code | Confirm existing tests still pass, or update/remove tests that cover deleted behavior. |

## What Not to Do

- Do not write implementation code "to get started" and then backfill tests.
- Do not write multiple tests at once before implementing anything.
- Do not skip refactoring — it's where code quality lives.
- Do not treat tests as optional or secondary to implementation.
