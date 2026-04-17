#!/usr/bin/env bash
# 
# @intent Gateway service installation and lifecycle management (§18-§20).
# @complexity 3
# 

# ── PRE-LOAD STATE ────────────────────────────────────────────────────────────
APPARMOR_UNCONFINED=0

warn_apparmor_unconfined() {
    log "----------------------------------------------------------------------"
    log "[SEC-004] WARNING: AppArmor profile load failed. Falling back to UNCONFINED."
    log "----------------------------------------------------------------------"
    export APPARMOR_UNCONFINED=1
}

scrub_gateway_unit_environment() {
    local unit="$1"
    [[ -f "$unit" ]] || return 0

    # Strip all secret/sensitive env vars baked in by 'oc gateway install'.
    # Non-secret runtime vars (HOME, TMPDIR, PATH, NODE_EXTRA_CA_CERTS,
    # OPENCLAW_SERVICE_*, OPENCLAW_GATEWAY_PORT) are kept.
    # Secrets are provided at runtime via environment.d/openclaw.conf instead,
    # which prevents them from appearing in 'systemctl show' output.
    sed -i -E \
        -e '/^Environment=OPENCLAW_GATEWAY_TOKEN=/d' \
        -e '/^Environment=(OPENAI_API_KEY|CODEX_API_KEY)=/d' \
        -e '/^Environment=.*REPLACE_ME.*$/d' \
        -e '/^Environment=.*=INHERIT$/d' \
        -e '/^Environment=TELEGRAM_BOT_TOKEN(_CC)?=/d' \
        -e '/^Environment=TELEGRAM_ALLOWED_USERS(_[A-Z]+)?=/d' \
        -e '/^Environment=TELEGRAM_BOT_TOKEN_(CODING|MARKETING)=/d' \
        -e '/^Environment=TELEGRAM_ALLOWED_USERS_(CODING|MARKETING)=/d' \
        -e '/^Environment=TELEGRAM_CHAT_ID=/d' \
        -e '/^Environment=TELEGRAM_AGENT_GROUP_ID=/d' \
        -e '/^Environment=MINIMAX_API_KEY=/d' \
        -e '/^Environment=GEMINI_API_KEY=/d' \
        -e '/^Environment=ANTHROPIC_API_KEY=/d' \
        -e '/^Environment=NVIDIA_API_KEY=/d' \
        -e '/^Environment=ELEVENLABS_API_KEY=/d' \
        -e '/^Environment=KLING_(ACCESS|SECRET)_KEY=/d' \
        -e '/^Environment=RUNWAY_API_KEY=/d' \
        -e '/^Environment=TAVILY_API_KEY=/d' \
        -e '/^Environment=GITHUB_(API_KEY|PAT)=/d' \
        -e '/^Environment=SUPABASE_(URL|SERVICE_KEY|ANON_KEY|ACCESS_TOKEN|REF)=/d' \
        -e '/^Environment=POSTHOG_(PROJECT_TOKEN|PERSONAL_API_KEY)=/d' \
        -e '/^Environment=KIT_API_KEY=/d' \
        -e '/^Environment=BUFFER_API_KEY=/d' \
        -e '/^Environment=RESEND_API_KEY=/d' \
        -e '/^Environment=OUTSCRAPER_API_KEY=/d' \
        -e '/^Environment=POST_BRIDGE_API_KEY=/d' \
        -e '/^Environment=GWS_(CREDENTIALS|ENCRYPTION_KEY)_B64=/d' \
        -e '/^Environment=GOOGLE_WORKSPACE_CLI_(CLIENT_ID|CLIENT_SECRET)=/d' \
        -e '/^Environment=WHATSAPP_ALLOWED_USERS=/d' \
        -e '/^Environment=WHATSAPP_GROUP_(ID|ALLOW_FROM)=/d' \
        -e '/^Environment=TRUSTED_ADMIN_IDS=/d' \
        -e '/^Environment=OPENCLAW_INSTALLER_SHA256=/d' \
        -e '/^Environment=TEST_DUMMY_KEY=/d' \
        "$unit"
    log "Gateway unit secrets scrubbed — runtime env provided via environment.d/openclaw.conf"
}

