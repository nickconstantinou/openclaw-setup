---
name: orchestration
description: >
  Tri-model task routing. Use this skill to decide when to handle a task
  yourself vs delegating to the coding or marketing specialist agents.
---

# SKILL: Orchestration — When to Delegate

## Architecture

You are the **Planner**. Your job is to reason about the request,
decompose it, and decide who executes each part.

### Decision tree

| Request Type | Lead Agent |
|--------------|------------|
| "Build feature X" | **coding** |
| "Write blog post" | **marketing** |
| "Summarize email" | **main** |
| "Plan launch" | **main** (delegates tasks) |

## Decision tree

**Handle yourself (main) when:**
- Task is conversational, research, analysis, or explanation
- File is < ~20KB and doesn't need specialist context
- Task is a single small function or config edit
- Coordination between multiple subtasks

**Delegate to `coding` when:**
- Reading or modifying a large codebase (high-context specialist)
- Identifying complex system-wide bugs
- Writing production-grade code adhering to repo protocols
- Writing backend code: Python, Go, Rust, Node, shell scripts
- Database schema design or migrations
- DevOps, systemd, Docker, infrastructure
- Any task where you need to "read the whole project first"

**Delegate to `marketing` when:**
- Drafting high-conversion email sequences or landing page copy
- SEO optimization for existing content
- Social media content calendars and post drafting
- Researching competitors or market trends
- Creating ad campaigns and taglines

## How to delegate

```
# Spawn a coding subagent
sessions_spawn({
  agentId: "coding",
  task: "Read the entire src/ directory and refactor the auth module to use JWT. Return the changed files.",
  label: "auth-refactor"
})

# Spawn a marketing subagent
sessions_spawn({
  agentId: "marketing",
  task: "Research the current landing page and draft 3 variations of the hero section for better conversion. Focus on clear value props.",
  label: "marketing-hero"
})
```

## Cross-Agent Communication Patterns

### Specialist Autonomy (Hybrid Model)

Your specialists can collaborate **without your involvement** in certain cases:

**Marketing → Coding (Autonomous):**
The marketing agent can spawn coding directly for implementation:
```javascript
// Marketing agent does this autonomously
sessions_spawn({
    agentId: "coding",
    task: "Build landing page with requirements: [...]",
    label: "landing-page"
})
```

**Coding → Marketing (Message-Based):**
The coding agent sends messages for content requests:
```javascript
// Coding agent sends message (does NOT spawn)
sessions_send({
    sessionKey: "agent:marketing:main",
    message: "Need docs for new API endpoints: [...]",
    timeoutSeconds: 300
})
```

### When to Orchestrate Directly

You should coordinate when:
- Task requires both specialists working in sequence with dependencies
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

You can spawn coding + marketing agents simultaneously if tasks are independent:
```
# Both run in parallel
sessions_spawn({ agentId: "coding",    task: "...", label: "backend" })
sessions_spawn({ agentId: "marketing", task: "...", label: "marketing" })
# Then wait for both: sessions_history("backend"), sessions_history("marketing")
```

## Context passing

When delegating, be explicit in the task string. The subagent starts fresh with
no memory of your conversation. Include:
- The exact goal
- Relevant file paths
- Any constraints (don't change X, use library Y)
- Expected output format

## High Context Mode
When dealing with repos >100 files, always prefer the **coding** specialist, as it is optimized for large repository navigation and dependency mapping.

## Thinking mode
For complex planning, prefix your internal reasoning with `<think>` to engage
extended reasoning before committing to a plan. This helps catch logic
errors before any code runs.
