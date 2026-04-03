#!/usr/bin/env bash
# OpenClaw Bootstrap Installer
# Usage: curl -fsSL --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/nickconstantinou/openclaw-setup/main/install.sh | bash

set -Eeuo pipefail

REPO_URL="https://github.com/nickconstantinou/openclaw-setup.git"
INSTALL_DIR="$HOME/.openclaw-scripts"

log() { echo -e "\033[1;32m[BOOTSTRAP]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; exit 1; }

# Install git if missing
if ! command -v git >/dev/null 2>&1; then
    log "Git not found. Installing..."
    sudo apt-get update && sudo apt-get install -y git || error "Failed to install git."
fi

# Clone or update repository
if [[ -d "$INSTALL_DIR" ]]; then
    log "Updating existing repository in $INSTALL_DIR..."
    git -C "$INSTALL_DIR" pull || error "Failed to update repository."
else
    log "Cloning repository to $INSTALL_DIR..."
    git clone "$REPO_URL" "$INSTALL_DIR" || error "Failed to clone repository."
fi

# Set up OpenClaw state backup repo
log "Setting up OpenClaw state backup..."
BACKUP_DIR="$HOME/.openclaw/workspace/openclaw-state"
BACKUP_REPO="https://github.com/nickconstantinou/openclaw-state.git"
if [[ ! -d "$BACKUP_DIR/.git" ]]; then
    mkdir -p "$(dirname "$BACKUP_DIR")"
    git clone "$BACKUP_REPO" "$BACKUP_DIR" 2>/dev/null || log "Backup repo clone skipped (may already exist)"
fi

# Install backup cron job if gh CLI is available
if command -v gh >/dev/null 2>&1; then
    BACKUP_SCRIPT="$HOME/.openclaw/workspace/scripts/backup-openclaw-state.sh"
    if [[ -f "$BACKUP_SCRIPT" ]] && ! crontab -l 2>/dev/null | grep -q "backup-openclaw-state"; then
        (crontab -l 2>/dev/null; echo "0 3 * * * $BACKUP_SCRIPT >> $HOME/.openclaw/workspace/logs/backup.log 2>&1") | crontab - 2>/dev/null || true
        log "Backup cron job installed (daily at 3 AM)"
    fi
fi

# Execute main orchestrator
log "Launching OpenClaw deployment..."
cd "$INSTALL_DIR"
sudo bash openclaw-self-heal.sh
