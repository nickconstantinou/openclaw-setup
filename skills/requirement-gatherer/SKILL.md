---
name: requirement-gatherer
description: Use this skill when a task is high-level or ambiguous. It forces a diagnostic Q&A session before any code is written.
---
# Requirement Gathering Protocol
1. Do not write code.
2. Analyze the prompt and identify the "Pillars of Uncertainty":
   - **Data Model**: How will this persist? Are there schema changes or new tables?
   - **User Flow**: What is the visual/interactive experience? How does it handle navigation?
   - **Security**: What are the RLS implications? Are there sensitive fields or multi-tenant boundaries?
   - **Verification**: How will we test this? (Unit tests, E2E browser verification, or manual QA?)
   - **Edge Cases**: What are the failure modes? (e.g., API timeouts, missing data, unauthorized access)
   - **Infrastructure**: Does this impact Edge Function latency, shared utilities, or external dependencies?
3. Present these as a numbered list of diagnostic questions to the user.
4. Wait for response before generating the Implementation Plan.
