---
name: orchestration
description: >
  Use this skill to decide when to handle a task yourself vs delegating coding
  execution to the Codex ACP worker.
---

# SKILL: Orchestration — When to Delegate

## Architecture

You are the **Main Agent**. Your job is to reason about the request, decompose
it, and decide whether to execute directly or hand code-heavy work to Codex ACP.

### Decision tree

| Request Type | Lead Worker |
|--------------|-------------|
| "Build feature X" | **codex** |
| "Write blog post" | **main** |
| "Summarize email" | **main** |
| "Plan launch" | **main** |

## Decision tree

**Handle yourself (main) when:**
- Task is conversational, research, analysis, or explanation
- File is < ~20KB and doesn't need a separate coding session
- Task is a single small function or config edit
- Task is marketing, copy, content, or user-facing strategy work
- Coordination between multiple subtasks

**Delegate to `codex` when:**
- Reading or modifying a large codebase in a dedicated ACP coding session
- Identifying complex system-wide bugs
- Writing production-grade code adhering to repo protocols
- Writing backend code: Python, Go, Rust, Node, shell scripts
- Database schema design or migrations
- DevOps, systemd, Docker, infrastructure
- Any task where you need to "read the whole project first"

## How to delegate

```
# Spawn a Codex ACP subagent
sessions_spawn({
  agentId: "codex",
  task: "Read the entire src/ directory and refactor the auth module to use JWT. Return the changed files.",
  label: "auth-refactor"
})
```

There is no separate marketing worker in this setup. Use content and marketing
skills directly from the main agent. The `family` agent is channel-bound and is
not a general-purpose worker for spawned tasks.

### When to Orchestrate Directly

You should coordinate when:
- Task requires both coding implementation and content/ops work in sequence
- User request needs decomposition into parallel work streams
- Complex workflows need supervision
- Explicit coordination requested

### Monitoring Sub-Agents

Check status of spawned sessions:
```javascript
sessions_list({
    kinds: ["other"],  // Lists subagent sessions
    activeMinutes: 60,
    messageLimit: 5
})
```

## Parallelism

You can keep content/research work in `main` while Codex runs implementation in
parallel:
```
# Codex runs while main continues with docs/research/planning
sessions_spawn({ agentId: "codex", task: "...", label: "backend" })
# Then wait for completion: sessions_history("backend")
```

## Context passing

When delegating, be explicit in the task string. The subagent starts fresh with
no memory of your conversation. Include:
- The exact goal
- Relevant file paths
- Any constraints (don't change X, use library Y)
- Expected output format

## High Context Mode
When dealing with repos >100 files, prefer **codex** for the implementation
workstream, as it is the dedicated ACP coding worker in this setup.

## Thinking mode
For complex planning, prefix your internal reasoning with `<think>` to engage
extended reasoning before committing to a plan. This helps catch logic
errors before any code runs.
