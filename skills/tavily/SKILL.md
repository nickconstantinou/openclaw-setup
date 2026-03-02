---
name: tavily
description: Search the web using Tavily API (free tier: 1000 searches/month)
metadata:
  {
    "openclaw":
      {
        "emoji": "🔍",
        "requires": { "env": ["TAVILY_API_KEY"] },
        "primaryEnv": "TAVILY_API_KEY",
      },
  }
---

# Tavily Web Search

Use Tavily for web search when you need fast, relevant results. Tavily is optimized for AI agents and provides up to 1000 free searches/month.

## When to use (trigger phrases)

Use this skill when the user asks you to:
- "search for X" / "look up X"
- "find information about X"
- "what is X" / "who is X"
- Any web search request

## Quick start

Search using curl:

```bash
curl -s -X POST https://api.tavily.com/search \
  -H "Authorization: Bearer $TAVILY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "<your search query>", "max_results": 5}'
```

## Environment

Set the API key:
```bash
export TAVILY_API_KEY="tvly-..."
```

Or configure in OpenClaw config.

## Response format

Tavily returns results with:
- `results[].title` - Result title
- `results[].url` - Result URL  
- `results[].content` - Snippet/content
- `results[].score` - Relevance score

## Tips

- Use `max_results` to control number of results (max 20)
- For best results, use specific queries
- Tavily is faster than Brave for most queries
- Great free alternative to Brave/Perplexity
