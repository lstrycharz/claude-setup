---
description: Scaffold the deterministic floor (.claude/, verify.sh, git hooks) in the current project
---

Scaffold this project's deterministic floor from the claude-setup plugin.

1. Run the scaffolder from the project root:

   ```
   bash ${CLAUDE_PLUGIN_ROOT}/bin/init-claude
   ```

2. It refuses to touch an existing `.claude/` — if it says one exists, stop and tell the user (they may want `/update-floor` instead).

3. Follow the "Next steps" it prints, doing them WITH the user:
   - Fill in `.claude/CLAUDE.md` (tech stack + real lint/typecheck/test commands)
   - Confirm `.claude/verify.sh` runs this project's actual commands
   - If it flagged a TEST FLOOR GAP, surface that to the user as a blocking decision — wire a test runner or get an explicit accept (per qa.md)
   - Offer to copy a CI file from `.claude/ci/` into place

4. Commit `.claude/` as a save point when done.
