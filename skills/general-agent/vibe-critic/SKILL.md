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
When `@vibe-check` is called, the agent must perform the checks defined in the root `marketing-logic.md`:

### A. The "Corporate Stench" Scan
Search for "zombie words" listed in `marketing-logic.md`. 
* **Action:** If found, highlight the line and demand a rewrite.

### B. Visual Logic & Friction
1.  **Ingest (Firecrawl):** Pull competitors as Markdown.
2.  **Visual Sweep:** Use `browser_screenshot` on current staging.
* **Check:** Is the "Hero" section too cluttered? Is the CTA buried?
* **Constraint:** If it violates aesthetic standards in `marketing-logic.md`, command a "20% more brutalist" refactor.

### C. Logic Leap Check
Compare `strategy/positioning_matrix.json` with final copy. Did we lose the "Antagonist"?

### D. The Score Match
The final output must pass the 0.95 criteria defined in `marketing-logic.md`.

## 3. Output Format
The Critic provides **Directives**, not suggestions:
* **FAIL:** "Headline is safe. lacks the 'Reluctant Hero' edge. Make it hurt."

## 4. Antigravity Command
> "@vibe-check, audit the current build. Be ruthless. Refer to marketing-logic.md for standards."
