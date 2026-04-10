---
name: repo-cleanup
version: 1.0.0
description: >
  Safely clean Python repositories using ruff and vulture, removing only clearly
  safe dead code and verifying changes with lint/tests before reporting back.
---

# Repo Cleanup

Use this skill when the user asks to clean up a repository, remove dead code, tidy unused imports/variables, or run a safe lint-driven cleanup.

## Goal

Reduce obvious code noise without breaking behavior.

This skill is intentionally conservative.

## Primary Tools

- `ruff` for fast linting and safe autofix opportunities
- `vulture` for dead-code discovery
- repo tests for verification
- normal file edit tools for any non-autofix cleanup

## Rules

1. Never blindly delete everything `vulture` reports.
2. Treat `vulture` output as suggestions, not truth.
3. Prefer removing:
   - unused imports
   - unused locals
   - duplicate definitions clearly shadowed by later definitions
   - unreachable code after `return` / `raise`
4. Be cautious with:
   - exported functions
   - CLI entry points
   - dynamically imported code
   - framework hooks, decorators, plugin registration, tests using monkeypatch/reflection
5. After edits, rerun lint/tests.
6. If confidence is low, leave the candidate in place and mention it.

## Workflow

### 1. Scan
Run:
- `python3 -m ruff check <repo>`
- `python3 -m vulture <repo>`

If `ruff` or `vulture` are unavailable, install them with:
- `python3 -m pip install --user --break-system-packages ruff vulture`

### 2. Categorize findings
Split findings into:
- **safe now**
- **needs review**
- **leave alone**

### 3. Apply safe cleanup
Use autofix where appropriate, then manual edits for anything structural.

### 4. Verify
At minimum rerun:
- `python3 -m ruff check <repo>`

Then run the relevant repo tests, not just a tiny touched subset.

Rules for test verification:
- Prefer the repo's real CI-equivalent test command when it is clear.
- If there is a GitHub Actions test workflow, inspect it and mirror that command locally when practical.
- If tests fail after cleanup, do not stop at reporting failure. Fix the cleanup-caused issues you can safely fix, then rerun lint/tests.
- Do not claim cleanup is complete until lint passes and the relevant repo tests pass, or you clearly state what remains blocked.

### 5. Report clearly
Summarize:
- what was removed
- what was intentionally left
- whether lint/tests passed
- whether commit/push is still needed
- cleanup stats

Required cleanup stats:
- number of ruff findings before cleanup
- number of ruff findings after cleanup
- number of vulture findings reviewed
- number of items removed
- number of items intentionally left in place
- test command(s) run
- test result summary

## Output style

Keep the final update short and practical:
- cleaned items
- remaining low-confidence items
- verification result
- cleanup stats

## Example commands

```bash
python3 -m ruff check /path/to/repo
python3 -m vulture /path/to/repo
python3 -m ruff check --fix /path/to/repo
pytest -q /path/to/repo/tests
```

## Safety standard

The standard is not “maximum deletion”.
The standard is “safe cleanup with evidence”.
