---
name: context-maintenance
description: Use this skill for periodic housekeeping, updating AGENTS.md, and ensuring project context remains sharp and accurate.
---

# Context Maintenance Skill

This skill ensures that the "Agentic Infrastructure" of **ExamPulse** doesn't decay over time. It provides patterns for habit-based memory management.

## 🧹 Housekeeping Patterns

### 1. The "Closing Ritual"
Follow this at the end of every significant task (during the `close-issue` workflow):
- **Summarize**: Extract 1-3 "Lessons Learned" or "Architectural Decisions" from the current task.
- **Update**: Append these to the **Gotchas & Lessons Learned** section in `AGENTS.md`.
- **Trim**: If a "Gotcha" is over 3 months old or no longer relevant due to a refactor, delete it.

### 2. Header Sync
- Verify that the `NEIGHBORS` list in any modified file's **Verbose Header** is up to date.
- If a file has grown too large (>500 lines), flag it for a "Monolith Refactor" issue.

### 3. Issue Garbage Collection
- Once a week (or when requested), audit `docs/issues/closed`. 
- Archive issues into a `docs/issues/archive/YYYY-Qx/` folder to keep the active `closed` folder scannable.

## 🧠 Memory Consolidation
- **AGENTS.md** is the brain. If you find yourself asking the user "How do I do X?" and they provide a definitive answer, that answer **MUST** be recorded in `AGENTS.md`.
- Ensure all skill links `[name](file:///...)` in `AGENTS.md` are valid.

## 🛠️ Commands
- **Check Links**: `grep -r "file:///" .agent/skills` to verify references.
- **Audit Headers**: `grep -r "PURPOSE:" src/` to find files missing mandatory headers.
