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
│   ├── CLAUDE.md          # Project-specific instructions (fill-in-the-blank)
│   ├── CLAUDE.local.md    # Personal preferences (gitignored)
│   ├── settings.json      # Shared deny rules
│   ├── settings.local.json# Personal overrides (gitignored)
│   ├── .project-gitignore # Root .gitignore for new projects
│   └── .pre-commit-hook   # Gitleaks secret scanning hook
├── bin/
│   └── init-claude        # CLI tool to scaffold .claude/ in any project
└── install.sh             # One-command setup for new machines
```

## Install (New Machine)

```bash
git clone git@github.com:<your-username>/claude-setup.git
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
- `.gitignore` with secrets, env, credentials, cloud configs blocked
- Pre-commit hook that scans for leaked secrets via gitleaks

Then edit `.claude/CLAUDE.md` to fill in your tech stack and project structure.

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
| Project config | `<project>/.claude/CLAUDE.md` | One project |
| Personal overrides | `<project>/.claude/CLAUDE.local.md` | One project, gitignored |
| Secret scanning | `.git/hooks/pre-commit` | One project, per git repo |
