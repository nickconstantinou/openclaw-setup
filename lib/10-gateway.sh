#!/usr/bin/env bash
# 
# @intent Gateway service installation and lifecycle management (§18-§20).
# @complexity 3
# 

# ── 18. INSTALL & START GATEWAY ───────────────────────────────────────────────
install_gateway_service() {
    log "Installing gateway service..."
    oc gateway install --force || die "Gateway install failed."

    local unit="$ACTUAL_HOME/.config/systemd/user/openclaw-gateway.service"
    if [[ -f "$unit" ]] && command -v aa-exec >/dev/null 2>&1; then
        local exec_line; exec_line=$(grep "^ExecStart=" "$unit" | head -1)
        local exec_cmd="${exec_line#ExecStart=}"
        if [[ -n "$exec_cmd" ]]; then
            if aa-exec -p openclaw-gateway -- true 2>/dev/null; then
                local dropin_dir="$ACTUAL_HOME/.config/systemd/user/openclaw-gateway.service.d"
                mkdir -p "$dropin_dir"
                cat > "$dropin_dir/apparmor.conf" <<EOF
[Service]
ExecStart=
ExecStart=aa-exec -p openclaw-gateway -- $exec_cmd
EOF
                chown -R "$ACTUAL_USER:$ACTUAL_USER" "$dropin_dir"
                log "AppArmor confinement applied via systemd drop-in."
            else
                log "WARNING: aa-exec found but profile 'openclaw-gateway' is not loaded. Skipping AppArmor confinement."
            fi
        fi
    fi

    # GAP 1: Performance Tuning Drop-in (docs/vps.md)
    # Moved outside aa-exec check to ensure tuning applies on all systems.
    local tuning_dir="$ACTUAL_HOME/.config/systemd/user/openclaw-gateway.service.d"
    mkdir -p "$tuning_dir"
    cat > "$tuning_dir/tuning.conf" <<EOF
[Service]
Environment=OPENCLAW_NO_RESPAWN=1
Environment=NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache
Restart=always
RestartSec=2
TimeoutStartSec=90
EOF
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$tuning_dir"
    log "Performance tuning (NODE_COMPILE_CACHE, etc.) applied via systemd drop-in."

    log "Starting OpenClaw gateway service..."
    uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user daemon-reload
    
    local start_failed=0
    uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user restart openclaw-gateway.service || start_failed=1

    if [[ $start_failed -eq 1 ]]; then
        log "WARNING: Gateway start failed! Checking logs..."
        local journal; journal=$(uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" journalctl --user -u openclaw-gateway.service -n 25 --no-pager 2>/dev/null || true)
        while IFS= read -r line; do log "  $line"; done <<< "$journal"
        
        log "Retrying without AppArmor confinement (drop-in removed)..."
        local dropin_file="$ACTUAL_HOME/.config/systemd/user/openclaw-gateway.service.d/apparmor.conf"
        rm -f "$dropin_file" 2>/dev/null || true
        uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user daemon-reload
        uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user restart openclaw-gateway.service || die "Gateway restart failed even unconfined."
    fi

    log "Waiting for gateway to bind port 18789 (confined, up to 30s)..."
    if ! wait_for_gateway_port 30; then
        log "WARNING: Gateway did not bind under AppArmor confinement. Checking logs..."
        local journal; journal=$(uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" journalctl --user -u openclaw-gateway.service -n 25 --no-pager 2>/dev/null || true)
        while IFS= read -r line; do log "  $line"; done <<< "$journal"
        
        log "Retrying without AppArmor confinement (drop-in removed)..."
        local dropin_file="$ACTUAL_HOME/.config/systemd/user/openclaw-gateway.service.d/apparmor.conf"
        rm -f "$dropin_file" 2>/dev/null || true
        uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user daemon-reload
        uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user restart openclaw-gateway.service || die "Gateway restart failed even unconfined."
        
        log "Waiting for gateway to bind port 18789 (unconfined, up to 30s)..."
        if wait_for_gateway_port 30; then
            log "Gateway bound port 18789 (UNCONFINED — run: sudo aa-logprof)"
        else
            die "Gateway timed out even unconfined. Check: openclaw logs --follow"
        fi
    fi
}

wait_for_gateway_port() {
    local secs="${1:-30}"
    for _ in $(seq 1 "$secs"); do
        if ss -tlnp 2>/dev/null | grep -q ':18789'; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# ── 19-20. OPERATIONAL READY ──────────────────────────────────────────────────
init_memory_index() {
    log "Initializing memory index..."
    oc memory index 2>/dev/null || log "INFO: Memory index will rebuild lazily."
}

run_doctor() {
    log "Running system doctor..."
    oc doctor --non-interactive 2>/dev/null || true
}
