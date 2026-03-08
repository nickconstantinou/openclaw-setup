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
   │ bash    │    │ no exec  │    │ WhatsApp  │
   │ exec    │    │ content  │    │ full      │
   │ write   │    │ creation │    │ profile   │
   └─────────┘    └──────────┘    └───────────┘
```

### Agent Capabilities

| Agent | Primary Model | Tools | Use Cases |
|-------|--------------|-------|-----------|
| **main** | MiniMax M2.5 | Full profile, can spawn subagents | Task planning, orchestration, general queries |
| **coding** | MiniMax M2.5 | bash, exec, write, edit, git | Development, code generation, system tasks |
| **marketing** | MiniMax M2.5 | Content tools (no exec) | Content creation, social media, documentation |
| **family** | MiniMax M2.5 | Full profile | Personal assistant via WhatsApp |

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
| **family** (WhatsApp) | Full profile | Medium | Family members |

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

#### Example 3: Maximum Security (Pairing Mode)

```bash
# Leave as REPLACE_ME for pairing mode
TELEGRAM_ALLOWED_USERS=REPLACE_ME
TELEGRAM_ALLOWED_USERS_CODING=INHERIT
TELEGRAM_ALLOWED_USERS_MARKETING=INHERIT
```

✅ All bots use `pairing` mode — users must send `/pair` command to authenticate

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
   - If using pairing mode, send `/pair` to authenticate

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
- `skills/`: Categorized tri-agent skills (`general`, `coding`, `marketing`) and specialized workspace scaffolds.
- `templates/`: AppArmor profile templates and systemd units.
- `config/`: Python-based JSON configuration patchers.

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

2. **🔒 Use Pairing Mode for Public Deployments**

   If your bot tokens might be exposed, use pairing mode:
   ```bash
   TELEGRAM_ALLOWED_USERS=REPLACE_ME  # Requires /pair command
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

### Refactoring

To refactor or add new components, maintain the sourced module structure in `lib/` and update the main orchestrator accordingly.
