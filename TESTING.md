# Testing Guide

Three ways to test this setup, in increasing thoroughness.

Since #13 the repo is split in two, and the tests follow that split:

- **The plugin** — hooks, slash commands, agents, and the project template. Installed inside Claude Code (`/plugin install claude-setup@claude-setup`), never copied into `~/.claude/`.
- **The global rules** — `install.sh` copies `global-rules/` and `playbooks/` into `~/.claude/`. That is now the *only* thing the script does; it never touches `settings.json`.

## 1. Automated test suite (30 sec)

Runs 160+ assertions in a sandboxed `HOME` directory. Your real `~/.claude/` is untouched.

```bash
./test.sh
```

Exits 0 if all pass, 1 if any fail. Run it after any change to `install.sh`, `uninstall.sh`, `bin/`, `hooks/`, or the template.

It covers: the fresh install, the plugin's shape (manifest, hooks.json wiring, the five commands, both agents), every hook path in `dispatch.mjs` (config protection, no-verify bypasses, floor enforcement, the commit watchdog), `verify.sh`'s tiers and its no-test-floor hard fail, `init-claude` / `update-claude`, and the uninstall — including the legacy pre-plugin cleanup.

**Requires:** Node.js 18+ (standard on most dev machines).

## 2. Docker sandbox (2 min)

Runs `test.sh` in a fresh `node:22-bookworm-slim` container — verifies the install works on a machine with zero existing configuration.

```bash
./docker-test.sh
```

**Requires:** Docker Desktop or Docker Engine. Install: https://docs.docker.com/get-docker/

**Why use this:** catches bugs that only surface on a clean machine (missing dependencies, assumed shell features, file permission edge cases). `./test.sh` on your own Mac uses your existing tools; Docker proves a coworker with nothing installed can run it too.

The image is deliberately `node:22`, not Ubuntu + `apt install nodejs`: Ubuntu 22.04's archive Node is v12, which can't parse the hooks. They would exit 1 with a SyntaxError, which Claude Code treats as non-blocking — silently disabling the entire protection layer.

## 3. Manual scenarios (10 min)

Walk through the checklist below if you're about to share this with others. Each scenario simulates a real user situation.

---

### Scenario 1: Fresh machine, no existing `~/.claude/`

**Setup:** Backup `mv ~/.claude ~/.claude.bak` if you have one.

**Steps:**
1. `./install.sh`
2. Answer yes to the gitleaks prompt if Homebrew is present

**Expected:**
- `~/.claude/rules/` holds the 7 rule files (including `frontend/react.md`)
- `~/.claude/playbooks/AGENT_PROJECT_PLAYBOOK.md` exists
- **No `~/.claude/settings.json` is created or modified** — the plugin owns hook wiring now
- Nothing is written to `~/.claude/hooks/`, `~/.claude/commands/`, `~/.claude/agents/`, or `~/bin/`

**Cleanup:** `./uninstall.sh`, then `mv ~/.claude.bak ~/.claude` to restore.

---

### Scenario 2: Installing the plugin

**Setup:** Inside Claude Code, on a machine that has never had this repo.

**Steps:**
```
/plugin marketplace add lstrycharz/claude-setup
/plugin install claude-setup@claude-setup
```

**Expected:**
- `/code-review`, `/security-scan`, `/logic-review`, `/init-floor`, `/update-floor` all appear in the slash-command list
- The hooks are live — confirm with Scenario 14 (config protection) or 15 (floor enforcement)
- Your `~/.claude/settings.json` is unchanged — check `git diff` on it if you version it

---

### Scenario 3: Existing Claude Code user with custom rules

**Setup:** Ensure you have some custom rule file, e.g. `~/.claude/rules/my-rule.md`.

**Steps:** `./install.sh`

**Expected:**
- Your custom `my-rule.md` is still there
- Our 7 rules (workflow, qa, testing, code-style, security, agent-design, frontend/react) are added alongside it

**Cleanup:** `./uninstall.sh` removes only our rules. Your custom `my-rule.md` stays.

---

### Scenario 4: Migrating off a pre-plugin install

**Setup:** A machine that ran the old `install.sh` — the one that copied hooks/commands/agents into `~/.claude/` and wired them into `settings.json`.

**Steps:** (order matters — install the plugin first so the guardrails never go dark)
1. Install the plugin (Scenario 2)
2. `./uninstall.sh`
3. `./install.sh`

**Expected:**
- The legacy copies are gone: `~/.claude/hooks/dispatch.mjs`, the four pre-#19 per-file hooks, `~/.claude/commands/{code-review,security-scan,logic-review}.md`, both `~/.claude/agents/` files, `~/bin/init-claude`, `~/bin/update-claude`
- Our entries are stripped from every hook event in `~/.claude/settings.json`
- **Your own** permissions, model, env, and custom hooks in that file are untouched
- The rules and playbooks are reinstalled

**Verify:** `cat ~/.claude/settings.json` — valid JSON, your keys intact, no `claude-setup` hook entries.

---

### Scenario 5: Project already has a `.gitignore`

**Setup:** `cd` to a project with an existing `.gitignore`.

**Steps:** `/init-floor`

