---
name: ralph
description: Implements the RALPH (Read, Analyze, Locate, Plan, High-Fidelity) autonomous agent loop for persistent context, rigorous verification, and high-quality execution.
---

# Ralph Agent Loop (RALPH)

The Ralph Agent Loop is a strategy designed to ensure that agents maintain high architectural rigor and quality control across sessions. It is based on the **RALPH** protocol and the **Quad Gate** verification process.

## 🧠 The RALPH Protocol

Before writing any code for a non-trivial task, follow these steps:

1.  **[R]ead**: Ingest all relevant context.
    - Check `AGENTS.md` for persistent memory and **Golden Rules**.
    - Read `package.json` for dependencies; verify against the **No Ghost Dependencies** rule.
    - Inspect database schemas and shared utilities in `src/lib/` or `src/types/`.
2.  **[A]nalyze**: Identify side effects and Proximity.
    - Consider RLS impact, state drift, and latency.
    - **Proximity Check**: Can this be solved within the existing monolith? Do not suggest microservices.
    - Evaluate cross-platform compatibility (Web vs. Mobile) per `AGENTS.md` gotchas.
3.  **[L]ocate**: Pinpoint exact lines and functions.
    - No "hallucinated" file paths.
    - Use `grep_search` and `find_by_name` to confirm locations.
4.  **[P]lan**: Present a step-by-step execution plan.
    - Create/update `implementation_plan.md`.
    - **Test Plan**: Define which `*.test.ts` files will be created/updated **before** implementation.
    - Break features into atomic stories in `task.md`.
5.  **[H]igh-Fidelity**: Execute with mandatory verification.
    - **Verbose Header**: Every new file must start with the standard Markdown header block (Purpose, Inputs, Outputs, Neighbors, Logic).
    - Follow the **Quad Gate** (Test, Logic, Lint, Efficiency).

## 🧪 The Quad Gate (Quality Control)

Every task must pass these four gates before completion:

1.  **Test**: `vitest` or `Playwright` passes. New logic must have a corresponding test file.
2.  **Logic**: TypeScript verification (`tsc --noEmit`) passes with 0 errors.
3.  **Linting**: Style check (`npx expo lint`) passes with 0 warnings.
4.  **Efficiency**: Performance check (Edge functions < 400ms) and complexity check.

## 🔒 Hygiene & Safety

- **Atomic Commits**: Group logic into clean, descriptive commits.
- **Header Integrity**: Ensure the "Plain English" logic summary in the file header matches the actual code implementation.
- **Destructive Actions**: Always prefix with !! WARNING: DESTRUCTIVE !!.

## 📝 Continuous Learning

Update `AGENTS.md` at the end of every task to capture new "gotchas," updated file locations, or architectural decisions to ensure the next session starts with full context.