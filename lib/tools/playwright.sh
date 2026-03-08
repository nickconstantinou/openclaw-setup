#!/usr/bin/env bash
#
# @intent Playwright/Chromium browser tool module.
# @complexity 2
#

TOOL_APPARMOR_RULES[playwright]=$(cat <<'RULES'
  # ── Chromium/Playwright ─────────────────────────────────────────────────────
  /usr/bin/chromium                    ix,
  /usr/bin/chromium-browser            ix,
  @{HOME}/.cache/ms-playwright/**      mrwix,
  userns,
RULES
)

TOOL_ENV_PLACEHOLDERS[playwright]=""
TOOL_SYSTEMD_EXPORTS[playwright]=""

# ── 7. INSTALL PLAYWRIGHT ─────────────────────────────────────────────────────
install_playwright() {
    log "Installing Chromium dependencies..."
    if command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1; then
        log "Chromium already installed — skipping Playwright install."
    else
        wait_for_apt

        log "  Running playbook: playwright install-deps (as root)..."
        # Use a root-owned cache dir so root's writes don't pollute the user's cache.
        local root_npm_cache; root_npm_cache=$(mktemp -d)
        if env PATH="/usr/bin:/usr/local/bin:$ACTUAL_HOME/.local/bin:$PATH" HOME=/root npm_config_cache="$root_npm_cache" npx -y playwright install-deps chromium 2>&1 | while IFS= read -r line; do log "  playwright-deps: $line"; done; then
            log "  System dependencies installed."
        else
            log "  WARNING: Failed to install Playwright OS dependencies."
        fi
        rm -rf "$root_npm_cache"

        log "  Running playbook: playwright install (as user)..."
        # Separate user-owned cache dir — never shared with the root call above.
        local user_npm_cache; user_npm_cache=$(mktemp -d)
        chown "$ACTUAL_USER:$ACTUAL_USER" "$user_npm_cache"
        if uas env npm_config_cache="$user_npm_cache" npx -y playwright install chromium 2>&1 | while IFS= read -r line; do log "  playwright: $line"; done; then
            log "Chromium browser binaries installed for agent."
        else
            log "WARNING: Playwright install failed. Browser tools may be unavailable."
        fi
        rm -rf "$user_npm_cache"
    fi
}

register_tool playwright
