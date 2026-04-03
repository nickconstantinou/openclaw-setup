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
            
            # GAP 2: Deep Application Health (docs/gateway/health.md)
            if oc health --json --timeout 5000 >/dev/null 2>&1; then
                log "[HEALTH] PASS — Gateway health probe (WS) OK"
            else
                log "[HEALTH] WARN — Gateway health probe (WS) failed or timed out"
            fi
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

    # Google Workspace CLI (gws)
    command -v gws >/dev/null 2>&1 \
        && log "[HEALTH] PASS — gws (Google Workspace CLI) available" \
        || log "[HEALTH] WARN — gws not found"
}

# ── 22e. APPARMOR HEALTH ──────────────────────────────────────────────────────
check_apparmor_denials() {
    local pid; pid=$(uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user show openclaw-gateway.service --property=MainPID --value 2>/dev/null || echo "0")
    if [[ "$pid" != "0" ]]; then
        local start_time
        start_time=$(uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user show openclaw-gateway.service --property=ActiveEnterTimestamp --value 2>/dev/null || echo "")
        local since_arg="10 min ago"
        if [[ -n "$start_time" ]]; then
            # systemctl returns e.g. "Wed 2026-03-04 10:05:34 GMT" which journalctl
            # can't parse. Reformat to ISO 8601 (journalctl accepts "YYYY-MM-DD HH:MM:SS").
            local iso_time; iso_time=$(date -d "$start_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "")
            [[ -n "$iso_time" ]] && since_arg="$iso_time"
        fi
        # 'grep -c' outputs "0" on no matches but exits 1, causing '|| echo "0"' to
        # append a second zero and produce a multiline value that breaks arithmetic.
        # Capture count and exit code separately to avoid this.
        local denials=0
        denials=$(sudo journalctl -k --since="$since_arg" 2>/dev/null | grep -i "apparmor.*DENIED" | grep -c "pid=$pid" 2>/dev/null) || denials=0
        if [[ "$denials" -gt 0 ]]; then
            log "[HEALTH] WARN — $denials AppArmor denial(s) for gateway pid $pid"
        else
            log "[HEALTH] PASS — No AppArmor denials for gateway"
        fi
    fi
}

# ── 22f. TAILSCALE HEALTH ─────────────────────────────────────────────────────
check_tailscale() {
    if command -v tailscale >/dev/null 2>&1; then
        local ts_status; ts_status=$(tailscale status --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('BackendState','unknown'))" 2>/dev/null || echo "unknown")
        if [[ "$ts_status" == "Running" ]]; then
            log "[HEALTH] PASS — Tailscale is running"
            return 0
        else
            log "[HEALTH] WARN — Tailscale is not running (state: $ts_status)"
            return 1
        fi
    fi
    return 0
}

# ── 22e-2. APPARMOR ENFORCED ──────────────────────────────────────────────────
check_apparmor_enforced() {
    # If kernel has no AppArmor or it's disabled
    if [[ ! -f /sys/module/apparmor/parameters/enabled ]] || [[ "$(cat /sys/module/apparmor/parameters/enabled)" == "N" ]]; then
        log "[HEALTH] INFO — AppArmor not supported or disabled by kernel"
        return 0
    fi

    local profile="openclaw-gateway"
    local pid; pid=$(uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user show openclaw-gateway.service --property=MainPID --value 2>/dev/null || echo "0")
    if [[ "$pid" != "0" ]] && [[ -r "/proc/$pid/attr/current" ]]; then
        local current_label
        current_label=$(cat "/proc/$pid/attr/current" 2>/dev/null || echo "")
        if [[ "$current_label" == *"$profile"* ]]; then
            log "[HEALTH] PASS — Gateway process confined by AppArmor profile '$profile'"
            return 0
        fi
        if [[ -n "$current_label" ]] && [[ "$current_label" != "unconfined" ]]; then
            log "[HEALTH] WARN — Gateway process label is '$current_label' (expected '$profile')"
        else
            log "[HEALTH] FAIL — [SEC-003] Gateway process is UNCONFINED"
        fi
        return 1
    fi

    # Check if aa-status is available to verify enforcement list
    if command -v aa-status >/dev/null 2>&1; then
        local status_json; status_json=$(sudo aa-status --json 2>/dev/null || echo "{}")
        # Check if openclaw-gateway is in 'enforce' list
        if ! echo "$status_json" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if '$profile' in d.get('profiles', {}) and d['profiles']['$profile'] == 'enforce' else 1)" 2>/dev/null; then
            # Check if it's in complain mode
            if echo "$status_json" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if '$profile' in d.get('profiles', {}) and d['profiles']['$profile'] == 'complain' else 1)" 2>/dev/null; then
                log "[HEALTH] WARN — AppArmor profile '$profile' in COMPLAIN mode"
                return 0
            else
                log "[HEALTH] FAIL — [SEC-003] AppArmor profile '$profile' NOT ENFORCED"
                return 1
            fi
        fi
    fi

    log "[HEALTH] PASS — AppArmor profile '$profile' is enforced"
    return 0
}

# ── MASTER HEALTH CHECK ───────────────────────────────────────────────────────
run_health_suite() {
    log "Running post-deployment health checks..."
    local errors=0
    
    check_ollama || ((++errors))
    check_gateway || ((++errors))
    check_vault || ((++errors))
    check_integrations
    check_apparmor_enforced || ((++errors))
    check_apparmor_denials
    check_tailscale

    if [[ $errors -gt 0 ]]; then
        log "WARNING: $errors critical health check(s) failed."
    else
        log "All critical health checks passed."
    fi

    # GAP 3: Deep Status Probe (docs/gateway/health.md)
    log "Running per-channel status probe..."
    oc status --deep 2>/dev/null || log "[HEALTH] WARN — Deep status probe failed."
}
