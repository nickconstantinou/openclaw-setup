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

    # Write core environment variables that all timer services inherit
    cat <<EOF | uas tee "$envd_file" > /dev/null
MINIMAX_API_KEY=${MINIMAX_API_KEY}
GEMINI_API_KEY=${GEMINI_API_KEY}
GOOGLE_API_KEY=${GEMINI_API_KEY}
TAVILY_API_KEY=${TAVILY_API_KEY:-}
GITHUB_TOKEN=${GITHUB_PAT:-}
POST_BRIDGE_API_KEY=${POST_BRIDGE_API_KEY:-}
TELEGRAM_BOT_TOKEN_CODING=${TELEGRAM_BOT_TOKEN_CODING:-}
TELEGRAM_BOT_TOKEN_MARKETING=${TELEGRAM_BOT_TOKEN_MARKETING:-}
EOF

    # Append tool-specific env vars from loaded tool modules
    local name
    for name in "${TOOL_NAMES[@]:-}"; do
        local exports="${TOOL_SYSTEMD_EXPORTS[$name]:-}"
        [[ -z "$exports" ]] && continue
        local _export_vars var
        IFS=' ' read -ra _export_vars <<< "$exports"
        for var in "${_export_vars[@]}"; do
            echo "${var}=${!var:-}" | uas tee -a "$envd_file" > /dev/null
        done
    done

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

# ── 15a. EXEC APPROVALS FOR HOST-LEVEL TOOLS ─────────────────────────────────
setup_exec_approvals() {
    log "Setting up exec-approvals.json for host-level tools..."
    local approvals_file="$ACTUAL_HOME/.openclaw/exec-approvals.json"
    
    # Create the exec-approvals.json with allowlist for gws and claude_code
    # These tools need to run on the gateway (host) not in sandbox
    # Schema: per-agent allowlists under agents.<id>.allowlist (see docs/tools/exec-approvals.md)
    cat << EOF | uas tee "$approvals_file" > /dev/null
{
  "version": 1,
  "defaults": {
    "security": "full",
    "ask": "on-miss",
    "askFallback": "deny"
  },
  "agents": {
    "main": {
      "allowlist": [
        {"pattern": "$ACTUAL_HOME/.local/bin/gws"},
        {"pattern": "$ACTUAL_HOME/.local/bin/claude"},
        {"pattern": "/usr/local/bin/gws"},
        {"pattern": "/usr/bin/gws"},
        {"pattern": "/usr/local/bin/claude"},
        {"pattern": "/usr/bin/claude"},
        {"pattern": "/root/.local/bin/gws"},
        {"pattern": "/root/.local/bin/claude"}
      ]
    },
    "coding": {
      "allowlist": [
        {"pattern": "$ACTUAL_HOME/.local/bin/gws"},
        {"pattern": "$ACTUAL_HOME/.local/bin/claude"},
        {"pattern": "/usr/local/bin/gws"},
        {"pattern": "/usr/bin/gws"},
        {"pattern": "/usr/local/bin/claude"},
        {"pattern": "/usr/bin/claude"},
        {"pattern": "/root/.local/bin/gws"},
        {"pattern": "/root/.local/bin/claude"}
      ]
    }
  }
}
EOF
    chmod 600 "$approvals_file"
    log "Exec-approvals configured for gws and claude_code."
}

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

    # 2. Setup exec-approvals.json for host-level tools (gws, claude_code)
    setup_exec_approvals

    # 3. Run Python Patch Scripts
    log "  Step 1: Cleanup stale keys..."
    uas python3 "$SCRIPT_DIR/config/patch-stale-keys.py" --config "$config_file"

    log "  Step 2: Apply core configuration..."
    # Pass all necessary env vars to the script
    uas env \
        MINIMAX_API_KEY="$MINIMAX_API_KEY" \
        GEMINI_API_KEY="$GEMINI_API_KEY" \
        ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
        POST_BRIDGE_API_KEY="${POST_BRIDGE_API_KEY:-}" \
        OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN" \
        TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}" \
        TELEGRAM_BOT_TOKEN_CODING="${TELEGRAM_BOT_TOKEN_CODING:-}" \
        TELEGRAM_BOT_TOKEN_MARKETING="${TELEGRAM_BOT_TOKEN_MARKETING:-}" \
        TELEGRAM_ALLOWED_USERS="${TELEGRAM_ALLOWED_USERS:-}" \
        TELEGRAM_ALLOWED_USERS_CODING="${TELEGRAM_ALLOWED_USERS_CODING:-}" \
        TELEGRAM_ALLOWED_USERS_MARKETING="${TELEGRAM_ALLOWED_USERS_MARKETING:-}" \
        WHATSAPP_ALLOWED_USERS="${WHATSAPP_ALLOWED_USERS:-}" \
        OPENCLAW_SANDBOX_MODE="${OPENCLAW_SANDBOX_MODE:-}" \
        ACTUAL_HOME="$ACTUAL_HOME" \
        python3 "$SCRIPT_DIR/config/apply-config.py" --config "$config_file"

    # 3. Patch Tailscale config (trustedProxies + tailscale.mode)
    if command -v tailscale >/dev/null 2>&1 && tailscale status --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if (d.get('BackendState')=='Running' or d.get('TailscaleIPs')) else 1)" 2>/dev/null; then
        log "  Step 3: Patching Tailscale config (trustedProxies + tailscale.mode)..."
        uas python3 - <<'EOF' "$config_file"
import json, sys
config_file = sys.argv[1]
try:
    with open(config_file) as f:
        config = json.load(f)
    gw = config.setdefault("gateway", {})
    # Set trustedProxies to include loopback for Tailscale Serve
    proxies = gw.get("trustedProxies", [])
    if "127.0.0.1" not in proxies:
        proxies.append("127.0.0.1")
        gw["trustedProxies"] = proxies
    # Set tailscale.mode so `oc status` reports correctly
    ts = gw.setdefault("tailscale", {})
    if ts.get("mode") != "serve":
        ts["mode"] = "serve"
    with open(config_file, "w") as f:
        json.dump(config, f, indent=2)
    print("ok")
except Exception as e:
    print(f"error: {e}")
EOF
    fi
}
