#!/usr/bin/env bash
# OpenClaw Bootstrap Installer
# Usage: curl -sSL https://raw.githubusercontent.com/nickconstantinou/openclaw-scripts/main/install.sh | bash

set -Eeuo pipefail

REPO_URL="https://github.com/nickconstantinou/openclaw-scripts.git"
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

# Execute main orchestrator
log "Launching OpenClaw deployment..."
cd "$INSTALL_DIR"
sudo bash openclaw-self-heal.sh
