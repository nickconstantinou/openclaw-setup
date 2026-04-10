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

# apt_install: wrapper that uses systemd-inhibit to avoid contention
apt_install() {
    wait_for_apt
    if command -v systemd-inhibit >/dev/null 2>&1; then
        sudo systemd-inhibit --what=idle --who="openclaw-deploy" --why="Installing packages" \
            apt-get install -y -q "$@"
    else
        sudo apt-get install -y -q "$@"
    fi
}

# ── COMMAND WRAPPERS ──────────────────────────────────────────────────────────
is_placeholder_value() {
    local value="${1:-}"
    [[ -z "$value" ]] && return 1
    case "$value" in
        *REPLACE_ME*|INHERIT)
            return 0
            ;;
    esac
    return 1
}

has_effective_value() {
    local value="${1:-}"
    [[ -n "$value" ]] && ! is_placeholder_value "$value"
}

build_user_path() {
    local path_parts=(
        "/bin"
        "/sbin"
        "/usr/bin"
        "/usr/local/bin"
        "$ACTUAL_HOME/.local/bin"
    )

    [[ -n "${NVM_NODE_DIR:-}" ]] && path_parts+=("$NVM_NODE_DIR")
    [[ -n "${BREW_BIN_DIR:-}" ]] && path_parts+=("$BREW_BIN_DIR")

    local joined="${path_parts[0]}"
    local part
    for part in "${path_parts[@]:1}"; do
        joined="${joined}:$part"
    done
    joined="${joined}:$PATH"
    printf '%s\n' "$joined"
}

resolve_openclaw_bin() {
    local candidate
    for candidate in \
        /usr/local/bin/openclaw \
        /usr/bin/openclaw \
        /bin/openclaw \
        "$ACTUAL_HOME/.local/bin/openclaw" \
        "${NVM_NODE_DIR:-}/openclaw" \
        "${BREW_BIN_DIR:-}/openclaw"; do
        [[ -x "$candidate" ]] && printf '%s\n' "$candidate" && return 0
    done

    command -v openclaw 2>/dev/null || return 1
}

# oc: wrapper for openclaw CLI with proper path and user context
oc() {
    local oc_bin
    oc_bin=$(resolve_openclaw_bin) || die "'openclaw' binary not found on PATH."
    sudo -u "$ACTUAL_USER" \
        env PATH="$(build_user_path)" \
            HOME="$ACTUAL_HOME" \
            XDG_CONFIG_HOME="$ACTUAL_HOME/.config" \
            XDG_DATA_HOME="$ACTUAL_HOME/.local/share" \
            XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" \
            DEBIAN_FRONTEND=noninteractive \
        "$oc_bin" "$@"
}

# uas: User-Agent-Shell wrapper to run commands as the actual user
uas() {
    local user_path oc_bin oc_dir
    user_path="$(build_user_path)"
    if oc_bin=$(resolve_openclaw_bin 2>/dev/null); then
        oc_dir="$(dirname "$oc_bin")"
        case ":$user_path:" in
            *":$oc_dir:"*) ;;
            *) user_path="$oc_dir:$user_path" ;;
        esac
    fi

    sudo -u "$ACTUAL_USER" \
        env HOME="$ACTUAL_HOME" \
            PATH="$user_path" \
            XDG_CONFIG_HOME="$ACTUAL_HOME/.config" \
            XDG_DATA_HOME="$ACTUAL_HOME/.local/share" \
            XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" \
        "$@"
}
