#!/usr/bin/env bash
#
# @intent Claude Code CLI tool module.
# @complexity 2
#

TOOL_APPARMOR_RULES[claude_code]=$(cat <<'RULES'
  # ── Claude Code — exec delegation ───────────────────────────────────────────
  # Agent invokes Claude Code via exec tool (claude --print / cc wrapper).
  # State in ~/.claude/, binary at ~/.local/bin/claude or /usr/local/bin/claude.
  # Wrapper script lives in ~/.openclaw/bin/cc
  @{HOME}/.claude/                     rw,
  @{HOME}/.claude/**                   rw,
  @{HOME}/.local/bin/claude            ix,
  /usr/local/bin/claude                ix,
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

register_tool claude_code
