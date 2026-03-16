# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
- **Fix: Coding Agent Cannot Access External APIs (Supabase)**: Sandboxed agents receive env vars only via `docker.env`, not the top-level `env` section. `SUPABASE_URL` and `SUPABASE_ANON_KEY` were being written to the wrong section in `apply-config.py` and never reached the Docker container. Fixed by adding Supabase vars to `_sandbox_env` (same pattern as Tavily). Live config re-applied.
- **Google Workspace CLI Integration**: Switched `gws` to use a file-based keyring backend (`GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file`) to support reliable execution in headless (systemd) and sandboxed (Docker) environments without requiring an OS keyring.
    - Added read-only bind mount for `~/.config/gws/` in `apply-config.py` so sandboxed agents can use credentials.
    - Updated `gws.sh` tool module to export keyring configuration.
- **Security Hardening & Sandboxing**: Implemented a modular sandbox environment registry and hardened agent profiles.
    - Added `TOOL_SANDBOX_ENV` registry to `lib/tools/` for modular API key pass-through to Docker containers.
    - Hardened `family` agent by locking it to the `messaging` tool profile in `apply-config.py`.
    - Implemented automatic bind-mount of `projects/` directory to `/projects` in the sandbox.
    - Updated `08-config.sh` to pass a JSON-serialized environment block to `apply-config.py`.
    - Added `OPENCLAW_SANDBOX_MODE=non-main` default to `01-env.sh`.
- **Security Audit Remediation**: Hardened channel DM policies and trust boundaries.
    - Switched all Telegram/WhatsApp `dmPolicy` from `"open"` to `"allowlist"` with env-driven user ID allowlists.
    - Added `INHERIT` pattern for per-bot Telegram allowlist inheritance.
    - Added `agents.defaults.sandbox.mode='all'` and `tools.fs.workspaceOnly=true` for workspace isolation.
    - Cleaned up dead `trustedProxies` configuration code.
    - Added numeric validation to `parse_allowed_users` to reject malformed entries.
    - Added unit tests for allowlist parsing (9 cases).
- **Modular Deployment Audit Fixes**: Addressed 17 security and operational issues identified in the audit report.
    - Improved AppArmor resilience with conditional unconfined fallback for boot-time races.
    - Implemented automated `SecretRef` migration for agent `auth-profiles.json` to prevent key shadowing.
    - Hardened systemd service units with robust shell escaping for `ExecStart`.
    - Integrated `systemd-inhibit` into `apt_install` to prevent package manager contention.
    - Updated Tailscale health checks and trusted proxy configuration.
    - Resolved Playwright `EACCES` errors by correcting npm cache ownership.
    - Added self-upgrade capabilities for `npm` within the deployment flow.

### Added
- **Tri-Agent Architecture**: Implemented a specialized multi-agent system consisting of `main` (planner), `coding` (executor), and `marketing` (strategist) agents.
- **Isolated Workspace Scaffolding**: Created dedicated `AGENTS.md`, `MEMORY.md`, and `TOOLS.md` for each agent to ensure strict context isolation and security boundaries.
- **Specialized Tool Access**: Implemented hard tool restriction matrices in `apply-config.py` (e.g., blocking `exec` for marketing, blocking `sessions_spawn` for subagents).
- **Environment Template**: Added `.env.example` with comprehensive documentation for all required API keys.

### Changed
- **Deployment Efficiency**: Updated `lib/03-skills.sh` to use recursive folder deployment, simplifying logic and increasing flexibility.
- **Hardening**: Applied ShellCheck fixes to all bash modules to prevent variable masking and logic errors.
- **Marketing Skill**: Consolidated 18 sub-skills into a unified `skills/marketing/SKILL.md` overview.
- **Config Hardening**: Updated `patch-stale-keys.py` and `apply-config.py` to inject `SecretRef` objects directly, preventing plaintext regressions in subsequent deployments.
- **Environment Resilience**: Added a fallback in `lib/01-env.sh` to load secrets from `~/.config/environment.d/openclaw.conf` for scrubbed `.env` files.
- **Subagent Best Practices**: Updated `apply-config.py` with recommended defaults for `maxSpawnDepth` (2), `maxChildrenPerAgent` (5), and `runTimeoutSeconds` (900) to support the orchestrator pattern.
- **Orchestration Persona**: Harmonized `orchestration` skill documentation to correctly identify `MiniMax M2.5` as the main planner model and `Chas` as the primary identity.

### Fixed
- **Gateway Installation**: Resolved systemd symlink collisions during re-runs.
- **AppArmor Fallback**: Restored missing fallback logic for non-AppArmor systems in the gateway module.
- **API Key Handling**: Corrected inconsistent environment variable names for GITHUB_TOKEN and GEMINI_API_KEY.
- **Security Hygiene**: Resolved `[PLAINTEXT_FOUND]` audit warnings by moving sensitive keys from `.env` to the secure OpenClaw secret store via SecretRef.
- **Node/NPM Environment Execution**: Added `/bin` and `/sbin` back into the default `$PATH` of `uas`/`oc` wrappers to prevent `ENOENT spawn sh` during subshell hook executions.
- **AppArmor Execution Policies**: Refined the `openclaw-gateway` profile with missing `mrix` permissions, unblocking `playwright` driver spawning, browser binaries, and local pip utilities like `yt-dlp`.
- **Playwright Sandbox**: Added `userns` support to AppArmor profile and fixed venv execution permissions.
- **Skill Deployment**: Updated `lib/03-skills.sh` to use `cp -a`, preserving symlinks for Playwright virtual environments.
- **Core Installation**: Updated `install_playwright` to run as the actual user, ensuring correct browser cache location.
