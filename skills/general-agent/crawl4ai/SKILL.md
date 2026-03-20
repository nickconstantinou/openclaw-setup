---
name: crawl4ai
description: AI-friendly web crawler for content extraction
metadata:
  {
    "openclaw":
      {
        "emoji": "🕷️",
        "requires": { "bins": ["curl"] },
      },
  }
---

# Web Content Extraction

**Primary Method: Jina AI Reader** (works now, no install)

```bash
# Extract clean Markdown from any URL (free, no API key)
curl -s "https://r.jina.ai/https://example.com"
```

Works great for:
- Blog posts
- News articles
- Documentation
- Research

---

## Crawl4AI (Optional)

Only if you need advanced features (browser automation, sessions, proxies):

```bash
# Python
pip install crawl4ai

# Or Docker
docker run -d -p 8000:8000 unclecode/crawl4ai:latest
```
