---
description: "Epoch 3 (Final Step): The Historian. Updates Human Docs, RAG Context, and Archives the Issue."
---

---
name: "Context Mapping & Closure (The Historian)"
model: "gemini-3-pro"
mode: "plan"
---

# 📚 Workflow: Context Mapping & Closure (The Historian)

**Role**: You are the **Chief Archivist**.
**Context**: You are in **Epoch 3**. The code is locked. Your job is to translate technical changes into **Human History** and **Agent Memory**.
**Input**: The `git diff` and the `walkthrough.md` (if generated).

## 1. The Semantic Audit (RAG Optimization)
Before closing, ensure the code is "Search Engine Ready" for future agents.
* **Intent Tags**: Scan new files. Do headers contain `@intent` and `@complexity` tags?
* **Neighbors**: Are `@dependency` lists in file headers accurate?

## 2. Human Documentation Sync 📝
*The map must match the territory. Update truth sources.*
- [ ] **CHANGELOG.md**: Add an entry under `## Unreleased`. Describe the change in plain English (e.g., "Added retry logic for 429 errors").
- [ ] **README.md**: If the "How to Run" instructions or Environment Variables changed, update the relevant sections.
- [ ] **AGENTS.md**: Update the "Context Map" if new high-level architectural patterns were introduced.

## 3. Issue Resolution & Archival 📂
You must finalize the Issue Record so it serves as a permanent Case Study.

1.  **Append Resolution**: Add a `## 🏁 Resolution` section to the original issue file in `docs/issues/open/`.
2.  **Embed Evidence**:
    * **Do not link** to external files.
    * **Embed the full text** of `walkthrough.md` (or the implementation summary) directly into this section.
    * Use clear headers: `### 🔄 Before/After` and `### 🧪 Verification Evidence`.
3.  **Move to Complete**: Move the file from `docs/issues/open/` to `docs/issues/closed/`.
    * *Command*: `mv docs/issues/open/[file].md docs/issues/closed/[file].md`

## 4. Workspace Sanitation
Delete *only* the ephemeral artifacts that are no longer needed (now that they are embedded in the Issue).
* `rm implementation_plan.md`
* `rm walkthrough.md` (since it is now inside the Issue file)

## 5. Git Synchronization 🚀
Perform the final commit sequence with strict hygiene.

- **Atomic Commits**: Group changes logically.
    * `feat: ...` for new logic.
    * `docs: ...` for the Issue move and CHANGELOG updates.
    * `refactor: ...` for code cleanup.
- **Push**: Push the verified branch to GitHub.
    * `git push origin [branch-name]`
- **Branch Management**:
    * If the task is fully merged/completed, delete the local feature branch to keep the workspace clean.
    * `git branch -d [branch-name]`

## 6. Retrospective & Self-Learning 🎓
**MANDATORY**: Before finishing, you must learn from this issue.
1. Trigger the **[/retrospective](./retrospective.md)** workflow.
2. Analyze your performance and update `AGENTS.md`.

---

## 🏁 End of Epoch 3
Once the repo is clean and synchronized:

1.  **The Final Ritual**: Output the following EXACTLY:
    > "📚 **Memory Consolidated. Issue Closed.**
    >
    > **Next Steps:**
    > 1. Performance analyzed via **[/retrospective](./retrospective.md)**.
    > 2. Lessons distilled into **[AGENTS.md](../../AGENTS.md)**."