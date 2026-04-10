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
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
TAVILY_API_KEY=${TAVILY_API_KEY:-}
GITHUB_TOKEN=${GITHUB_PAT:-}
POST_BRIDGE_API_KEY=${POST_BRIDGE_API_KEY:-}
OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN:-}
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-}
SUPABASE_URL=${SUPABASE_URL:-}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
OLLAMA_API_KEY=ollama-local
EOF

    # Append tool-specific env vars from loaded tool modules
    local name
    for name in "${TOOL_NAMES[@]:-}"; do
        local exports="${TOOL_SYSTEMD_EXPORTS[$name]:-}"
        [[ -z "$exports" ]] && continue
        local _export_vars var
        IFS=' ' read -ra _export_vars <<< "$exports"
        for var in "${_export_vars[@]}"; do
            local value="${!var:-}"
            has_effective_value "$value" || continue
            echo "${var}=${value}" | uas tee -a "$envd_file" > /dev/null
        done
    done

    local sanitized_envd="${envd_file}.tmp"
    : > "$sanitized_envd"
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local value="${line#*=}"
        has_effective_value "$value" || continue
        printf '%s\n' "$line" >> "$sanitized_envd"
    done < "$envd_file"
    mv "$sanitized_envd" "$envd_file"

    chmod 600 "$envd_file"

    # Make the current user manager pick up the fresh environment immediately
    # so services can rely on environment.d instead of embedding secrets.
    local import_vars=(
        MINIMAX_API_KEY
        GEMINI_API_KEY
        GOOGLE_API_KEY
        ANTHROPIC_API_KEY
        TAVILY_API_KEY
        GITHUB_TOKEN
        POST_BRIDGE_API_KEY
        OPENCLAW_GATEWAY_TOKEN
        TELEGRAM_BOT_TOKEN
        SUPABASE_URL
        SUPABASE_ANON_KEY
        OLLAMA_API_KEY
    )
    uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" \
        systemctl --user unset-environment OPENAI_API_KEY CODEX_API_KEY 2>/dev/null || true
    for name in "${TOOL_NAMES[@]:-}"; do
        local exports="${TOOL_SYSTEMD_EXPORTS[$name]:-}"
        [[ -z "$exports" ]] && continue
        local _export_vars var
        IFS=' ' read -ra _export_vars <<< "$exports"
        for var in "${_export_vars[@]}"; do
            local value="${!var:-}"
            has_effective_value "$value" || continue
            import_vars+=("$var")
        done
    done
    uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" OLLAMA_API_KEY="ollama-local" \
        systemctl --user import-environment "${import_vars[@]}" 2>/dev/null || true
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
    mkdir -p "$ACTUAL_HOME/.npm"
    sudo chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$ACTUAL_HOME/.openclaw"
    sudo chown -R "$ACTUAL_USER":"$ACTUAL_USER" "$ACTUAL_HOME/.npm" 2>/dev/null || true
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
    
    # Create the exec-approvals.json with allowlist for host-level helpers.
    # These tools need to run on the gateway (host) not in sandbox.
    # Schema: per-agent allowlists under agents.<id>.allowlist (see docs/tools/exec-approvals.md)
    cat << EOF | uas tee "$approvals_file" > /dev/null
{
  "version": 1,
  "defaults": {
    "security": "full",
    "ask": "off",
    "askFallback": "deny"
  },
  "agents": {
    "main": {
      "allowlist": [
        {"pattern": "$ACTUAL_HOME/.local/bin/gws"},
        {"pattern": "$ACTUAL_HOME/.local/bin/codex"},
        {"pattern": "/usr/local/bin/gws"},
        {"pattern": "/usr/bin/gws"},
        {"pattern": "/usr/local/bin/codex"},
        {"pattern": "/usr/bin/codex"},
        {"pattern": "/root/.local/bin/gws"},
        {"pattern": "/root/.local/bin/codex"}
      ]
    }
  }
}
EOF
    chmod 600 "$approvals_file"
    log "Exec-approvals configured for gws and codex."
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

    # 2. Setup exec-approvals.json for host-level tools (gws, codex)
    setup_exec_approvals

    # 3. Run Python Patch Scripts
    log "  Step 1: Cleanup stale keys..."
    uas python3 "$SCRIPT_DIR/config/patch-stale-keys.py" --config "$config_file"

    log "  Step 2: Apply core configuration..."
    # Build sandbox env JSON from tool modules
    local sandbox_env_json="{"
    local _sep=""
    for name in "${TOOL_NAMES[@]:-}"; do
        local _sandbox_vars="${TOOL_SANDBOX_ENV[$name]:-}"
        [[ -z "$_sandbox_vars" ]] && continue
        local var
        # Ensure we split on spaces even if the main script restricts IFS
        local IFS=$' \n\t'
        for var in $_sandbox_vars; do
            sandbox_env_json+="${_sep}\"${var}\":\"${!var:-}\""
            _sep=","
        done
    done
    sandbox_env_json+="}"

    # Pass all necessary env vars to the script
    uas env \
        MINIMAX_API_KEY="$MINIMAX_API_KEY" \
        GEMINI_API_KEY="$GEMINI_API_KEY" \
        ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
        TAVILY_API_KEY="${TAVILY_API_KEY:-}" \
        SANDBOX_ENV_JSON="$sandbox_env_json" \
        POST_BRIDGE_API_KEY="${POST_BRIDGE_API_KEY:-}" \
        OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN" \
        TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}" \
        TELEGRAM_ALLOWED_USERS="${TELEGRAM_ALLOWED_USERS:-}" \
        WHATSAPP_ALLOWED_USERS="${WHATSAPP_ALLOWED_USERS:-}" \
        WHATSAPP_GROUP_ID="${WHATSAPP_GROUP_ID:-}" \
        WHATSAPP_GROUP_ALLOW_FROM="${WHATSAPP_GROUP_ALLOW_FROM:-}" \
        SUPABASE_URL="${SUPABASE_URL:-}" \
        SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
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
