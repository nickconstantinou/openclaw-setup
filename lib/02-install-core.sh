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
version_ge() {
    local left="$1"
    local right="$2"
    [[ -n "$left" ]] && [[ -n "$right" ]] || return 1
    printf '%s\n%s\n' "$right" "$left" | sort -V -C
}

resolve_system_node_bin() {
    local candidate
    for candidate in /usr/bin/node /usr/local/bin/node /bin/node; do
        [[ -x "$candidate" ]] && printf '%s\n' "$candidate" && return 0
    done
    return 1
}

resolve_system_npm_bin() {
    local candidate
    for candidate in /usr/bin/npm /usr/local/bin/npm /bin/npm; do
        [[ -x "$candidate" ]] && printf '%s\n' "$candidate" && return 0
    done
    return 1
}

resolve_system_openclaw_bin() {
    local candidate
    for candidate in /usr/local/bin/openclaw /usr/bin/openclaw /bin/openclaw; do
        [[ -x "$candidate" ]] && printf '%s\n' "$candidate" && return 0
    done
    return 1
}

run_system_npm_global_install() {
    local npm_bin="$1"
    shift

    env -i \
        HOME=/root \
        PATH=/usr/bin:/usr/local/bin:/bin \
        npm_config_cache=/root/.npm \
        npm_config_prefix=/usr \
        XDG_CONFIG_HOME=/root/.config \
        XDG_DATA_HOME=/root/.local/share \
        DEBIAN_FRONTEND=noninteractive \
        "$npm_bin" install -g "$@"
}

system_node_is_supported() {
    local node_bin node_ver node_major
    node_bin=$(resolve_system_node_bin 2>/dev/null) || return 1
    node_ver=$("$node_bin" --version 2>/dev/null | sed 's/^v//')
    [[ -n "$node_ver" ]] || return 1
    node_major="${node_ver%%.*}"

    if [[ "$node_major" -ge 24 ]]; then
        return 0
    fi

    [[ "$node_major" -eq 22 ]] && version_ge "$node_ver" "22.14.0"
}

ensure_system_node_runtime() {
    if system_node_is_supported; then
        local node_bin
        node_bin=$(resolve_system_node_bin)
        log "Supported system Node detected: $node_bin ($("$node_bin" --version 2>/dev/null || echo unknown))"
        return 0
    fi

    log "Installing supported system Node.js 24.x runtime..."
    apt_install ca-certificates curl gnupg
    wait_for_apt
    if command -v systemd-inhibit >/dev/null 2>&1; then
        sudo systemd-inhibit --what=idle --who="openclaw-deploy" --why="Installing NodeSource runtime" \
            bash -lc 'curl -fsSL https://deb.nodesource.com/setup_24.x | bash -'
    else
        sudo bash -lc 'curl -fsSL https://deb.nodesource.com/setup_24.x | bash -'
    fi
    apt_install nodejs

    system_node_is_supported || die "Supported system Node.js 24.x installation failed."
    local node_bin npm_bin
    node_bin=$(resolve_system_node_bin)
    npm_bin=$(resolve_system_npm_bin || true)
    log "System Node ready: ${node_bin} ($("$node_bin" --version 2>/dev/null || echo unknown))"
    [[ -n "$npm_bin" ]] && log "System npm ready: ${npm_bin} ($("$npm_bin" --version 2>/dev/null || echo unknown))"
}

