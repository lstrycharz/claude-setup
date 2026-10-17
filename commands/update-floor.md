---
description: Refresh this project's .claude/ infrastructure (reviewer, CI templates, configs) from the plugin
---

Refresh this project's floor infrastructure from the claude-setup plugin.

1. Run the updater from the project root:

   ```
   bash ${CLAUDE_PLUGIN_ROOT}/bin/update-claude
   ```

   If the project is missing a git hook, the updater installs it into `.git/hooks/`, which the Claude app's sandbox protects. When a hook can't be installed, the updater says so, exits 1, and prints a command to run. Run it once with the sandbox disabled, or, if that's refused, give the user the exact command it printed to run in their own terminal. Never copy hooks in by hand.

2. It overwrites only infrastructure (`.claude/bin`, `.claude/review`, `.claude/ci`, `.claude/configs`) and never clobbers customized files (`verify.sh`, `CLAUDE.md`, settings). It adds `verify.sh`, `review-ledger.md` and the git hooks only if they're missing.

3. Show the user what changed (`git diff --stat .claude/`) and commit the refresh as its own save point. This applies even when it exited 1 over a hook: everything else was refreshed.
