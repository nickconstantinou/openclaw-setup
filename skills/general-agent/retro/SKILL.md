---
name: retro
description: Post-incident retrospectives
metadata:
  {
    "openclaw": {
      "emoji": "🔴",
      "requires": { "env": ["GITHUB_CLASSIC"] }
    }
  }
---

# Retro Skill

Post-incident retrospectives - document what went wrong and implement fixes.

## Run a Retro

When something goes wrong (security breach, site outage, bug):

```bash
# Use the retro skill
retro --check-credentials
```

## What It Does

1. Creates incident report in `memory/`
2. Checks for credential exposure
3. Verifies `.gitignore`
4. Runs QA checks
5. Updates `MEMORY.md` with lessons
6. Adds safety checks to relevant skills

## Credentials Location

All credentials are now stored in `~/.openclaw/.env`

Check credentials:
```bash
source ~/.openclaw/.env
echo $GITHUB_CLASSIC
```
