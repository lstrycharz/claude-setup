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
| **Running out of memory** | After 50 actions, reminds Claude to save progress and free up space with `/compact`. |

### Slash Commands (on-demand checks)

Type these in Claude Code whenever you want a second opinion:

- **`/code-review`** — Reviews everything you've changed but haven't committed yet. Finds bugs, security issues, and style problems. Like having a senior dev look over your shoulder.
- **`/security-scan`** — Scans your whole project for security vulnerabilities (leaked secrets, injection risks, auth problems). Based on the OWASP Top 10.

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

### Step 1: Install (once per computer)

```bash
git clone https://github.com/lstrycharz/claude-setup.git
cd claude-setup
./install.sh
```

This puts everything in the right place. It'll also ask if you want to install `gitleaks` (the secret scanner) — say yes.

### Step 2: Set up a new project

```bash
cd my-project
git init           # if it's not already a git repo
init-claude        # sets up .claude/, .gitignore, and the pre-commit hook
```

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
    └── /code-review, /security-scan  → available when you want them
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
│   └── frontend/
│       └── react.md           # React-specific patterns
├── hooks/                     # Automatic safety guardrails
│   ├── config-protection.mjs  # Don't let Claude weaken your linter rules
│   ├── block-no-verify.mjs    # Don't let Claude skip pre-commit hooks
│   └── suggest-compact.mjs    # Remind Claude to save progress and free memory
├── commands/                  # Slash commands you can run on demand
│   ├── code-review.md         # /code-review
│   └── security-scan.md       # /security-scan
├── agents/                    # Specialized sub-agents
│   ├── code-reviewer.md       # Reviews code with fresh eyes (used by /code-review)
│   └── security-reviewer.md   # Scans for vulnerabilities (used by /security-scan)
├── template/                  # Starter files for new projects
│   ├── CLAUDE.md              # Project instructions (auto-filled after first plan)
│   ├── CLAUDE.local.md        # Your personal preferences (not shared with team)
│   ├── PROGRESS.md            # Cross-session progress tracking
│   ├── settings.json          # Blocks Claude from reading .env files and secrets
│   ├── settings.local.json    # Your personal command overrides
│   ├── .project-gitignore     # Blocks secrets, keys, credentials from git
│   └── .pre-commit-hook       # Scans commits for leaked secrets
├── bin/
│   └── init-claude            # The command that sets up a new project
└── install.sh                 # The command that sets up a new computer
```

## Security — How Your Secrets Stay Safe

There are 7 layers of protection, each catching what the others might miss:

| Layer | What it does | When it runs |
|---|---|---|
| `.gitignore` | Blocks `.env`, `.pem`, `.key`, credentials from being committed | Every `git add` |
| `settings.json` | Blocks Claude from even *reading* secret files | Every Claude session |
| `security.md` rule | Tells Claude: no hardcoded secrets, validate URLs, sanitize input | Every Claude session |
| Config protection hook | Stops Claude from loosening your linter/formatter rules | Before every file edit |
| No-verify blocker hook | Stops Claude from skipping pre-commit checks | Before every git command |
| Gitleaks pre-commit | Scans the actual content of every commit for leaked tokens/keys | Every `git commit` |
| `/security-scan` | Full OWASP Top 10 audit of your codebase | Whenever you run it |

## Updating

When you make changes to this repo:

```bash
cd claude-setup
git pull
./install.sh
```

That's it. The install script copies everything to the right places.

**Safe to re-run anytime.** The installer merges instead of overwrites — your personal permissions, custom hooks, and other settings in `~/.claude/settings.json` are preserved. It only updates the hooks this repo manages.

## The Rules at a Glance

| Rule file | What it tells Claude |
|---|---|
| `workflow.md` | Plan before building. Work in small chunks. Commit often. Track progress between sessions. Don't skip verification. |
| `qa.md` | Always write a failing test first. Then make it pass. Then clean up. No exceptions. |
| `testing.md` | How to write tests for Python (pytest), TypeScript (vitest), and browsers (Playwright). Keep them fast and deterministic. |
| `code-style.md` | Functions under 30 lines. Clear names. Explicit types. Composition over inheritance. |
| `security.md` | Never hardcode secrets. Validate all input. Prevent SQL injection, XSS, and SSRF. Check auth on every request. |
| `frontend/react.md` | Functional components only. Use TanStack Query. No prop drilling. Early returns in JSX. |
