# OpenClaw Scripts

Deployment and self-healing scripts for **OpenClaw Enterprise** — an AI agent orchestration platform with specialized coding, marketing, and personal assistant capabilities.

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
- ✅ Claude Code integration (optional)
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

OpenClaw uses a **tri-agent architecture** with specialized AI agents working together:

```
┌─────────────────────────────────────────────────────────┐
│  MAIN AGENT (Orchestrator)                             │
│  • Plans and coordinates tasks                         │
│  • Full tool access                                     │
│  • Spawns specialized subagents                         │
└─────────────────────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                ▼                ▼
   ┌─────────┐    ┌──────────┐    ┌───────────┐
   │ CODING  │    │ MARKETING│    │  FAMILY   │
   │  AGENT  │    │  AGENT   │    │  AGENT    │
   │         │    │          │    │           │
   │ bash    │    │ no exec  │    │ messaging │
   │ exec    │    │ content  │    │ profile   │
   │ write   │    │ creation │    │ (secured) │
   └─────────┘    └──────────┘    └───────────┘
```

### Agent Capabilities

| Agent | Primary Model | Tools | Use Cases |
|-------|--------------|-------|-----------|
| **main** | MiniMax M2.5 | Full profile, can spawn subagents | Task planning, orchestration, general queries |
| **coding** | MiniMax M2.5 | bash, exec, write, edit, git | Development, code generation, system tasks |
| **marketing** | MiniMax M2.5 | Content tools (no exec) | Content creation, social media, documentation |
| **family** | MiniMax M2.5 | Messaging profile (locked) | Personal assistant via WhatsApp (no exec/bash) |

### Communication Channels

- **Telegram**: Three separate bots (default, coding, marketing)
- **WhatsApp**: One account (family agent)
- **Gateway API**: HTTP API for programmatic access

## Security Configuration

OpenClaw uses **per-channel access control** to protect your AI agents from unauthorized access. Each Telegram bot and WhatsApp account can have different allowed users.

### 🛡️ Access Control Model

| Bot | Tools | Risk Level | Recommended Access |
|-----|-------|------------|-------------------|
| **default** | Full profile | Medium | Personal use only |
| **coding** | bash, exec, write, edit, process | 🔴 **CRITICAL** | **You only** |
| **marketing** | No exec/bash/process | Low | Marketing team |
| **family** (WhatsApp) | Messaging profile | **SECURE** | Family members |

### 🛡️ Sandboxing & Isolation

OpenClaw enforces a **Docker-first security posture** to protect your host system.

#### Sandbox Modes
Configure via `OPENCLAW_SANDBOX_MODE` in `~/.openclaw/.env`:
- `non-main` (Default): All agents run in Docker **except** the `main` agent. Safe experimentation for specialized agents while keeping the host orchestrator unconstrained.
- `all`: All agents, including `main`, run in Docker.
- `off`: Sandboxing disabled (not recommended).

#### Features
- **Network Isolation**: Uses `bridge` networking to allow agents to reach APIs (Anthropic, Google, etc.) while isolating them from the host's private network services.
- **Projects Mount**: The host directory `~/.openclaw/agents/coding/workspace/projects` is automatically bind-mounted to `/projects` inside the sandbox with Read/Write access. This allows coding/marketing agents to work on local repos safely.
- **Modular Env Pass-through**: Tools specify which API keys they need in the sandbox via the `TOOL_SANDBOX_ENV` registry.

#### Adding Tools to the Sandbox
When adding a new tool in `lib/tools/`, declare which environment variables should be passed into the Docker container:

```bash
# In lib/tools/mytool.sh
TOOL_SANDBOX_ENV[mytool]="MYTOOL_API_KEY MYTOOL_OTHER_VAR"
```
The setup script automatically collects these and passes them to the container's `docker.env`.

### 🛡️ Exec Approvals (Host Security)

OpenClaw includes an execution approval system in `~/.openclaw/exec-approvals.json`. This acts as a final gate for commands running on your host.

- **`security: "full"` + `ask: "off"` (Current Default)**: Recommended for single-user trusted environments. This allows all commands to run without manual approval, providing a seamless "unconstrained" experience.
- **`security: "allowlist"` + `ask: "on-miss"`**: Recommended for higher security. Only commands in the allowlist run automatically; everything else requires manual approval via the Control UI or a linked channel.

To change this, edit `~/.openclaw/exec-approvals.json` or use `openclaw approvals set-default --ask on-miss`.

### Configuration Examples

