---
name: orchestration
description: >
  Tri-model task routing. Use this skill to decide when to handle a task
  yourself vs delegating to the coding or frontend specialist agents.
  Main agent (you) = Kimi K2 Planner. Coding agent = Kimi K2 Executor.
  Frontend agent = Kimi K2 Builder (specialised context).
---

# SKILL: Orchestration — When to Delegate

## Architecture

You are the **Planner** (MiniMax). Your job is to reason about the request,
decompose it, and decide who executes each part.

| Agent | Model | Use for |
|-------|-------|---------|
| **main** (you) | MiniMax M2.5 | All conversation, reasoning, planning, coordination — best communication quality |
| **coding** | Kimi K2 (NVIDIA) | Backend code, APIs, databases, reading large codebases, system design, shell scripts |
| **frontend** | Kimi K2 (NVIDIA) | React, Vue, CSS, Tailwind, TypeScript, UI components, HTML, browser automation |

## Decision tree

**Handle yourself (main) when:**
- Task is conversational, research, analysis, or explanation
- File is < ~20KB and doesn't need specialist context
- Task is a single small function or config edit
- Coordination between multiple subtasks

**Delegate to `coding` when:**
- Reading or modifying a large codebase (Kimi K2 has the biggest context window)
- Writing backend code: Python, Go, Rust, Node, shell scripts
- Database schema design or migrations
- DevOps, systemd, Docker, infrastructure
- Any task where you need to "read the whole project first"

**Delegate to `frontend` when:**
- Writing React/Vue/Svelte components
- CSS, Tailwind, responsive design
- TypeScript interfaces and types
- UI testing, browser automation
- Design system work

## How to delegate

```
# Spawn a coding subagent
sessions_spawn({
  agentId: "coding",
  task: "Read the entire src/ directory and refactor the auth module to use JWT. Return the changed files.",
  label: "auth-refactor"
})

# Spawn a frontend subagent
sessions_spawn({
  agentId: "frontend",
  task: "Create a responsive dashboard component in React/Tailwind. Spec: [paste spec here]",
  label: "dashboard-component"
})
```

## Parallelism

You can spawn coding + frontend agents simultaneously if tasks are independent:
```
# Both run in parallel
sessions_spawn({ agentId: "coding",   task: "...", label: "backend" })
sessions_spawn({ agentId: "frontend", task: "...", label: "frontend" })
# Then wait for both: sessions_history("backend"), sessions_history("frontend")
```

## Context passing

When delegating, be explicit in the task string. The subagent starts fresh with
no memory of your conversation. Include:
- The exact goal
- Relevant file paths
- Any constraints (don't change X, use library Y)
- Expected output format

## Thinking mode (Kimi K2)

For complex planning, prefix your internal reasoning with `<think>` to engage
extended reasoning before committing to a plan. This helps catch logic
errors before any code runs.
