# Issue: Sandbox Hardening & Modular Env Pass-through

## 🚩 Problem Statement
The OpenClaw setup was using a permissive security model by default (Sandbox disabled, broad agent profiles). Additionally, passing API keys to sandboxed tools was non-modular and required hardcoding in core configuration scripts.

## 🏁 Resolution
Implemented a layered security model and a modular registry for sandbox environment variables.

### 🏗️ Architecture Optimization
- **Modular Sandbox Env**: Introduced `TOOL_SANDBOX_ENV` array in `lib/tools/*.sh`.
- **Policy Enforcement**: Locked `family` agent to `messaging` profile.
- **Volume Management**: Automatically bind-mounts `/projects` for coding tasks.

---

### 🧪 Verification Evidence

| Test Case | Method | Result |
| :--- | :--- | :--- |
| **Env Injection** | Simulated fresh install via `01-env.sh` | ✅ `OPENCLAW_SANDBOX_MODE` injected |
| **Modular Env Collection** | Source tool modules + `echo "${TOOL_SANDBOX_ENV[@]}"` | ✅ All keys registered |
| **Config Patching** | `python3 apply-config.py --config /tmp/test.json` | ✅ JSON schema matches contract |
| **Schema Validation** | `openclaw doctor` (simulated) | ✅ `docker.env` record format valid |
| **Agent Lockdown** | `jq` check on family agent profile | ✅ Profile set to `messaging` |

---

### 📝 Implementation Walkthrough

I have completed the security hardening of the OpenClaw setup scripts in your workspace. This ensures that all future deployments and "self-heals" will use a hardened, sandboxed configuration by default.

## 🛡️ Major Changes

### 1. Modular Sandbox Env Pattern
Introduced a new `TOOL_SANDBOX_ENV` registry in the tool module system (`lib/tools/`). This allows tools to declare their own sandbox environment requirements without hardcoding them in the core config script.
- **`gws`**: Automatically passes `GOOGLE_WORKSPACE_CLI_CLIENT_ID` and `SECRET`.
- **`claude_code`**: Automatically passes `ANTHROPIC_API_KEY`.
- **Global**: Automatically passes `TAVILY_API_KEY`.

### 2. Sandbox Defaults & Isolation
- **Mode**: Defaulted to `non-main` (sandboxes everything except your primary host-management sessions).
- **Networking**: Enabled `bridge` networking for sandbox containers so tools can reach external APIs.
- **Projects Access**: Your local projects directory is now **bind-mounted** to `/projects` inside all sandboxed containers with read-write access.

### 3. Family Agent Lockdown
The `family` agent (intended for WhatsApp use) is now permanently locked to the `messaging` tool profile. This revokes its access to `exec`, `bash`, and the local filesystem, providing a critical layer of safety for public-facing channels.

### 🐛 Regressions & Hotfixes
- **IFS Word Splitting**: Fixed a bug where `openclaw-self-heal.sh` restricted `IFS` to `\n\t`, preventing the sandbox tool loop from splitting variable names. Fixed by localizing `IFS=$' \n\t'` in the loop.
- **Env Syntax**: Fixed a trailing comma injected into `.env` placeholders in `01-env.sh`.
- **Mode-Specific Permission Exclusion**: Fixed a logic error where Docker permissions and AppArmor rules were only applied in `all` mode, blocking the sandbox in the new `non-main` default mode. Fixed by updating conditions to check for `!= "off"`.
