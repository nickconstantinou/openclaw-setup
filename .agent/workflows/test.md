---
description: Run the full test suite including unit, integration, and browser verification flows.
---

---
description: Robust Test Suite Execution
---

## 🧪 The Quad Gate (Verification)

This project adheres to the **Quad Gate** verification standard.

1.  **Test (Unit & E2E)**: `npm run test` (Vitest) or `npx playwright test`
2.  **Logic (Type Safety)**: `tsc --noEmit` (Must have 0 errors)
3.  **Linting (Style)**: `npx expo lint` (Must have 0 warnings)
4.  **Efficiency**: Performance (Edge functions < 400ms) and Complexity check.

### 1. Unit & Integration Tests (Vitest)
// turbo
```bash
npm run test
```

### 2. End-to-End Tests (Playwright)
// turbo
```bash
npx playwright test
```