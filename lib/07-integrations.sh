#!/usr/bin/env bash
# 
# @intent Third-party integrations: GitHub CLI and Obsidian vault (§11b-§11c).
# @complexity 3
# 

# ── 11b. GITHUB CLI ───────────────────────────────────────────────────────────
setup_github_cli() {
    log "Setting up GitHub CLI..."
    local keyring="/usr/share/keyrings/githubcli-archive-keyring.gpg"
    local sources="/etc/apt/sources.list.d/github-cli.list"

    if ! command -v gh >/dev/null 2>&1; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of="$keyring" 2>/dev/null
        sudo chmod go+r "$keyring"
        echo "deb [arch=$(dpkg --print-architecture) signed-by=$keyring] https://cli.github.com/packages stable main" | sudo tee "$sources" > /dev/null
        wait_for_apt
        sudo apt-get update -q && apt_install gh
    fi

    log "Configuring GitHub authentication..."
    # Scope check
    local scopes; scopes=$(curl -sf -I -H "Authorization: token $GITHUB_API_KEY" https://api.github.com/user 2>/dev/null | grep -i '^x-oauth-scopes:' | sed 's/x-oauth-scopes: //I' || echo "")
    if [[ -n "$scopes" ]] && ! echo "$scopes" | grep -q "read:org"; then
        log "WARNING: GitHub token missing 'read:org' scope. gh CLI may fail."
    fi

    local auth_out
    if auth_out=$(echo "$GITHUB_API_KEY" | uas env GH_CONFIG_DIR="$ACTUAL_HOME/.config/gh" gh auth login --with-token 2>&1); then
        log "GitHub CLI authenticated."
        uas env GH_CONFIG_DIR="$ACTUAL_HOME/.config/gh" gh auth setup-git
        chmod 700 "$ACTUAL_HOME/.config/gh" 2>/dev/null || true
        
        # Export identity for notifications
        local identity
        identity=$(uas env GH_CONFIG_DIR="$ACTUAL_HOME/.config/gh" gh api user -q .login 2>/dev/null || echo "unknown")
        export GH_IDENTITY="$identity"
    else
        log "WARNING: GitHub CLI authentication failed: $auth_out"
    fi
}

# ── 11c. OBSIDIAN VAULT ───────────────────────────────────────────────────────
setup_obsidian_vault() {
    log "Setting up Obsidian vault integration..."
    local vault_path="${OBSIDIAN_VAULT_PATH%/}"

    # Create directory structure
    local dirs=("$vault_path" "$vault_path/.obsidian" "$vault_path/Inbox" "$vault_path/Daily Notes" "$vault_path/Templates" "$vault_path/Attachments")
    for d in "${dirs[@]}"; do
        mkdir -p "$d"
    done

    sudo chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$vault_path"
    chmod 750 "$vault_path"

    # Initialise config
    local app_json="$vault_path/.obsidian/app.json"
    if [[ ! -f "$app_json" ]]; then
        cat > "$app_json" <<EOF
{
  "defaultViewMode": "source",
  "newFileLocation": "folder",
  "newFileFolderPath": "Inbox",
  "attachmentFolderPath": "Attachments",
  "dailyNotesFolder": "Daily Notes",
  "templateFolder": "Templates",
  "alwaysUpdateLinks": true
}
EOF
        chown "$ACTUAL_USER":"$ACTUAL_USER" "$app_json"
    fi

    # Symlink
    local ws_link="$ACTUAL_HOME/.openclaw/workspace/obsidian"
    if [[ "$vault_path" != "$ACTUAL_HOME/.openclaw/workspace"* ]]; then
        uas ln -sf "$vault_path" "$ws_link"
        log "Vault symlinked: $ws_link -> $vault_path"
    fi

    # README
    local readme="$vault_path/README.md"
    if [[ ! -f "$readme" ]]; then
        cat > "$readme" <<EOF
# Obsidian Vault
Managed by OpenClaw. New notes land in Inbox/.
EOF
        chown "$ACTUAL_USER":"$ACTUAL_USER" "$readme"
    fi

    # Patch AppArmor (calls function from lib/05-apparmor.sh)
    patch_apparmor_vault "$vault_path"
}
