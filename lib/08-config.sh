#!/usr/bin/env bash
# 
# @intent OpenClaw configuration state management and JSON patching (§12-§15).
# @complexity 3
# 

# ── 12. STOP GATEWAY ──────────────────────────────────────────────────────────
stop_gateway() {
    log "Stopping OpenClaw gateway..."
    oc gateway stop 2>/dev/null || true
    sleep 2
    pkill -u "$ACTUAL_USER" -f "openclaw-gateway" 2>/dev/null || true

    # Purge existing systemd units for a clean install
    local unit_base="$ACTUAL_HOME/.config/systemd/user"
    uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user disable openclaw-gateway.service 2>/dev/null || true
    rm -f "$unit_base/openclaw-gateway.service" "$unit_base/default.target.wants/openclaw-gateway.service" 2>/dev/null || true
    rm -rf "$unit_base/openclaw-gateway.service.d" 2>/dev/null || true
}

# ── 12a. SYSTEMD USER ENVIRONMENT ─────────────────────────────────────────────
setup_systemd_env() {
    log "Writing systemd user environment..."
    local envd_dir="$ACTUAL_HOME/.config/environment.d"
    local envd_file="$envd_dir/openclaw.conf"
    uas mkdir -p "$envd_dir"

    # Write environment variables that all timer services inherit
    cat <<EOF | uas tee "$envd_file" > /dev/null
MINIMAX_API_KEY=${MINIMAX_API_KEY}
GEMINI_API_KEY=${GEMINI_API_KEY}
GOOGLE_API_KEY=${GEMINI_API_KEY}
NVIDIA_API_KEY=${NVIDIA_API_KEY:-}
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
TAVILY_API_KEY=${TAVILY_API_KEY:-}
GITHUB_TOKEN=${GITHUB_PAT:-}
POST_BRIDGE_API_KEY=${POST_BRIDGE_API_KEY:-}
GOG_ACCOUNT=${GOG_ACCOUNT:-}
EOF
    chmod 600 "$envd_file"
}

# ── 12b. SYSTEMD LINGER ───────────────────────────────────────────────────────
enable_linger() {
    log "Enabling systemd linger for $ACTUAL_USER..."
    loginctl enable-linger "$ACTUAL_USER"
    mkdir -p "$ACTUAL_HOME/.config/systemd/user"
    chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$ACTUAL_HOME/.config/systemd"
}

# ── 13. HARDEN PERMISSIONS ────────────────────────────────────────────────────
harden_permissions() {
    log "Securing OpenClaw directories..."
    mkdir -p "$ACTUAL_HOME/.openclaw"
    sudo chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$ACTUAL_HOME/.openclaw"
    chmod 700 "$ACTUAL_HOME/.openclaw"
    chmod 600 "$ENV_FILE"
}

# ── 14. BACKUP CONFIG ─────────────────────────────────────────────────────────
backup_config() {
    local config_file="$ACTUAL_HOME/.openclaw/openclaw.json"
    if [[ -f "$config_file" ]]; then
        local backup
        backup="${config_file}.bak.$(date +%s)"
        cp "$config_file" "$backup"
        log "Config backed up to: $backup"
        find "$(dirname "$config_file")" -maxdepth 1 -name "openclaw.json.bak.*" | sort -rn | tail -n +4 | xargs rm -f 2>/dev/null || true
    fi
}

# ── 15. PATCH CONFIG ──────────────────────────────────────────────────────────
patch_config() {
    log "Applying configuration patches..."
    local config_file="$ACTUAL_HOME/.openclaw/openclaw.json"
    
    # 1. Resolve/Generate Gateway Token
    if [[ -z "${OPENCLAW_GATEWAY_TOKEN:-}" ]]; then
        local existing; existing=$(python3 -c "import json; c=json.load(open('$config_file')) if open('$config_file') else {}; t=c.get('gateway',{}).get('auth',{}).get('token',''); print(t if len(t)>=32 else '')" 2>/dev/null || true)
        if [[ -n "$existing" ]]; then
            OPENCLAW_GATEWAY_TOKEN="$existing"
        else
            OPENCLAW_GATEWAY_TOKEN="$(openssl rand -hex 32)"
            grep -q "OPENCLAW_GATEWAY_TOKEN" "$ENV_FILE" && sed -i "s/^OPENCLAW_GATEWAY_TOKEN=.*/OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN/" "$ENV_FILE" || echo "OPENCLAW_GATEWAY_TOKEN=$OPENCLAW_GATEWAY_TOKEN" >> "$ENV_FILE"
        fi
        export OPENCLAW_GATEWAY_TOKEN
    fi

    # 2. Run Python Patch Scripts
    log "  Step 1: Cleanup stale keys..."
    uas python3 "$SCRIPT_DIR/config/patch-stale-keys.py" --config "$config_file"

    log "  Step 2: Apply core configuration..."
    # Pass all necessary env vars to the script
    uas env \
        MINIMAX_API_KEY="$MINIMAX_API_KEY" \
        GEMINI_API_KEY="$GEMINI_API_KEY" \
        ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
        GOG_ACCOUNT="${GOG_ACCOUNT:-}" \
        GOG_KEYRING_PASSWORD="${GOG_KEYRING_PASSWORD:-}" \
        POST_BRIDGE_API_KEY="${POST_BRIDGE_API_KEY:-}" \
        NVIDIA_API_KEY="${NVIDIA_API_KEY:-}" \
        OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN" \
        ACTUAL_HOME="$ACTUAL_HOME" \
        python3 "$SCRIPT_DIR/config/apply-config.py" --config "$config_file"
}
