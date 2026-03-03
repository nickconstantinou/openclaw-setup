---
name: vibe-critic
description: Performs a ruthless audit of marketing artifacts to ensure they adhere to the Brand Constitution.
type: skill
version: 1.4.0
dependencies: [marketing-logic, vibe-architect]
---

# Skill 13: Vibe Critic

## 1. Goal
To protect the brand from "Mid-ness." The Critic’s job is to find where the AI became lazy, corporate, or incoherent.

## 2. The Audit Protocol
When `@vibe-check` is called, the agent must perform these four checks:

### A. The "Corporate Stench" Scan
Search for "zombie words" (solutions, leading, innovative, empowered). 
* **Action:** If found, highlight the line and demand a "human-first" rewrite.

### B. The "Visual Friction" Audit
1.  **Ingest (Firecrawl):** Use `firecrawl_scrape` to pull the competitor's landing page as Markdown.
2.  **Visual Sweep (Playwright):** Use `browser_screenshot` to analyze the actual render.
* **Check:** Is the "Hero" section too cluttered? Is the call-to-action (CTA) buried?
* **Constraint:** If it looks like a generic Shopify template, the Critic must command the Architect to "Add 20% more brutalist aesthetic."

### C. The "Logic Leap" Check
Compare the `positioning_matrix.json` with the final copy. 
* **Check:** Did the Architect lose the "Antagonist"? If we are fighting "Slow Software," but the copy is talking about "Efficiency," the vibe is broken.

### D. The "2 AM Resonance" Test
Read the copy aloud (internally). 
* **Action:** If a real person wouldn't say this over a drink at 2 AM, it is rejected.

## 3. Output Format
The Critic does not provide "suggestions." It provides **Directives**:
* **FAIL:** "Maybe make the headline punchier?"
* **PASS:** "REWRITE: The headline is safe. It lacks the 'Reluctant Hero' edge from our matrix. Make it hurt more."

## 4. Antigravity Command
> "@vibe-check, audit the current build in the browser. Be ruthless. Refer to marketing-logic.md for the standards."
