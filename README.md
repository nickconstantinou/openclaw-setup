# OpenClaw Scripts

Deployment and self-healing scripts for OpenClaw Enterprise.

## Quick Start

To deploy or repair OpenClaw on a fresh Ubuntu 24.04 server:

```bash
curl -fsSL --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/nickconstantinou/openclaw-setup/main/install.sh | bash
```

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

3.  **Run the deployment**:
    ```bash
    sudo bash openclaw-self-heal.sh
    ```

## Repository Structure

- `openclaw-self-heal.sh`: Main deployment orchestrator.
- `lib/`: Modular shell scripts for environment setup, installations, and configuration.
- `skills/`: External SKILL.md and helper scripts for the OpenClaw agent.
- `templates/`: AppArmor profile templates and systemd units.
- `config/`: Python-based JSON configuration patchers.

## Requirements

- Ubuntu 24.04 (LTS)
- Root/Sudo access
- 7GB+ RAM, 20GB+ Disk

## Development

This repository follows the **Antigravity Workflow** pattern:
- **Atomic Modularity**: Scripts are decomposed into single-responsibility modules in `lib/`.
- **Idempotency**: All scripts are safe to run multiple times.
- **Strict Error Handling**: Bash scripts use `set -Eeuo pipefail`.

### Refactoring

To refactor or add new components, maintain the sourced module structure in `lib/` and update the main orchestrator accordingly.
