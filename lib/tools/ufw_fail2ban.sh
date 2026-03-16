#!/usr/bin/env bash
#
# @intent UFW firewall and fail2ban intrusion-prevention module.
# @complexity 2
#

TOOL_APPARMOR_RULES[ufw_fail2ban]=""
TOOL_ENV_PLACEHOLDERS[ufw_fail2ban]=""
TOOL_SYSTEMD_EXPORTS[ufw_fail2ban]=""

# ── UFW + FAIL2BAN ────────────────────────────────────────────────────────────
install_ufw_fail2ban() {
    # ── Install packages ──────────────────────────────────────────────────────
    local pkgs=(ufw fail2ban)
    local missing=()
    local p
    for p in "${pkgs[@]}"; do
        dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        wait_for_apt
        apt_install "${missing[@]}" \
            && log "ufw + fail2ban installed." \
            || { log "WARNING: ufw/fail2ban install failed."; return 1; }
    else
        log "ufw + fail2ban already installed."
    fi

    # ── Configure UFW ─────────────────────────────────────────────────────────
    # Only configure on first run — guard prevents overwriting user customisations.
    if ! ufw status | grep -q "Status: active"; then
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow in on tailscale0   # permit all traffic on the Tailscale tunnel
        # Port 22 is intentionally NOT opened — SSH is routed via Tailscale only.
        ufw --force enable
        log "ufw configured and enabled (deny incoming, Tailscale allowed, public SSH blocked)."
    else
        log "ufw already active — skipping configuration."
    fi

    # ── Configure fail2ban ────────────────────────────────────────────────────
    local jail_local=/etc/fail2ban/jail.local
    if [[ ! -f "$jail_local" ]]; then
        cat > "$jail_local" << 'EOF'
[DEFAULT]
# Ban duration: 1 hour for general jails
bantime  = 3600
# Window to count failures: 10 minutes
findtime = 600
# Max failures before ban
maxretry = 5
# Use systemd journal as log backend (Ubuntu 20.04+)
backend  = systemd

[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = %(sshd_log)s
# Stricter than default — 24-hour ban after 3 failures
maxretry = 3
bantime  = 86400
EOF
        log "fail2ban jail.local written."
    else
        log "fail2ban jail.local already exists — skipping."
    fi

    systemctl enable --now fail2ban 2>/dev/null \
        && log "fail2ban service enabled and started." \
        || log "WARNING: failed to start fail2ban service."
}

register_tool ufw_fail2ban
