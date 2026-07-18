# Claude Code Setup

A ready-to-go configuration for Claude Code that makes it smarter, safer, and more consistent across all your projects.

**Think of it like this:** Claude Code is a junior developer. This setup gives it a handbook of rules, safety guardrails, and good habits — so it writes better code, doesn't leak your secrets, and picks up where it left off between sessions.

## What Does This Actually Do?

### Rules (the handbook)

These are instructions that Claude reads automatically every time you start a conversation. They tell Claude *how* to work:

- **Write tests first** — Claude must write a failing test before writing any code (Red/Green/Refactor)
- **Work in small pieces** — no building an entire feature in one go. Small chunks, tested and committed one at a time
- **Keep code clean** — short functions, clear names, no shortcuts
- **Stay secure** — never hardcode passwords, always validate user input, check for common vulnerabilities
- **Use React properly** — functional components, proper state management, no bad patterns
- **Verify with E2E tests** — for anything users interact with, Claude should check that it actually works in a browser, not just that tests pass

### Hooks (the guardrails)

These run automatically in the background and stop Claude from doing dumb things:

| What it prevents | How |
|---|---|
| **Weakening your code rules** | Blocks Claude from editing your linter/formatter configs. It has to fix the code, not loosen the rules. |
| **Skipping safety checks** | Blocks `--no-verify` on git commits. Your secret scanner stays on. |
| **Committing with no floor** | Blocks `git commit` in a code repo that has no pre-commit gate installed — so commits can't ship with nothing checking them. Points you at `init-claude`. |
| **Running out of memory** | After 50 actions, reminds Claude to save progress and free up space with `/compact`. |

### The deterministic floor (gates, not vibes)

Every project gets one `.claude/verify.sh` — **the single source of truth for lint + typecheck + test.** Three gates run that same script, so what the agent runs, what blocks your commit, and what blocks a merge are identical:

1. **Pre-commit hook** — runs `verify.sh` (+ secret scan) on every commit, agent or human.
2. **`enforce-floor` hook** — blocks the agent from committing a code repo that has no floor wired at all.
3. **CI templates** (`.claude/ci/`) — run `verify.sh` on PRs; enable branch protection (`BRANCH_PROTECTION.md`) to make red **block the merge**.

`init-claude` auto-detects your stack, drops starter ESLint / TS / Prettier / ruff configs, and **loudly flags a missing test framework** (writing it into `PROGRESS.md`) instead of letting untested code ship silently. The rule: gates the machine enforces, not instructions a human has to remember.

`verify.sh` picks the Node manager from the lockfile (pnpm / yarn / bun / npm) and runs Python tools through the project env (`uv run` / `poetry run`) — so it never false-greens by running `npm` against a pnpm tree or a global `pytest` that collects nothing. **Monorepos** (e.g. a Python backend + Node frontend in one repo) opt in explicitly — point it at each sub-project and it runs and accumulates every suite:

```bash
VERIFY_ROOTS="backend frontend" .claude/verify.sh
```

Defaults to the repo root; the opt-in is one line, not magic directory-walking.

If a code project has **no test runner at all**, `verify.sh` now *blocks* rather than just warning — closing the "passes because it has no tests" gap that the floor exists to prevent. Accept the gap deliberately (a config repo, a scratch spike) with a marker file: `.claude/verify.allow-no-tests`.

### The cross-vendor reviewer (a second opinion)

The floor catches code that's *mechanically* wrong (won't lint, won't typecheck, fails tests). It can't catch code that's *designed* wrong — a swallowed error, a missing timeout, an unvalidated input crossing a trust boundary. So there's a second layer: an independent **different-vendor** AI (DeepSeek by default, via OpenRouter — deliberately not Claude, so it doesn't share Claude's blind spots) reads each PR's diff and flags semantic and security risks.

It is **advisory** — it posts its findings as a comment on the PR and **never blocks the merge**. A probabilistic reviewer can be wrong (and will occasionally raise a confident false alarm), so it advises rather than gates. You — or `/logic-review` — verify each flag and fix the real ones. The deterministic floor stays the thing that actually blocks.

**Setting it up (GitHub):**

