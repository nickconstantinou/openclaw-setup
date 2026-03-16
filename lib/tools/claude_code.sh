#!/usr/bin/env bash
#
# @intent Claude Code CLI tool module.
# @complexity 2
#

TOOL_APPARMOR_RULES[claude_code]=$(cat <<'RULES'
  # ── Claude Code — exec delegation ───────────────────────────────────────────
  # Agent invokes Claude Code via exec tool (claude --print / cc wrapper).
  # env is needed for #!/usr/bin/env node shebang
  /usr/bin/env                         ix,
  /usr/bin/node                        ix,
  @{HOME}/.claude/                     rw,
  @{HOME}/.claude/**                   rw,
  @{HOME}/.local/bin/claude            ix,
  /usr/bin/claude                      ix,
  /usr/local/bin/claude                ix,
  # Claude Code self-manages its binary under ~/.local/share/claude/versions/<ver>
  # AppArmor resolves ~/.local/bin/claude → the real ELF path, so we need ix there.
  @{HOME}/.local/share/claude/           r,
  @{HOME}/.local/share/claude/**         r,
  @{HOME}/.local/share/claude/versions/* ix,
  # ~/.openclaw/bin/ — agent exec wrappers (cc, etc.)
  # Scripts need rix (read+inherit+exec) — interpreter must read the script file
  @{HOME}/.openclaw/bin/               rw,
  @{HOME}/.openclaw/bin/*              rix,
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

    log "Installing Claude Code..."
    local bin; bin=$(command -v claude 2>/dev/null || true)
    if [[ -n "$bin" ]]; then
        local current_ver; current_ver=$("$bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        local latest_ver; latest_ver=$(uas npm view @anthropic-ai/claude-code version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        if [[ "$current_ver" == "$latest_ver" ]] && [[ "$current_ver" != "unknown" ]]; then
            log "Claude Code already installed ($current_ver) and is up-to-date. Skipping upgrade."
            return 0
        fi
        log "Claude Code update available: $current_ver → $latest_ver. Attempting upgrade..."
    fi

    if HOME=/root npm install -g @anthropic-ai/claude-code --quiet 2>&1; then
        local new_ver; new_ver=$(command -v claude >/dev/null && claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        log "Claude Code installed/upgraded: $new_ver"
    else
        log "WARNING: Claude Code install failed."
    fi

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

register_tool claude_code
