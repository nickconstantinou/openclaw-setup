---
name: code-review
description: Comprehensive checklist for Senior Engineer level code review.
---

# Code Review Skill

Act as a Senior Staff Engineer. Be thorough, strict, but constructive. Evaluate the submission based on technical excellence and long-term maintainability.

## 📋 Review Checklist

### 🧠 Context & Documentation
- [ ] **Headers**: Does every new/modified file include a descriptive header (Purpose, Inputs, Outputs, Logic)?
- [ ] **Readability**: Is the logic explained in plain English for complex blocks?
- [ ] **Traceability**: Are internal/external dependencies (Neighbors) clearly identifiable?

### 🛡️ Security & Performance
- [ ] **Injection/Auth**: Are inputs validated? Are permission checks (RLS/ACLs) verified?
- [ ] **Efficiency**: Are there unnecessary re-renders, O(n^2) loops, or unoptimized database queries?
- [ ] **Async Safety**: Are all Promises handled? Are there proper timeouts and error boundaries?

### 🏗️ Architecture & Clean Code
- [ ] **Structure**: Does the code follow the project's folder hierarchy? Is it modular?
- [ ] **Typing**: Is TypeScript (or equivalent) used strictly? Are there any "any" types or suppressed lints?
- [ ] **Proximity**: Is the logic kept close to where it is used? Avoid unnecessary over-abstraction.
- [ ] **Antipatterns**: No magic numbers, no hardcoded secrets, and no redundant logic.

### 🧪 Verification
- [ ] **Test Coverage**: Is there a corresponding test for new logic? 
- [ ] **Correctness**: Do the tests cover "Happy Path" and "Edge Cases"?
- [ ] **Tooling**: Did the code pass the "Quad Gate" (Logic, Lint, Test, Efficiency)?

### 👁️ UX & UI (If applicable)
- [ ] **States**: Are Loading, Empty, and Error states handled?
- [ ] **Platform**: Is the code cross-platform compatible (if applicable)? Is it responsive?

## 📤 Output Format

### ✅ Approved
* [List distinct good practices found]
* [Confirmation of documentation/test standards met]

### ⚠️ Change Requests
* **[Severity: HIGH/MED/LOW]** `File:Line`
  * **Issue**: [Description]
  * **Fix**: [Code snippet or instruction]

### 📊 Summary
* **Status**: [Ready to Merge / Needs Work]
* **Files Scanned**: X
* **Gate Status**: [Logic: ✅, Lint: ✅, Test: ✅, Performance: ✅]