upgrade_npm() {
    local npm_bin
    npm_bin=$(resolve_system_npm_bin 2>/dev/null || command -v npm 2>/dev/null || true)
    if [[ -z "$npm_bin" ]]; then
        log "WARNING: npm not found on PATH — skipping upgrade_npm."
        return 0
    fi
    local current_major
    current_major=$("$npm_bin" --version 2>/dev/null | cut -d. -f1 || echo "")
    local latest_major
    latest_major=$("$npm_bin" view npm version 2>/dev/null | cut -d. -f1 || echo "${current_major:-}")
    if [[ -n "$current_major" ]] && [[ "$current_major" != "$latest_major" ]] && [[ -n "$latest_major" ]]; then
        log "Upgrading npm: $("$npm_bin" --version 2>/dev/null || echo unknown) → latest..."
        # Run with HOME=/root so root's npm cache stays separate from the user's ~/.npm.
        # Without this, npm writes root-owned files into $ACTUAL_HOME/.npm, causing
        # subsequent 'uas npm install' calls to fail with EACCES.
        local upgrade_err
        if upgrade_err=$(HOME=/root "$npm_bin" install -g "npm@${latest_major}" --quiet 2>&1); then
            chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.npm" 2>/dev/null || true
            log "npm upgraded to $("$npm_bin" --version 2>/dev/null || echo unknown)."
        else
            # MODULE_NOT_FOUND means the system npm install is corrupted (missing internal dep,
            # e.g. promise-retry inside @npmcli/arborist). npm cannot self-heal in this state.
            # On NodeSource node systems, apt-get reinstall npm fails due to dep conflicts.
            # Instead, fetch the target npm tarball and extract it directly over the existing
            # installation — this bypasses npm's arborist entirely.
            if echo "$upgrade_err" | grep -q "MODULE_NOT_FOUND"; then
                log "npm is corrupted (MODULE_NOT_FOUND). Repairing via tarball extraction..."
                local npm_pkg_dir repaired=0
                npm_pkg_dir="$(npm root -g 2>/dev/null)/npm"
                local tarball_ver
                tarball_ver=$(curl -fsSL "https://registry.npmjs.org/npm/${latest_major}" 2>/dev/null \
                    | python3 -c "import json,sys; print(json.load(sys.stdin)['version'])" 2>/dev/null || echo "")
                if [[ -n "$tarball_ver" ]] && [[ -d "$npm_pkg_dir" ]]; then
                    local tmp_npm; tmp_npm=$(mktemp -d)
                    if curl -fsSL "https://registry.npmjs.org/npm/-/npm-${tarball_ver}.tgz" \
                            | tar -xz -C "$tmp_npm" --strip-components=1 2>/dev/null; then
                        cp -rf "$tmp_npm/." "$npm_pkg_dir/"
                        repaired=1
                        log "npm repaired to ${tarball_ver} via tarball ($("$npm_bin" --version 2>/dev/null || echo unknown))."
                    fi
                    rm -rf "$tmp_npm"
                fi
                if [[ "$repaired" -eq 0 ]]; then
                    # Tarball failed — fall back to apt (works on plain Debian/Ubuntu npm)
                    if apt-get install --reinstall npm -y -q 2>/dev/null; then
                        repaired=1
                        log "npm repaired via apt ($("$npm_bin" --version 2>/dev/null || echo unknown))."
                    fi
                fi
                if [[ "$repaired" -eq 1 ]] \
                        && [[ "$("$npm_bin" --version 2>/dev/null | cut -d. -f1)" != "$latest_major" ]]; then
                    log "Retrying upgrade to npm@${latest_major}..."
                    if HOME=/root "$npm_bin" install -g "npm@${latest_major}" --quiet 2>&1; then
                        chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.npm" 2>/dev/null || true
                        log "npm upgraded to $("$npm_bin" --version 2>/dev/null || echo unknown) after repair."
                    else
                        log "WARNING: npm upgrade failed after repair — continuing with $("$npm_bin" --version 2>/dev/null || echo 'repaired base')."
                    fi
                elif [[ "$repaired" -eq 0 ]]; then
                    log "WARNING: npm repair failed — continuing with existing install."
                fi
            else
                log "WARNING: npm upgrade failed — continuing. (${upgrade_err%%$'\n'*})"
            fi
        fi
    fi
}

