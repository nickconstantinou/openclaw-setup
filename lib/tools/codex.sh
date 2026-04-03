#!/usr/bin/env bash
#
# @intent OpenAI Codex CLI tool module — non-interactive code generation agent.
# @complexity 2
#

TOOL_APPARMOR_RULES[codex]=$(cat <<'RULES'
  # ── OpenAI Codex CLI ─────────────────────────────────────────────────────────
  # Codex runs as a Node.js process via npm global install
  /usr/bin/env                         ix,
  /usr/bin/node                        ix,
  # npm global bin location (codex binary symlink)
  /usr/local/bin/codex                 ix,
  @{HOME}/.local/bin/codex             ix,
  # Codex state directory (~/.codex): config, auth, session cache
  @{HOME}/.codex/                      rw,
  @{HOME}/.codex/**                    rw,
  # npm global package install location
  /usr/lib/node_modules/@openai/       r,
  /usr/lib/node_modules/@openai/**     mrwix,
  @{HOME}/.local/lib/node_modules/@openai/   r,
  @{HOME}/.local/lib/node_modules/@openai/** mrwix,
  # Wrapper script
  @{HOME}/.openclaw/bin/cx             rix,
RULES
)

TOOL_ENV_PLACEHOLDERS[codex]="OPENAI_API_KEY=sk-REPLACE_ME_WHEN_READY"
TOOL_SYSTEMD_EXPORTS[codex]="OPENAI_API_KEY"
TOOL_SANDBOX_ENV[codex]="OPENAI_API_KEY"

# ── INSTALL CODEX CLI ─────────────────────────────────────────────────────────
install_codex() {
    if [[ "${OPENAI_API_KEY:-}" == "sk-REPLACE_ME_WHEN_READY" ]] || [[ -z "${OPENAI_API_KEY:-}" ]]; then
        log "Codex CLI SKIPPED — OPENAI_API_KEY not configured."
        return
    fi

    local codex_bin
    codex_bin=$(command -v codex 2>/dev/null || true)

    if [[ -n "$codex_bin" ]]; then
        local current_ver; current_ver=$("$codex_bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        local latest_ver;  latest_ver=$(uas npm view @openai/codex version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")

        if [[ "$current_ver" == "$latest_ver" ]] && [[ "$current_ver" != "unknown" ]]; then
            log "Codex CLI already installed ($current_ver) and up-to-date. Skipping."
        else
            log "Codex CLI update available: $current_ver → $latest_ver. Upgrading..."
            HOME=/root npm install -g @openai/codex@latest --quiet 2>&1 \
                && log "Codex CLI upgraded to $latest_ver." \
                || log "WARNING: Codex CLI upgrade failed — continuing with existing version."
        fi
    else
        log "Installing Codex CLI (@openai/codex)..."
        # Node 22+ required — check before installing
        local node_major; node_major=$(node --version 2>/dev/null | grep -oE '^v[0-9]+' | tr -d 'v' || echo "0")
        if [[ "$node_major" -lt 22 ]]; then
            log "WARNING: Codex CLI requires Node.js 22+. Current: v${node_major}. Skipping install."
            return
        fi

        HOME=/root npm install -g @openai/codex --quiet 2>&1 \
            && log "Codex CLI installed: $(command -v codex 2>/dev/null || echo 'location unknown')" \
            || log "WARNING: Codex CLI install failed. Coding tasks will fall back to Claude Code."
    fi

    # Create cx wrapper at ~/.openclaw/bin/cx
    # Usage: cx "implement a binary search function in src/utils.ts"
    # Runs codex non-interactively with full-auto approval (file edits + shell without prompts)
    local codex_path; codex_path=$(command -v codex 2>/dev/null || true)
    if [[ -n "$codex_path" ]]; then
        local wrapper="$ACTUAL_HOME/.openclaw/bin/cx"
        mkdir -p "$(dirname "$wrapper")"
        cat > "$wrapper" << WRAPEOF
#!/usr/bin/env bash
# cx — non-interactive Codex CLI wrapper
# Usage: cx "<task description>"
# Runs codex exec with full-auto approval (no interactive prompts)
exec "$codex_path" exec --full-auto "\$@"
WRAPEOF
        chmod 755 "$wrapper"
        chown "$ACTUAL_USER:$ACTUAL_USER" "$wrapper"
        log "Codex wrapper installed: $wrapper"
    fi
}

register_tool codex
