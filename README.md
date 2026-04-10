# OpenClaw Scripts

Deployment and self-healing scripts for **OpenClaw Enterprise** — an AI agent orchestration platform with specialized coding, marketing, and personal assistant capabilities.

## Model migration guidance
For GPT 5.4 prompt tuning and a practical GPT/Claude routing pattern, see:
- `GPT54_MIGRATION.md`

## Table of Contents

- [Quick Start](#quick-start)
- [Setup](#setup)
- [Architecture Overview](#architecture-overview)
- [Security Configuration](#security-configuration)
- [Post-Installation](#post-installation)
- [Troubleshooting](#troubleshooting)
- [Maintenance & Updates](#maintenance--updates)
- [Security Best Practices](#security-best-practices)
- [Repository Structure](#repository-structure)
- [Development](#development)

## Quick Start

Deploy OpenClaw on a fresh **Ubuntu 24.04 LTS** server with a single command:

```bash
curl -fsSL --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/nickconstantinou/openclaw-setup/main/install.sh | bash
```

> [!NOTE]
> This script is **idempotent** — safe to re-run for updates or repairs.

**What gets installed:**
- ✅ OpenClaw gateway (multi-agent orchestrator)
- ✅ Ollama (local embeddings for memory search)
- ✅ Playwright (browser automation)
- ✅ Python packages (yt-dlp, pandoc, etc.)
- ✅ Google Workspace CLI (optional)
- ✅ UFW firewall (default-deny, Tailscale-aware)
- ✅ fail2ban intrusion prevention (SSH brute-force protection)
- ✅ AppArmor security profiles
- ✅ Systemd service units

### Setup

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/nickconstantinou/openclaw-setup.git ~/.openclaw-scripts
    cd ~/.openclaw-scripts
    ```

2.  **Configure environment**:
    ```bash
    cp .env.example ~/.openclaw/.env
    chmod 600 ~/.openclaw/.env
    nano ~/.openclaw/.env  # Fill in your keys
    ```
    > [!NOTE]
    > On first run, `openclaw-self-heal.sh` automatically migrates sensitive API keys from `.env` to OpenClaw's secure SecretRef system. Your `.env` will be scrubbed of plaintext keys, and values will be moved to `~/.config/environment.d/openclaw.conf` to maintain systemd environment compatibility.

    > [!IMPORTANT]
    > **Security**: Configure access control for Telegram and WhatsApp bots. See [Security Configuration](#security-configuration) below.

3.  **Run the deployment**:
    ```bash
    sudo bash openclaw-self-heal.sh
    ```

## Architecture Overview

OpenClaw uses a compact **main + family + external harness** architecture:

```
┌─────────────────────────────────────────────────────────┐
│  MAIN AGENT (Orchestrator)                             │
│  • Plans and coordinates tasks                         │
│  • Full tool access                                     │
│  • Spawns specialized subagents                         │
└─────────────────────────────────────────────────────────┘
                         │
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
   ┌───────────┐         ┌───────────┐
   │  CODEX    │         │  FAMILY   │
   │   ACP     │         │  AGENT    │
   │  HARNESS  │         │           │
   │ (external)│         │ messaging │
   │           │         │ profile   │
   └───────────┘         └───────────┘
```

### Agent Capabilities

| Agent | Primary Model | Tools | Use Cases |
|-------|--------------|-------|-----------|
| **main** | GPT-5.4 with MiniMax fallback | Full profile, can spawn Codex ACP | Task planning, orchestration, general queries |
| **codex** | Codex ACP runtime | External ACP harness via `acpx` | Coding runs bound through OpenClaw ACP |
| **family** | MiniMax M2.5 | Messaging profile (locked) | Personal assistant via WhatsApp (no exec/bash) |

### Communication Channels

- **Telegram**: One OpenClaw bot
- **WhatsApp**: One account (family agent)
- **Gateway API**: HTTP API for programmatic access

## Security Configuration

OpenClaw uses **per-channel access control** to protect your agents from unauthorized access.

### 🛡️ Access Control Model

| Channel | Routed Agent | Risk Level | Recommended Access |
|---------|--------------|------------|-------------------|
| **Telegram** (`default`) | **main** | Medium | Personal use only |
| **WhatsApp** (`family`) | **family** | **SECURE** | Family members |

Codex ACP is not exposed as a separate public bot. It is invoked by the main
agent through the ACP runtime.

### 🛡️ Sandboxing & Isolation

OpenClaw enforces a **Docker-first security posture** to protect your host system.

#### Sandbox Modes
Configure via `OPENCLAW_SANDBOX_MODE` in `~/.openclaw/.env`:
- `off` (Default in this setup repo): Leave the main install on the host. This repo still keeps the `family` agent sandboxed separately when Docker is available.
- `non-main`: Sandbox non-main sessions while leaving the main session on the host.
- `all`: All agents, including `main`, run in Docker.

This keeps the current dedicated-laptop workflow fast by default, while preserving a one-variable path back to broader sandboxing later.

### ACP Sessions via ACPX

This setup routes Codex through OpenClaw's ACP runtime instead of relying on a local wrapper script.

- The deploy keeps the bundled `acpx` backend enabled for ACP
- ACP is enabled by default with backend `acpx`
- Default harness allowlist is `codex`
- ACPX permissions default to `approve-all` so non-interactive write/exec turns do not fail with `AcpRuntimeError`
- Codex ACP is treated as **OAuth-only** in this repo. The setup installs the CLI, reuses `~/.codex/auth.json` when it contains Codex web login state, and strips API-key auth from the gateway/Codex harness path.
- If Codex CLI OAuth is not configured yet, run `codex login` as the OpenClaw user before expecting ACP Codex runs to succeed.

Configure via `~/.openclaw/.env`:

```bash
OPENCLAW_ACP_ENABLED=true
OPENCLAW_ACP_DEFAULT_AGENT=codex
OPENCLAW_ACP_ALLOWED_AGENTS=codex
OPENCLAW_ACPX_PERMISSION_MODE=approve-all
OPENCLAW_ACPX_NONINTERACTIVE_PERMISSIONS=fail
OPENCLAW_ACPX_PLUGIN_TOOLS_MCP_BRIDGE=false
```

After deploy, verify ACP health with:

```bash
openclaw acp doctor
```

#### Features
- **Network Isolation**: Uses `bridge` networking to allow agents to reach APIs (Anthropic, Google, etc.) while isolating them from the host's private network services.
- **Shared Workspace**: `~/.openclaw/workspace` is the shared project root used by the main agent and Codex ACP sessions.
- **UID/GID Matching**: The sandbox image is built with the host user's UID/GID so bind-mounted files are readable and writable without permission errors. Rebuild the image after changing the host user.
- **gws Credential Mount**: `~/.config/gws/` is mounted read/write so OpenClaw-managed sessions can read OAuth tokens and write the API discovery cache.
- **Modular Env Pass-through**: Tools specify which API keys they need in the sandbox via the `TOOL_SANDBOX_ENV` registry.

#### Adding Tools to the Sandbox
When adding a new tool in `lib/tools/`, declare which environment variables should be passed into the Docker container:

```bash
# In lib/tools/mytool.sh
TOOL_SANDBOX_ENV[mytool]="MYTOOL_API_KEY MYTOOL_OTHER_VAR"
```
The setup script automatically collects these and passes them to the container's `docker.env`.

### 🛡️ Exec Approvals (Host Security)

OpenClaw includes an execution approval system in `~/.openclaw/exec-approvals.json`. This acts as a final gate for commands running on your host machine.

#### How it applies to Agents
The system uses a **Defaults + Overrides** hierarchy:

- **Inheritance**: Any setting in the `defaults` block (like `ask: "off"`) applies to **every agent** unless specifically overridden.
- **Per-Agent Overrides**: You can define custom security levels or allowlists for specific agents by adding their ID (e.g., `main`) to the `agents` block.
- **Allowlists**: These are always per-agent. For example, if you allow `git` for the `main` agent, the `family` agent will still use its own restricted profile.

#### Common Postures
- **`security: "full"` + `ask: "off"` (Current Default)**: Recommended for single-user trusted environments. This allows all commands to run without manual approval, providing a seamless "unconstrained" experience.
- **`security: "allowlist"` + `ask: "on-miss"`**: Recommended for higher security. Only commands in the allowlist run automatically; everything else requires manual approval via the Control UI or a linked channel.

To change this, edit `~/.openclaw/exec-approvals.json` or use `openclaw approvals set-default --ask on-miss`.

### Configuration Examples

#### Example 1: Personal Use (Most Secure)

```bash
# In ~/.openclaw/.env
TELEGRAM_ALLOWED_USERS=123456789
```

✅ The OpenClaw Telegram bot is restricted to your Telegram ID only

#### Example 2: Team Access with Role Separation

```bash
# Default bot: You + two team members
TELEGRAM_ALLOWED_USERS=123456789,987654321,555111222
```

✅ Shared access on the OpenClaw Telegram bot

#### Example 3: Smart Default (Auto-allowlist)

```bash
# Leave as REPLACE_ME to auto-populate with TELEGRAM_CHAT_ID
TELEGRAM_ALLOWED_USERS=REPLACE_ME
```

✅ Auto-populated with your `TELEGRAM_CHAT_ID` — you get instant access
✅ Other users still blocked (no pairing needed since you're pre-authorized)
✅ Group messages always disabled for security

### Getting Your IDs

- **Telegram**: Search for `@userinfobot` in Telegram and start a chat
- **WhatsApp**: Use international format without `+` (e.g., `+1-415-555-2671` becomes `14155552671`)

### Verify Security

After deployment, run:

```bash
openclaw security audit
```

Expected output:
```
Summary: 0 critical · 0 warn · 1 info
  ✅ All channels using secure access control
  ✅ Pairing/allowlist mode enabled
```

## Post-Installation

### Verify Installation

After deployment completes, verify everything is running:

```bash
# Check gateway status
openclaw status

# View recent logs
tail -n 50 /var/log/openclaw-deploy.log

# Run health checks
openclaw doctor

# Security audit
openclaw security audit
```

### Connect to Your Bots

1. **Telegram**:
   - Search for your bot using the bot token you configured
   - Send `/start` or a test message
   - If you used the smart default (REPLACE_ME), you'll have instant access via TELEGRAM_CHAT_ID fallback

2. **WhatsApp**:
   - Run: `openclaw channels whatsapp link family`
   - Scan the QR code with WhatsApp mobile app
   - Send a test message

4. **Gateway API**:
   ```bash
   # Test gateway endpoint (replace TOKEN with your OPENCLAW_GATEWAY_TOKEN)
   curl -H "Authorization: Bearer TOKEN" http://localhost:3002/api/agents
   ```

### Configure Google Workspace CLI (gws)

If you plan to let agents manage your Calendar, Gmail, Drive, Docs, or Sheets, you must authenticate `gws`:

1. Obtain OAuth 2.0 credentials from Google Cloud Console (APIs & Services → Credentials → Create OAuth client ID).
2. Add your keys to `~/.openclaw/.env`:
   ```bash
   GOOGLE_WORKSPACE_CLI_CLIENT_ID=<your-client-id>
   GOOGLE_WORKSPACE_CLI_CLIENT_SECRET=<your-client-secret>
   ```
3. Run the automated deployment script to apply the changes (it will auto-add the file-based keyring backend variable for sandbox compatibility):
   ```bash
   sudo bash ~/.openclaw-scripts/openclaw-self-heal.sh
   ```
   This also repairs both `/usr/bin/gws` and `/usr/local/bin/gws` so they point at the native `gws` binary instead of npm's `run.js` shim.
4. Authenticate `gws` to generate `credentials.enc` and your `.encryption_key`:
   ```bash
   gws auth login
   ```

### Access Agent Workspaces

The deployment keeps one shared project workspace plus per-agent state for the
named OpenClaw agents:

```bash
# Shared workspace
~/.openclaw/workspace/

# Named agent directories
~/.openclaw/agents/main/
~/.openclaw/agents/family/

# Each named agent directory contains:
# - workspace/     # Agent's working directory
# - agent/         # Agent configuration (AGENTS.md, MEMORY.md, TOOLS.md)
# - memory.db      # Conversation history and memory index
```

Codex ACP sessions reuse `~/.openclaw/workspace` rather than a separate named
agent directory.

## Troubleshooting

### Common Issues

#### Gateway Won't Start

```bash
# Check if port 3002 is already in use
sudo lsof -i :3002

# View detailed logs
journalctl --user -u openclaw-gateway -n 100 --no-pager

# Restart gateway
openclaw gateway restart
```

#### "Missing API Key" Error

```bash
# Verify all required keys are set
grep -v '^#' ~/.openclaw/.env | grep '='

# Check environment.d file
cat ~/.config/environment.d/openclaw.conf

# Re-run deployment to fix
sudo bash ~/.openclaw-scripts/openclaw-self-heal.sh
```

#### Telegram Bot Not Responding

1. Verify bot token is correct in `~/.openclaw/.env`
2. Check your Telegram ID is in the allowlist
3. Restart gateway: `openclaw gateway restart`
4. Check logs: `tail -f /var/log/openclaw-deploy.log`

#### WhatsApp QR Code Won't Scan

```bash
# Unlink and re-link
openclaw channels whatsapp unlink family
openclaw channels whatsapp link family

# If that fails, check Playwright installation
~/.openclaw/venv/bin/playwright install
```

#### "spawn docker EACCES" Error (Sandbox)

If your agents fail with a "spawn docker EACCES" error, the sandbox is missing or misconfigured.

1. Ensure sandbox mode is configured in `~/.openclaw/.env`:
   ```bash
   OPENCLAW_SANDBOX_MODE="all" # Enable
   # or
   OPENCLAW_SANDBOX_MODE="off" # Disable default sandboxing
   ```
2. Re-run deployment to automatically build the `openclaw-sandbox:bookworm-slim` image and add your user to the `docker` group:
   ```bash
   sudo bash ~/.openclaw-scripts/openclaw-self-heal.sh
   ```
3. If the user was just added to the `docker` group, you may need to **log out and log back in** for permissions to apply.

#### gws "Permission Denied" or "discoveryError" in Sandbox

gws writes an API discovery cache and reads OAuth tokens on startup. If it errors with permission denied inside the sandbox:

1. **UID/GID mismatch**: The sandbox image must be built with your host UID/GID. Rebuild it:
   ```bash
   sudo bash ~/.openclaw-scripts/scripts/sandbox-setup.sh
   ```
2. **Stale image**: Older images used an npm JS shim that was blocked by Docker's seccomp profile. The current setup installs gws as a native binary. Rebuild to pick up this fix (same command above).
3. **Mount permissions**: gws needs `~/.config/gws/` mounted read/write for token and discovery cache. This is configured automatically by `config/apply-config.py` — re-run the self-heal to regenerate config.
4. **Broken host entrypoint**: If you see `bad interpreter` from `/usr/bin/gws`, re-run the self-heal. It now repairs both `/usr/bin/gws` and `/usr/local/bin/gws` to the native binary and the health check will warn when either path still resolves to `run.js`.

#### Codex ACP Auth Missing

If Codex ACP sessions fail because host auth is missing, sign in as the OpenClaw
user and rerun the self-heal so the adapter can be prewarmed cleanly:
```bash
codex login
sudo bash ~/.openclaw-scripts/openclaw-self-heal.sh
```

#### Permission Denied Errors

```bash
# Fix ownership of OpenClaw directories
sudo chown -R $USER:$USER ~/.openclaw
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/.env

# Restart gateway
openclaw gateway restart
```

#### High Memory Usage

OpenClaw runs local Ollama for embeddings. If memory is constrained:

```bash
# Check Ollama status
systemctl --user status ollama

# Reduce concurrent subagents in ~/.openclaw/openclaw.json:
# "agents.defaults.subagents.maxConcurrent": 2  # Instead of 4
```

### Debug Mode

Enable verbose logging:

```bash
# Add to ~/.openclaw/.env
OPENCLAW_LOG_LEVEL=debug

# Restart gateway
openclaw gateway restart

# Watch logs in real-time
tail -f /var/log/openclaw-deploy.log
```

### Getting Help

If you encounter issues:

1. Run diagnostics: `openclaw doctor --deep`
2. Check security audit: `openclaw security audit --deep`
3. Review logs: `/var/log/openclaw-deploy.log`
4. Check GitHub issues: [openclaw-setup/issues](https://github.com/nickconstantinou/openclaw-setup/issues)

## Maintenance & Updates

### Updating OpenClaw

```bash
# Pull latest scripts
cd ~/.openclaw-scripts
git pull

# Re-run deployment (safe, idempotent)
sudo bash openclaw-self-heal.sh
```

### Updating Skills

Skills are deployed from `~/.openclaw-scripts/skills/`:

```bash
# After modifying skills
cd ~/.openclaw-scripts
sudo bash openclaw-self-heal.sh  # Re-deploys all skills
```

### Backup & Restore

#### Backup

```bash
# Backup configuration and memory
tar -czf openclaw-backup-$(date +%Y%m%d).tar.gz \
  ~/.openclaw/.env \
  ~/.openclaw/openclaw.json \
  ~/.openclaw/agents/*/memory.db

# Store backup securely off-server
```

#### Restore

```bash
# Extract backup
tar -xzf openclaw-backup-YYYYMMDD.tar.gz -C ~/

# Re-run deployment to restore services
sudo bash ~/.openclaw-scripts/openclaw-self-heal.sh
```

### Monitoring

#### Check Resource Usage

```bash
# Memory and CPU
htop

# Disk space
df -h ~/.openclaw

# Gateway process
ps aux | grep openclaw-gateway
```

#### View Active Conversations

```bash
# List recent sessions
openclaw sessions list

# View specific session
openclaw sessions view SESSION_ID
```

## Agent Communication Settings

This setup no longer provisions a Claude-side inbox, memory bridge, or Claude
Telegram plugin. `lib/13-agent-comms.sh` now only keeps the main Telegram
account's optional group allowlist aligned with `TELEGRAM_AGENT_GROUP_ID`.

### What gets set up automatically

| Component | Location | Managed by |
|-----------|----------|-----------|
| Telegram group access | `~/.openclaw/openclaw.json` | `lib/13-agent-comms.sh` |

---

## Repository Structure

- `openclaw-self-heal.sh`: Main deployment orchestrator.
- `lib/`: Modular shell scripts for environment setup, installations, and configuration.
  - `lib/tools/`: **Tool modules** — one file per 3rd-party tool. Each file is the single source of truth for that tool's install logic, AppArmor rules, env var placeholders, and systemd exports.
  - `lib/13-agent-comms.sh`: Final Telegram access adjustments for the main OpenClaw account.
- `skills/`: Shared `general-agent` skills plus `family-agent` skills and supporting scaffolds.
- `templates/`: AppArmor profile templates and systemd units.
- `config/`: Python-based JSON configuration patchers.
- `test/`: Automated test suite (safe to run without sudo or network).

## Requirements

- Ubuntu 24.04 (LTS)
- Root/Sudo access
- 7GB+ RAM, 20GB+ Disk

## Security Best Practices

### 🔐 Critical Security Warnings

1. **⚠️ Keep Telegram Access Narrow**

   The OpenClaw Telegram bot can invoke powerful tools. Keep its allowlist tight:
   ```bash
   # ✅ GOOD: Only you can access the bot
   TELEGRAM_ALLOWED_USERS=123456789

   # ❌ BAD: Broad shared access to the bot
   TELEGRAM_ALLOWED_USERS=123456789,987654321
   ```

2. **🔒 Smart Default for Solo Users**

   The default config auto-allowlists you using `TELEGRAM_CHAT_ID`:
   ```bash
   TELEGRAM_ALLOWED_USERS=REPLACE_ME  # Auto-populated with TELEGRAM_CHAT_ID
   ```
   ✅ You get instant access, other users blocked
   ✅ No pairing needed — you're pre-authorized

   **For WhatsApp pairing mode** (no auto-allowlist):
   ```bash
   WHATSAPP_ALLOWED_USERS=REPLACE_ME  # Requires openclaw pairing approve
   ```

3. **🔄 Rotate Gateway Token Regularly**
   ```bash
   # Generate new token
   openssl rand -hex 32

   # Update in ~/.openclaw/.env
   OPENCLAW_GATEWAY_TOKEN=<new_token>

   # Re-deploy
   sudo bash ~/.openclaw-scripts/openclaw-self-heal.sh
   ```

4. **📊 Monitor API Usage**
   - Check MiniMax/Gemini API dashboards for unusual consumption
   - Review OpenClaw logs: `tail -f /var/log/openclaw-deploy.log`
   - Run security audits regularly: `openclaw security audit`

5. **🔥 Firewall & Intrusion Prevention (UFW + fail2ban)**

   The setup script configures UFW and fail2ban automatically:

   - **UFW**: default deny inbound, Tailscale tunnel allowed, port 22 not exposed
   - **fail2ban**: sshd jail active — bans IPs after 3 failed SSH attempts for 24 hours

   Verify after deployment:
   ```bash
   sudo ufw status verbose          # Should show: Status: active, tailscale0 ALLOW IN
   sudo fail2ban-client status sshd # Should show active jail with 0 currently banned
   ```

   > [!IMPORTANT]
   > SSH access is exclusively via Tailscale (`tailscale up --ssh`). Direct port 22 connections are blocked by design. Ensure Tailscale is authenticated before enabling the firewall.

6. **🔑 Protect Your .env File**
   ```bash
   # Verify permissions
   ls -la ~/.openclaw/.env
   # Should show: -rw------- (600)

   # Fix if needed
   chmod 600 ~/.openclaw/.env
   ```

### Multi-User Security

For deployments with multiple untrusted users, consider:

1. **Separate Gateway Instances**
   - Run different gateway instances for different trust boundaries
   - Use separate OS users/hosts for isolation

2. **Enable Sandbox Mode**
   ```bash
   # Add to ~/.openclaw/.env
   OPENCLAW_SANDBOX_MODE=all
   ```

3. **Restrict Tool Access**
   - Use `tools.deny` to block dangerous operations
   - Set `tools.fs.workspaceOnly=true`
   - Deny runtime/fs/web tools unless required

## Development

This repository follows the **Antigravity Workflow** pattern:
- **Atomic Modularity**: Scripts are decomposed into single-responsibility modules in `lib/`.
- **Idempotency**: All scripts are safe to run multiple times.
- **Strict Error Handling**: Bash scripts use `set -Eeuo pipefail`.

### Adding a New Tool

Each 3rd-party tool is fully self-contained in `lib/tools/<toolname>.sh`. To add one:

**1. Create `lib/tools/mytool.sh`:**

```bash
# AppArmor rules injected into the gateway profile
TOOL_APPARMOR_RULES[mytool]=$(cat <<'RULES'
  /usr/local/bin/mytool               rix,
  @{HOME}/.config/mytool/             rw,
  @{HOME}/.config/mytool/**           rw,
RULES
)

# Placeholder keys added to ~/.openclaw/.env on first run
TOOL_ENV_PLACEHOLDERS[mytool]="MYTOOL_API_KEY=REPLACE_ME"

# Vars written to ~/.config/environment.d/openclaw.conf (systemd inherits these)
TOOL_SYSTEMD_EXPORTS[mytool]="MYTOOL_API_KEY"

# Vars exported into the Docker sandbox environment (space-separated NAMES)
# These are collected by 08-config.sh and passed to sandbox.docker.env
TOOL_SANDBOX_ENV[mytool]="MYTOOL_API_KEY"

install_mytool() {
    log "Installing mytool..."
    npm install -g mytool --quiet || log "WARNING: mytool install failed."
}

register_tool mytool
```

**2. Add one line to `config/apply-config.py`:**

```python
TOOL_REGISTRY = {
    ...
    'mytool': ['main'],   # agents that can use this tool
}
```

That's the complete contract. No other files need editing.

### Running Tests

```bash
bash test/test-tool-registry.sh
```

The test suite runs with no sudo, no network, and no system changes. It covers
tool registration, AppArmor marker injection, `apply-config.py` TOOL_REGISTRY
output, and a full dummy-tool end-to-end proof.
