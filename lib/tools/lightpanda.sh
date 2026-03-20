#!/usr/bin/env bash
#
# @intent LightPanda headless browser tool module — CDP-compatible, 10x faster than Chrome.
# @complexity 2
#

TOOL_APPARMOR_RULES[lightpanda]=$(cat <<'RULES'
  # ── LightPanda Browser ───────────────────────────────────────────────────────
  # npm package install dir
  @{HOME}/.openclaw/tools/lightpanda/**          mrwix,
  # binary download location (npm postinstall writes here)
  @{HOME}/.cache/lightpanda-node/                rw,
  @{HOME}/.cache/lightpanda-node/**              mrwix,
  # /usr/bin/node and network rules already in base profile
RULES
)

# Use actual newlines so inject_tool_env_placeholders splits correctly into
# separate KEY=value pairs (literal \n is NOT a newline in bash strings).
TOOL_ENV_PLACEHOLDERS[lightpanda]="LIGHTPANDA_HOST=127.0.0.1
LIGHTPANDA_PORT=9222"

# Export host/port to the gateway process via systemd environment.d.
# NOT in TOOL_SANDBOX_ENV: the sandbox Docker container cannot reach 127.0.0.1
# on the host, so these values are meaningless (and an empty LIGHTPANDA_PORT
# can break sandbox initialisation).
TOOL_SYSTEMD_EXPORTS[lightpanda]="LIGHTPANDA_HOST LIGHTPANDA_PORT"

# ── INSTALL LIGHTPANDA ────────────────────────────────────────────────────────
install_lightpanda() {
    local install_dir="$ACTUAL_HOME/.openclaw/tools/lightpanda"
    local binary="$ACTUAL_HOME/.cache/lightpanda-node/lightpanda"

    # Idempotency: check for the actual downloaded binary
    if [ -x "$binary" ]; then
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
