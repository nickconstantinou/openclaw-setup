---
description: Generic Focus Group Simulator & Optimization Engine
---

# SKILL.md

## Generic Focus Group Simulator & Optimization Engine

---

# Skill Name

generic_focus_group_optimizer

---

# Purpose

This skill simulates a **high-fidelity qualitative research engagement** to evaluate and iteratively improve content (e.g., books, marketing material, product pitches, articles) for a **user-specified target audience and topic**.

It replicates the workflow of a **top-tier research consultancy**, combining:

- Dynamic generation of simulated focus groups (14 diverse personas tailored to the topic)
- Persona-driven critique
- Cross-persona insight synthesis
- Structured editorial improvement
- Iterative quality scoring

The skill runs **multiple improvement cycles** until the material reaches a **minimum overall quality score of 0.95**.

---

# Key Outputs

The skill produces:

1. **Dynamically Generated Persona Set** (14 personas based on the topic and target audience)
2. Simulated **focus group dialogue** (from the generated personas)
3. Persona-specific reactions
4. **Confidence score** for every excerpt
5. Cross-person insight synthesis
6. Editorial improvement recommendations
7. Iterative editing cycles
8. Final **validated manuscript score ≥ 0.95**

---

# Input

Provide:
- **Topic/Subject Matter**: What is the content about?
- **Target Audience Details**: Demographics, psychographics, age range, etc.
- **Content Type**: Chapter, draft manuscript, blog post, marketing content, etc.
- **The Content**: The actual text to be evaluated.

Example:

Run generic_focus_group_optimizer on the following:
- Topic: Adopting AI in mid-sized logistics companies
- Target Audience: Operations Directors, IT Managers, and CEOs (ages 35–60)
- Content Type: Marketing Whitepaper
- Content: [Insert content]

---

# Core Concept

Each excerpt is evaluated using five metrics:

| Metric | Description |
|--------|-------------|
| Authenticity | Does it reflect the real psychology and lived experience of the target audience? |
| Clarity | Is the message understandable? |
| Relevance | Does it match the real concerns, needs, and pain points of the audience? |
| Credibility | Does it feel believable and authoritative? |
| Emotional resonance | Does it connect with the readers on a deeper level? |

**Excerpt Score** = weighted average of all metrics

All excerpts combine into an **overall manuscript score**.

---

# Workflow

The skill runs in **five phases**.

---

# Phase 1 — Dynamic Persona Generation

Instead of using a static set of personas, the system first generates a **diverse focus group** of 14 people that match the provided **Target Audience Details** and **Topic**. 

For each persona, generate:
- **Name/Identifier**
- **Age & Career/Role**
- **Profile:** Their background, socioeconomic status, or worldview.
- **Concerns:** What keeps them up at night regarding the topic?
- **Voice:** A signature quote or attitude they embody.

Ensure wild diversity within the target audience (e.g., skeptics, enthusiastic adopters, burned-out veterans, cautious planners, outliers).

---

# Phase 2 — Persona Focus Group Simulation

Simulate the focus group with the 14 dynamically generated personas.

Each persona:
- Reviews the excerpt
- Provides emotional reactions
- Critiques realism and usefulness
- Suggests improvements
- Responds to other personas' comments

---

# Phase 3 — Excerpt Scoring

## Scoring Matrix

| Metric | Weight |
|--------|--------|
| Authenticity | 25% |
| Clarity | 20% |
| Relevance | 20% |
| Credibility | 20% |
| Emotional Resonance | 15% |

## Score Thresholds

* **0.95+**: Publication ready
* **0.85-0.94**: Minor revisions needed
* **0.70-0.84**: Major revisions needed
* **Below 0.70**: Significant rewrite required

---

# Phase 4 — Insight Consolidation

## Major Themes (Cross-Persona)

Synthesize the major themes and takeaways from the focus group simulation. Identify missing frameworks, misplaced assumptions, and areas where the content failed to resonate with specific subsets of the audience.

---

# Phase 5 — Editorial Optimization Loop

## Step 1 — Implement Edits

- Rewrite weak excerpts based on the feedback.
- Add missing frameworks or context.
- Strengthen credibility (e.g., tone adjustments, evidence).
- Introduce realistic examples or case studies as requested by the personas.

## Step 2 — Re-Run Skill

Re-evaluate revised material using the same 14 personas.

## Step 3 — Compare Scores

| Version | Score |
|---------|-------|
| Original manuscript | X.XX |
| Edited manuscript | X.XX |

## Step 4 — Iteration Rule

If score < 0.95:
1. Identify lowest-scoring excerpts.
2. Generate rewrite guidance.
3. Request another revision.
4. Re-run focus group simulation.

**Iteration continues until score ≥ 0.95**

---

# Output FORMAT

## 1 Generated Persona Set
Detailed list of the 14 dynamically generated personas.

## 2 Focus Group Transcript
Simulated multi-persona discussion.

## 3 Excerpt Score Table
| Excerpt | Score |
|---------|-------|
| Excerpt 1 | X.XX |

## 4 Cross-Persona Insights
Major themes across all participants.

## 5 Editorial Improvement Log
- Weaknesses identified
- Edits applied
- Score improvements

## 6 Final Manuscript Score
**Final Quality Score: X.XX**

---

# Quality Standard

The skill targets the rigor of high-end qualitative research engagements by ensuring:

- Deeply considered, dynamically generated demographic and psychographic diversity
- Psychologically realistic personas pushing back on the content
- Credible dialogue simulation and inter-persona debate
- Measurable improvement cycles

---

# Command

Run generic_focus_group_optimizer on the following:

- **Topic:** [Topic]
- **Target Audience:** [Audience Details]
- **Content Type:** [Content Type]
- **Content:** [Insert manuscript or excerpts]

The system will define the personas, run the complete focus group simulation, scoring process, and optimization loop until the material achieves a minimum score of 0.95.

---
