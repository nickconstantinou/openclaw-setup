# GPT 5.4 Migration and Model Routing

## Why this exists
If you switch an OpenClaw setup from Claude to GPT 5.4 without changing prompts, GPT can feel slower or less proactive than Claude even when the model is strong.

The fix is usually prompt-level, not platform-level.

## Step 1: change the agent prompt first
Add these lines to your shipped/default agent instructions:

- Always use tools proactively. When given a task, call a tool first.
- Act first, explain after.
- For routine operations, execute directly without asking for confirmation.
- For high-risk actions like destructive deletion, publishing, production config changes, or security-sensitive operations, pause for confirmation.
- When a task has an obvious next low-risk step, continue without waiting. When a decision materially changes outcomes, decide briefly or ask, then continue.

## Step 2: give GPT 5.4 a few days
Do not judge the switch in the first hour.
A short adaptation period usually reveals that many "GPT won't do anything" moments are prompt issues or expectation mismatch.

## Step 3: use a simple task log
Track:

| Task type | Model | Result | Notes |
| --- | --- | --- | --- |
| cron jobs | GPT 5.4 | stable | repeatable |
| cheap summarization | MiniMax | good enough | low cost |

This is often enough to discover your own model-routing strategy.

## Recommended setup
### GPT 5.4 for primary execution
Use GPT 5.4 for:
- config changes
- scripts
- daily ops
- data processing
- cron jobs
- routine engineering tasks
- most tool-using agent workflows

### MiniMax for cheap support workloads
Use MiniMax for:
- lower-cost summarization
- supporting generation tasks
- fallback experimentation
- jobs where price consistency matters more than premium reasoning

## Example config pattern
```json
{
  "agents": {
    "defaults": {
      "model": { "primary": "openai-codex/gpt-5.4" }
    },
    "fallbacks": {
      "cheap": "minimax/MiniMax-M2.7"
    }
  }
}
```

## Model ID reminder
- Codex/ChatGPT subscription route: `openai-codex/gpt-5.4`
- OpenAI API key route: `openai/gpt-5.4`
- MiniMax example: `minimax/MiniMax-M2.7`

## Practical recommendation
If you need to act today:
1. switch default execution to GPT 5.4
2. update prompts first
3. use MiniMax where low-cost support capacity is more important than premium reasoning
4. log which task types fit which model best
