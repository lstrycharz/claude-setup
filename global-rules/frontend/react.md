# Frontend / React Rules

## Components
- Functional components only — no class components
- One component per file
- Co-locate styles, tests, and types with the component
- Props interface named `{ComponentName}Props`

## State & Data
- Use React Query / TanStack Query for server state
- Local state with `useState` / `useReducer` only for UI state
- No prop drilling beyond 2 levels — use context or composition

## Patterns
- Prefer early returns over nested conditionals in JSX
- Extract custom hooks when logic is reused across 2+ components
- Keep `useEffect` dependencies explicit — never suppress lint warnings
- Memoize with `useMemo` / `useCallback` only when measured, not preemptively