gateway_unit_has_embedded_environment() {
    local unit="$1"
    [[ -f "$unit" ]] || return 1
    grep -Eq '^Environment=(OPENCLAW_GATEWAY_TOKEN|PATH)=' "$unit"
}

gateway_unit_uses_version_manager_runtime() {
    local unit="$1"
    [[ -f "$unit" ]] || return 1
    grep -Eq '^ExecStart=.*(/\.nvm/|/\.asdf/|/\.volta/|/\.fnm/|/\.bun/)' "$unit"
}

wait_for_gateway_unit_file() {
    local unit="$1"
    local secs="${2:-10}"
    for _ in $(seq 1 "$secs"); do
        [[ -f "$unit" ]] && return 0
        sleep 1
    done
    return 1
}

normalize_gateway_unit_execstart() {
    local unit="$1"
    [[ -f "$unit" ]] || return 1

    local oc_bin node_bin oc_real oc_pkg desired_exec
    oc_bin=$(resolve_system_openclaw_bin 2>/dev/null || true)
    node_bin=$(resolve_system_node_bin 2>/dev/null || true)
    [[ -n "$oc_bin" ]] && [[ -n "$node_bin" ]] || return 0

    oc_real=$(readlink -f "$oc_bin" 2>/dev/null || true)
    [[ -n "$oc_real" ]] || return 0
    oc_pkg=$(dirname "$oc_real")
    [[ -f "$oc_pkg/dist/index.js" ]] || return 0

    desired_exec="ExecStart=$node_bin $oc_pkg/dist/index.js gateway --port 18789"
    python3 - "$unit" "$desired_exec" <<'PYEOF'
from pathlib import Path
import sys
unit = Path(sys.argv[1])
desired = sys.argv[2]
lines = unit.read_text(encoding='utf-8').splitlines()
out = []
replaced = False
for line in lines:
    if line.startswith('ExecStart=') and not replaced:
        out.append(desired)
        replaced = True
    else:
        out.append(line)
if not replaced:
    out.append(desired)
unit.write_text('\n'.join(out) + '\n', encoding='utf-8')
PYEOF
}

normalize_gateway_unit() {
    local unit="$1"
    wait_for_gateway_unit_file "$unit" 15 || return 1
    scrub_gateway_unit_environment "$unit"
    normalize_gateway_unit_execstart "$unit"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$unit" 2>/dev/null || true
}

