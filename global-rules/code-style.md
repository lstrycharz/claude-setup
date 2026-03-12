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
