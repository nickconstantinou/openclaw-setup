# AGENTS.md

This file serves as the persistent memory for autonomous agents working on **Antigravity Workflows**.
It captures high-level context, architectural patterns, "gotchas," and lessons learned to ensure continuity between sessions.

## 🌟 The Golden Rules (Operational Constraints)

1.  **Workflows-Only**: This repository is a library of workflows. Do not add component or application logic here.
2.  **Mirror Structure**: The repository layout MUST mirror a target project's `.agent/workflows` directory.
3.  **Self-Contained**: Each workflow should contain its own procedural knowledge.

## 🏗️ Architecture Patterns
- **Modular Bash**: Large scripts MUST be decomposed into `lib/XX-name.sh` modules and sourced by a thin orchestrator.
- **Skill Folders**: Skills MUST follow the folder-per-skill pattern with a `SKILL.md` (YAML frontmatter + Markdown).
- **Hardening**: All shell scripts MUST pass ShellCheck analysis.
- **Tri-Agent Architecture**: High-complexity tasks SHOULD be decomposed into `main` (planner), `coding` (executor), and `marketing` (strategist) agents with strictly scoped workspaces (`AGENTS.md`, `MEMORY.md`, `TOOLS.md`).
- **SecretRef Migration**: Non-interactive secrets migration MUST use ephemeral JSON plans (`migrate_secrets.py`) and a `systemd environment.d` fallback for scrubbed `.env` resilience.
- **Technology Layer**: Workflows assume a Supabase (Backend) + Expo (Frontend) stack unless otherwise specified.

## 🔄 Available Workflows
- **[/create-issue](file://./.agent/workflows/create-issue.md)**: Architecture Discovery.
- **[/create-plan](file://./.agent/workflows/create-plan.md)**: Unified Research & Implementation Planning.
- **[/execute](file://./.agent/workflows/execute.md)**: Deterministic Code Generation.
- **[/refactor](file://./.agent/workflows/refactor.md)**: Migrate code to Atomic Blueprint.
- **[/peer-review](file://./.agent/workflows/peer-review.md)**: Senior Architect audit.
- **[/synthesis](file://./.agent/workflows/synthesis.md)**: Synthesis of multiple reviews & bug-fixes.
- **[/test](file://./.agent/workflows/test.md)**: Quad Gate verification.
- **[/close-issue](file://./.agent/workflows/close-issue.md)**: Memory consolidation & hygiene.
- **[/cto](file://./.agent/workflows/cto.md)**: Technical Brainstorming & Plan Critique.
- **[/learning-opportunity](file://./.agent/workflows/learning-opportunity.md)**: Deep Dive into technical topics & architectural "why".

## 🛡️ Security & Risks
- **Security**: Never include secrets in workflow files.
- **Persistence**: Multi-stage (Epoch) workflows MUST use artifacts in `~/.gemini/antigravity/brain/` for state management across sessions.

## 🎓 Self-Learning & Pattern Recognition
- `[BASH_VAR_MASK]` -> **Pattern**: `local x=$(cmd)` masks `cmd`'s exit code. | **Fix**: Declare and assign separately: `local x; x=$(cmd)`.
- `[STRUCTURAL_DRIFT]` -> **Pattern**: Moving files into subfolders breaks hardcoded paths in `tests/verify-repo.sh`. | **Fix**: Update testing assets *concurrently* with structural refactors.
- `[GLOB_RECURSION]` -> **Pattern**: Deployment loops using `dir/*` fail when content is moved to sub-subfolders. | **Fix**: Use `find` or recursive globs in deployment logic.
- `[HYPHENATED_PYTHON_MODULE]` -> **Pattern**: Naming scripts with hyphens (e.g., `migrate-secrets.py`) prevents Python imports in tests. | **Fix**: Use underscores for Python scripts intended for unit testing.
- `[VARIABLE_PRUNING_ORPHAN]` -> **Pattern**: Refactoring complex config blocks can orphan dependent variables (e.g., `skill_key`). | **Fix**: Audit all f-string references in a block after removing any assignment lines.
- `[SUBAGENT_PERSONA_TRAP]` -> **Pattern**: Subagents in OpenClaw skip `SOUL.md`. | **Fix**: Persona and identity rules MUST be merged directly into `AGENTS.md` for any agent intended for `sessions_spawn`.
- `[APPARMOR_USERNS]` -> **Pattern**: Chromium (Playwright) requires unprivileged user namespaces. | **Fix**: Add `userns,` to AppArmor profile and use `rix` for venv python binaries.
- `[GIT_SYMLINK_PATHSPEC]` -> **Pattern**: `git add` fails on paths traversing symlinks to external repositories. | **Fix**: Archive issue records in a local `archive/` directory within the current repo.
- `[PLAYWRIGHT_SUDO_TRAP]` -> **Pattern**: `npx playwright install-deps` as user hangs for sudo. | **Fix**: Run `install-deps` as root with specified cache/PATH first.
- `[EACCES_TEMP_OWNER]` -> **Pattern**: `mktemp -d` under `sudo` creates root-owned dirs, blocking user-phase `npx`. | **Fix**: `chown $ACTUAL_USER:$ACTUAL_USER` immediately after `mktemp -d`.
- `[APPARMOR_BOOT_RACE]` -> **Pattern**: systemd unit with `aa-exec` crash-loops if profile isn't loaded at boot. | **Fix**: Use conditional `ExecStartPre` and `ExecStart` that falls back to unconfined.
- `[AUTH_PROFILE_SHADOW]` -> **Pattern**: `auth-profiles.json` plaintext `api_key` entries override config-level SecretRefs. | **Fix**: Scrub plaintext from all agent `auth-profiles.json` and convert to env-based SecretRefs.
- `[OPEN_DM_SURFACE]` -> **Pattern**: `dmPolicy="open"` on messaging channels allows any user to interact with agents, including those with exec/bash tools. | **Fix**: Use `dmPolicy="allowlist"` with env-driven user ID lists; fall back to `"pairing"` when unset. Always pair with `sandbox.mode="all"` + `workspaceOnly=true`.
- `[MODULAR_SANDBOX_ENV]` -> **Pattern**: Hardcoding sandbox env vars in common config scripts is brittle. | **Fix**: Use a per-tool `TOOL_SANDBOX_ENV` registry to declare requirements at the source.
- `[AGENT_PROFILE_LOCK]` -> **Pattern**: Trusting agents with `full` profiles on public channels (WhatsApp) is risky. | **Fix**: Permanently lock public agents to specialized profiles (e.g., `messaging`) in `apply-config.py`.
- `[SANDBOX_BIND_ROOT]` -> **Pattern**: OpenClaw sandbox security unconditionally rejects bind mounts originating outside allowed roots. | **Fix**: Use the explicit schema property `agents.defaults.sandbox.docker.dangerouslyAllowExternalBindSources: true` when mounting local project directories.
'' Openclaw Docs
- Read all docs in `docs/` directory.