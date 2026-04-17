#!/usr/bin/env bash
# 
# @intent Tailscale installation and verification (§11).
# @complexity 2
# 

# ── 11. TAILSCALE ─────────────────────────────────────────────────────────────
setup_network() {
    if [[ "${OPENCLAW_NO_TAILSCALE:-0}" == "1" ]]; then
        log "Tailscale setup disabled via OPENCLAW_NO_TAILSCALE=1. Skipping."
        return 0
    fi

    log "Setting up Tailscale..."

    if ! command -v tailscale >/dev/null 2>&1; then
        log "Tailscale not found — installing via official script..."
        curl -fsSL --proto '=https' --tlsv1.2 https://tailscale.com/install.sh | sh || die "Tailscale install failed."
    fi

    systemctl enable tailscaled --now 2>/dev/null || true

    local state; state=$(tailscale status --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin) if sys.stdin.isatty()==False else {}; print(d.get('BackendState','unknown'))" 2>/dev/null || echo "unknown")

    log "Tailscale backend state: $state"

    if [[ "$state" == "Running" ]]; then
        local ip; ip=$(tailscale ip -4 2>/dev/null || echo "unknown")
        local name; name=$(tailscale status --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('Self',{}).get('DNSName','').rstrip('.'))" 2>/dev/null || echo "unknown")
        log "Tailscale connected — IP: $ip  Hostname: $name"
        log "Enabling Tailscale SSH..."
        sudo tailscale up --ssh && log "Tailscale SSH enabled." || log "WARNING: Tailscale SSH failed."
    elif [[ "$state" == "NeedsLogin" ]] || [[ "$state" == "NoState" ]]; then
        die "Tailscale not authenticated. Run: sudo tailscale up"
    else
        log "WARNING: Tailscale in state '$state' — attempting tailscale up..."
        tailscale up --ssh 2>/dev/null || true
    fi
}
