#!/usr/bin/env bash
# 
# @intent Comprehensive health check suite for all OpenClaw services (§22).
# @complexity 3
# 

# ── 22. DEVICE SCOPE ROTATION ─────────────────────────────────────────────────
rotate_device_scopes() {
    log "Rotating device scopes..."
    
    # Run rotation script
    uas env OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN" python3 - <<EOF
import json, subprocess, sys, os
gw_token = os.environ.get('OPENCLAW_GATEWAY_TOKEN', '')
token_args = ['--token', gw_token] if gw_token else []

result = subprocess.run(['openclaw', 'devices', 'list', '--json'] + token_args, capture_output=True, text=True)
if result.returncode != 0:
    print("No paired devices — skipping.")
    sys.exit(0)

devices = json.loads(result.stdout).get('devices', [])
for dev in devices:
    did = dev.get('id') or dev.get('deviceId', '')
    if not did: continue
    subprocess.run(['openclaw', 'devices', 'rotate', '--device', did, '--role', 'operator', 
                   '--scope', 'operator.admin', '--scope', 'operator.approvals', 
                   '--scope', 'operator.pairing', '--scope', 'operator.write', '--scope', 'operator.read'], 
                   capture_output=True)
EOF
}

# ── 22a. OLLAMA HEALTH ────────────────────────────────────────────────────────
check_ollama() {
    if curl -sf http://127.0.0.1:11434/ >/dev/null 2>&1; then
        log "[HEALTH] PASS — Ollama is responding"
        return 0
    else
        log "[HEALTH] FAIL — Ollama is not responding"
        return 1
    fi
}

# ── 22b. GATEWAY HEALTH ───────────────────────────────────────────────────────
check_gateway() {
    local state; state=$(uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user is-active openclaw-gateway.service 2>/dev/null || echo "inactive")
    if [[ "$state" == "active" ]]; then
        if ss -tlnp 2>/dev/null | grep -q ":18789"; then
            log "[HEALTH] PASS — Gateway active and listening on :18789"
            return 0
        else
            log "[HEALTH] WARN — Gateway unit active but port 18789 not detected"
            return 0
        fi
    else
        log "[HEALTH] FAIL — Gateway is not active (state: $state)"
        return 1
    fi
}

# ── 22c. VAULT HEALTH ─────────────────────────────────────────────────────────
check_vault() {
    if [[ -d "$OBSIDIAN_VAULT_PATH" ]]; then
        log "[HEALTH] PASS — Obsidian vault accessible: $OBSIDIAN_VAULT_PATH"
        return 0
    else
        log "[HEALTH] FAIL — Obsidian vault not found"
        return 1
    fi
}

# ── 22d. INTEGRATION HEALTH ───────────────────────────────────────────────────
check_integrations() {
    # GitHub
    uas env GH_CONFIG_DIR="$ACTUAL_HOME/.config/gh" gh auth status >/dev/null 2>&1 \
        && log "[HEALTH] PASS — GitHub CLI authenticated" \
        || log "[HEALTH] WARN — GitHub CLI not authenticated"

    # Pandoc
    command -v pandoc >/dev/null 2>&1 \
        && log "[HEALTH] PASS — pandoc available" \
        || log "[HEALTH] WARN — pandoc not found"

    # Gogcli
    command -v gog >/dev/null 2>&1 \
        && log "[HEALTH] PASS — gogcli available" \
        || log "[HEALTH] WARN — gogcli not found"
}

# ── 22e. APPARMOR HEALTH ──────────────────────────────────────────────────────
check_apparmor_denials() {
    local pid; pid=$(uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user show openclaw-gateway.service --property=MainPID --value 2>/dev/null || echo "0")
    if [[ "$pid" != "0" ]]; then
        local denials; denials=$(sudo journalctl -k --since "10 min ago" | grep -i "apparmor.*DENIED" | grep -c "pid=$pid" || echo "0")
        if [[ "$denials" -gt 0 ]]; then
            log "[HEALTH] WARN — $denials AppArmor denial(s) for gateway pid $pid"
        else
            log "[HEALTH] PASS — No AppArmor denials for gateway"
        fi
    fi
}

# ── MASTER HEALTH CHECK ───────────────────────────────────────────────────────
run_health_suite() {
    log "Running post-deployment health checks..."
    local errors=0
    
    check_ollama || ((errors++))
    check_gateway || ((errors++))
    check_vault || ((errors++))
    check_integrations
    check_apparmor_denials

    if [[ $errors -gt 0 ]]; then
        log "WARNING: $errors critical health check(s) failed."
    else
        log "All critical health checks passed."
    fi
}
