---
name: superpowers
description: Auto-enforces brainstorming, planning, TDD, and code review into every session
metadata:
  {
    "openclaw": {
      "emoji": "💪",
      "requires": { "tools": ["exec", "read", "write"] }
    }
  }
---

# Superpowers Skill

Superpowers is a complete software development workflow that auto-enforces best practices.

## Installation

Already installed at: `~/.openclaw/skills/superpowers/`

## How It Works

Superpowers activates automatically when you start building something:

1. **Brainstorming** - Steps back, asks what you're trying to do
2. **Planning** - Creates clear implementation plans
3. **TDD** - Emphasizes red/green test-driven development
4. **Code Review** - Automatic review before completion

## Skills Included

| Skill | Description |
|-------|-------------|
| brainstorming | Ask clarifying questions before coding |
| writing-plans | Create clear implementation plans |
| test-driven-development | TDD workflow |
| subagent-driven-development | Multi-agent task execution |
| verification-before-completion | Verify work before finishing |
| receiving-code-review | Handle code reviews |
| systematic-debugging | Debug effectively |

## Usage

When user wants to build something:

1. Don't jump into code - use brainstorming first
2. Create a spec/plan
3. Use TDD (write test first)
4. Verify before completing

## Key Principle

> "It emphasizes true red/green TDD, YAGNI, and DRY"

## Reference

- Docs: `~/.openclaw/skills/superpowers/docs/`
- Skills: `~/.openclaw/skills/superpowers/skills/`
- README: `~/.openclaw/skills/superpowers/README.md`
