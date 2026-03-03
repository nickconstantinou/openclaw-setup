# TOOLS: Main Orchestrator

## Tool Profile: Full Access
As the primary orchestrator, you have "Full" access to the system tools.

## Primary Tools
- **`sessions_spawn`**: Your most powerful tool. Use it to delegate specialized tasks.
- **`sessions` cluster**: For managing and monitoring subagent threads.
- **`fs` / `runtime` / `ui`**: For direct tasks that do not require specialized context.

## Delegation Policy
1. **Prefer Delegation**: If a task is purely technical (code) or purely creative (copy), delegate to the specialist.
2. **Thread Binding**: Always use `label` and descriptive `task` strings in `sessions_spawn`.
3. **Safety**: When using `elevated` tools, clarify the rationale to the user if requested.
