#!/usr/bin/env bash
#
# @intent Claude Code CLI tool module.
# @complexity 2
#

TOOL_APPARMOR_RULES[claude_code]=$(cat <<'RULES'
  # ── Claude Code — exec delegation ───────────────────────────────────────────
  # Agent invokes Claude Code via its native CLI.
  # env is needed for #!/usr/bin/env node shebang
  /usr/bin/env                         ix,
  /usr/bin/node                        ix,
  @{HOME}/.claude/                     rw,
  @{HOME}/.claude/**                   rw,
  @{HOME}/.local/bin/claude            ix,
  # Claude Code self-manages its binary under ~/.local/share/claude/versions/<ver>
  # AppArmor resolves ~/.local/bin/claude → the real ELF path, so we need ix there.
  @{HOME}/.local/share/claude/           r,
  @{HOME}/.local/share/claude/**         r,
  @{HOME}/.local/share/claude/versions/* ix,
  @{HOME}/.cache/claude/               rw,
  @{HOME}/.cache/claude/**             rw,
RULES
)

TOOL_ENV_PLACEHOLDERS[claude_code]="ANTHROPIC_API_KEY=sk-ant-REPLACE_ME_WHEN_READY"
TOOL_SYSTEMD_EXPORTS[claude_code]="ANTHROPIC_API_KEY"
TOOL_SANDBOX_ENV[claude_code]="ANTHROPIC_API_KEY"

# ── 7f. INSTALL CLAUDE CODE ───────────────────────────────────────────────────
install_claude_code() {
    if [[ "${ANTHROPIC_API_KEY:-}" == "sk-ant-REPLACE_ME_WHEN_READY" ]]; then
        log "Claude Code SKIPPED — placeholder key."
        return
    fi

    # Remove root-owned npm-global install if present — it blocks user-owned upgrades
    if [[ -f /usr/bin/claude ]] || npm list -g @anthropic-ai/claude-code --depth=0 &>/dev/null; then
        log "Removing root-owned npm-global Claude Code install..."
        npm uninstall -g @anthropic-ai/claude-code 2>&1 || log "WARNING: npm uninstall failed — continuing."
        rm -f /usr/bin/claude /usr/local/bin/claude
    fi

    log "Installing Claude Code (native install, user-owned)..."
    local native_bin="$ACTUAL_HOME/.local/bin/claude"

    local current_ver="none"
    if [[ -x "$native_bin" ]]; then
        current_ver=$(sudo -u "$ACTUAL_USER" "$native_bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        local latest_ver; latest_ver=$(uas npm view @anthropic-ai/claude-code version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        if [[ "$current_ver" == "$latest_ver" ]] && [[ "$current_ver" != "unknown" ]]; then
            log "Claude Code already installed ($current_ver) and is up-to-date. Skipping upgrade."
        else
            log "Claude Code update available: $current_ver → $latest_ver. Upgrading via native install..."
            sudo -u "$ACTUAL_USER" HOME="$ACTUAL_HOME" "$native_bin" install 2>&1 \
                && log "Claude Code upgraded to $(sudo -u "$ACTUAL_USER" "$native_bin" --version 2>/dev/null | head -1)" \
                || log "WARNING: Claude Code native upgrade failed."
        fi
    else
        # Fresh native install — runs as the actual user so ~/.local/bin/claude is user-owned
        sudo -u "$ACTUAL_USER" HOME="$ACTUAL_HOME" \
            XDG_CONFIG_HOME="$ACTUAL_HOME/.config" \
            XDG_DATA_HOME="$ACTUAL_HOME/.local/share" \
            npm install -g @anthropic-ai/claude-code --quiet 2>&1 \
            && log "Claude Code native install complete." \
            || log "WARNING: Claude Code install failed."
    fi

    # Ensure ~/.local/bin is on the PATH for the user's shell profile
    local profile_file="$ACTUAL_HOME/.bashrc"
    [[ -f "$ACTUAL_HOME/.zshrc" ]] && profile_file="$ACTUAL_HOME/.zshrc"
    if ! grep -q '\.local/bin' "$profile_file" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$profile_file"
        chown "$ACTUAL_USER":"$ACTUAL_USER" "$profile_file"
        log "Added ~/.local/bin to PATH in $profile_file"
    fi

}

# claude_code removed — Anthropic notified OpenClaw users (2026-04-04) that
# the claude-cli path counts as third-party harness usage requiring Extra Usage.
# The bundled backend is removed in OpenClaw source. Use Anthropic API keys
# directly if Anthropic models are needed.
# register_tool claude_code
