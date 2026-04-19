Run a thorough code review on all uncommitted changes in the current repository. Dispatch the `code-reviewer` sub-agent in a fresh context — do not review code written in the same session that wrote it.

The agent gathers uncommitted changes (`git diff`, `git diff --cached`), analyzes each change against the full review checklist (bugs, security, performance, type safety, error handling, style, test coverage), and returns findings by severity (CRITICAL / WARNING / SUGGESTION) with file:line references and concrete fixes. The review ends with a verdict: **Ship it** / **Needs fixes** / **Needs rework**, plus the top 3 priority items if fixes are needed.

Full checklist and severity definitions: `~/.claude/agents/code-reviewer.md`
