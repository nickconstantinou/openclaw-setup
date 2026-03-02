---
name: gsd
description: Get Shit Done - Spec-driven development framework for OpenClaw
metadata:
  {
    "openclaw": {
      "emoji": "🎯",
      "requires": { "tools": ["exec", "read", "write"] }
    }
  }
---

# GSD (Get Shit Done) Skill

GSD is a spec-driven development framework that interviews you, builds a plan, then executes phase by phase with verification.

## Installation

GSD is already installed as a SKILL.md

## Usage

GSD works through conversation prompts. For OpenClaw, you can use these commands:

### Start New Project
Tell GSD about your project idea. It will:
1. Ask clarifying questions
2. Research domain (optional)
3. Create REQUIREMENTS.md
4. Create ROADMAP.md
5. Set up project memory

### Plan Phase
After project creation: `/gsd:plan-phase <phase-number>`

### Execute Phase
Run a specific phase with verification

### Check Todos
See pending tasks

## Manual Usage

You can also manually trigger GSD commands by reading the command files and guiding the user through them:

```bash
# List available GSD commands
ls ~/.openclaw/workspace/get-shit-done/commands/gsd/
```

## Commands Available

| Command | Description |
|---------|-------------|
| gsd:new-project | Initialize new project |
| gsd:plan-phase | Plan a specific phase |
| gsd:execute-phase | Execute a phase |
| gsd:research-phase | Research domain |
| gsd:check-todos | View pending tasks |
| gsd:progress | Show progress |
| gsd:health | Check project health |

## Example Workflow

1. User: "I want to build a todo app"
2. You: Use the GSD methodology - ask questions, then guide through requirements → roadmap → execution
3. Create `~/.openclaw/workspace/get-shit-done/planning/PROJECT.md` with context
4. Create `~/.openclaw/workspace/get-shit-done/planning/REQUIREMENTS.md`
5. Create `~/.openclaw/workspace/get-shit-done/planning/ROADMAP.md`

## Key Files

- `~/.openclaw/workspace/get-shit-done/workflows/` - Workflow     definitions
- `~/.openclaw/workspace/get-shit-done/templates/` - Project templates
- `~/.openclaw/workspace/get-shit-done/references/` - Questioning guides
