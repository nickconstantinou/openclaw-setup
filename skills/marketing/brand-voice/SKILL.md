---
name: brand-voice-engine
type: skill
version: 2.0.0
---

# Skill 01: Brand Voice Constitution

## Objective
To eliminate "AI-slop" and corporate speak by enforcing a specific, human, and magnetic frequency. This file acts as a filter for all text generation skills (05-09).

## 1. The Core Frequency
Choose one primary archetype for the project. If not defined, default to **The Reluctant Expert**.

### Archetypes
*   **The Reluctant Expert:** "I hate that I know this, but here's how the industry is scamming you." (High Authority, Low Patience).
*   **The Chaos Philosopher:** "Nothing matters, so let's build something cool." (High Intellect, High Whimsy).
*   **The Aggressive Minimalist:** "Cut the fluff. Do the work. Here are the numbers." (High efficiency, Zero tolerance).
*   **The Lucid Dreamer:** "What if reality is just a suggestion?" (High Creativity, High Abstract).

## 2. Tone Modifiers
Apply these globally unless verified otherwise.
*   **Sentence Length:** Variance is King. One word. Then a long, flowing sentence that takes you on a journey before snapping you back.
*   **Vocabulary:** No "delve," "comprehensive," "unlock," "catalyst," or "tapestry." Use Anglo-Saxon roots (e.g., "build" not "construct", "talk" not "communicate").
*   **Rhythm:** Write for the ear, not the eye. If you can't read it aloud without taking a breath, cut it.

## 3. The "Vibe Check" Protocol
Before finalizing ANY text asset, run this checklist:
1.  **The "So What?" Test:** If you delete the first paragraph, does the meaning change? If no, delete it.
2.  **The "2AM Bar" Test:** Would you say this to a friend at a bar at 2 AM?
    *   *Bad:* "We provide comprehensive solutions for leveraging synergies."
    *   *Good:* "We help you stop burning cash."
3.  **The Specificity Rule:** Never say "many people." Say "342 founders in our beta group."

## 4. Banned Glossary
*   Innovative
*   Game-changing
*   Revolutionary
*   Cutting-edge
*   Seamless
*   Robust
*   Synergy
*   Holistic

## 5. Output Format
When asked to define the voice for a project, output a **Voice Profile**:
```json
{
  "archetype": "The Reluctant Expert",
  "modifiers": ["Dry Humor", "Data-First"],
  "banned_words": ["Synergy", "Unlock"],
  "sample_sentence": "Most marketing is noise; we sell signal."
}
```
