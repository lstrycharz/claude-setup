Perform a security audit of the current codebase. Dispatch the `security-reviewer` sub-agent in a fresh context for an unbiased review.

The agent scans systematically against the OWASP-aligned checklist: hardcoded secrets, injection (SQL / command / XSS), SSRF, authentication and authorization gaps, input validation and path traversal, dependency vulnerabilities (`npm audit` / `pip audit`), and error-handling leaks. Findings are returned in a table (Severity | Category | File:Line | Finding | Fix), followed by risk counts (CRITICAL / HIGH / MEDIUM / LOW) and the top 3 priority fixes.

Full scan checklist: `~/.claude/agents/security-reviewer.md`