# ── 18. INSTALL & START GATEWAY ───────────────────────────────────────────────
install_gateway_service() {
    log "Installing gateway service..."
    ensure_system_node_runtime

    local oc_bin
    oc_bin=$(resolve_system_openclaw_bin) || die "System-global 'openclaw' binary not found for gateway install."
    local install_path
    install_path="/bin:/sbin:/usr/bin:/usr/local/bin:$ACTUAL_HOME/.local/bin"

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

    # Install the service without embedding the live gateway token into the unit.
    sudo -u "$ACTUAL_USER" \
        env -i \
            PATH="$install_path" \
            HOME="$ACTUAL_HOME" \
            XDG_CONFIG_HOME="$ACTUAL_HOME/.config" \
            XDG_DATA_HOME="$ACTUAL_HOME/.local/share" \
            XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" \
            DEBIAN_FRONTEND=noninteractive \
            TMPDIR=/tmp \
            NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt \
        "$oc_bin" gateway install --force --runtime node || die "Gateway install failed."

    local unit="$ACTUAL_HOME/.config/systemd/user/openclaw-gateway.service"
    if [[ -f "$unit" ]] || wait_for_gateway_unit_file "$unit" 15; then
        normalize_gateway_unit "$unit" || true
    fi

    if [[ -f "$unit" ]] && command -v aa-exec >/dev/null 2>&1; then
        local exec_line; exec_line=$(grep "^ExecStart=" "$unit" | head -1)
        local exec_cmd="${exec_line#ExecStart=}"
        if [[ -n "$exec_cmd" ]]; then
            if uas aa-exec -p openclaw-gateway -- true 2>/dev/null; then
                local dropin_dir="$ACTUAL_HOME/.config/systemd/user/openclaw-gateway.service.d"
                mkdir -p "$dropin_dir"
                # $exec_cmd is expanded by bash during heredoc — do NOT use printf '%q' here.
                # printf '%q' escapes spaces, causing aa-exec to receive the whole command as
                # a single argument instead of a binary + args, producing "No such file or directory".
                cat > "$dropin_dir/apparmor.conf" <<EOF
[Service]
ExecStartPre=/bin/sh -c 'aa-exec -p openclaw-gateway -- true 2>/dev/null || (echo "AppArmor profile not loaded for user service — starting unconfined" && exit 0)'
ExecStart=
ExecStart=/bin/sh -c 'if aa-exec -p openclaw-gateway -- true 2>/dev/null; then exec aa-exec -p openclaw-gateway -- $exec_cmd; else exec $exec_cmd; fi'
EOF
                chown -R "$ACTUAL_USER:$ACTUAL_USER" "$dropin_dir"
                log "AppArmor confinement applied via systemd drop-in."
            else
                log "WARNING: aa-exec probe failed for service user '$ACTUAL_USER' — gateway will start unconfined."
                warn_apparmor_unconfined
            fi
        fi
    fi

    if gateway_unit_has_embedded_environment "$unit"; then
        log "WARNING: Gateway unit still contains embedded OPENCLAW_GATEWAY_TOKEN or PATH after normalization."
    fi
    if gateway_unit_uses_version_manager_runtime "$unit"; then
        log "WARNING: Gateway unit ExecStart still references a version-manager runtime after normalization."
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

    cat > "$tuning_dir/codex-oauth.conf" <<EOF
[Service]
Environment=OPENAI_API_KEY=
Environment=CODEX_API_KEY=
EOF
    chown "$ACTUAL_USER:$ACTUAL_USER" "$tuning_dir/codex-oauth.conf"
    log "Codex OAuth-only environment override applied via systemd drop-in."

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
        warn_apparmor_unconfined
        local dropin_file="$ACTUAL_HOME/.config/systemd/user/openclaw-gateway.service.d/apparmor.conf"
        rm -f "$dropin_file" 2>/dev/null || true
        uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user daemon-reload
        uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user restart openclaw-gateway.service || die "Gateway restart failed even unconfined."
    fi

    # Allow up to 60s for cold start — Node.js gateway takes ~45s on first run
    # before NODE_COMPILE_CACHE is warm. 30s was too short and caused false
    # AppArmor failures followed by premature die().
    log "Waiting for gateway to bind port 18789 (confined, up to 60s)..."
    if ! wait_for_gateway_port 60; then
        log "WARNING: Gateway did not bind under AppArmor confinement. Checking logs..."
        local journal; journal=$(uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" journalctl --user -u openclaw-gateway.service -n 25 --no-pager 2>/dev/null || true)
        while IFS= read -r line; do log "  $line"; done <<< "$journal"
        warn_apparmor_unconfined
        local dropin_file="$ACTUAL_HOME/.config/systemd/user/openclaw-gateway.service.d/apparmor.conf"
        rm -f "$dropin_file" 2>/dev/null || true
        uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user daemon-reload
        uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" systemctl --user restart openclaw-gateway.service || die "Gateway restart failed even unconfined."

        log "Waiting for gateway to bind port 18789 (unconfined, up to 60s)..."
        if wait_for_gateway_port 60; then
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
