---
name: git-in-sandbox
description: >
  Git operations inside the OpenClaw sandbox environment with secure \n  environment-sourced credential management. Use this skill for all git \n  operations including clone, commit, push, pull with automatic credential \n  isolation via ~/.openclaw/.env.
---

# SKILL: Git in Sandbox

Git operations inside the OpenClaw sandbox environment with **secure environment-sourced credential management**. Use this skill for all git operations including clone, commit, push, pull with automatic credential isolation via `~/.openclaw/.env`.

> **⚠️ SECURITY UPDATE 2026-03-02:**
> Container credential layer is restricted for security. Use **environment-sourced** authentication instead of direct credentials.

## Core Rules (Security Model)

### HOME Rules
- **HOME is `/home/openclaw/`** - this is CORRECT. Do NOT change this.
- **Never rely on your current directory** - always use `-C` flag or `GIT_DIR`
- **Use -C flag:** `git -C /path/to/repo command`

## Secure Authentication (Environment-Sourced)

### ✅ Recommended: Secure Push Tool
```bash
# Automatic secure push via environment sourcing
~/.openclaw/workspace/tools/git-secure-push /path/to/repo [remote] [branch]

# Simple usage
~/.openclaw/workspace/tools/git-secure-push
# → pushes current directory to origin/main
```

### 🔐 Secure Manual Approach
```bash
# Source credentials and operate
source ~/.openclaw/.env  # loads GITHUB_API_KEY
git -C /path/to/repo remote set-url origin "https://${GITHUB_API_KEY}@github.com/username/repo.git"
git -C /path/to/repo push origin main --force-with-lease
```

### 🔧 Environment Requirements
- **File**: `~/.openclaw/.env` containing:
  ```bash
  GITHUB_API_KEY=ghp_your_token_here
  ```
- **No other credentials** - all git operations use this token

## Common Operations (Updated)

### Push Changes Securely
```bash
# Single command push
~/.openclaw/workspace/tools/git-secure-push ~/workspace/projects/my-repo

# Manual approach
cd ~/workspace/projects/my-repo
source ~/.openclaw/.env
git -C . remote set-url origin "https://${GITHUB_API_KEY}@github.com/username/my-repo.git"  
git -C . push origin main --force-with-lease
```

### Clone New Repository
```bash
git -C ~/workspace/projects clone https://github.com/username/new-repo.git
```

### Status and Commit
```bash
git -C ~/workspace/projects/skill-status status
git -C ~/workspace/projects/skill-status add -A
git -C ~/workspace/projects/skill-status commit -m "Update via git-in-sandbox"
```

### Branch Operations
```bash
git -C ~/workspace/projects/skill-status checkout -b feature/my-feature
git -C ~/workspace/projects/skill-status checkout main
git -C ~/workspace/projects/skill-status branch -d feature/done
```

### Pull Remote Changes
```bash
git -C ~/workspace/projects/skill-status pull --rebase
```

## Pre-commit Hooks
```bash
# Ensure hooks are executable
git -C /path/to/repo config user.name "Your Name"
git -C /path/to/repo config user.email "user@example.com"
chmod +x /path/to/repo/.git/hooks/pre-commit
```

## Troubleshooting

| Error | Solution |
|-------|----------|
| `.env not found` | Create `~/.openclaw/.env` with `GITHUB_API_KEY=...` |
| `Permission denied (publickey)` | Use HTTPS remote with token: `https://${GITHUB_API_KEY}@github.com/...` |
| `credentials not found` | Ensure `.env` sources correctly: `cat ~/.openclaw/.env` |
| `remote: Repository not found` | Verify remote URL: `git -C /path/to/repo remote -v` |

## Migration from Old SSH model

**Before:**
```bash
git -C /path/to/repo push origin main  # SSH key required
```

**After:**
```bash
~/.openclaw/workspace/tools/git-secure-push /path/to/repo  # Environment token
```

## Tools Provided

- **Base tool**: `~/.openclaw/workspace/tools/git-secure-push` - Script for secure pushing
- **PATH access**: `~/.openclaw/bin/git-secure-push` - System path convenience