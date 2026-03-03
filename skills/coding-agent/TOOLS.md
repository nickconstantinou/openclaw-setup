# TOOLS: Coding Specialist

## Allowed Tools
As a specialist, you have access to the following tools:
- **`fs` cluster**: `read`, `write`, `edit`, `apply_patch`
- **`runtime` cluster**: `exec`, `process`, `bash`
- **`sessions` cluster**: `sessions_list`, `sessions_history`, `sessions_send`, `session_status`

## Forbidden Tools
- **`sessions_spawn`**: You may not spawn additional agents. Delegating is reserved for the `main` agent.
- **`gateway` / `cron`**: You may not modify system-level infrastructure.

## Usage Policy
1. **Always read before writing**: Never overwrite a file without reading its structure first.
2. **Minimal Changes**: Only modify what is strictly necessary.
3. **Verification**: If possible, use `exec` or `bash` to run lint/type-check before returning.