#### Example 1: Personal Use (Most Secure)

```bash
# In ~/.openclaw/.env
TELEGRAM_ALLOWED_USERS=123456789
TELEGRAM_ALLOWED_USERS_CODING=INHERIT
TELEGRAM_ALLOWED_USERS_MARKETING=INHERIT
```

✅ All three bots restricted to your Telegram ID only

#### Example 2: Team Access with Role Separation

```bash
# Base list: You + two team members
TELEGRAM_ALLOWED_USERS=123456789,987654321,555111222

# Coding bot: Only you (has dangerous bash/exec tools!)
TELEGRAM_ALLOWED_USERS_CODING=123456789

# Marketing bot: Marketing team members only
TELEGRAM_ALLOWED_USERS_MARKETING=987654321,555111222
```

✅ Role-based access:
- Default bot → All 3 users
- Coding bot → Only you (user 123456789)
- Marketing bot → Only users 987654321 and 555111222

#### Example 3: Smart Default (Auto-allowlist)

```bash
# Leave as REPLACE_ME to auto-populate with TELEGRAM_CHAT_ID
TELEGRAM_ALLOWED_USERS=REPLACE_ME
TELEGRAM_ALLOWED_USERS_CODING=INHERIT
TELEGRAM_ALLOWED_USERS_MARKETING=INHERIT
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
   - Search for your bot(s) using the bot tokens you configured
   - Send `/start` or a test message
   - If you used the smart default (REPLACE_ME), you'll have instant access via TELEGRAM_CHAT_ID fallback

2. **WhatsApp**:
   - Run: `openclaw channels whatsapp link family`
   - Scan the QR code with WhatsApp mobile app
   - Send a test message

3. **Gateway API**:
   ```bash
   # Test gateway endpoint (replace TOKEN with your OPENCLAW_GATEWAY_TOKEN)
   curl -H "Authorization: Bearer TOKEN" http://localhost:3002/api/agents
   ```

### Access Agent Workspaces

Each agent has its own workspace and memory:

```bash
# Agent directories
~/.openclaw/agents/main/
~/.openclaw/agents/coding/
~/.openclaw/agents/marketing/
~/.openclaw/agents/family/

# Each contains:
# - workspace/     # Agent's working directory
# - agent/         # Agent configuration (AGENTS.md, MEMORY.md, TOOLS.md)
# - memory.db      # Conversation history and memory index
```

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
   OPENCLAW_SANDBOX_MODE="untrusted" # Disable
   ```
2. Re-run deployment to automatically build the `openclaw-sandbox:bookworm-slim` image and add your user to the `docker` group:
   ```bash
   sudo bash ~/.openclaw-scripts/openclaw-self-heal.sh
   ```
3. If the user was just added to the `docker` group, you may need to **log out and log back in** for permissions to apply.

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

## Repository Structure

- `openclaw-self-heal.sh`: Main deployment orchestrator.
- `lib/`: Modular shell scripts for environment setup, installations, and configuration.
  - `lib/tools/`: **Tool modules** — one file per 3rd-party tool. Each file is the single source of truth for that tool's install logic, AppArmor rules, env var placeholders, and systemd exports.
- `skills/`: Categorized tri-agent skills (`general`, `coding`, `marketing`) and specialized workspace scaffolds.
- `templates/`: AppArmor profile templates and systemd units.
- `config/`: Python-based JSON configuration patchers.
- `test/`: Automated test suite (safe to run without sudo or network).

## Requirements

- Ubuntu 24.04 (LTS)
- Root/Sudo access
- 7GB+ RAM, 20GB+ Disk

## Security Best Practices

### 🔐 Critical Security Warnings

1. **⚠️ Coding Bot Has Bash/Exec Access**

   The coding bot can execute arbitrary shell commands. **NEVER** grant access to untrusted users:
   ```bash
   # ✅ GOOD: Only you can access coding bot
   TELEGRAM_ALLOWED_USERS_CODING=123456789

   # ❌ BAD: Multiple users with exec access
   TELEGRAM_ALLOWED_USERS_CODING=123456789,987654321
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

5. **🔑 Protect Your .env File**
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
    'mytool': ['coding'],   # agents that can use this tool
}
```

That's the complete contract. No other files need editing.

### Running Tests

```bash
bash test/test-tool-registry.sh
```

The test suite runs 38 assertions with no sudo, no network, and no system changes. It covers tool registration, AppArmor marker injection, `apply-config.py` TOOL_REGISTRY output, and a full dummy-tool end-to-end proof.
