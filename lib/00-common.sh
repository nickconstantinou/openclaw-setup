#!/usr/bin/env bash
# 
# @intent Core utility functions for logging, error handling, and command wrappers.
# @complexity 2
# 

# ── LOGGING & ERROR HANDLING ──────────────────────────────────────────────────
log() {
    local _ts
    _ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    printf '[%s] %s\n' "$_ts" "$1" | sudo tee -a "$LOG_FILE"
}

die() {
    log "[FATAL] $1"
    exit 1
}

# ── LOCK MANAGEMENT ───────────────────────────────────────────────────────────
wait_for_apt() {
    local MAX_WAIT=300
    local WAITED=0
    while sudo fuser /var/lib/apt/lists/lock      >/dev/null 2>&1 || \
          sudo fuser /var/lib/dpkg/lock            >/dev/null 2>&1 || \
          sudo fuser /var/lib/dpkg/lock-frontend   >/dev/null 2>&1 || \
          sudo fuser /var/cache/apt/archives/lock  >/dev/null 2>&1; do
        if (( WAITED >= MAX_WAIT )); then
            die "Timeout waiting for APT lock after ${MAX_WAIT}s."
        fi
        log "  APT locked (unattended-upgrades?). Waiting 10s... (${WAITED}/${MAX_WAIT}s)"
        sleep 10
        (( WAITED += 10 ))
    done
    if (( WAITED > 0 )); then
        log "  APT lock released after ${WAITED}s."
    fi
}

# ── COMMAND WRAPPERS ──────────────────────────────────────────────────────────
# oc: wrapper for openclaw CLI with proper path and user context
oc() {
    sudo -u "$ACTUAL_USER" \
        env PATH="/bin:/sbin:/usr/bin:/usr/local/bin:$PATH" \
            HOME="$ACTUAL_HOME" \
            XDG_CONFIG_HOME="$ACTUAL_HOME/.config" \
            XDG_DATA_HOME="$ACTUAL_HOME/.local/share" \
            XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" \
            DEBIAN_FRONTEND=noninteractive \
        openclaw "$@"
}

# uas: User-Agent-Shell wrapper to run commands as the actual user
uas() {
    sudo -u "$ACTUAL_USER" \
        env HOME="$ACTUAL_HOME" \
            PATH="/bin:/sbin:/usr/bin:/usr/local/bin:$ACTUAL_HOME/.local/bin:$PATH" \
            XDG_CONFIG_HOME="$ACTUAL_HOME/.config" \
            XDG_DATA_HOME="$ACTUAL_HOME/.local/share" \
            XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" \
        "$@"
}
