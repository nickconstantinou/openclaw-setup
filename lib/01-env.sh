#!/usr/bin/env bash
# 
# @intent Environment resolution and validation (§1-§5).
# @complexity 3
# 

# ── 1. RESOLVE USER + LOAD ~/.openclaw/.env ───────────────────────────────────
resolve_user_context() {
    ACTUAL_USER="${SUDO_USER:-$USER}"
    ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6) \
        || die "Could not resolve home directory for user: $ACTUAL_USER"
    ACTUAL_UID=$(id -u "$ACTUAL_USER")
    export ACTUAL_USER ACTUAL_HOME ACTUAL_UID

    ENV_FILE="${OPENCLAW_ENV_FILE:-$ACTUAL_HOME/.openclaw/.env}"
    
    if [[ ! -f "$ENV_FILE" ]]; then
        die "No .env file found at $ENV_FILE. Please create it with required secrets."
    fi

    # Inject placeholder values for core (non-tool) keys if not already present
    # Tool-specific placeholders are injected later by inject_tool_env_placeholders()
    local placeholders=(
        "POST_BRIDGE_API_KEY=pb_REPLACE_ME_WHEN_READY"
        "TAVILY_API_KEY=tvly-REPLACE_ME_WHEN_READY"
        "GITHUB_PAT=ghp_REPLACE_ME_WHEN_READY"
        "TELEGRAM_BOT_TOKEN_CODING=tg-REPLACE_ME_CODING"
        "TELEGRAM_BOT_TOKEN_MARKETING=tg-REPLACE_ME_MARKETING"
        "TELEGRAM_ALLOWED_USERS=REPLACE_ME"
        "TELEGRAM_ALLOWED_USERS_CODING=INHERIT"
        "TELEGRAM_ALLOWED_USERS_MARKETING=INHERIT"
        "WHATSAPP_ALLOWED_USERS=REPLACE_ME"
    )

    for p in "${placeholders[@]}"; do
        local key="${p%%=*}"
        local val="${p#*=}"
        if ! grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
            echo "${key}=${val}" >> "$ENV_FILE"
            log "  Added placeholder to .env: ${key}=${val}"
        fi
    done

    if [[ "$(stat -c '%a' "$ENV_FILE")" != "600" ]]; then
        die "$ENV_FILE has unsafe permissions. Run: chmod 600 $ENV_FILE"
    fi

    log "Loading environment from $ENV_FILE"
    set -o allexport
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    
    # Fallback: source systemd environment.d if .env was scrubbed
    local envd_file="$ACTUAL_HOME/.config/environment.d/openclaw.conf"
    if [[ -f "$envd_file" ]]; then
        # shellcheck source=/dev/null
        source "$envd_file"
    fi
    set +o allexport
}

# ── 2. ENVIRONMENT VALIDATION ─────────────────────────────────────────────────
validate_env() {
    log "Validating required environment variables..."
    local required=(
        TELEGRAM_BOT_TOKEN
        TELEGRAM_CHAT_ID
        OPENCLAW_INSTALLER_SHA256
        MINIMAX_API_KEY
        GEMINI_API_KEY
        GITHUB_API_KEY
        OBSIDIAN_VAULT_PATH
    )
    for var in "${required[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            die "Missing required variable: $var — add it to $ENV_FILE"
        fi
    done

    if [[ "${OPENCLAW_SANDBOX_MODE:-}" == "untrusted" ]]; then
        die "[SEC-001] OPENCLAW_SANDBOX_MODE=untrusted is deprecated. Use: off | non-main | all"
    fi

    if ! [[ "$OPENCLAW_INSTALLER_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
        die "OPENCLAW_INSTALLER_SHA256 does not look like a valid SHA256 hash."
    fi
}

# ── 3. OS + SYSTEM VALIDATION ─────────────────────────────────────────────────
validate_system() {
    log "Validating OS and system requirements..."
    command -v systemctl >/dev/null 2>&1 \
        || die "systemd is required but systemctl was not found."
    grep -qiE 'ubuntu|debian' /etc/os-release \
        || die "This script supports Debian/Ubuntu only."
}

# ── 4. RESOURCE CHECKS ────────────────────────────────────────────────────────
check_resources() {
    log "Validating system resources..."
    local min_ram=7
    local min_disk=20
    local total_ram
    total_ram=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
    local avail_disk
    avail_disk=$(df -BG / | awk 'NR==2 {gsub("G",""); print int($4)}')

    (( total_ram >= min_ram )) \
        || die "Insufficient RAM: ${total_ram}GB detected (minimum ${min_ram}GB required)."
    (( avail_disk >= min_disk )) \
        || die "Insufficient disk: ${avail_disk}GB available (minimum ${min_disk}GB required)."
    log "Resources OK — RAM: ${total_ram}GB, Disk free: ${avail_disk}GB"
}

# ── 1b. TOOL ENV PLACEHOLDERS ─────────────────────────────────────────────────
# Called after load_tool_modules() — injects per-tool placeholder keys into .env
inject_tool_env_placeholders() {
    local name
    for name in "${TOOL_NAMES[@]:-}"; do
        local raw="${TOOL_ENV_PLACEHOLDERS[$name]:-}"
        [[ -z "$raw" ]] && continue
        local p
        while IFS= read -r p; do
            [[ -z "$p" ]] && continue
            local key="${p%%=*}"
            local val="${p#*=}"
            if ! grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
                echo "${key}=${val}" >> "$ENV_FILE"
                log "  Added placeholder (${name}): ${key}"
            fi
        done <<< "$raw"
    done
}

# ── 5. SHELL PROFILE TUNING ───────────────────────────────────────────────────
setup_shell_profile() {
    log "Configuring shell performance tuning (NODE_COMPILE_CACHE)..."
    local bashrc="$ACTUAL_HOME/.bashrc"
    
    # Ensure compile cache directory exists with correct ownership
    mkdir -p /var/tmp/openclaw-compile-cache
    chown "$ACTUAL_USER:$ACTUAL_USER" /var/tmp/openclaw-compile-cache

    if [[ -f "$bashrc" ]]; then
        if ! grep -q "NODE_COMPILE_CACHE" "$bashrc"; then
            cat >> "$bashrc" <<'EOF'

# OpenClaw Performance Tuning (added by self-heal)
export NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache
export OPENCLAW_NO_RESPAWN=1
EOF
            chown "$ACTUAL_USER:$ACTUAL_USER" "$bashrc"
            log "  Performance tuning added to $bashrc"
        fi
    fi
}