1. **Get an OpenRouter key.** Sign up at [openrouter.ai](https://openrouter.ai), add a little credit, and create an API key. (OpenRouter is one gateway to many models — Claude, GPT, Gemini, DeepSeek — so you can switch models without changing code.)
2. **Add the workflow.** Copy `.claude/ci/reviewer-github.yml` into your repo's `.github/workflows/` folder and commit it.
3. **Add the key as a secret.** In GitHub: **your repo → Settings → Secrets and variables → Actions → New repository secret**. Name it exactly `OPENROUTER_API_KEY` and paste your key. It must be a **repository** secret — *not* an Environment secret (the workflow won't see an environment secret).
4. **(Optional) pick the model.** The default is `deepseek/deepseek-chat` (cheap and solid for a second opinion). To use another, add a repository **variable** (same screen → *Variables* tab) named `LOGIC_REVIEWER_MODEL` — e.g. `google/gemini-2.5-pro`, `openai/gpt-5`, `anthropic/claude-sonnet-4-6`. Any ID from [openrouter.ai/models](https://openrouter.ai/models) works.

Open a pull request and the reviewer posts its findings as a comment. If the model you picked is ever retired, it says so on the PR instead of failing silently.

> **Run it locally too:** `OPENROUTER_API_KEY=sk-... node .claude/bin/review-diff.mjs` reviews your current branch from the terminal. Point `OPENROUTER_BASE_URL` at a local Ollama/vLLM endpoint to run it free and offline.

### Slash Commands (on-demand checks)

Type these in Claude Code whenever you want a second opinion:

- **`/code-review`** — Reviews everything you've changed but haven't committed yet. Finds bugs, security issues, and style problems. Like having a senior dev look over your shoulder.
- **`/security-scan`** — Scans your whole project for security vulnerabilities (leaked secrets, injection risks, auth problems). Based on the OWASP Top 10.
- **`/logic-review`** — Runs the cross-vendor reviewer on your current changes, then fixes the *real* findings with you reviewing each step (RED-green, surgical, never auto-commits).

### Progress Tracking (the memory)

This is the newest addition. Claude used to forget everything between sessions — like handing a project to a new developer every time with no notes.

Now Claude maintains a **PROGRESS.md** file that acts like a shift handoff:
- What's been finished
- What's still in progress
- What's stuck and why
- What to work on next

Every new session, Claude reads this file first, checks the git history, runs the tests, and picks up right where it left off. No repeated work, no lost context.

### Project Template (the starter kit)

When you start a new project, one command sets up:
- A `.claude/` folder with project-specific instructions
- A `.gitignore` that blocks secrets, API keys, and credentials from ever being committed
- A pre-commit hook that scans every commit for accidentally leaked passwords or tokens
- A progress file for tracking work across sessions

## Getting Started

### Step 1: Install the plugin (once per computer)

Inside Claude Code:

```
/plugin marketplace add lstrycharz/claude-setup
/plugin install claude-setup@claude-setup
```

That gives you the hooks, the slash commands (`/code-review`, `/init-floor`, …),
the agents, and the project template — versioned, updatable, and removable as
one unit, without ever touching your `settings.json`.

Then install the global rules (the one part plugins don't cover — they're
auto-loaded from `~/.claude/rules` into every session):

```bash
git clone https://github.com/lstrycharz/claude-setup.git
cd claude-setup
./install.sh       # copies global rules + playbooks; checks Node + gitleaks
```

**Upgrading from the old copied install?** Run `./uninstall.sh` once — it
removes the old copied hooks/commands/agents and strips their wiring from
`settings.json` (your own settings are preserved).

### Step 2: Set up a new project

In Claude Code, from the project directory:

```
/init-floor        # sets up .claude/, .gitignore, and the git hooks
```

(Or from a repo checkout: `cd my-project && /path/to/claude-setup/bin/init-claude`.)

### Step 3: Start working

Open Claude Code and enter plan mode. On your first planning session, Claude will automatically fill in your project's `CLAUDE.md` with the tech stack, commands, and project structure you discussed. You review it, confirm, and you're set.

From then on, every Claude session in that project will:
1. Read the project instructions
2. Follow the global rules (testing, security, code style)
3. Get blocked by hooks if it tries something unsafe
4. Track progress for the next session

## How Everything Fits Together

```
You install once (install.sh)
    │
    │   Sets up global rules, hooks, commands, and agents
    │   These apply to EVERY project automatically
    │
You run init-claude in each project
    │
    │   Creates project-specific config, .gitignore, secret scanning
    │
You start Claude Code
    │
    ├── Claude reads the rules        → knows HOW to work
    ├── Claude reads CLAUDE.md        → knows WHAT this project is
    ├── Claude reads PROGRESS.md      → knows WHERE it left off
    ├── Hooks run in background       → prevent mistakes silently
    └── /code-review, /security-scan, /logic-review → available when you want them
```

## What's in the Box

```
claude-setup/
├── global-rules/              # Rules Claude follows in every project
│   ├── workflow.md            # How to plan, build, track progress, and hand off between sessions
│   ├── qa.md                  # Write tests first, always (Red/Green/Refactor)
│   ├── testing.md             # How to write good tests (pytest, vitest, Playwright)
│   ├── code-style.md          # Clean code rules (short functions, clear names, explicit types)
│   ├── security.md            # Never leak secrets, validate input, prevent attacks
│   ├── agent-design.md        # Three-layer framework for AI agent / LLM-pipeline projects
│   └── frontend/
│       └── react.md           # React-specific patterns
├── playbooks/                 # Long-form references (pulled when needed, not auto-loaded)
│   └── AGENT_PROJECT_PLAYBOOK.md  # Companion to agent-design.md (~270 lines)
├── hooks/                     # Automatic safety guardrails
│   ├── config-protection.mjs  # Don't let Claude weaken your linter rules
│   ├── block-no-verify.mjs    # Don't let Claude skip pre-commit hooks
│   ├── enforce-floor.mjs      # Don't let Claude commit a code repo with no floor
│   └── suggest-compact.mjs    # Remind Claude to save progress and free memory
├── commands/                  # Slash commands you can run on demand
│   ├── code-review.md         # /code-review
│   ├── security-scan.md       # /security-scan
│   └── logic-review.md        # /logic-review (cross-vendor review + supervised fix)
├── agents/                    # Specialized sub-agents
│   ├── code-reviewer.md       # Reviews code with fresh eyes (used by /code-review)
│   └── security-reviewer.md   # Scans for vulnerabilities (used by /security-scan)
├── template/                  # Starter files for new projects
│   ├── CLAUDE.md              # Project instructions (auto-filled after first plan)
│   ├── CLAUDE.local.md        # Your personal preferences (not shared with team)
│   ├── PROGRESS.md            # Cross-session progress tracking
│   ├── verify.sh              # The deterministic floor (lint + typecheck + test)
│   ├── settings.json          # Blocks Claude from reading .env files and secrets
│   ├── settings.local.json    # Your personal command overrides
│   ├── .project-gitignore     # Blocks secrets, keys, credentials from git
│   ├── .pre-commit-hook       # Scans commits for leaked secrets
│   ├── bin/review-diff.mjs    # The cross-vendor logic reviewer (advisory)
│   ├── review/                # The reviewer's prompt / rubric
│   ├── ci/                    # CI templates: floor + reviewer (GitHub & Bitbucket)
│   └── configs/               # Starter eslint / tsconfig / prettier / ruff
├── bin/
│   ├── init-claude            # The command that sets up a new project
│   └── update-claude          # Upgrades an existing project's .claude/ to the latest
├── install.sh                 # The command that sets up a new computer
├── uninstall.sh               # Safely removes everything this setup installed
├── verify.sh                  # This repo's own floor — it gates its own PRs
├── .github/workflows/         # Runs the floor + reviewer on this repo's own PRs
├── test.sh                    # Automated test suite (114 assertions, runs in sandbox)
├── Dockerfile                 # Ubuntu container for cross-platform testing
├── docker-test.sh             # Runs test.sh in the Docker container
└── TESTING.md                 # Manual scenario checklist for coworker validation
```

## Security — How Your Secrets Stay Safe

There are 7 layers of protection, each catching what the others might miss:

| Layer | What it does | When it runs |
|---|---|---|
| `.gitignore` | Blocks `.env`, `.pem`, `.key`, credentials from being committed | Every `git add` |
| `settings.json` | Deny rules for reading secret files and dangerous commands (best-effort — see below) | Every Claude session |
| `security.md` rule | Tells Claude: no hardcoded secrets, validate URLs, sanitize input | Every Claude session |
| Config protection hook | Stops Claude from loosening your linter/formatter rules | Before every file edit |
| No-verify blocker hook | Stops Claude from skipping pre-commit checks | Before every git command |
| Gitleaks pre-commit | Scans the actual content of every commit for leaked tokens/keys | Every `git commit` |
| `/security-scan` | Full OWASP Top 10 audit of your codebase | Whenever you run it |

### What the deny lists are (and aren't)

The `deny` patterns in `settings.json` / `settings.local.json` are **speed bumps,
not a security boundary**. Pattern matching over a shell surface can always be
sidestepped by an equivalent spelling (`cat .env` instead of a `Read`, a
variant flag, a no-space pipe) — so treat them as friction against the lazy
path, and rely on the layers that actually enforce:

- **Secrets never land in git**: `.gitignore` + gitleaks in the pre-commit hook.
- **Force-push protection**: enable **branch protection** on your host
  (see `.claude/ci/BRANCH_PROTECTION.md`) — server-side, spelling-proof.
- **Unverified code never merges**: the verify.sh floor in the pre-commit /
  pre-push hooks and CI.

If you add deny rules, add them for the friction value — don't build a threat
model on them.

## Updating

**The plugin** (hooks, commands, agents, template): bump `version` in
`.claude-plugin/plugin.json`, push to GitHub — every machine picks it up
through the plugin system (`/plugin` → update). No per-machine script runs.

**The global rules**: after changing `global-rules/`, re-run `./install.sh`
on each machine (it only copies rules + playbooks now — it never touches
`settings.json`).

**Your projects**: run `/update-floor` in a project to refresh its `.claude/`
infrastructure (reviewer, CI templates, configs) from the current plugin —
your customized `verify.sh`, `CLAUDE.md`, and settings are never clobbered.

## Testing

Before sharing this with teammates, verify it works cleanly:

```bash
./test.sh          # the full suite in a sandboxed ~/ (30 sec)
./docker-test.sh   # full install on a clean Ubuntu container (2 min, requires Docker)
```

See [TESTING.md](./TESTING.md) for a manual scenario checklist covering edge cases like existing custom rules, malformed settings, missing Node, and false positives on hooks.

## Uninstalling

**The plugin**: `/plugin uninstall claude-setup` inside Claude Code — removes
hooks, commands, and agents cleanly.

**The global rules (and any legacy pre-plugin install)**:

```bash
./uninstall.sh
```

Safely removes only what this repo installed:
- Our rules and playbooks — your custom ones stay
- Legacy copied hooks/commands/agents from the old install.sh era, plus their
  entries in `~/.claude/settings.json` — your permissions, model, env, and
  other hooks are preserved
- Legacy `~/bin/init-claude` / `~/bin/update-claude`

It does **not** touch per-project `.claude/` directories or git hooks already
installed in specific repos — remove those manually where needed.

## The Rules at a Glance

| Rule file | What it tells Claude |
|---|---|
| `workflow.md` | Plan before building. Work in small chunks. Commit often. Track progress between sessions. Don't skip verification. |
| `qa.md` | Always write a failing test first. Then make it pass. Then clean up. No exceptions. |
| `testing.md` | How to write tests for Python (pytest), TypeScript (vitest), and browsers (Playwright). Keep them fast and deterministic. |
| `code-style.md` | Functions under 30 lines. Clear names. Explicit types. Composition over inheritance. Deep modules over shallow. |
| `security.md` | Never hardcode secrets. Validate all input. Prevent SQL injection, XSS, and SSRF. Check auth on every request. |
| `agent-design.md` | Three-layer framework for AI agent / LLM-pipeline projects (decomposition → evaluation → self-improvement). Self-scopes — skipped for non-agent work. |
| `frontend/react.md` | Functional components only. Use TanStack Query. No prop drilling. Early returns in JSX. |

## Playbooks (pull-loaded references)

Some content is too long for the ambient rule layer but useful to have available on every machine. These live in `~/.claude/playbooks/` and are not auto-loaded — Claude reads them via the Read tool only when relevant (e.g. starting an agent project).

| Playbook | When Claude pulls it |
|----------|---------------------|
| `AGENT_PROJECT_PLAYBOOK.md` | Plan mode at the start of an agent / LLM-pipeline project. The 50-line `agent-design.md` rule points to it. ~270 lines of detail on the three-layer framework, with worked examples from GEOQuery. |

This is the push-vs-pull pattern: short principles **push** every session via rules; deep references **pull** only when needed.
