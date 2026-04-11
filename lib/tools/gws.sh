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
  # points to the real ELF binary below. Package layouts vary by version, so
  # allow both the older .bin_real path and the newer bin/gws path.
  /usr/lib/node_modules/@googleworkspace/cli/node_modules/.bin_real/gws  ix,
  /usr/lib/node_modules/@googleworkspace/cli/bin/gws  ix,
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

GWS_PRIMARY_NATIVE_BIN="/usr/lib/node_modules/@googleworkspace/cli/bin/gws"
GWS_LEGACY_NATIVE_BIN="/usr/lib/node_modules/@googleworkspace/cli/node_modules/.bin_real/gws"
GWS_ENTRYPOINT_PATHS=(
    "/usr/bin/gws"
    "/usr/local/bin/gws"
)

resolve_gws_native_bin() {
    local candidate
    for candidate in "$GWS_PRIMARY_NATIVE_BIN" "$GWS_LEGACY_NATIVE_BIN"; do
        [[ -x "$candidate" ]] && printf '%s\n' "$candidate" && return 0
    done
    return 1
}

gws_entrypoint_is_native() {
    local path="$1"
    local native="${2:-}"
    [[ -n "$native" ]] || native=$(resolve_gws_native_bin 2>/dev/null || true)
    [[ -n "$native" ]] || return 1

    local resolved
    resolved=$(readlink -f "$path" 2>/dev/null || true)
    [[ -n "$resolved" ]] || return 1
    [[ "$resolved" == "$native" ]]
}

repair_gws_entrypoints() {
    local native
    native=$(resolve_gws_native_bin 2>/dev/null || true)
    if [[ -z "$native" ]]; then
        log "WARNING: gws native binary not found under @googleworkspace/cli; cannot normalize entrypoints yet."
        return 1
    fi

    chmod +x "$native" 2>/dev/null || true

    local path failed=0
    for path in "${GWS_ENTRYPOINT_PATHS[@]}"; do
        if gws_entrypoint_is_native "$path" "$native"; then
            continue
        fi
        if ln -sf "$native" "$path"; then
            log "gws: normalized $path -> $native"
        else
            log "WARNING: gws: failed to normalize $path -> $native"
            failed=1
        fi
    done
    [[ $failed -eq 0 ]]
}

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
    repair_gws_entrypoints 2>/dev/null || true

    if command -v gws >/dev/null 2>&1; then
        local current_ver
        local gws_native
        gws_native=$(resolve_gws_native_bin 2>/dev/null || true)
        if [[ -n "$gws_native" ]]; then
            current_ver=$("$gws_native" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        else
            current_ver=$(gws --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        fi
        local latest_ver; latest_ver=$(uas npm view @googleworkspace/cli version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        if [[ "$current_ver" == "$latest_ver" ]] && [[ "$current_ver" != "unknown" ]]; then
            repair_gws_entrypoints || true
            log "gws already installed ($current_ver) and is up-to-date. Entry points normalized."
            return 0
        fi
        log "gws update available: $current_ver → $latest_ver. Attempting upgrade..."
    fi

    if HOME=/root npm install -g @googleworkspace/cli --quiet 2>&1; then
        log "gws installed: $(command -v gws 2>/dev/null || echo 'not found in PATH')"
        # Fix binary permissions (robust - no errors if files missing)
        chmod +x "$GWS_LEGACY_NATIVE_BIN" 2>/dev/null || true
        chmod +x "$GWS_PRIMARY_NATIVE_BIN" 2>/dev/null || true
        chmod +x /usr/lib/node_modules/@googleworkspace/cli/run-gws.js 2>/dev/null || true
        repair_gws_entrypoints || true
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

    # Restore pre-existing credentials (headless auth bypass).
    # If GWS_CREDENTIALS_B64 and GWS_ENCRYPTION_KEY_B64 are set in .env, write the
    # encrypted credentials and key directly — no browser / gws auth login required.
    #
    # To export from a working machine:
    #   GWS_CREDENTIALS_B64=$(base64 -w0 ~/.config/gws/credentials.enc)
    #   GWS_ENCRYPTION_KEY_B64=$(base64 -w0 ~/.config/gws/.encryption_key)
    # Then add both values to ~/.openclaw/.env.
    local creds_b64="${GWS_CREDENTIALS_B64:-}"
    local key_b64="${GWS_ENCRYPTION_KEY_B64:-}"

    if [[ -n "$creds_b64" && "$creds_b64" != "REPLACE_ME" \
       && -n "$key_b64"   && "$key_b64"   != "REPLACE_ME" ]]; then
        log "Restoring gws credentials from env (headless mode)..."
        local gws_dir="$ACTUAL_HOME/.config/gws"
        uas mkdir -p "$gws_dir"
        echo "$creds_b64" | base64 -d > "$gws_dir/credentials.enc"
        echo "$key_b64"   | base64 -d > "$gws_dir/.encryption_key"
        chmod 600 "$gws_dir/credentials.enc" "$gws_dir/.encryption_key"
        chown "$ACTUAL_USER:$ACTUAL_USER" "$gws_dir/credentials.enc" "$gws_dir/.encryption_key"

        # Verify the restored credentials work
        if sudo -u "$ACTUAL_USER" env \
                HOME="$ACTUAL_HOME" \
                GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file \
                gws auth status 2>/dev/null | grep -q '"token_valid": true'; then
            log "  gws credentials restored and valid — gws auth login not required."
        else
            log "  WARNING: Restored credentials did not validate. Run gws auth login manually via SSH tunnel."
        fi
    else
        log "  GWS_CREDENTIALS_B64 not set — gws auth login required after install."
        log "  To skip this on future installs, add to .env:"
        log "    GWS_CREDENTIALS_B64=\$(base64 -w0 ~/.config/gws/credentials.enc)"
        log "    GWS_ENCRYPTION_KEY_B64=\$(base64 -w0 ~/.config/gws/.encryption_key)"
    fi
}

register_tool gws
