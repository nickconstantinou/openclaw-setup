---
name: state-management
description: Rules for Zustand stores, selectors, and persistence.
---

# State Management Skill (Zustand)

This skill enforces unstructured state management best practices to prevent "spaghetti code."

## 1. Store Architecture
- **Atomic Stores**: create separate stores for distinct features.
  - ✅ `useAuthStore`, `useExamStore`, `useSettingsStore`
  - ❌ `useGlobalStore`, `useAppStore`
- **Location**: Place stores in `src/stores/` or `app/(feature)/_stores/` if strictly local.

## 2. Selectors (Performance)
- **Strict Selection**: Never export the whole state hook if you only need one value.
- **Usage**:
  ```typescript
  // BAD causes re-renders on ANY change
  const { user, token } = useAuthStore(); 
  
  // GOOD
  const user = useAuthStore(state => state.user);
  ```

## 3. Actions vs State
- **Encapsulation**: State mutations should happen *inside* the store via Actions, not in components.
- **Async Logic**: handle API calls inside actions, setting `isLoading` states internally.

## 4. Persistence
- **Middleware**: Use `persist` middleware for data that must survive app restarts (Auth tokens, User preferences).
- **Storage Engine**: Use `AsyncStorage` for React Native persistence.
