# SKILL: Elite General Writing Skill — AI Slop Prevention

## Purpose
Enable an agent to produce high-quality, professional writing from the outset, without relying on post-hoc rewriting. 

This skill ensures content is:

- Clear, concise, and authoritative 
- Human-like in voice, rhythm, and style 
- Insightful and specific 
- Free from generic AI patterns 

It applies to any writing task: marketing copy, articles, reports, or creative content.

---

# Core Writing Standards

All content must meet the **Universal Vibe Standards** defined in the root `marketing-logic.md`.

### Mandatory Benchmarks:
1. **Zero Zombies**: No words from the Banned Glossary in `marketing-logic.md`.
2. **Human Rhythm**: Must demonstrate sentence length variance (staccato feel).
3. **Information Gain**: Every paragraph must provide a specific insight or data point.
4. **Target Score**: Final output must achieve ≥ 0.95.

---

# AI Slop Prevention
Refer to `marketing-logic.md` for the full list of structural red flags and rejection criteria.

---

# Writing Workflow

1. **Plan Content**
   - Define goal, audience, tone, and key points 
   - Identify specific examples or evidence 

2. **Draft Content**
   - Use varied sentence structure 
   - Integrate examples and insights naturally 
   - Maintain persona and human-like voice 

3. **Self-Evaluate**
   - Check against all 12 elite dimensions 
   - Detect AI slop patterns in real time 
   - Score content internally (0–1 per dimension) 
   - Confidence check: only finalize if ≥ 0.95 equivalent 

4. **Revise Inline**
   - Adjust wording, structure, and voice immediately 
   - Remove any detected filler, weak verbs, or mechanical phrasing 

5. **Finalize**
   - Ensure clarity, conciseness, authority, and engagement 
   - Confirm coherence, readability, and persona alignment 

---

# Agent Output Requirements

When producing content:

1. Draft Content
2. Self-Audit Summary
   - Dimension scores 0–10
   - Detected AI slop patterns
   - Confidence score 0–1
3. Inline Adjustments Made
4. Final Draft

**Mandatory:** The agent must never output content without a confidence ≥ 0.95. If it fails, the draft must be iteratively improved before release.

---

# Guardrails

- Never introduce factual errors or change intended meaning 
- Preserve author persona and style unless explicitly directed 
- Ensure original insights, examples, and perspective 
- Avoid over-editing that makes content sound robotic or formulaic 

---

# Success Criteria

The skill succeeds if content:

- Reads as elite professional writing 
- Is free of generic AI patterns 
- Demonstrates clarity, authority, and originality 
- Achieves internal ≥ 0.95 confidence 
- Aligns with intended voice, tone, and audience 
