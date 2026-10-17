---
description: Scaffold the deterministic floor (.claude/, verify.sh, git hooks) in the current project
---

Scaffold this project's deterministic floor from the claude-setup plugin.

1. **Run the scaffolder from the project root.** It writes `.git/hooks/` and `.claude/settings*.json`, which the Claude app's sandbox protects by design (so Claude can't change its own permissions or plant hooks), so it needs one run outside the sandbox; the user approves that single call:

   ```
   bash ${CLAUDE_PLUGIN_ROOT}/bin/init-claude
   ```

   It checks those paths **before writing anything**, so a sandboxed first try is harmless: if it can't write them, it changes nothing and prints a one-line command. Re-run that same command with the sandbox disabled.

   **If the unsandboxed call is refused, or the script prints that message: stop.** Give the user the exact command it printed to run in their own terminal, from this folder. **Never rebuild the scaffold by hand** (copying files, renaming the gitignore, installing hooks one at a time): a hand-made copy is where drift creeps in, and the script's own checks don't run on it.

2. **An existing `.claude/` is normal.** The app creates one in any folder a session has been open in (`.cc-writes/`, and `settings.local.json` once a permission is approved). The scaffolder merges into it and keeps `settings.local.json` and `CLAUDE.local.md` as they are. It refuses only when template files would be overwritten. Then the project is already scaffolded: stop, and suggest `/update-floor` instead.

3. Follow the "Next steps" it prints, doing them WITH the user:
   - Fill in `.claude/CLAUDE.md` (tech stack + real lint/typecheck/test commands)
   - Confirm `.claude/verify.sh` runs this project's actual commands
   - If it flagged a TEST FLOOR GAP, surface that to the user as a blocking decision — wire a test runner or get an explicit accept (per qa.md)
   - Offer to copy a CI file from `.claude/ci/` into place

4. Commit `.claude/` as a save point when done.
