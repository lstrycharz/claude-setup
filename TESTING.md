# Testing Guide

Three ways to test this setup, in increasing thoroughness.

## 1. Automated test suite (30 sec)

Runs 47 assertions in a sandboxed `HOME` directory. Your real `~/.claude/` is untouched.

```bash
./test.sh
```

Exits 0 if all pass, 1 if any fail. Use this anytime you make changes to `install.sh`, `uninstall.sh`, or the hooks.

**Requires:** Node.js (standard on most dev machines).

## 2. Docker sandbox (2 min)

Runs `test.sh` in a fresh Ubuntu 22.04 container — verifies the install works on a machine with zero existing configuration.

```bash
./docker-test.sh
```

**Requires:** Docker Desktop or Docker Engine. Install: https://docs.docker.com/get-docker/

**Why use this:** catches bugs that only surface on a clean machine (missing dependencies, assumed shell features, file permission edge cases). `./test.sh` on your own Mac uses your existing tools; Docker ensures a coworker with nothing installed can also run it.

## 3. Manual scenarios (10 min)

Walk through the checklist below if you're about to share this with others. Each scenario simulates a real user situation.

---

### Scenario 1: Fresh machine, no existing `~/.claude/`

**Setup:** Backup `mv ~/.claude ~/.claude.bak` if you have one.

**Steps:**
1. `./install.sh`
2. Answer yes to the gitleaks prompt if Homebrew is present

**Expected:**
- All rules, hooks, commands, agents copied to `~/.claude/`
- `~/bin/init-claude` exists and is executable
- `~/.claude/settings.json` created with `ENABLE_TOOL_SEARCH=true` and 3 hooks
- `~/bin` added to PATH in shell rc file if missing

**Cleanup:** `./uninstall.sh`, then `mv ~/.claude.bak ~/.claude` to restore.

---

### Scenario 2: Existing Claude Code user with custom rules

**Setup:** Ensure you have some custom rule file, e.g. `~/.claude/rules/my-rule.md`.

**Steps:** `./install.sh`

**Expected:**
- Your custom `my-rule.md` is still there
- Our 6 rules (workflow, qa, testing, code-style, security, frontend/react) are added alongside it

**Cleanup:** `./uninstall.sh` removes only our rules. Your custom `my-rule.md` stays.

---

### Scenario 3: Existing custom hooks in settings.json

**Setup:** Pre-seed `~/.claude/settings.json` with a custom `PostToolUse` hook.

**Steps:** `./install.sh`

**Expected:**
- Your custom `PostToolUse` hook is preserved exactly
- Our `PreToolUse` hooks are added alongside it
- Any existing `permissions`, `model`, `env`, `extraKnownMarketplaces` keys are preserved

**Verify:** `cat ~/.claude/settings.json` — both your hooks and ours should be present.

---

### Scenario 4: Project already has a `.gitignore`

**Setup:** `cd` to a project with an existing `.gitignore`.

**Steps:** `init-claude`

**Expected:**
- `.gitignore` is NOT overwritten
- You see: `ℹ️ .gitignore already exists — skipped. Review it to ensure .env* is ignored.`
- `.claude/` is still created normally

**Action:** Review the existing `.gitignore` to confirm it blocks `.env*`. If not, add it manually.

---

### Scenario 5: Project not yet a git repo

**Setup:** `cd` to a plain directory with no `.git/`.

**Steps:** `init-claude`

**Expected:**
- `.claude/` is created
- `.gitignore` is created (if missing)
- Pre-commit hook is skipped with message: `ℹ️ Not a git repo — skipping pre-commit hook. Run 'git init' first, then re-run init-claude.`

**Action:** `git init`, then re-run `init-claude` to get the pre-commit hook installed.

---

### Scenario 6: Node not installed

**Setup:** On a machine without Node.js.

**Steps:** `./install.sh`

**Expected:**
- Script fails at the settings-merging step with a clear error
- Rules, hooks, commands, agents, `init-claude` still get copied (they're file copies, no Node needed)

**Current behavior:** install.sh will fail with `node: command not found` partway through. Coworkers should install Node first: `brew install node` (macOS) or `apt-get install nodejs` (Ubuntu).

---

### Scenario 7: No Homebrew (macOS or Linux without brew)

**Setup:** Run on a machine without Homebrew.

**Steps:** `./install.sh`

**Expected:**
- Gitleaks prompt is skipped gracefully: `⚠️ gitleaks not installed. Secret scanning won't work without it.` followed by manual install link.
- Install completes successfully otherwise.

---

### Scenario 8: Team doesn't use TDD

**Setup:** Your team doesn't write tests before code.

**Issue:** `~/.claude/rules/qa.md` enforces strict Red/Green/Refactor. This will friction with your team's workflow.

**Options:**
- Remove `~/.claude/rules/qa.md` after install
- Edit the file to match your team's actual testing philosophy
- Tell coworkers it's optional: `rm ~/.claude/rules/qa.md` after install

---

### Scenario 9: Team uses Go / Python / non-React stacks

**Setup:** Your team doesn't use React.

**Issue:** `~/.claude/rules/frontend/react.md` is loaded regardless.

**Options:**
- Remove `~/.claude/rules/frontend/react.md`
- Ignore it — Claude won't apply React rules to Go code, so it's mostly noise, but it does eat some tokens

---

### Scenario 10: Running install.sh twice

**Setup:** Already ran `./install.sh` once.

**Steps:** `./install.sh` again

**Expected:**
- No duplicate hooks in settings.json (hook count stays at 3)
- All files overwritten with latest versions from the repo
- Custom settings still preserved

**Verify:** `cat ~/.claude/settings.json` — should be valid JSON with exactly 3 hook entries.

---

### Scenario 11: Running uninstall.sh

**Setup:** After a full install.

**Steps:** `./uninstall.sh`

**Expected:**
- All our files removed (hooks, commands, agents, rules we added)
- Your custom permissions, model, env, other hooks in settings.json — **preserved**
- Prompt asks before removing `~/.claude-template/`
- Final summary lists what was preserved and what to clean manually

**Verify after:** `cat ~/.claude/settings.json` should still have your custom keys. Files you added to `~/.claude/rules/` (not ours) should still be there.

---

### Scenario 12: False positive on config-protection

**Setup:** You legitimately need to edit `.eslintrc.json` (e.g., adding a new valid rule for your team).

**Steps:** Ask Claude to edit `.eslintrc.json` directly.

**Expected:** Blocked with message about fixing code instead of weakening config.

**Workaround:**
- Option A: Edit the file yourself outside Claude
- Option B: Temporarily remove the hook: `rm ~/.claude/hooks/config-protection.mjs`, re-run install to restore
- Option C: Edit the `PROTECTED` list in the hook to remove `.eslintrc.json` for your workflow

---

## What's covered vs not

| Covered | Not Covered |
|---------|------------|
| Install on Ubuntu | Install on Windows |
| Install on macOS (indirectly via test.sh) | Install on Alpine/other minimal distros |
| Fresh machine | Machines with hostile existing configs |
| Idempotent re-install | Partial/interrupted installs |
| Uninstall preserves custom settings | Rollback of project-level changes (pre-commit, .gitignore) |
| Hook false positives (manual) | Every possible MCP server interaction |

If you test any of the "Not Covered" scenarios successfully, PR an addition to this file.
