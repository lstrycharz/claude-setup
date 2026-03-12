# Claude Code Setup

Personal Claude Code configuration — global rules, project template, and tooling.

## What's Included

```
claude-setup/
├── global-rules/          # → ~/.claude/rules/ (auto-loaded in every project)
│   ├── workflow.md        # Collaboration modes, chunked implementation, delegation
│   ├── qa.md              # Strict Red/Green/Refactor TDD
│   ├── testing.md         # Framework-specific testing conventions
│   ├── code-style.md      # Code style rules
│   ├── security.md        # SSRF, auth, input validation, secrets
│   └── frontend/
│       └── react.md       # React component patterns
├── template/              # → ~/.claude-template/ (used by init-claude)
│   ├── CLAUDE.md          # Project instructions (auto-populated from first plan)
│   ├── CLAUDE.local.md    # Personal preferences (gitignored)
│   ├── settings.json      # Shared deny rules (.env, secrets, force push)
│   ├── settings.local.json# Personal overrides (gitignored)
│   ├── .project-gitignore # Root .gitignore for new projects
│   └── .pre-commit-hook   # Gitleaks secret scanning hook
├── bin/
│   └── init-claude        # CLI tool to scaffold .claude/ in any project
└── install.sh             # One-command setup for new machines
```

## Install (New Machine)

```bash
git clone https://github.com/lstrycharz/claude-setup.git
cd claude-setup
./install.sh
```

This installs:
- Global rules to `~/.claude/rules/`
- Project template to `~/.claude-template/`
- `init-claude` command to `~/bin/`
- Prompts to install `gitleaks` for secret scanning

## Usage (New Project)

```bash
cd my-project
git init
init-claude
```

This creates:
- `.claude/` with project-specific config
- `.gitignore` blocking secrets, env, credentials, cloud configs, keys
- Pre-commit hook that scans for leaked secrets via gitleaks

Then start Claude Code and enter plan mode. After the first planning session, Claude **auto-populates** `CLAUDE.md` with your tech stack, commands, project structure, and rules. No manual copy-paste needed.

## How It Works

```
New project
    │
    ├─ init-claude         → scaffolds .claude/, .gitignore, pre-commit hook
    │
    ├─ Plan mode           → discuss stack, structure, architecture
    │                        → Claude auto-fills CLAUDE.md from the plan
    │                        → you review and confirm
    │
    └─ Start building      → global rules (TDD, security, workflow) apply automatically
                             → CLAUDE.md provides project-specific context every session
```

## Security Layers

| Layer | What it does | Type |
|-------|-------------|------|
| `.gitignore` | Blocks `.env*`, `*.pem`, `*.key`, credentials, cloud configs from git | Passive |
| `settings.json` | Blocks Claude from reading `.env*`, secrets, key files | Passive |
| `security.md` (global rule) | Instructs Claude: no hardcoded secrets, validate URLs, sanitise input | Passive |
| gitleaks pre-commit hook | Scans every commit for API keys, tokens, passwords — blocks if found | Active |

## Updating

Edit files in this repo, push, then on each machine:

```bash
cd claude-setup
git pull
./install.sh
```

## Architecture

| Layer | Location | Scope |
|-------|----------|-------|
| Global rules | `~/.claude/rules/` | Every project, automatically |
| Project config | `<project>/.claude/CLAUDE.md` | One project (auto-populated) |
| Personal overrides | `<project>/.claude/CLAUDE.local.md` | One project, gitignored |
| Secret scanning | `.git/hooks/pre-commit` | One project, per git repo |

## Global Rules Summary

| Rule | What it enforces |
|------|-----------------|
| `workflow.md` | Plan mode, pair/delegation modes, chunked implementation, commit strategy, CLAUDE.md auto-population |
| `qa.md` | Strict Red/Green/Refactor TDD — no implementation without a failing test |
| `testing.md` | pytest/vitest conventions, no flaky tests, co-located test files |
| `code-style.md` | Composition over inheritance, explicit types, 30-line function limit |
| `security.md` | SSRF prevention, secrets management, input validation, auth, frontend security |
| `frontend/react.md` | Functional components, TanStack Query, no prop drilling |
