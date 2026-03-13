#!/usr/bin/env bash
#
# @intent Installation of core services and tools (§6-§7g).
# @complexity 3
#

# ── LOAD TOOL MODULES ─────────────────────────────────────────────────────────
# shellcheck source=lib/tools/_base.sh
source "$SCRIPT_DIR/lib/tools/_base.sh"
for _f in "$SCRIPT_DIR"/lib/tools/*.sh; do
    [[ "$(basename "$_f")" == "_base.sh" ]] && continue
    # shellcheck source=/dev/null
    source "$_f"
done; unset _f

# ── 5.5 UPGRADE NPM ──────────────────────────────────────────────────────────
upgrade_npm() {
    local current_major
    current_major=$(npm --version 2>/dev/null | cut -d. -f1)
    local latest_major
    latest_major=$(npm view npm version 2>/dev/null | cut -d. -f1 || echo "$current_major")
    if [[ "$current_major" != "$latest_major" ]] && [[ -n "$latest_major" ]]; then
        log "Upgrading npm: $(npm --version) → latest..."
        # Run with HOME=/root so root's npm cache stays separate from the user's ~/.npm.
        # Without this, npm writes root-owned files into $ACTUAL_HOME/.npm, causing
        # subsequent 'uas npm install' calls to fail with EACCES.
        HOME=/root npm install -g "npm@$latest_major" --quiet 2>&1 || log "WARNING: npm upgrade failed."
        chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.npm" 2>/dev/null || true
    fi
}

# ── 6. INSTALL OPENCLAW ───────────────────────────────────────────────────────
install_openclaw() {
    # Check for existing binary in common install locations (runs as root, so check explicit paths)
    local oc_bin
    oc_bin=$(command -v openclaw 2>/dev/null || true)
    [[ -z "$oc_bin" ]] && oc_bin=$(sudo -u "$ACTUAL_USER" env PATH="/usr/bin:/usr/local/bin:$ACTUAL_HOME/.local/bin:$PATH" which openclaw 2>/dev/null || true)

    if [[ -n "$oc_bin" ]]; then
        local oc_ver; oc_ver=$("$oc_bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")

        # Check remote version before running slow npm install
        local latest_ver; latest_ver=$(uas npm view openclaw version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")

        if [[ "$oc_ver" == "$latest_ver" ]] && [[ "$oc_ver" != "unknown" ]]; then
            log "OpenClaw already installed ($oc_ver) and is up-to-date. Skipping upgrade."
            return 0
        fi

        log "OpenClaw update available: $oc_ver → $latest_ver. Attempting upgrade..."
        upgrade_npm
        # /usr/lib/node_modules is root-owned, so upgrade must run as root.
        # Use HOME=/root so root's npm cache stays out of the user's ~/.npm.
        if HOME=/root npm install -g openclaw@latest --quiet 2>&1; then
            local new_ver; new_ver=$("$oc_bin" --version 2>/dev/null | head -1 | tr -d 'v' || echo "unknown")
            log "OpenClaw upgraded: $oc_ver → $new_ver"
        else
            log "WARNING: Upgrade failed — continuing with existing version ($oc_ver)."
            local tmp_installer; tmp_installer=$(mktemp)
            if curl -fsSL "https://openclaw.ai/install.sh" -o "$tmp_installer" 2>/dev/null; then
                local new_sha
                new_sha=$(sha256sum "$tmp_installer" | awk '{print $1}')
                if [[ -n "$new_sha" ]]; then
                    log "INFO: New installer checksum for review: $new_sha"
                fi
            fi
            rm -f "$tmp_installer"
        fi
        return 0
    fi

    log "Installing OpenClaw (checksum enforced)..."
    local installer_dir; installer_dir=$(mktemp -d)
    chmod 700 "$installer_dir"
    local installer_path="$installer_dir/openclaw-install.sh"

    # Early AppArmor cleanup to prevent node EACCES during install
    if [[ -f /etc/apparmor.d/openclaw-gateway ]]; then
        sudo apparmor_parser -R /etc/apparmor.d/openclaw-gateway 2>/dev/null || true
    fi

    log "Downloading OpenClaw installer..."
    curl -fsSL "https://openclaw.ai/install.sh" -o "$installer_path"
    chmod 600 "$installer_path"

    log "Verifying installer checksum..."
    local actual_sha; actual_sha=$(sha256sum "$installer_path" | awk '{print $1}')
    if [[ "$actual_sha" != "$OPENCLAW_INSTALLER_SHA256" ]]; then
        rm -rf "$installer_dir"
        die "Installer checksum mismatch! Expected: $OPENCLAW_INSTALLER_SHA256, Got: $actual_sha"
    fi

    log "Checksum verified. Running installer..."
    sudo HOME="$ACTUAL_HOME" \
        XDG_CONFIG_HOME="$ACTUAL_HOME/.config" \
        XDG_DATA_HOME="$ACTUAL_HOME/.local/share" \
        bash "$installer_path" --no-onboard

    rm -rf "$installer_dir"

    if [[ "$ACTUAL_HOME" != "/root" ]] && [[ -d "/root/.openclaw" ]]; then
        log "Cleaning up stale /root/.openclaw..."
        rm -rf /root/.openclaw
    fi

    command -v openclaw >/dev/null 2>&1 || die "'openclaw' binary not found after install."
    log "OpenClaw installed: $(command -v openclaw)"
}

# ── 7g. INSTALL ACPX PLUGIN ───────────────────────────────────────────────────
install_acpx_plugin() {
    if [[ "${ANTHROPIC_API_KEY:-}" == "sk-ant-REPLACE_ME_WHEN_READY" ]]; then
        log "acpx plugin SKIPPED — placeholder key."
        return
    fi

    log "Installing acpx plugin..."
    mkdir -p "$ACTUAL_HOME/.openclaw/plugins"
    chown "$ACTUAL_USER":"$ACTUAL_USER" "$ACTUAL_HOME/.openclaw/plugins"
    # Note: @openclaw/acpx may not be publicly available on npm; skip gracefully
    local acpx_err
    acpx_err=$(oc plugins install @openclaw/acpx 2>&1) \
        && log "acpx plugin installed." \
        || log "INFO: acpx plugin not available — skipping. ($acpx_err)"
}

# ── 7j. AGENT DIRECTORIES ─────────────────────────────────────────────────────
setup_agent_dirs() {
    log "Creating named agent directories (Tri-Agent Architecture)..."
    for id in main coding marketing family; do
        local agent_root="$ACTUAL_HOME/.openclaw/agents/$id"
        local agent_state_dir="$agent_root/agent"
        local agent_workspace_dir="$agent_root/workspace"

        # Create directories
        mkdir -p "$agent_state_dir" "$agent_workspace_dir"

        # Sync base files (AGENTS.md, SOUL.md, MEMORY.md, TOOLS.md SKILLS.md)
        # Note: Subagents only load AGENT/TOOLS but we sync all for consistency
        for f in AGENTS.md SOUL.md MEMORY.md TOOLS.md SKILLS.md; do
            if [[ -f "$ACTUAL_HOME/.openclaw/workspace/$f" ]]; then
                uas cp "$ACTUAL_HOME/.openclaw/workspace/$f" "$agent_workspace_dir/$f" 2>/dev/null || true
            fi
        done

        # Create symlinks to media/inbound for all agents (Telegram, WhatsApp images)
        mkdir -p "$ACTUAL_HOME/.openclaw/media/inbound"
        uas ln -sfn "$ACTUAL_HOME/.openclaw/media/inbound" "$agent_workspace_dir/inbound" 2>/dev/null || true
        
        # Also add symlink to main media folder for broader access
        mkdir -p "$ACTUAL_HOME/.openclaw/media"
        uas ln -sfn "$ACTUAL_HOME/.openclaw/media" "$agent_workspace_dir/media" 2>/dev/null || true

        # Harden permissions
        chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$agent_root"
        chmod 700 "$agent_state_dir"
        chmod 755 "$agent_workspace_dir"
    done
    
    # Generate SKILLS.md for each agent based on their actual config
    generate_agent_skills_md
}

# ── 7aa. GENERATE AGENT SKILLS MD ────────────────────────────────────────────
generate_agent_skills_md() {
    log "Generating SKILLS.md for each agent..."
    
    # Read agent config to get each agent's tools
    local config_file="$ACTUAL_HOME/.openclaw/openclaw.json"
    if [[ ! -f "$config_file" ]]; then
        log "WARN: Config file not found, skipping SKILLS.md generation"
        return 0
    fi
    
    # Extract agents and their tools from config
    local agents_json
    agents_json=$(python3 -c "import json; c=json.load(open('$config_file')); print(json.dumps(c.get('agents',{}).get('list',[])))" 2>/dev/null)
    
    if [[ -z "$agents_json" ]]; then
        log "WARN: No agents found in config"
        return 0
    fi
    
    # For each agent, generate SKILLS.md
    echo "$agents_json" | python3 -c "
import json, sys
agents = json.load(sys.stdin)
for agent in agents:
    agent_id = agent.get('id', 'unknown')
    tools = agent.get('tools', {})
    allowlist = tools.get('allow', [])
    profile = tools.get('profile', 'custom')
    
    skills_content = f'''# Skills Guide - {agent_id.upper()}

Auto-generated from agent config.

## Available Tools
{', '.join(allowlist) if allowlist else '(using profile: ' + profile + ')'}

## When to Use Skills
- Building features → Use superpowers skill
- Large projects → Use gsd skill  
- Code review → Use code-review skill
- Refactoring → Use refactoring skill

## Workspace Files
- MEMORY.md - Persistent memory
- TOOLS.md - Available tools
- SKILLS.md - This file
'''
    
    # Write to agent workspace
    workspace = f'/home/{os.environ.get(\"ACTUAL_USER\", \"openclaw\")}/.openclaw/agents/{agent_id}/workspace/SKILLS.md'
    with open(workspace, 'w') as f:
        f.write(skills_content)
    print(f'Created SKILLS.md for {agent_id}')
" 2>/dev/null || log "WARN: Failed to generate SKILLS.md via Python"
    
    log "SKILLS.md generation complete"
}

# ── 7i. INSTALL POST BRIDGE ───────────────────────────────────────────────────
install_post_bridge() {
    log "Installing Post Bridge social media skill..."
    # Note: skill is also deployed via lib/03-skills.sh file-copy; this registers it from upstream if available
    # Command currently broken in OpenClaw CLI, relying on local deploy
    log "INFO: Post Bridge upstream skill registration skipped (already deployed locally)."
}