# ── 6. INSTALL OPENCLAW ───────────────────────────────────────────────────────
install_openclaw() {
    ensure_system_node_runtime

    # Only treat a system-global openclaw binary as canonical for service installs.
    local oc_bin
    oc_bin=$(resolve_system_openclaw_bin 2>/dev/null || true)
    if [[ -z "$oc_bin" ]]; then
        local user_oc_bin=""
        user_oc_bin=$(command -v openclaw 2>/dev/null || true)
        [[ -z "$user_oc_bin" ]] && user_oc_bin=$(sudo -u "$ACTUAL_USER" env PATH="/usr/bin:/usr/local/bin:$ACTUAL_HOME/.local/bin:$PATH" which openclaw 2>/dev/null || true)
        if [[ -n "$user_oc_bin" ]]; then
            log "Non-system OpenClaw install detected at $user_oc_bin. Installing a system-global copy for gateway stability."
        fi
    fi
    local npm_bin
    npm_bin=$(resolve_system_npm_bin 2>/dev/null || command -v npm 2>/dev/null || true)
    [[ -n "$npm_bin" ]] || die "npm not found after installing system Node.js."

    if [[ -n "$oc_bin" ]]; then
        local oc_ver; oc_ver=$("$oc_bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")

        # Check remote version before running slow npm install
        local latest_ver; latest_ver=$("$npm_bin" view openclaw version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")

        if [[ "$oc_ver" == "$latest_ver" ]] && [[ "$oc_ver" != "unknown" ]]; then
            log "OpenClaw already installed ($oc_ver) and is up-to-date. Skipping upgrade."
            return 0
        fi

        log "OpenClaw update available: $oc_ver → $latest_ver. Attempting upgrade..."
        upgrade_npm
        # /usr/lib/node_modules is root-owned, so upgrade must run as root.
        # Use HOME=/root so root's npm cache stays out of the user's ~/.npm.
        if run_system_npm_global_install "$npm_bin" openclaw@latest --quiet 2>&1; then
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
    # Ensure npm is healthy before attempting install (catches corrupted system npm)
    upgrade_npm
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
    # Fix any root-owned npm cache files before running installer (stale from prior runs).
    # Also redirect npm_config_cache to /root/.npm so the installer's npm calls never
    # pollute $ACTUAL_HOME/.npm with root-owned files (the EACCES cause on re-runs).
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.npm" 2>/dev/null || true
    sudo HOME="$ACTUAL_HOME" \
        npm_config_cache=/root/.npm \
        XDG_CONFIG_HOME="$ACTUAL_HOME/.config" \
        XDG_DATA_HOME="$ACTUAL_HOME/.local/share" \
        bash "$installer_path" --no-onboard

    rm -rf "$installer_dir"

    if [[ "$ACTUAL_HOME" != "/root" ]] && [[ -d "/root/.openclaw" ]]; then
        log "Cleaning up stale /root/.openclaw..."
        rm -rf /root/.openclaw
    fi

    local installed_oc_bin
    installed_oc_bin=$(resolve_system_openclaw_bin 2>/dev/null || true)
    if [[ -z "$installed_oc_bin" ]]; then
        log "System-global OpenClaw binary not found after installer. Installing via system npm..."
        run_system_npm_global_install "$npm_bin" openclaw@latest --quiet \
            || die "System-global OpenClaw install failed after installer run."
        installed_oc_bin=$(resolve_system_openclaw_bin 2>/dev/null || true)
    fi
    [[ -n "$installed_oc_bin" ]] || die "System-global 'openclaw' binary not found after install."
    log "OpenClaw installed: $installed_oc_bin"
}

# ── 7g. ACPX PLUGIN — BUNDLED ────────────────────────────────────────────────
# ACPX is part of the OpenClaw install used here, so the setup keeps the
# bundled plugin enabled in config instead of installing or disabling it later.

# ── 7j. AGENT DIRECTORIES ─────────────────────────────────────────────────────
setup_agent_dirs() {
    log "Creating named agent directories (main + family)..."
    for id in main family; do
        local agent_root="$ACTUAL_HOME/.openclaw/agents/$id"
        local agent_state_dir="$agent_root/agent"
        local agent_workspace_dir="$agent_root/workspace"

        # Create directories
        mkdir -p "$agent_state_dir" "$agent_workspace_dir"

        # Seed base files only when missing so agent-local memory/instructions
        # are not overwritten on reinstall or self-heal.
        for f in AGENTS.md SOUL.md MEMORY.md TOOLS.md SKILLS.md; do
            if [[ -f "$ACTUAL_HOME/.openclaw/workspace/$f" ]] && [[ ! -e "$agent_workspace_dir/$f" ]]; then
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
    # Skip agents whose workspace directory doesn't exist (e.g. codex only has an
    # agent state dir, not a full workspace) — open() would throw and exit non-zero,
    # triggering the fallback warning even when the named agents succeeded.
    echo "$agents_json" | python3 -c "
import json, os, sys
agents = json.load(sys.stdin)
base = f'/home/{os.environ.get(\"ACTUAL_USER\", \"openclaw\")}/.openclaw/agents'
for agent in agents:
    agent_id = agent.get('id', 'unknown')
    workspace = f'{base}/{agent_id}/workspace'
    if not os.path.isdir(workspace):
        continue
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

## Project Conventions
- Files: kebab-case (user-profile.tsx)
- Components: PascalCase (UserProfile)
- Keep files under 200 lines
- Verify changes work after making them
- Ask before installing new dependencies
- Update status after each phase

## Agent Communication
- @mention agent name → routes message to that agent
- sessions_send → explicit message to another agent's session
- All agents can message each other via these methods

## Workspace Files
- MEMORY.md - Persistent memory
- TOOLS.md - Available tools
- SKILLS.md - This file
'''

    with open(f'{workspace}/SKILLS.md', 'w') as f:
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
