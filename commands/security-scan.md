Perform a security audit of the current codebase. Use the `security-reviewer` agent to scan in a fresh context for an unbiased review.

## Scan Areas

1. **Secrets Detection** — Search all source files for hardcoded API keys, tokens, passwords, connection strings, private keys. Check if `.env` files are tracked in git.

2. **Injection Vulnerabilities** — Find raw SQL queries with string interpolation, unsanitized input passed to shell commands (`shell=True`, backticks), `eval()`/`exec()` usage, `dangerouslySetInnerHTML` without sanitization.

3. **SSRF Risks** — Find HTTP client calls that accept user-supplied URLs without DNS-resolved validation, missing timeouts on external requests, uncapped response sizes.

4. **Authentication/Authorization** — Check JWT handling (expiry, server-side validation), session management, missing auth middleware on protected routes, CORS configuration, tokens in localStorage.

5. **Input Validation** — Find endpoints or functions that process external input without schema validation (Pydantic, Zod, etc.).

6. **Dependency Audit** — Run `npm audit` or `pip audit` (whichever applies) and report known vulnerabilities.

7. **File System Safety** — Check for path traversal vulnerabilities in file read/write operations, missing containment checks.

8. **Error Handling** — Find places where stack traces or internal details leak to client responses.

## Output Format

| # | Severity | Category | File:Line | Finding | Recommendation |
|---|----------|----------|-----------|---------|----------------|

## Summary

End with:
- Risk counts: CRITICAL / HIGH / MEDIUM / LOW
- Top 3 priority fixes with specific file paths and code suggestions
- Dependency vulnerability summary (if applicable)
