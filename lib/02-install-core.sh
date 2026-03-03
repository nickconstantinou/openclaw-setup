#!/usr/bin/env bash
# 
# @intent Installation of core services and tools (§6-§7g).
# @complexity 3
# 

# ── 6. INSTALL OPENCLAW ───────────────────────────────────────────────────────
install_openclaw() {
    # Check for existing binary in common install locations (runs as root, so check explicit paths)
    local oc_bin
    oc_bin=$(command -v openclaw 2>/dev/null || true)
    [[ -z "$oc_bin" ]] && oc_bin=$(sudo -u "$ACTUAL_USER" env PATH="/usr/bin:/usr/local/bin:$ACTUAL_HOME/.local/bin:$PATH" which openclaw 2>/dev/null || true)

    if [[ -n "$oc_bin" ]]; then
        local oc_ver; oc_ver=$("$oc_bin" --version 2>/dev/null | head -1 | tr -d 'v' || echo "unknown")
        
        # Check remote version before running slow npm install
        local latest_ver; latest_ver=$(uas npm view openclaw version 2>/dev/null || echo "unknown")
        
        if [[ "$oc_ver" == "$latest_ver" ]] && [[ "$oc_ver" != "unknown" ]]; then
            log "OpenClaw already installed ($oc_ver) and is up-to-date. Skipping upgrade."
            return 0
        fi

        log "OpenClaw update available: $oc_ver → $latest_ver. Attempting upgrade..."
        if uas npm install -g openclaw@latest --quiet 2>/dev/null; then
            local new_ver; new_ver=$("$oc_bin" --version 2>/dev/null | head -1 | tr -d 'v' || echo "unknown")
            log "OpenClaw upgraded: $oc_ver → $new_ver"
        else
            log "WARNING: Upgrade failed — continuing with existing version ($oc_ver)."
            local new_sha
            new_sha=$(curl -fsSL "https://openclaw.ai/install.sh" 2>/dev/null | sha256sum | awk '{print $1}')
            
            # Use OPENCLAW_INSTALLER_SHA256 if defined, otherwise ensure we log the fetched SHA
            if [[ -n "$new_sha" ]]; then
                if [[ -z "$OPENCLAW_INSTALLER_SHA256" ]] || [[ "$new_sha" != "$OPENCLAW_INSTALLER_SHA256" ]]; then
                    log "INFO: New installer checksum for review: $new_sha"
                fi
            fi
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

# ── 7. INSTALL PLAYWRIGHT ─────────────────────────────────────────────────────
install_playwright() {
    log "Installing Chromium dependencies..."
    if command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1; then
        log "Chromium already installed — skipping Playwright install."
    else
        local npm_cache; npm_cache=$(mktemp -d)
        wait_for_apt
        
        log "  Running playbook: playwright install-deps (as root)..."
        if env PATH="/usr/bin:/usr/local/bin:$ACTUAL_HOME/.local/bin:$PATH" HOME=/root npm_config_cache="$npm_cache" npx -y playwright install-deps chromium 2>&1 | while IFS= read -r line; do log "  playwright-deps: $line"; done; then
            log "  System dependencies installed."
        else
            log "  WARNING: Failed to install Playwright OS dependencies."
        fi

        log "  Running playbook: playwright install (as user)..."
        if uas env npm_config_cache="$npm_cache" npx -y playwright install chromium 2>&1 | while IFS= read -r line; do log "  playwright: $line"; done; then
            log "Chromium browser binaries installed for agent."
        else
            log "WARNING: Playwright install failed. Browser tools may be unavailable."
        fi
        rm -rf "$npm_cache"
    fi
}

# ── 7b. INSTALL PYTHON PACKAGES ───────────────────────────────────────────────
install_python_packages() {
    log "Installing Python packages for agent use..."
    local pip_packages=(
        pytest pytest-asyncio requests python-dotenv rich yt-dlp
        python-docx openpyxl python-pptx markitdown
        faster-whisper av markdown pyyaml
    )
    for pkg in "${pip_packages[@]}"; do
        uas python3 -m pip install --user --quiet --break-system-packages "$pkg" \
            && log "  pip: installed $pkg" \
            || log "  WARNING: pip install $pkg failed."
    done
}

# ── 7c. INSTALL PANDOC TOOLCHAIN ──────────────────────────────────────────────
install_pandoc_toolchain() {
    log "Installing pandoc, PDF engine, and ffmpeg..."
    local pkgs=(pandoc texlive-xetex poppler-utils ffmpeg sqlite3)
    local missing=()
    for p in "${pkgs[@]}"; do
        dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        log "pandoc/ffmpeg toolchain already installed."
    else
        wait_for_apt
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q "${missing[@]}" \
            && log "pandoc toolchain installed." \
            || log "WARNING: pandoc install failed."
    fi
}

# ── 7d. INSTALL GOGCLI ────────────────────────────────────────────────────────
install_gogcli() {
    log "Installing gogcli (Google Workspace CLI)..."
    if command -v gog >/dev/null 2>&1; then
        log "gogcli already installed: $(gog --version 2>/dev/null | head -1)"
    fi

    local latest; latest=$(curl -fsSL -H "Accept: application/vnd.github+json" "https://api.github.com/repos/steipete/gogcli/releases/latest" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['tag_name'])" 2>/dev/null || echo "")
    
    if [[ -z "$latest" ]]; then
        log "WARNING: Could not fetch gogcli release info."
        return
    fi

    local arch; arch=$(uname -m)
    local gog_arch=""
    case "$arch" in
        x86_64)  gog_arch="linux_amd64" ;;
        aarch64) gog_arch="linux_arm64" ;;
    esac

    if [[ -n "$gog_arch" ]]; then
        local url="https://github.com/steipete/gogcli/releases/download/${latest}/gogcli_${latest#v}_${gog_arch}.tar.gz"
        local tmp; tmp=$(mktemp -d)
        if curl -fsSL "$url" -o "$tmp/gogcli.tar.gz" && tar -xzf "$tmp/gogcli.tar.gz" -C "$tmp" && sudo install -m 755 "$tmp/gog" "/usr/local/bin/gog"; then
            log "gogcli installed: $(gog --version 2>/dev/null | head -1)"
        else
            log "WARNING: gogcli binary download failed."
        fi
        rm -rf "$tmp"
    fi

    # Write auth hint
    local hint="$ACTUAL_HOME/.openclaw/workspace/google-auth-setup.md"
    mkdir -p "$(dirname "$hint")"
    cat > "$hint" << 'EOF'
