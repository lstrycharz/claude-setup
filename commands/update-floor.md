---
description: Refresh this project's .claude/ infrastructure (reviewer, CI templates, configs) from the plugin
---

Refresh this project's floor infrastructure from the claude-setup plugin.

1. Run the updater from the project root:

   ```
   bash ${CLAUDE_PLUGIN_ROOT}/bin/update-claude
   ```

2. It overwrites only infrastructure (`.claude/bin`, `.claude/review`, `.claude/ci`, `.claude/configs`) and never clobbers customized files (`verify.sh`, `CLAUDE.md`, settings). It adds git hooks only if missing.

3. Show the user what changed (`git diff --stat .claude/`) and commit the refresh as its own save point.
