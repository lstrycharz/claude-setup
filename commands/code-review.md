Run a thorough code review on all uncommitted changes in the current repository. Use the `code-reviewer` agent to perform the review in a fresh context — do not review your own work in the same session that wrote it.

## Steps

1. Run `git diff` (unstaged) and `git diff --cached` (staged) to gather all changes
2. Run `git diff --name-only` to identify all changed files
3. Read the full content of each changed file for surrounding context
4. For each changed file, analyze:
   - **Logic errors or bugs** — off-by-one, null refs, race conditions, missing edge cases
   - **Security vulnerabilities** — SQL injection, XSS, SSRF, hardcoded secrets, missing auth checks
   - **Performance issues** — N+1 queries, unnecessary re-renders, missing indexes, unbounded loops
   - **Type safety** — `any` types, unsafe assertions, missing null checks
   - **Missing error handling** — uncaught exceptions, missing try/catch at boundaries
   - **Code style violations** — against project CLAUDE.md and global rules
   - **Test coverage gaps** — new behavior without corresponding tests

## Output Format

For each issue found:

- **File**: `path/to/file.ext` (line X-Y)
- **Severity**: CRITICAL / WARNING / SUGGESTION
- **Issue**: Clear description of the problem
- **Fix**: Concrete recommendation with code example if applicable

## Summary

End with:
- Issue counts by severity
- Overall verdict: **Ship it** / **Needs fixes** / **Needs rework**
- Top 3 priority items if there are fixes needed
