---
name: marketing-suite
description: >
  A comprehensive suite of marketing sub-skills (Brand Voice, Content Atomization, 
  Creative Strategy, SEO, etc.) designed to eliminate "AI-slop" and create 
  high-conversion, high-vibe assets.
metadata:
  {
    "openclaw":
      {
        "emoji": "📈",
        "requires": { "tools": ["generate_image"], "skills": ["nvidia-imagegen"] },
      },
  }
---

# Marketing Suite - High-Conversion Engine

This directory acts as a container for 18 specialized marketing sub-skills. Use these to maintain a consistent brand voice, atomize content for distribution, and define visual DNA.

## Sub-Skills Overview

| Skill | Description | Target |
|-------|-------------|--------|
| **Brand Voice** | Defines archetype (e.g. Reluctant Expert) and tone. | All Text |
| **Content Atomizer** | Turns 1 asset into 15+ native social pieces. | X, LinkedIn, IG |
| **Creative Strategist**| Defines visual DNA (Neo-Brutalist, Lux-Minimal).| UI/Images |
| **Offer Architect** | Structures high-converting offers/landing pages. | Sales |
| **Vibe Critic** | Audits content for "AI-slop" and corporate speak. | QC |
| **Visual Producer** | Generates high-impact AI imagery prompts. | Assets |

## Usage Pattern

When starting a marketing task, follow this sequence:
1.  **Voice Check**: Reference `brand-voice/SKILL.md` to set the frequency.
2.  **Creative Brief**: Reference `creative-strategist/SKILL.md` for visual direction.
3.  **Execution**: Use the specific sub-skill (e.g., `email-sequences`, `newsletter`).
4.  **Atomization**: Use `content-atomizer/SKILL.md` to distribute the result.

## The "AI-Slop" Manifesto
- **No** "delve," "comprehensive," "unlock," or "catalyst."
- **No** blue gradient backgrounds or 3D clay hands.
- **Yes** specific numbers, raw honesty, and bold typography.
- **Yes** "2AM Bar" test — would you say this to a friend?

## Repository Structure
```text
skills/marketing/
├── brand-voice/         # Voice Engine
├── content-atomizer/    # Distribution
├── creative-strategist/ # Visual DNA
├── seo-content/         # Search Visibility
└── [14 more...]         # Specialized Tools
```