# Google Workspace Setup (gog)
1. Run: gog auth credentials ~/Downloads/client_secret_xxx.json
2. Run: gog auth add you@gmail.com --services all
3. Add to ~/.openclaw/.env: GOG_ACCOUNT=you@gmail.com, GOG_KEYRING_PASSWORD=xxx
EOF
    chown "$ACTUAL_USER":"$ACTUAL_USER" "$hint"
}

# ── 7f. INSTALL CLAUDE CODE ───────────────────────────────────────────────────
install_claude_code() {
    if [[ "${ANTHROPIC_API_KEY:-}" == "sk-ant-REPLACE_ME_WHEN_READY" ]]; then
        log "Claude Code SKIPPED — placeholder key."
        return
    fi

    log "Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code --quiet || log "WARNING: Claude Code install failed."
    
    local bin; bin=$(command -v claude 2>/dev/null || true)
    if [[ -n "$bin" ]]; then
        local wrapper="$ACTUAL_HOME/.openclaw/bin/cc"
        mkdir -p "$(dirname "$wrapper")"
        cat > "$wrapper" << WRAPEOF
#!/usr/bin/env bash
exec "$bin" --print "\$@"
WRAPEOF
        chmod 755 "$wrapper"
        chown "$ACTUAL_USER":"$ACTUAL_USER" "$wrapper"
    fi
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
    oc plugins install @openclaw/acpx 2>/dev/null && log "acpx plugin installed." || log "INFO: acpx plugin not available — skipping."
}

# ── 7j. AGENT DIRECTORIES ─────────────────────────────────────────────────────
setup_agent_dirs() {
    log "Creating named agent directories (Tri-Agent Architecture)..."
    for id in main coding marketing; do
        local agent_root="$ACTUAL_HOME/.openclaw/agents/$id"
        local agent_state_dir="$agent_root/agent"
        local agent_workspace_dir="$agent_root/workspace"
        
        # Create directories
        mkdir -p "$agent_state_dir" "$agent_workspace_dir"
        
        # Sync base files (AGENTS.md, SOUL.md, MEMORY.md, TOOLS.md) 
        # Note: Subagents only load AGENT/TOOLS but we sync all for consistency
        for f in AGENTS.md SOUL.md MEMORY.md TOOLS.md; do
            if [[ -f "$ACTUAL_HOME/.openclaw/workspace/$f" ]]; then
                uas cp "$ACTUAL_HOME/.openclaw/workspace/$f" "$agent_workspace_dir/$f" 2>/dev/null || true
            fi
        done

        # Harden permissions
        chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$agent_root"
        chmod 700 "$agent_state_dir"
        chmod 755 "$agent_workspace_dir"
    done
}

# ── 7i. INSTALL POST BRIDGE ───────────────────────────────────────────────────
install_post_bridge() {
    log "Installing Post Bridge social media skill..."
    # Note: skill is also deployed via lib/03-skills.sh file-copy; this registers it from upstream if available
    # Command currently broken in OpenClaw CLI, relying on local deploy
    log "INFO: Post Bridge upstream skill registration skipped (already deployed locally)."
}
