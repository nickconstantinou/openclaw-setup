#!/usr/bin/env bash
#
# @intent LightPanda headless browser tool module — CDP-compatible, 10x faster than Chrome.
# @complexity 2
#

TOOL_APPARMOR_RULES[lightpanda]=$(cat <<'RULES'
  # ── LightPanda Browser ───────────────────────────────────────────────────────
  @{HOME}/.openclaw/tools/lightpanda/**          mrwix,
  /usr/bin/node                                   ix,
  /usr/local/bin/node                             ix,
  network inet stream,
  network inet6 stream,
RULES
)

TOOL_ENV_PLACEHOLDERS[lightpanda]="LIGHTPANDA_HOST=127.0.0.1\nLIGHTPANDA_PORT=9222"
TOOL_SYSTEMD_EXPORTS[lightpanda]="LIGHTPANDA_HOST LIGHTPANDA_PORT"
TOOL_SANDBOX_ENV[lightpanda]="LIGHTPANDA_HOST LIGHTPANDA_PORT"

# ── INSTALL LIGHTPANDA ────────────────────────────────────────────────────────
install_lightpanda() {
    local install_dir="$ACTUAL_HOME/.openclaw/tools/lightpanda"

    if [ -d "$install_dir/node_modules/@lightpanda/browser" ]; then
        log "LightPanda already installed — skipping."
        return 0
    fi

    log "Installing LightPanda browser..."
    mkdir -p "$install_dir"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$install_dir"

    local npm_cache; npm_cache=$(mktemp -d)
    chown "$ACTUAL_USER:$ACTUAL_USER" "$npm_cache"

    if uas env npm_config_cache="$npm_cache" npm --prefix "$install_dir" install @lightpanda/browser --save \
        2>&1 | while IFS= read -r line; do log "  lightpanda: $line"; done; then
        log "LightPanda installed successfully."
    else
        log "WARNING: LightPanda install failed. Browser tools may be unavailable."
    fi
    rm -rf "$npm_cache"
}

register_tool lightpanda
