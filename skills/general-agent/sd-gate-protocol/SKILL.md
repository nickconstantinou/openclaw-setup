# SD Gate Protocol

Structured three-way conversational review for resolving scoring disagreements across SD persona reviews.

---

## When to Run

After any SD persona review round where:
1. Average score is below the threshold (default 0.95)
2. One or more reviewers scored significantly below average (gap > 0.10)
3. A specific reviewer (typically Test or Full-Stack) is the consistent floor across multiple rounds

---

## The Problem

When reviewers disagree on edge cases, a scoring table doesn't resolve anything — you need a conversation. The lowest-scoring reviewer (typically Test) keeps citing theoretical concerns (concurrent writes, OS fault injection, etc.) that other reviewers accept as non-issues. You need a structured dialogue to distinguish:
- **Valid gaps** that should block shipping
- **Acceptable trade-offs** that don't apply to this architecture
- **Gold-plating** that would cost more to fix than the risk warrants

---

## The Protocol

### Step 1 — Identify the Floor Reviewer

After scoring, find the reviewer with the lowest score. If multiple rounds have been run, look for the reviewer who has been the floor in ≥2 consecutive rounds. That reviewer becomes the "focus reviewer" for the conversation.

### Step 2 — Extract Their Specific Objections

List each individual objection, not the overall score. Extract exact quotes. Example:

> "No concurrent-write test — two processes writing simultaneously could corrupt the .tmp file"
> "No OS-level fault injection — disk full not tested"
> "UTF-8 BOM not tested — errors=ignore silently swallows encoding errors"

Do not paraphrase. Use their exact words.

### Step 3 — Architects + Engineers Respond to Each Objection

For each objection, the Architect and Engineer reviewers give their position:

**Acceptable trade-off** (document and close):
> "Concurrent writes don't apply here — cron-triggered single-writer, systemd prevents simultaneous firing. Withdrawn."

**Valid gap with fix** (create action item):
> "Disk-full fault injection: Agree, add a monkeypatch test. Action: test_write_ffs_intel_returns_false_on_disk_full"

**Gold-plating** (document and close with rationale):
> "UTF-8 BOM: Writer always produces clean UTF-8. External files at this risk level are acceptable for v1. Not a blocker."

### Step 4 — Tester Confirms or Withdraws

The focus reviewer (Tester) confirms each response:
- Confirms withdrawal: "Withdrawn — I agree concurrent writes don't apply"
- Confirms acceptance of fix: "Action item accepted, please add test"
- Escalates: "I still think this is a blocker — here's why" (requires additional discussion)

### Step 5 — Document Exceptions

Any objection that is withdrawn or accepted as a trade-off gets documented in the plan:

```markdown
## Post-Review Exceptions (SD Gate)

| Objection | Outcome | Rationale |
|-----------|---------|-----------|
| Concurrent-write test missing | Withdrawn | Cron single-writer, systemd prevents simultaneous firing |
| OS-level fault injection | Action: add monkeypatch test | Valid gap, fix is low-cost |
| UTF-8 BOM silent ignore | Accepted for v1 | Writer produces clean UTF-8; BOM from external files is acceptable risk |
```

### Step 6 — Recalculate Adjusted Average

After documented exceptions, the adjusted average may be higher than the raw average. Use this for the final gate decision.

---

## Skill Usage

### Phase 1: Lightweight (for incremental improvements)
When scoring is above 0.85 and the gap is small, run a fast version:
- Skip Steps 1-2 if there's a clear outlier (just ask the low scorer directly)
- Combine Steps 3-4 into a single structured response
- Skip Step 5 if all items are "valid gap with fix" — just create the action items

### Phase 2: Full (for new architecture or significant changes)
When scoring is below 0.80 or multiple rounds have failed, run the full protocol as described above.

### Phase 3: Main Agent (required)
When asked to run the skill as main agent (not subagent), the main agent:
1. Embodies ALL five personas directly (no spawning)
2. Conducts the three-way conversation internally
3. Documents exceptions using the table format
4. Produces a final weighted average accounting for accepted trade-offs

---

## Scoring Conventions

### What scores of 0.70-0.80 usually mean
- Something is architecturally sound but needs a specific fix
- The fix is usually <30 minutes of work
- Don't iterate again — just fix it and proceed

### What scores below 0.65 usually mean
- A real bug that would silently fail in production
- An architectural assumption that doesn't hold
- Fix immediately before proceeding

### What repeated scores of 0.60-0.70 from the same reviewer mean
- The reviewer has a consistent philosophical disagreement (e.g., "all regex is fragile")
- Not a bug — a design philosophy gap
- Document the disagreement as an accepted trade-off and move on

---

## Anti-Patterns

**Don't re-run the full persona protocol more than twice** on the same plan version. After 2 rounds of <0.95, use the conversational step to close gaps manually.

**Don't average away the lowest score.** If Test is consistently 0.60-0.70 and everyone else is 0.85+, the average is 0.75. The real question is whether Test's objections are valid. Address them directly.

**Don't let "theoretical" beat "practical".** If an objection requires mocking the kernel, simulating ENOSPC, or injecting faults at the OS level — and the reviewer can't propose a test that doesn't require that — it's gold-plating.

**Do distinguish between "this would be better" and "this is a blocker."** Many reviewers score down for theoretical future problems. If it works correctly today and degrades gracefully on the edge case, it's not a blocker.

---

## Integration with Requirement Gatherer

The requirement-gatherer skill feeds into this protocol:
- Requirement Gatherer → defines the plan
- SD Gate Protocol → validates and hardens the plan
- Three-Way Review → resolves disagreements

Run requirement-gatherer first to build the plan, then SD gate to validate it. Use the conversational review when the gate hits a stalemate.
