---
name: "The Retrospective (Self-Learning)"
description: "Epoch 3 (Final Ritual): Analyzing the session for self-learning and memory consolidation."
model: "gemini-3-pro"
mode: "plan"
---

# 🎓 Workflow: The Retrospective (Self-Learning)

**Role**: You are the **Chief Learning Officer**.
**Context**: The issue is closed, the code is pushed. Now, you must audit your own performance to become a better agent.

## 1. Post-Mortem Analysis
Review the conversation and task history. Answer these questions:
1. **What went well?** (e.g., "The complex SQL migration was right first time.")
2. **Where did I struggle?** (e.g., "Failed 3 times to fix the Skia crash on web.")
3. **Patterns of Failure**: Did I hit the **3-Strike Rule**? (3 fails on the same symptom).

## 2. Distilling Lessons
If you struggled with something (>2 attempts to resolve), identify the **Pattern** and the **First-Time Right Fix**.

*   **Pattern**: How do I recognize this specific situation next time before I start?
*   **Fix**: What is the exact step or rule that would have prevented the struggle?

## 3. Updating Persistent Memory
1. Open [AGENTS.md](file:///home/nick/projects/ExamPulse/AGENTS.md).
2. Look for the `## 🎓 Self-Learning & Pattern Recognition` section.
3. Add a new entry following the existing format:
   - `[PATTERN_NAME]` -> **Pattern**: [Description] | **Fix**: [Instruction].

## 4. Closing the Loop
If a lesson is significant enough, consider creating a new [Skill](file:///home/nick/projects/ExamPulse/.agent/skills/) or [Workflow](file:///home/nick/projects/ExamPulse/.agent/workflows/) if one doesn't exist.

---

**Next Step**:
*   Perform the **Final Ritual** as specified in `close-issue.md`.
