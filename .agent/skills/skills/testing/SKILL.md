# Testing & Verification Skill

This skill defines the rigorous testing standards required for the **Quad Gate** verification process.

## 🧪 The Quad Gate

This project adheres to the **Quad Gate** verification standard. 
> [!IMPORTANT]
> For the definitive list of gates and thresholds, see the **[RALPH Skill](file:///home/nick/projects/ExamPulse/.agent/skills/ralph/SKILL.md)**.

1.  **Test (Unit & E2E)**: `npm run test` (Vitest) or `npx playwright test`
2.  **Logic (Type Safety)**: `tsc --noEmit` (Must have 0 errors)
3.  **Linting (Style)**: `npx expo lint` (Must have 0 warnings)
4.  **Efficiency**: Performance (Edge functions < 400ms) and Complexity check.

## 1. Unit & Integration Tests (Vitest)

Used for testing business logic, utility functions, and component rendering in isolation.

- **Run All**: `npm run test`
- **Run File**: `npx vitest run path/to/file`
- **Watch Mode**: `npx vitest`

### Best Practices
- Mock external dependencies (Supabase, API calls).
- Test edge cases (null, undefined, empty arrays).

## 2. End-to-End Tests (Playwright)

Used for verifying critical user flows in a real browser environment.

- **Run All**: `npx playwright test`
- **UI Mode**: `npx playwright test --ui` (Great for debugging)
- **Headed**: `npx playwright test --headed`

### Setup (First Time Only)
If Playwright is missing browsers:
```bash
npx playwright install
```

## 3. Troubleshooting
- **Tests hanging?** Check for unawaited async calls or open database connections.
- **"Invalid JWT" in tests?** Ensure `.env.test` is configured or mocks are correctly applied.
