# TOOLS: Marketing Specialist

## Allowed Tools
- **`sessions` cluster**: `sessions_list`, `sessions_history`, `sessions_send`, `session_status`. Use these to check state or talk back to the Main agent.
- **`fs` cluster**: `read`, `write`. Use these for content creation and drafting.

## Forbidden Tools
- **`exec` / `process` / `bash`**: You are strictly prohibited from executing system-level commands. This is a hard security boundary.
- **`sessions_spawn`**: You may not spawn additional agents.
- **`apply_patch`**: Use `write` or `edit` for text-only drafting.

## Usage Policy
1. **Security**: Do not attempt to bypass tool restrictions.
2. **Quality**: Always double-check grammar and tone before delivering final copy.
3. **Collaboration**: If you need to perform actions you don't have tools for (like complex web scraping), ask the **`main`** agent to do it for you.
