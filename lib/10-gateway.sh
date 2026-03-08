#!/usr/bin/env bash
# 
# @intent Gateway service installation and lifecycle management (§18-§20).
# @complexity 3
# 

# ── 18. INSTALL & START GATEWAY ───────────────────────────────────────────────
install_gateway_service() {
    log "Installing gateway service..."

    # Work around a bug in openclaw's isSystemdServiceEnabled():
    # systemctl --user is-enabled writes "not-found" to STDOUT (not stderr), but
    # Node.js execFileUtf8 substitutes error.message ("Command failed: ...") as the
    # stderr fallback when stderr is empty. readSystemctlDetail prefers stderr, so it
    # sees "Command failed: ..." which matches no known pattern and throws
    # "systemctl is-enabled unavailable".
    #
    # Fix: pre-seed a stub unit file and enable it so is-enabled returns exit code 0.
    # With code 0, openclaw returns true immediately without any pattern matching.
    # oc gateway install --force then sees the service as already-loaded + --force,
    # falls through to full reinstall, and overwrites the stub with the real unit file.
    local unit_dir="$ACTUAL_HOME/.config/systemd/user"
    local unit_file="$unit_dir/openclaw-gateway.service"
    if [[ ! -f "$unit_file" ]]; then
        local oc_bin; oc_bin=$(command -v openclaw)
        mkdir -p "$unit_dir"
        chown "$ACTUAL_USER:$ACTUAL_USER" "$unit_dir"
        cat > "$unit_file" <<EOF
[Unit]
Description=OpenClaw Gateway
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$oc_bin gateway run
Restart=always
RestartSec=5
KillMode=control-group

[Install]
WantedBy=default.target
EOF
        chown "$ACTUAL_USER:$ACTUAL_USER" "$unit_file"
        uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" \
            systemctl --user daemon-reload || true
        uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" \
            systemctl --user enable openclaw-gateway.service || true
        log "Stub unit pre-seeded (workaround for openclaw is-enabled stdout/stderr bug)."
    fi

    oc gateway install --force || die "Gateway install failed."

    local unit="$ACTUAL_HOME/.config/systemd/user/openclaw-gateway.service"
    if [[ -f "$unit" ]] && command -v aa-exec >/dev/null 2>&1; then
        local exec_line; exec_line=$(grep "^ExecStart=" "$unit" | head -1)
        local exec_cmd="${exec_line#ExecStart=}"
        if [[ -n "$exec_cmd" ]]; then
            if aa-exec -p openclaw-gateway -- true 2>/dev/null; then
                local dropin_dir="$ACTUAL_HOME/.config/systemd/user/openclaw-gateway.service.d"
                mkdir -p "$dropin_dir"
                # $exec_cmd is expanded by bash during heredoc — do NOT use printf '%q' here.
                # printf '%q' escapes spaces, causing aa-exec to receive the whole command as
                # a single argument instead of a binary + args, producing "No such file or directory".
                cat > "$dropin_dir/apparmor.conf" <<EOF
[Service]
ExecStartPre=/bin/sh -c 'aa-exec -p openclaw-gateway -- true 2>/dev/null || (echo "AppArmor profile not loaded — starting unconfined" && exit 0)'
ExecStart=
ExecStart=/bin/sh -c 'if aa-exec -p openclaw-gateway -- true 2>/dev/null; then exec aa-exec -p openclaw-gateway -- $exec_cmd; else exec $exec_cmd; fi'
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

    # SupplementaryGroups= is not supported in user-mode systemd services (requires CAP_SETGID,
    # exits with code 216/GROUP). The openclaw user is added to the docker group at the OS level.
    # Remove any stale docker-group.conf from previous installs.
    local docker_dropin="$ACTUAL_HOME/.config/systemd/user/openclaw-gateway.service.d/docker-group.conf"
    if [[ -f "$docker_dropin" ]]; then
        rm -f "$docker_dropin"
        log "Removed stale docker-group drop-in (SupplementaryGroups not supported in user services)."
    fi

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
