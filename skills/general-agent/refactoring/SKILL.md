---
name: refactoring
description: Defines the "Monolith First" principle, Proximity Test, and Header protocols for refactoring.
---

# Refactoring Skill

This skill ensures code remains modular, type-safe, and AI-readable while strictly adhering to the "Monolith First" principle and the **AGENTS.md** Golden Rules.

## 1. Discovery 🔍
- **Context Scan**: Identify target file and **Neighbors** via the mandatory header in `coding-logic.md`.
- **Rule Audit**: Identify violations of the **Universal Coding Logic** (e.g., missing headers, "any" types).

## 2. Analysis 🧠
- **The Proximity Test**: Follow the proximity rules defined in `coding-logic.md`.
- **Impact Assessment**: List modules affected by signature changes.

## 3. Execution 🛠️
- **Step A: Header Protocol**: Create/Update the verbose header as per `coding-logic.md`.
- **Step B: Test Scaffolding**: Trigger `@superpowers` for TDD loop.
- **Step C: Implementation**: Maintain strict type safety and zero magic numbers.

## 4. Verification (The Quad Gate) ✅
Every refactor must pass the **Quad Gate** defined in `coding-logic.md` before completion:
1. **Logic**: Type check passes.
2. **Lint**: Zero warnings.
3. **Test**: All unit/E2E tests pass.
4. **Efficiency**: Performance limits met.

## 5. Memory Sync
- Update **AGENTS.md** "Gotchas" if the refactor revealed a new architectural pattern or fixed a persistent bug.
