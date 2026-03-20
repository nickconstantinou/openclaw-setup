# Coding Universal Logic & Standards

This file is the central source of truth for **technical excellence** and **orchestration protocols** enforced by the Coding Agent.

---

## 1. The Quad Gate (Mandatory Verification)

Every task must pass these four gates before sign-off:

1.  **Logic (Type Safety):** `tsc --noEmit` must pass with zero errors. `any` is strictly prohibited.
2.  **Lint (Hygiene):** `npx expo lint` (or project equivalent) must return zero warnings.
3.  **Test (Correctness):** Minimum 70% coverage for new logic. Unit tests (Vitest) + E2E (Playwright) if UI.
4.  **Efficiency (Performance):** Edge Functions < 400ms. O(n) complexity limit for render/loop logic.

---

## 2. The Header Protocol

Every new or significantly refactored file must include a **Verbose Header**:
```typescript
/**
 * @file: [filename]
 * @purpose: [1-sentence explanation]
 * @logic: [Brief bullet points of core algorithm/flow]
 * @neighbors: [List of immediate dependencies/consumers]
 */
```

---

## 3. Implementation "Anti-Slop"

*   **No Magic Numbers:** All constants must be defined in a `const` or `enum` block.
*   **Monolith First:** Do not extract logic to new services or complex abstractions unless the file exceeds 700 LOC.
*   **Proximity Rule:** Keep logic as close to the call-site as possible.
*   **Self-Healing:** If a command fails due to missing dependencies, run the install command immediately and retry exactly once.

---

## 4. Multi-Agent Collaboration

*   **Content/Docs:** Delegate to Marketing Agent via `sessions_send`.
*   **Orchestration:** Escalate complex multi-step flows to the Main Agent.
*   **Verification:** Use `@review` (MOE Expert Review) for high-severity architectural changes.
