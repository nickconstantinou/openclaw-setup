---
name: git-in-sandbox
description: >
  Git operations inside the OpenClaw sandbox environment. Use this skill
  whenever performing git clone, commit, push, or pull operations. Critical:
  always use -C flag, never change HOME, and authenticate via token URL.
---

# SKILL: Git in Sandbox

HOME is /home/openclaw — this is CORRECT. Do NOT change HOME to /home/openclaw/.openclaw.
That workaround is wrong and will break other tools.

Use -C flag or GIT_DIR to be explicit about the repo, not HOME.

## Correct invocation pattern

```bash
# Option 1: -C flag (preferred — no env vars needed)
git -C ~/.openclaw/workspace/projects/my-repo status
git -C ~/.openclaw/workspace/projects/my-repo add -A
git -C ~/.openclaw/workspace/projects/my-repo commit -m "message"
git -C ~/.openclaw/workspace/projects/my-repo push

# Option 2: explicit env (use when piping or in subshells)
GIT_DIR=~/.openclaw/workspace/projects/my-repo/.git GIT_WORK_TREE=~/.openclaw/workspace/projects/my-repo git status
```

## Auth — always use token in remote URL

```bash
# Set remote with token (do once per repo)
git -C /path/to/repo remote set-url origin https://${GITHUB_TOKEN}@github.com/nickconstantinou/my-repo.git

# Or inline on push
git -C /path/to/repo push https://${GITHUB_TOKEN}@github.com/nickconstantinou/my-repo.git main
```

## Verify identity before committing

```bash
git -C /path/to/repo config user.name   # must not be blank
git -C /path/to/repo config user.email  # must not be blank

# Set if missing
git -C /path/to/repo config user.name "Griptide"
git -C /path/to/repo config user.email "nick@example.com"
```

## Common operations

```bash
git -C /path/to/repo clone https://github.com/nickconstantinou/repo.git .
git -C /path/to/repo log --oneline -10
git -C /path/to/repo checkout -b feature/my-feature
git -C /path/to/repo diff HEAD
git -C /path/to/repo stash
git -C /path/to/repo pull --rebase
```

## Pre-commit hooks

If a hook fails with "bad interpreter: Permission denied":
- This means the hook file lacks execute permission or the interpreter path is wrong
- Fix: `chmod +x .git/hooks/pre-commit`
- Or bypass for emergency commits: `git commit --no-verify`

## gitignore resolution order

1. Repo `.gitignore` (committed, shared)
2. `.git/info/exclude` (local, not committed)
3. Global: `~/.gitconfig core.excludesFile` (usually `~/.gitignore_global`)

Write shared rules to repo `.gitignore`, private rules to `.git/info/exclude`.

## Rules
- Never set HOME to anything other than /home/openclaw
- Always use -C or GIT_DIR to specify repo — never rely on cwd
- Never commit with blank user.name/user.email
- Never push directly to main — use a branch and PR via gh
