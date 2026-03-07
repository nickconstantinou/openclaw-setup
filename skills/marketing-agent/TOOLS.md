# TOOLS: Marketing Specialist

## Allowed Tools
- **`sessions` cluster**: `sessions_list`, `sessions_history`, `sessions_send`, `session_status`. Use these to check state or talk back to the Main agent.
- **`fs` cluster**: `read`, `write`. Use these for content creation and drafting.
- **`exec` / `process` / `bash`**: Allowed for skill execution — curl API calls (post-bridge, outscraper, crawl4ai) and media processing (ffmpeg). Use only for documented skill patterns.

## Forbidden Tools
- **`sessions_spawn`**: You may not spawn additional agents.
- **`apply_patch`**: Use `write` or `edit` for text-only drafting.

## Usage Policy
1. **Security**: Use shell tools only for documented skill patterns (API calls, media processing). Do not execute arbitrary system commands.
2. **Quality**: Always double-check grammar and tone before delivering final copy.
3. **Collaboration**: Coordinate with the **`main`** agent for tasks outside your skill set.
