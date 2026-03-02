#!/usr/bin/env bash
# 
# @intent Installation and configuration of Ollama (§8-§9).
# @complexity 2
# 

# ── 8. INSTALL & CONFIGURE OLLAMA ─────────────────────────────────────────────
install_ollama() {
    if ! command -v ollama >/dev/null 2>&1; then
        log "Downloading Ollama installer..."
        local tmp; tmp=$(mktemp -d)
        chmod 700 "$tmp"
        curl -fsSL https://ollama.com/install.sh -o "$tmp/ollama-install.sh"
        sudo sh "$tmp/ollama-install.sh"
        rm -rf "$tmp"
    else
        log "Ollama already installed: $(command -v ollama)"
    fi
}

# ── 9. OLLAMA SYSTEMD & MODELS ────────────────────────────────────────────────
configure_ollama() {
    log "Configuring Ollama systemd override..."
    local override_dir="/etc/systemd/system/ollama.service.d"
    sudo mkdir -p "$override_dir"
    sudo tee "$override_dir/override.conf" > /dev/null << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_KEEP_ALIVE=2m"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KV_CACHE_TYPE=q4_0"
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable ollama
    sudo systemctl restart ollama

    log "Waiting for Ollama API to become ready..."
    local ready=false
    for _ in {1..30}; do
        if curl -sf http://127.0.0.1:11434/ >/dev/null 2>&1; then
            ready=true
            log "Ollama is ready."
            break
        fi
        sleep 2
    done
    [[ "$ready" == "true" ]] || die "Ollama did not become ready within 60 seconds."

    log "Pulling pinned Ollama models..."
    ollama pull nomic-embed-text:latest
}
