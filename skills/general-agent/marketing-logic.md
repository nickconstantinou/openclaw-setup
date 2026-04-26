# Marketing Universal Vibe Standards & Logic

This file is the central source of truth for the **Marketing Agent orchestration**, **Vibe Metrics**, and **Quality Standards**.

---

## 1. The "Anti-Slop" Baseline (Hard Rejection Criteria)

Any content containing these markers must be rejected and rewritten:

### A. Banned "Zombie" Vocabulary
*Innovative, Game-changing, Revolutionary, Cutting-edge, Seamless, Robust, Synergy, Holistic, Transformative, Comprehensive, Unlock, Leverage, Catalyst, Tapestry, Landscape, Delve, In conclusion.*

### B. Structural Red Flags
* **Symmetry Slop:** Symmetrical lists (e.g., 3 bullet points of exactly the same length) or uniform paragraph sizes.
* **Motivational Fluff:** Sentences that sound good but contain zero data or specific claims.
* **Passive Hedging:** "It could be argued that..." or "We aim to provide..."

---

## 2. Vibe Score Dimensions (0.0 - 1.0)

Skills like `vibe-critic` and `ai-slop-audit` must score against these criteria:

1. **Specificity (30%):** Does it use specific numbers, real names, or measurable outcomes?
2. **Human Rhythm (20%):** Does sentence length vary naturally? Is there a "staccato" human feel?
3. **Insight Density (20%):** Does it provide a non-obvious observation that only an expert would know?
4. **Banned-Free (20%):** Is it 100% free of "Zombie" words?
5. **Persona Resonance (10%):** Does it match the selected `brand-voice` frequency?

---

## 3. Aesthetic Standards (Visual)

* **No "Corporate Blue" Accents:** Avoid #0000FF.
* **No "Clay Hands":** 3D generic icons holding phones are banned.
* **High Contrast:** Every design must use a bold, intentional palette.
* **Real Data Viewports:** Use real numbers and graphs, never "Lorem Ipsum".

---

## 4. Marketing Orchestration Loop

All marketing work routes through this phase sequence:

```
researcher → keyword-research → positioning → offer-architect → brand-voice
    → asset skill → creative-strategist → content-atomizer → focus_group → vibe-critic
```

### Phase Skills
| Phase | Primary Skill | Artifacts |
|-------|---------------|-----------|
| Research | `market-researcher`, `content-research` | Pain point deep-dive, raw intel |
| Strategy | `positioning`, `offer-architect`, `brand-voice` | Market gap, Grand Slam offer, brand frequency |
| Execution | `elite-editor`, `seo-content`, `direct-response` | Draft copy, asset production |
| Creative | `creative-strategist`, `visual-producer` | Visual DNA, hook/angle selection |
| Distribution | `content-atomizer` | Platform-native repurposing |
| Audit | `focus_group`, `vibe-critic`, `ai-slop-audit` | Audience simulation, vibe score |

### Standard Workflows
- **Product/Offer:** `researcher` → `positioning` → `offer-architect` → `elite-editor` → `vibe-critic`
- **Content Strategy:** `keyword-research` → `brand-voice` → `seo-content` → `focus_group`
- **Hooks/Angles:** `creative-strategist` → `elite-editor` → `focus_group`
- **Rewrite/Critique:** `vibe-critic` (score < 0.95) → rewrite → re-audit
- **Campaign Creative:** Full loop above

---

## 5. Quality Gates (Quad Gate)

All marketing deliverables MUST pass:

| Gate | Criteria |
|------|----------|
| Anti-Slop | Zero banned vocabulary, zero symmetry slop |
| Vibe Score | Overall >= 0.95 across all dimensions |
| Audience Sim | `focus_group` confirms resonance with target |
| Brand Alignment | Matches `brand-voice` frequency parameters |

---

## 6. Skill Routing Rules

- **Pure research** → `market-researcher` or `content-research`
- **Copywriting** → `elite-editor` (foundation) or `direct-response` (conversion)
- **SEO content** → `seo-content` skill
- **Visual assets** → `nvidia-imagegen` or `visual-producer`
- **Video/editing** → `ffmpeg`, `video_generate`
- **Multi-channel distribution** → `content-atomizer`, `post-bridge`
- **Audience validation** → `focus_group` (high-fidelity simulation)
- **Technical audit** → `ai-slop-audit`, `vibe-critic`

---

## 7. Usage in Skills
* **`vibe-critic`**: Uses Section 1 & 3 for automated audit checks.
* **`elite-editor`**: Uses Section 1 & 2 for drafting standards.
* **`brand-voice`**: Supplies the 'Persona Resonance' parameters.
* **`focus_group`**: Uses Section 4 & 5 for audience simulation quality gates.