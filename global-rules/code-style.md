# Code Style

## General
- Prefer composition over inheritance
- Max function length: ~30 lines — split if longer
- One responsibility per function/class
- Name things clearly — no abbreviations unless universally understood
- No bare `except:` in Python — catch specific exceptions
- No `Any` types in TypeScript — be explicit

## Python
- Type hints on all function signatures
- Docstrings on public functions (Google style)
- Use `ruff` for formatting and linting
- Imports: stdlib → third-party → local (enforced by ruff)

## TypeScript
- Strict mode always enabled
- Prefer `interface` over `type` for object shapes
- Use `const` by default, `let` only when mutation is needed
- No `enum` — use `as const` objects instead

## Module Architecture

Prefer **deep modules** over shallow ones (Ousterhout, *A Philosophy of Software Design*):

- **Deep module** — a small, simple public interface that hides a large amount of internal complexity. Easy to use, easy to test as a unit, easy for AI to navigate.
- **Shallow module** — many tiny files exporting many things, with sprawling cross-dependencies. Hard to test (where do you draw the boundary?), hard for AI to reason about (it has to walk the entire dependency graph).

**Rules:**
- A new feature is usually one deep module with a clear interface, not five shallow ones
- Test boundaries belong around deep modules, not around individual functions
- If you find yourself mocking three internal helpers to test one function, the module is probably too shallow — collapse the helpers
- Resist the urge to extract every reusable bit into its own file. "Reusable" before there's a second caller is speculative

**The test:** can a caller use this module by reading just its public interface? If they need to understand five other files to use it correctly, the module is leaky.

This is architecture-level guidance — not a substitute for the 30-line function rule. Functions stay short; modules stay deep.
