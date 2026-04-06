# SD Review — Multi-Persona Software Development Review Workflow

## Purpose

Run a structured review of any software development artifact (plan, design doc, architecture decision, migration guide, API spec, etc.) through five specialist personas. Each persona scores the artifact 0.0–1.0 and provides actionable feedback. The workflow iterates — improving the artifact after each pass — until all persona scores reach ≥ 0.95.

Use this skill when you need rigorous pre-implementation review of a technical document and want to catch strategic, architectural, implementation, testing, and operational gaps before any code is written.

---

## The Five Personas

### 1. CTO
**Focus:** Strategic alignment, technical risk, build vs. buy decisions, long-term maintainability, cost

**Review criteria:**
- Does this align with the stated product and technical strategy?
- What are the highest-risk assumptions? What happens if they're wrong?
- Is the build/buy/borrow decision justified?
- Is there a vendor lock-in risk, and is it acceptable?
- Is there a cost model or token/compute budget analysis where relevant?
- Is there a rollback or contingency path if the approach fails?
- Does this leave the system in a maintainable state 12–24 months out?
- Are the success criteria measurable and production-relevant?

---

### 2. Senior Architect
**Focus:** System design, cohesion, separation of concerns, scalability, edge cases, interface contracts

**Review criteria:**
- Are service boundaries clean? Do dependencies flow in the right direction?
- Are interfaces/contracts defined so concrete implementations can be swapped?
- Is there a resilience strategy (retry, circuit-breaker, timeout) for external calls?
- What is the error taxonomy — which errors are transient vs. permanent? Are they handled differently?
- Are edge cases (empty responses, malformed data, oversized inputs) handled explicitly?
- Does the design scale to 10x current load without structural changes?
- Are there hidden coupling points not addressed in the plan?
- Is the data model sound, and are DB migrations safe?

---

### 3. Senior Full-Stack Engineer
**Focus:** Implementation feasibility, code quality, developer experience, practical gaps

**Review criteria:**
- Is every code path shown actually implementable as written?
- Are there silent failures — missing null checks, uncaught exceptions, empty-string defaults that should throw?
- Are naming conventions, file paths, and type contracts consistent and fully specified?
- Is the developer experience good? Can a new contributor follow this plan without asking questions?
- Are there any "TODO: figure this out later" items that should be resolved now?
- Is mock/test mode workable for local development?
- Are imports, dependency versions, and module boundaries correct?
- Are all modified files listed? Are there implicit dependencies not called out?

---

### 4. Automation Test Engineer
**Focus:** Testability, coverage gaps, regression risk, test strategy, fixtures

**Review criteria:**
- Is there a test strategy section? Does it cover unit, integration, and regression?
- Is there a mock/stub path that doesn't require real credentials for local and CI testing?
- Are test fixtures defined or referenced?
- What are the regression risks? Which existing tests break and need updating?
- Is the quality acceptance threshold (e.g., score ≥ 3) testable?
- Are there untested code paths that could produce silent data corruption?
- Is the DB migration covered by a staging test before production rollout?
- Are deleted test files and components called out explicitly?

---

### 5. DevOps Engineer
**Focus:** CI/CD pipeline integrity, deployment safety, environment config, secrets management, observability

**Review criteria:**
- **CI/CD pipeline (highest priority):** Does the change affect any workflow file (`.github/workflows/`)? If so, was a dry-run completed before the push (e.g., `act`, workflow syntax validation, or manual step execution)? Flag any push that skips this.
- **Workflow dry-run gate:** Before every `git push` to GitHub, confirm that: (a) the full test suite passes locally, (b) any modified workflow YAML has been validated (`act --dryrun` or `actionlint`), and (c) no new required secrets are introduced without being added to the repo's environment first. If no workflow files were changed, the test suite pass counts as the dry-run.
- Where does each secret/credential live in production? Is this documented?
- Are there any secrets that could accidentally be committed to the repo?
- Is there a clear migration execution environment (who runs it, with what credentials)?
- Is there a rollback procedure for the DB migration?
- Is the deployment order safe? Can services be rolled forward/back independently?
- Are there observability hooks — what does a failure look like in logs?
- Are there structured log tags to make log filtering practical?
- Are alert thresholds or monitoring signals defined?
- Does CI need to change for this migration? If yes, block merge until pipeline is updated and dry-run passes.

---

## Workflow

### Step 1 — Read the artifact
Read the full artifact. Note its stated goals, constraints, and decisions already made. Do not second-guess firm decisions; focus reviews on gaps and risks within the chosen approach.

### Step 2 — Run all five persona reviews
For each persona, produce:
- **Score:** 0.0–1.0
- **Concerns:** 2–3 specific, actionable gaps or risks
- **Recommendations:** 1–2 specific improvements to address the concerns

### Step 3 — Identify lowest-scoring areas
Rank personas by score. The bottom 1–3 personas represent the plan's weakest dimensions. List the specific gaps that are driving those scores.

### Step 4 — Improve the artifact
Edit the artifact directly (use Edit/Write tools). Do not describe what you would change — actually make the changes. Address the concerns from the lowest-scoring personas first, then sweep for any remaining gaps from higher-scoring personas.

### Step 5 — Re-score
Run all five personas again against the improved artifact. Record new scores.

### Step 6 — Iterate until ≥ 0.95
If any score is below 0.95, return to Step 3. Repeat until all five scores reach ≥ 0.95.

Typical number of passes: 2–3 for a plan that was written by one person. Well-reviewed plans may clear 0.95 in one pass.

---

## Output Format

### Per-pass output block

```
## Pass N — Persona Reviews

### CTO — {score}
Concerns:
1. {concern}
2. {concern}
Recommendations:
- {recommendation}

### Senior Architect — {score}
Concerns:
1. {concern}
2. {concern}
Recommendations:
- {recommendation}

### Senior Full-Stack Engineer — {score}
...

### Automation Test Engineer — {score}
...

### DevOps Engineer — {score}
...

### Lowest-scoring areas this pass
- {persona}: {specific gap driving the score}
- {persona}: {specific gap driving the score}

### Changes made
- {description of what was added/changed in the artifact}
```

### Final summary block

```
## Final Scores (all ≥ 0.95)

| Persona | Pass 1 | Pass 2 | Final |
|---------|--------|--------|-------|
| CTO | {score} | {score} | {score} |
| Senior Architect | {score} | {score} | {score} |
| Senior Full-Stack Engineer | {score} | {score} | {score} |
| Automation Test Engineer | {score} | {score} | {score} |
| DevOps Engineer | {score} | {score} | {score} |

## Key improvements made
- {summary of most important additions per dimension}
```

---

## Tips

- **Be specific in concerns.** "No error handling" is weak. "The `generateJson` method indexes `choices[0]` without checking if `choices` is non-empty" is actionable.
- **Don't gold-plate.** If a decision is marked as already made (e.g., single-model, no fallback), accept it and review within that constraint.
- **Score honestly.** A score of 0.70 is not a failure — it means there's real work to do. Inflated scores defeat the purpose.
- **Each persona has a different frame.** The DevOps persona does not care about naming conventions. The Full-Stack persona does not evaluate strategic fit. Keep reviews in-lane.
- **Iterate on the actual document.** The goal is an artifact that can be handed to an engineer and executed without ambiguity, not a review report that lives alongside a still-incomplete plan.
