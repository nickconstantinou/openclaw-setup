#!/usr/bin/env bash
# 
# @intent Telegram deployment notifications and detailed summary (§21, §23).
# @complexity 2
# 

# ── 21. SUMMARY & TAILSCALE SERVE ─────────────────────────────────────────────
print_summary() {
    log "Configuring Tailscale Serve..."
    if command -v tailscale >/dev/null 2>&1; then
        tailscale serve --bg https / "http://127.0.0.1:18789" 2>/dev/null \
            || tailscale serve --bg http:443 / "http://127.0.0.1:18789" 2>/dev/null \
            || tailscale serve --bg 18789 2>/dev/null || true
        
        local host; host=$(tailscale status --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('Self',{}).get('DNSName','').rstrip('.'))" 2>/dev/null || echo "localhost")
        local ip; ip=$(tailscale ip -4 2>/dev/null || echo "unknown")
        local token; token=$(python3 -c "import json; c=json.load(open('$ACTUAL_HOME/.openclaw/openclaw.json')); print(c.get('gateway',{}).get('auth',{}).get('token',''))" 2>/dev/null)
        
        log "==================================================================="
        log "  OPENCLAW DEPLOYMENT COMPLETE"
        log "==================================================================="
        log ""
        log "  Dashboard URL: https://${host}/#token=${token}"
        log "  SSH URL:       ssh ${ACTUAL_USER}@${host}"
        log "  Ollama API:    http://${ip}:11434"
        log ""
        
        # Integrations status
        if [[ "${GH_IDENTITY:-unknown}" != "unknown" ]]; then
            log "  [OK]   GitHub CLI: authenticated as $GH_IDENTITY"
        else
            log "  [WARN] GitHub CLI: not authenticated"
        fi

        if [[ -d "$OBSIDIAN_VAULT_PATH" ]]; then
            log "  [OK]   Obsidian: vault accessible at $OBSIDIAN_VAULT_PATH"
        fi

        if [[ -n "${POST_BRIDGE_API_KEY:-}" && "$POST_BRIDGE_API_KEY" != "pb_REPLACE_ME_WHEN_READY" ]]; then
            log "  [OK]   Post Bridge: social media integration active"
        fi
        
        log "==================================================================="
    fi
}

# ── 23. TELEGRAM NOTIFICATION ─────────────────────────────────────────────────
send_telegram_notification() {
    log "Sending Telegram deployment notification..."

    local host; host=$(hostname)
    local dns_name; dns_name=$(tailscale status --json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('Self',{}).get('DNSName','').rstrip('.'))" 2>/dev/null || echo "localhost")
    local dashboard="https://${dns_name}/"
    local ssh_url="${ACTUAL_USER}@${dns_name}"

    local msg; read -r -d "" msg <<EOF || true
🦞 <b>OpenClaw Deployed</b>

<b>Version</b>  ${SCRIPT_VERSION}
<b>Host</b>     ${host}

<b>Dashboard</b>
<code>${dashboard}</code>

<b>SSH</b>
<code>ssh ${ssh_url}</code>

<b>GitHub</b>   ${GH_IDENTITY:-unknown}
<b>Obsidian</b> ${OBSIDIAN_VAULT_PATH:-unset}
EOF

    local status; status=$(curl \
        --silent --show-error --write-out "%{http_code}" --max-time 10 \
        -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${msg}" \
        --data-urlencode "parse_mode=HTML" \
        -o /dev/null)

    if [[ "$status" == "200" ]]; then
        log "Telegram notification sent."
    else
        log "WARNING: Telegram notification failed (HTTP $status)."
    fi
}
