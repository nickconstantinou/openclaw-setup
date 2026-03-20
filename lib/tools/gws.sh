#!/usr/bin/env bash
#
# @intent Google Workspace CLI (gws) tool module.
# @complexity 2
#

TOOL_APPARMOR_RULES[gws]=$(cat <<'RULES'
  # ── Google Workspace CLI (gws / @googleworkspace/cli) ───────────────────────
  # gws is an npm global package
  /usr/local/bin/gws                   rix,
  /usr/bin/gws                         rix,
  # AppArmor resolves symlinks at exec time — the symlink at /usr/local/bin/gws
  # points to the real ELF binary below. That path only gets 'r' from the broad
  # node_modules/** rule, so we need an explicit 'ix' here.
  /usr/lib/node_modules/@googleworkspace/cli/node_modules/.bin_real/gws  ix,
  # env is needed for #!/usr/bin/env node shebang
  /usr/bin/env                         ix,
  # node runtime for gws
  /usr/bin/node                        ix,
  # gws config dir — OAuth credentials stored after `gws auth login`
  @{HOME}/.config/gws/                 rw,
  @{HOME}/.config/gws/**               rw,
RULES
)

TOOL_ENV_PLACEHOLDERS[gws]="GOOGLE_WORKSPACE_CLI_CLIENT_ID=REPLACE_ME
GOOGLE_WORKSPACE_CLI_CLIENT_SECRET=REPLACE_ME
GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file"

TOOL_SYSTEMD_EXPORTS[gws]="GOOGLE_WORKSPACE_CLI_CLIENT_ID GOOGLE_WORKSPACE_CLI_CLIENT_SECRET GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND"
TOOL_SANDBOX_ENV[gws]="GOOGLE_WORKSPACE_CLI_CLIENT_ID GOOGLE_WORKSPACE_CLI_CLIENT_SECRET GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND"

# ── 7d. INSTALL GCLOUD CLI ────────────────────────────────────────────────────
_install_gcloud() {
    log "Installing Google Cloud CLI (gcloud)..."
    if command -v gcloud >/dev/null 2>&1; then
        log "gcloud already installed: $(gcloud version 2>/dev/null | head -1 || echo 'unknown')"
        return 0
    fi

    local keyring=/usr/share/keyrings/cloud.google.gpg
    local list=/etc/apt/sources.list.d/google-cloud-sdk.list

    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
        | gpg --dearmor -o "$keyring" 2>&1 \
        && echo "deb [signed-by=$keyring] https://packages.cloud.google.com/apt cloud-sdk main" \
            > "$list" \
        && apt-get update -qq \
        && apt_install google-cloud-cli \
        && log "gcloud installed: $(gcloud version 2>/dev/null | head -1)" \
        || log "WARNING: gcloud install failed — gws auth setup will not work."
}

# ── 7e. INSTALL GWS (Google Workspace CLI) ────────────────────────────────────
install_gws() {
    _install_gcloud

    log "Installing @googleworkspace/cli (gws)..."

    # Always ensure /usr/local/bin/gws points directly to the native binary,
    # bypassing the npm JS shim (which chains through /usr/bin/env and is blocked
    # by AppArmor when run inside the gateway process).
    local _gws_native="/usr/lib/node_modules/@googleworkspace/cli/node_modules/.bin_real/gws"
    if [[ -f "$_gws_native" ]]; then
        ln -sf "$_gws_native" /usr/local/bin/gws
        log "gws: linked native binary to /usr/local/bin/gws (bypasses npm shim)"
    fi

    if command -v gws >/dev/null 2>&1; then
        local current_ver; current_ver=$(gws --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        local latest_ver; latest_ver=$(uas npm view @googleworkspace/cli version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        if [[ "$current_ver" == "$latest_ver" ]] && [[ "$current_ver" != "unknown" ]]; then
            log "gws already installed ($current_ver) and is up-to-date. Skipping upgrade."
            return 0
        fi
        log "gws update available: $current_ver → $latest_ver. Attempting upgrade..."
    fi

    if HOME=/root npm install -g @googleworkspace/cli --quiet 2>&1; then
        log "gws installed: $(command -v gws 2>/dev/null || echo 'not found in PATH')"
        # Fix binary permissions (robust - no errors if files missing)
        chmod +x /usr/lib/node_modules/@googleworkspace/cli/node_modules/.bin_real/gws 2>/dev/null || true
        chmod +x /usr/lib/node_modules/@googleworkspace/cli/run-gws.js 2>/dev/null || true
        # Point /usr/local/bin/gws at the native binary (AppArmor already has rix for this path)
        [[ -f "$_gws_native" ]] && ln -sf "$_gws_native" /usr/local/bin/gws || true
    else
        log "WARNING: gws install failed."
        return
    fi

    # Write auth hint
    local hint="$ACTUAL_HOME/.openclaw/workspace/google-auth-setup.md"
    mkdir -p "$(dirname "$hint")"
    cat > "$hint" << 'EOF'
# Google Workspace Setup (gws)
1. Obtain OAuth 2.0 credentials from Google Cloud Console:
   https://console.cloud.google.com/ → APIs & Services → Credentials → Create OAuth client ID
2. Add to ~/.openclaw/.env:
   GOOGLE_WORKSPACE_CLI_CLIENT_ID=<your-client-id>
   GOOGLE_WORKSPACE_CLI_CLIENT_SECRET=<your-client-secret>
   GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file   # headless-safe; uses local .encryption_key
3. Run: gws auth setup   (one-time: configures the OAuth client)
4. Run: gws auth login   (browser OAuth flow; creds stored in ~/.config/gws/)
EOF
    chown "$ACTUAL_USER":"$ACTUAL_USER" "$hint"

    # Run gws auth setup now if credentials are available
    local client_id="${GOOGLE_WORKSPACE_CLI_CLIENT_ID:-}"
    local client_secret="${GOOGLE_WORKSPACE_CLI_CLIENT_SECRET:-}"
    local sentinel_id="REPLACE_ME"
    local sentinel_secret="REPLACE_ME"

    if [[ -n "$client_id" && -n "$client_secret" \
          && "$client_id" != *"$sentinel_id"* \
          && "$client_secret" != *"$sentinel_secret"* ]]; then
        log "Running gws auth setup (credentials found)..."
        if sudo -u "$ACTUAL_USER" env \
                HOME="$ACTUAL_HOME" \
                GOOGLE_WORKSPACE_CLI_CLIENT_ID="$client_id" \
                GOOGLE_WORKSPACE_CLI_CLIENT_SECRET="$client_secret" \
                GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file \
                gws auth setup 2>&1; then
            log "gws auth setup completed."
        else
            log "WARNING: gws auth setup failed — run manually after install."
        fi
    else
        log "gws auth setup SKIPPED — credentials not set (add to ~/.openclaw/.env and re-run)."
    fi
}

register_tool gws
