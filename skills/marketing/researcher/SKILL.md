---
name: market-researcher
description: Conducts deep-dive research into market gaps, Reddit sentiment, and competitor 'vibe' analysis using Playwright.
type: skill
version: 1.1.0
---

# Market Researcher Skill

## Goal
To move past surface-level search results and identify "The 6 Circles of Relevance." The agent must find raw human pain points, unedited reviews, and cultural momentum shifts.

## Tools

### 1. Exa Search (Neural)
Use `exa_search` to find high-signal technical blogs, niche newsletters, and "founder-led" content.

### 2. Jina AI Reader (Web Content)
Use for clean Markdown extraction from any URL (free, no install):
```bash
curl -s "https://r.jina.ai/https://example.com"
```

### 3. Reddit/X Deep-Dive (Firecrawl)
Use `firecrawl_scrape` to ingest entire threads where users are complaining about competitors. 

### 4. Browser Screenshots
Use `browser_screenshot` (Playwright) if a visual discovery is found.

## Process

1. **Neural Sweep (Exa):** Find high-authority sources
2. **Content Crawl (Crawl4AI):** Extract clean Markdown from relevant URLs
3. **Sentiment Mapping:** Extract raw human pain points
4. **Vibe Extraction:** Describe the *emotional state* of the audience
5. **Output:** Save to `research/raw_intel_[topic].json`

## Constraints
* **Signal > Volume:** Use Exa's filters for high-authority sources
* **No Fluff:** Report specific pain points, not generic market statements
* **Privacy First:** Do not scrape or store PII
* **Visual Evidence:** Screenshot relevant discoveries
