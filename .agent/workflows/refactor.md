---
description: Workflow: Refactor & Align
---

---
description: "Epoch 2: Refactoring. incremental migration of legacy code to the Atomic Blueprint."
trigger: "/refactor"
---

# 🛠️ Workflow: Refactor & Align (The Fixer)

This workflow applies the **Agentic Laws of Physics** (Strict Types, Result Pattern, Atomic Modularity) to existing/legacy code.

## 🧠 Refactoring Logic (The Modernizer)

### 1. Discovery (The Entropy Scan) 🔍
Identify "Technical Debt" violations:
- **Type Holes**: Usage of `any`, `as unknown`, or loose typing.
- **Impurity**: Functions that rely on global state or have side effects mixed with logic.
- **Exception Leaks**: `throw new Error()` usage (Legacy) vs `return Result.err()` (Target).
- **Proximity Check**: Is this logic re-used? If yes, it belongs in `src/lib/`.

### 2. Analysis (The Atomic Sieve) 🧠
- **Decomposition**: If a file exceeds ~200 lines or 3 responsibilities, split it.
- **Contract Definition**: Define Zod Schemas or Interfaces for all boundary logic.

### 3. Execution (The Migration) 🛠️
- **The Contract**: Define the **Truth** before writing logic.
- **The Pattern Shift**: Replace `try/catch` with the **Result Pattern**.
- **The Header Protocol**: Update the file header with `@intent` and `@complexity`.

### 4. Verification (The Quad Gate) ✅
1.  **Test**: `vitest`. Does the new atomic unit pass its contract tests?
2.  **Logic**: `tsc --noEmit`. **Zero** type errors allowed.
3.  **Lint**: `eslint`. Code must look uniform.
4.  **Behavior**: Regression Check.

---