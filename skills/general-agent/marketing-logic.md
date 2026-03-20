# Marketing Universal Vibe Standards & Logic

This file is the central source of truth for the **Vibe Metrics** and **Quality Standards** enforced by the Marketing Agent.

---

## 1. The "Anti-Slop" Baseline (Hard Rejection Criteria)

Any content containing these markers must be rejected and rewritten:

### A. Banned "Zombie" Vocabulary
*Innovative, Game-changing, Revolutionary, Cutting-edge, Seamless, Robust, Synergy, Holistic, Transformative, Comprehensive, Unlock, Leverage, Catalyst, Tapestry, Landscape, Delve, In conclusion.*

### B. Structural Red Flags
*   **Symmetry Slop:** Symmetrical lists (e.g., 3 bullet points of exactly the same length) or uniform paragraph sizes.
*   **Motivational Fluff:** Sentences that sound good but contain zero data or specific claims.
*   **Passive Hedging:** "It could be argued that..." or "We aim to provide..."

---

## 2. Vibe Score Dimensions (0.0 - 1.0)

Skills like `vibe-critic` and `ai-slop-audit` must score against these criteria:

1.  **Specificity (30%):** Does it use specific numbers, real names, or measurable outcomes?
2.  **Human Rhythm (20%):** Does sentence length vary naturally? Is there a "staccato" human feel?
3.  **Insight Density (20%):** Does it provide a non-obvious observation that only an expert would know?
4.  **Banned-Free (20%):** Is it 100% free of "Zombie" words?
5.  **Persona Resonance (10%):** Does it match the selected `brand-voice` frequency?

---

## 3. Aesthetic Standards (Visual)

*   **No "Corporate Blue" Accents:** Avoid #0000FF.
*   **No "Clay Hands":** 3D generic icons holding phones are banned.
*   **High Contrast:** Every design must use a bold, intentional palette.
*   **Real Data Viewports:** Use real numbers and graphs, never "Lorem Ipsum".

---

## 4. Usage in Skills
*   **`vibe-critic`**: Uses Section 1 & 3 for automated audit checks.
*   **`elite-writing`**: Uses Section 1 & 2 for drafting standards.
*   **`brand-voice`**: Supplies the 'Persona Resonance' parameters.
