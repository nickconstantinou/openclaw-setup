---
name: refactoring
description: Defines the "Monolith First" principle, Proximity Test, and Header protocols for refactoring.
---

# Refactoring Skill

This skill ensures code remains modular, type-safe, and AI-readable while strictly adhering to the "Monolith First" principle and the **AGENTS.md** Golden Rules.

## 1. Discovery 🔍
- **Context Scan**: Identify the target file and its **Neighbors** (per the existing file header). 
- **Rule Audit**: Identify violations of the **Golden Rules** (e.g., missing headers, "any" types, or hardcoded DB logic).
- **Dependency Check**: Ensure no "Ghost Dependencies" are required for the proposed refactor.

## 2. Analysis 🧠
- **The Proximity Test**: Determine if the logic should remain local or move to `src/lib/`. 
  - *Constraint*: Do not extract into a new service. Keep logic within the monorepo.
- **Categorization**: Label the refactor: 🛠️ [Cleanup], 🔒 [Security/Auth], or ⚡ [Performance].
- **Impact Assessment**: List which components or Edge Functions will be affected by signature changes.

## 3. Execution 🛠️
- **Step A: Header Protocol**: Update or create the **Verbose Header**. Summarize the "New Logic" in plain English before writing code.
- **Step B: Test Scaffolding**: Create or update the `*.test.ts` file. Define the expected behavior for the refactored code.
- **Step C: Implementation**:
    - Maintain strict Type Safety (no `any`).
    - Move hardcoded SQL to `supabase/migrations` if found.
    - Ensure cross-platform safety (Web vs. Native) for UI components.

## 4. Verification (The Quad Gate) ✅
Every refactor must pass the Quad Gate before the task is marked "Done":

1. **Test**: Run `vitest` or `Playwright`. **Verify the test passes for the new implementation.**
2. **Logic**: Run `tsc --noEmit`. Fix all type regressions.
3. **Lint**: Run `npx expo lint`. Ensure zero style warnings.
4. **Efficiency**: Performance check (Edge functions < 400ms) and complexity check.

## 5. Memory Sync
- Update **AGENTS.md** "Gotchas" if the refactor revealed a new architectural pattern or fixed a persistent bug.