**Expected:**
- `.gitignore` is NOT overwritten
- You see: `ℹ️ .gitignore already exists — skipped. Review it to ensure .env* is ignored.`
- `.claude/` is still created normally

**Action:** Review the existing `.gitignore` to confirm it blocks `.env*`. If not, add it manually.

---

### Scenario 6: Project not yet a git repo

**Setup:** `cd` to a plain directory with no `.git/`.

**Steps:** `/init-floor`

**Expected:**
- `.claude/` and `.gitignore` are created
- The git hooks are skipped with: `ℹ️ Not a git repo — skipping git hooks. Run 'git init' first, then re-run init-claude.`

**Why it matters:** the floor's commit and push gates ARE git hooks. Without `git init` first, they are silently absent — the scaffold looks complete but nothing gates a commit.

**Action:** `git init`, remove `.claude/`, then re-run `/init-floor`.

---

### Scenario 7: Project with a manifest but no tests

**Setup:** A fresh project with `pyproject.toml` (or `package.json`) and no test files.

**Steps:** `/init-floor`

**Expected:**
- A loud `⚠️ TEST FLOOR GAP` on the console
- A matching `## ⚠️ Known Issue — test floor gap` section appended to `.claude/PROGRESS.md`
- `.claude/verify.sh` **exits non-zero** until you add tests or create `.claude/verify.allow-no-tests`

**The point:** a globally installed `pytest` must NOT satisfy this — the check looks for test files in the project, not a runner on `$PATH`.

---

### Scenario 8: Node not installed, or too old

**Setup:** A machine without Node.js, or with Ubuntu's apt default (v12).

**Steps:** `./install.sh`

**Expected:** fails up front with a clear error and install instructions. Nothing is copied.

**Why it fails hard:** the hooks use modern syntax an old Node can't parse. They would exit 1 with a SyntaxError on every tool call, which Claude Code treats as non-blocking — so every protection would silently no-op. A hard failure is better than a floor that looks installed and isn't.

---

### Scenario 9: No Homebrew (macOS or Linux without brew)

**Setup:** Run on a machine without Homebrew.

**Steps:** `./install.sh`

**Expected:**
- The gitleaks prompt is skipped gracefully: `⚠️ gitleaks not installed. Secret scanning won't work without it.` followed by the manual install link
- The install completes successfully otherwise

**Note:** without gitleaks, the pre-commit hook prints a warning and skips the secret scan — the lint/typecheck floor still runs.

---

### Scenario 10: Team doesn't use TDD

**Setup:** Your team doesn't write tests before code.

**Issue:** `~/.claude/rules/qa.md` enforces strict Red/Green/Refactor. This will friction with your team's workflow.

**Options:**
- Remove `~/.claude/rules/qa.md` after install
- Edit the file to match your team's actual testing philosophy
- Tell coworkers it's optional: `rm ~/.claude/rules/qa.md` after install

---

### Scenario 11: Team uses Go / Python / non-React stacks

**Setup:** Your team doesn't use React.

**Issue:** `~/.claude/rules/frontend/react.md` is loaded regardless.

**Options:**
- Remove `~/.claude/rules/frontend/react.md`
- Ignore it — Claude won't apply React rules to Go code, so it's mostly noise, but it does eat some tokens

**Related:** `verify.sh` has no runner for Go/Rust/Java. It refuses to pass silently on those manifests — add your stack's commands to `.claude/verify.sh`, mirroring `verify_node` / `verify_python`.

---

### Scenario 12: Running install.sh twice

**Setup:** Already ran `./install.sh` once.

**Steps:** `./install.sh` again

**Expected:**
- Rules and playbooks are overwritten with the latest versions from the repo
- Custom rules and playbooks you added are untouched
- Still no `settings.json` changes

---

### Scenario 13: Uninstalling

**Steps:**
- Plugin: `/plugin uninstall claude-setup` inside Claude Code
- Rules: `./uninstall.sh`

**Expected:**
- The plugin's hooks, commands, and agents stop being available
- Our rules and playbooks are removed; your custom ones stay
- Any legacy pre-plugin files and their `settings.json` wiring are cleaned up (Scenario 4)
- Per-project `.claude/` directories and already-installed git hooks are **not** touched — remove those manually where you want them gone

---

### Scenario 14: False positive on config-protection

**Setup:** You legitimately need to edit `.eslintrc.json` (e.g., adding a new valid rule for your team).

**Steps:** Ask Claude to edit `.eslintrc.json` directly.

**Expected:** Blocked with a message about fixing code instead of weakening the config.

**Action:** Edit it yourself. The block is deliberate — the agent must not be able to loosen the rules it is being measured against, and the same applies to `.claude/verify.sh` and `.git/hooks/*`.

---

### Scenario 15: Committing in a repo with no floor

**Setup:** A git repo with a `package.json` (or any code manifest) and no executable `.git/hooks/pre-commit`.

**Steps:** Ask Claude to commit something.

**Expected:**
- The commit is blocked before it runs, with a message pointing at `/init-floor`
- If a commit lands anyway (spelled some way the pre-check missed), the post-command watchdog flags it on the next Bash call and tells Claude to verify and amend

**Note:** repos with no code manifest (a docs or config repo) are deliberately not gated.
