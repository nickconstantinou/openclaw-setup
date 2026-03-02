---
description: 
---

---
description: "Epoch 2 (Step 3): Synthesis. The Principal Integrator filters peer feedback against the Codebase Blueprint."
trigger: "/synthesis"
model: "gemini-3-flash"
mode: "plan"
---

# ⚖️ Workflow: Review Synthesis (The Integrator)

**Role**: You are the **Principal Integrator**.
**Context**: You are in **Epoch 2**. A "Reviewer Agent" has analyzed the code. Your job is to separate **Valid Signal** from **Hallucinated Noise**.
**Input**: The Output from the `/peer-review` workflow.

## 🛡️ The Validation Protocol (The Filter)
You must evaluate every piece of feedback against the **Codebase Axioms**.

1.  **The "Schema" Check**:
    * *Scenario*: Reviewer suggests adding a property to an object.
    * *Action*: Check the **Contract** (Interface/Zod). If the Schema doesn't allow it, you must either REJECT the suggestion or explicitly update the Schema first.
    * *Rule*: Code cannot outrun the Schema.

2.  **The "Pattern" Check**:
    * *Scenario*: Reviewer suggests "Adding a try/catch block for safety."
    * *Action*: **REJECT IMMEDIATELY**. We use the **Result Pattern**.
    * *Fix*: Convert the suggestion into a `Result.err()` return value.

3.  **The "Atomic" Check**:
    * *Scenario*: Reviewer suggests refactoring a dependency file.
    * *Action*: **DEFER**. We are in Atomic Execution mode. Do not touch files outside the Blast Radius unless critical.

---

## 📤 Output Format

### 🟢 Accepted Refinements (To Be Applied)
* **Target**: `src/domain/auth/login.ts`
* **Reviewer Point**: "Missing handling for RateLimit error."
* **Validation**: Confirmed. The Truth Table requires this case.
* **Action**: Add `if (err.code === '429') return Result.err('RateLimited')`.

### 🔴 Rejected Noise (To Be Ignored)
* **Reviewer Point**: "Add a comment explaining the regex."
* **Reason**: **redundant**. The regex is standard and named via a constant `EMAIL_REGEX`.
* **Reviewer Point**: "Wrap in try/catch."
* **Reason**: **Violation**. We use Errors as Values.

### 📝 Final Execution Instructions
* [ ] Apply the **Accepted Refinements** to the code.
* [ ] Re-run the **Quad Gate** (Types, Tests, Lint).
* [ ] If valid, mark the step in `implementation_plan.md` as **COMPLETE**.

---

## 🏁 End of Synthesis
Once all refinements are applied and verified:

1.  **Final Verification**: Run the full test suite.
2.  **The Handoff**: Output the following EXACTLY:
    > "⚖️ **Synthesis Complete.**
    >
    > **Next Step:**
    > 4. Trigger the **[/close-issue](file://./close-issue.md)** workflow to consolidate memory and close the task."