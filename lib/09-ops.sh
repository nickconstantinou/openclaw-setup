#!/usr/bin/env bash
# 
# @intent Operations: audit, optimization, and onboarding (§16-§17).
# @complexity 2
# 

# ── 16.1 SECRET REF MIGRATION ────────────────────────────────────────────────
migrate_secrets() {
    log "Migrating plaintext API keys to SecretRefs..."
    local config_file="$ACTUAL_HOME/.openclaw/openclaw.json"
    local plan_file
    plan_file=$(mktemp /tmp/openclaw-secrets-plan.XXXXXX.json)
    chown "$ACTUAL_USER:$ACTUAL_USER" "$plan_file"
    
    uas python3 "$SCRIPT_DIR/config/migrate_secrets.py" \
        --config "$config_file" \
        --plan-out "$plan_file"
    
    if [[ -s "$plan_file" ]] && python3 -c "import json,sys; p=json.load(open(sys.argv[1])); sys.exit(0 if p.get('targets') else 1)" "$plan_file" 2>/dev/null; then
        log "  Applying secrets plan..."
        oc secrets apply --from "$plan_file" 2>&1 | while IFS= read -r line; do log "  secrets: $line"; done
    else
        log "  No secrets migration needed (already clean or no targets)."
    fi
    rm -f "$plan_file"
}

# ── 16.2 AUTH PROFILE SCRUBBING ──────────────────────────────────────────────
scrub_auth_profile_plaintext() {
    log "Scrubbing plaintext keys from auth-profiles.json..."
    local needs_scrub=false

    # Primary: use oc secrets audit if available
    local audit_out
    audit_out=$(oc secrets audit --check 2>&1 || true)
    if echo "$audit_out" | grep -q "PLAINTEXT_FOUND.*auth-profiles"; then
        needs_scrub=true
    fi

    # Fallback: direct filesystem scan if audit didn't find anything
    # (handles case where oc secrets audit --check is unavailable or output format changes)
    if [[ "$needs_scrub" == false ]]; then
        for agent_id in main family; do
            local ap="$ACTUAL_HOME/.openclaw/agents/$agent_id/agent/auth-profiles.json"
            if [[ -f "$ap" ]] && python3 -c "
import json, sys
with open(sys.argv[1]) as f: data = json.load(f)
for p in data.get('profiles', {}).values():
    for a in p.values():
        if isinstance(a, dict) and 'key' in a and isinstance(a['key'], str):
            sys.exit(0)
sys.exit(1)" "$ap" 2>/dev/null; then
                needs_scrub=true
                break
            fi
        done
    fi

    if [[ "$needs_scrub" == true ]]; then
        log "  Found plaintext keys in auth-profiles.json — applying SecretRef conversion..."
        for agent_id in main family; do
            local ap="$ACTUAL_HOME/.openclaw/agents/$agent_id/agent/auth-profiles.json"
            [[ -f "$ap" ]] || continue
            uas python3 - <<'PYEOF' "$ap"
import json, sys
ap_file = sys.argv[1]
try:
    with open(ap_file) as f:
        data = json.load(f)
    changed = False
    for profile_key, profile in data.get("profiles", {}).items():
        if not isinstance(profile, dict):
            continue
        provider_name = profile_key.split(":")[0] if ":" in profile_key else profile_key
        env_var = provider_name.upper().replace("-", "_") + "_API_KEY"
        # Flat format: profiles["minimax:default"] = {"key": "sk-...", ...}
        if "key" in profile and isinstance(profile["key"], str):
            profile["key"] = {"source": "env", "provider": "default", "id": env_var}
            changed = True
        else:
            # Nested format: profiles["minimax"] = {"default": {"key": "sk-...", ...}}
            for account_key, account in profile.items():
                if isinstance(account, dict) and "key" in account and isinstance(account["key"], str):
                    account["key"] = {"source": "env", "provider": "default", "id": env_var}
                    changed = True
    if changed:
        with open(ap_file, "w") as f:
            json.dump(data, f, indent=2)
        print(f"Converted plaintext keys to SecretRefs in {ap_file}")
    else:
        print(f"No plaintext keys found in {ap_file}")
except Exception as e:
    print(f"Error processing {ap_file}: {e}")
PYEOF
        done
    else
        log "  No plaintext keys in auth-profiles.json."
    fi
}

# ── 16. SECURITY AUDIT ────────────────────────────────────────────────────────
run_security_audit() {
    log "Running security audit..."
    oc security audit --fix 2>/dev/null \
        && log "Security audit complete." \
        || log "WARNING: Security audit returned non-zero."

    # GAP 6: Secrets Audit (docs/gateway/secrets.md)
    log "Running secrets hygiene audit..."
    local audit_out
    audit_out=$(oc secrets audit --check 2>&1 || true)
    if [[ -n "$audit_out" ]]; then
        log "  Secrets audit: $audit_out"
    else
        log "  Secrets audit: no findings."
    fi
}

# ── 16.5 SQLITE OPTIMIZATION ──────────────────────────────────────────────────
optimize_sqlite() {
    local db="$ACTUAL_HOME/.openclaw/memory/main.sqlite"
    mkdir -p "$(dirname "$db")"
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$(dirname "$db")"

    if [[ -f "$db" ]]; then
        log "Optimizing memory database (WAL mode + integrity check)..."
        # Clear stale locks while stopped
        rm -f "${db}-wal" "${db}-shm" 2>/dev/null || true
        
        if command -v sqlite3 >/dev/null 2>&1; then
            uas sqlite3 "$db" "PRAGMA journal_mode=WAL; PRAGMA integrity_check;" | while IFS= read -r line; do log "  sqlite: $line"; done
        fi
    fi
}

# ── 16.8 SANDBOX SETUP ────────────────────────────────────────────────────────
setup_docker_permissions() {
    log "Checking Docker group permissions for $ACTUAL_USER..."
    if ! command -v docker >/dev/null 2>&1; then
        log "Docker not found; skipping permission setup."
        return
    fi

    if ! id -nG "$ACTUAL_USER" | grep -qw "docker"; then
        log "Adding $ACTUAL_USER to the docker group..."
        usermod -aG docker "$ACTUAL_USER"
        log "WARNING: You may need to log out and back in for Docker permissions to fully apply."
    else
        log "  $ACTUAL_USER is already in the docker group."
    fi

    # (Docker rules are now baked natively into the AppArmor template)
}

setup_sandbox() {
    log "Checking OpenClaw Docker sandbox requirement..."
    local config_file="$ACTUAL_HOME/.openclaw/openclaw.json"
    
    # Check if sandbox mode is enabled in config (family agent uses mode: "all")
    local sandbox_enabled=false

    if [[ -f "$config_file" ]] && grep -q '"mode"[[:space:]]*:[[:space:]]*"all"' "$config_file"; then
        sandbox_enabled=true
    fi
    
    # Check if the image exists
    local image_exists=false
    if command -v docker >/dev/null 2>&1; then
        if sudo -u "$ACTUAL_USER" docker images | grep -q "openclaw-sandbox"; then
            image_exists=true
        fi
    fi

    if [[ "$sandbox_enabled" == true ]] || [[ "$image_exists" == false ]]; then
        log "Building OpenClaw sandbox base image (this may take a minute)..."
        if [[ -x "$SCRIPT_DIR/scripts/sandbox-setup.sh" ]]; then
            # Run the setup script as the current user (which is root in a sudo context)
            # to avoid unnecessary privilege dropping and re-sudoing for the password.
            if bash "$SCRIPT_DIR/scripts/sandbox-setup.sh"; then
                log "  Sandbox image built successfully."
            else
                log "  WARNING: Failed to build sandbox image."
            fi
        else
            log "  WARNING: $SCRIPT_DIR/scripts/sandbox-setup.sh not found or not executable."
        fi
    else
        log "  Sandbox image already exists and sandbox mode is not explicitly 'all'."
    fi
}

# ── 17. ONBOARDING ────────────────────────────────────────────────────────────
onboard_gateway() {
    log "Running onboard setup..."
    # WS 1006 ("abnormal closure") expected here — onboard triggers a config
    # hot-reload that drops the WS connection. The onboard changes are still
    # applied successfully. This is an upstream race condition in the OpenClaw
    # CLI, not a deployment failure.
    oc onboard --non-interactive --accept-risk 2>&1 | grep -v "1006 abnormal" || true
}

# ── 17b. RE-APPLY MODELS ──────────────────────────────────────────────────────
reapply_models() {
    log "Re-applying model catalog and media config (post-onboard)..."
    local config_file="$ACTUAL_HOME/.openclaw/openclaw.json"
    uas python3 "$SCRIPT_DIR/config/reapply-models.py" --config "$config_file"
}

# ── 17c. CONFIGURE MODEL HIERARCHY ───────────────────────────────────────────
# main agent:   openai-codex/gpt-5.4 (primary), minimax/MiniMax-M2.5 (fallback)
# family agent: minimax/MiniMax-M2.5 (primary + fallback)
# Anthropic removed — claude-cli path requires Extra Usage (notice 2026-04-04).
#
# TTY LIMITATION — openai-codex OAuth requires an interactive terminal.
# If auth is ever needed again, run manually from a local session:
#   openclaw models auth login --provider openai-codex
configure_model_hierarchy() {
    local auth_profiles="$ACTUAL_HOME/.openclaw/agents/main/agent/auth-profiles.json"

    # ── Step 1: openai-codex OAuth (skip if already configured or no TTY) ─────
    local has_codex_auth
    has_codex_auth=$(python3 -c "
import json, sys
try:
    ap = json.load(open('$auth_profiles'))
    print('yes' if any(k.startswith('openai-codex') for k in ap.get('profiles', {})) else 'no')
except Exception:
    print('no')
" 2>/dev/null || echo "no")

    if [[ "$has_codex_auth" == "yes" ]]; then
        log "openai-codex auth already configured — skipping OAuth step."
    elif [[ ! -t 0 ]]; then
        log "INFO: No interactive TTY — openai-codex OAuth must be completed manually if needed."
        log "  Run: openclaw models auth login --provider openai-codex"
    else
        log "Running openai-codex OAuth login (TTY detected)..."
        uas openclaw models auth login --provider openai-codex \
            || log "WARNING: openai-codex auth login failed — continuing."
    fi

    # ── Step 2: Apply per-agent model hierarchy via CLI ────────────────────────
    # Anthropic removed — claude-cli path requires Extra Usage (notice 2026-04-04).
    log "Setting model hierarchy: main=gpt-5.4, family=MiniMax-M2.5, fallback=MiniMax-M2.5"
    uas openclaw config set agents.defaults.model.primary "openai-codex/gpt-5.4" 2>&1 \
        | while IFS= read -r line; do log "  config: $line"; done
    uas openclaw config set agents.defaults.model.fallbacks \
        '["minimax/MiniMax-M2.5"]' --strict-json 2>&1 \
        | while IFS= read -r line; do log "  config: $line"; done
    uas openclaw config set 'agents.list[0].model.primary' "openai-codex/gpt-5.4" 2>&1 \
        | while IFS= read -r line; do log "  config: $line"; done
    uas openclaw config set 'agents.list[0].model.fallbacks' \
        '["minimax/MiniMax-M2.5"]' --strict-json 2>&1 \
        | while IFS= read -r line; do log "  config: $line"; done
    uas openclaw config set 'agents.list[1].model.primary' "minimax/MiniMax-M2.5" 2>&1 \
        | while IFS= read -r line; do log "  config: $line"; done
    uas openclaw config set 'agents.list[1].model.fallbacks' \
        '["minimax/MiniMax-M2.5"]' --strict-json 2>&1 \
        | while IFS= read -r line; do log "  config: $line"; done

    # ── Step 3: Verify ────────────────────────────────────────────────────────
    if gateway_is_reachable; then
        verify_model_status
    else
        log "Gateway is not reachable yet — deferring model status verification until after service install."
    fi
}

gateway_is_reachable() {
    oc health --json --timeout 5000 >/dev/null 2>&1
}

verify_model_status() {
    log "--- openclaw models status --plain ---"
    uas openclaw models status --plain 2>&1 \
        | while IFS= read -r line; do log "  $line"; done
    log "--- openclaw models status --plain (family) ---"
    uas openclaw models status --plain --agent family 2>&1 \
        | while IFS= read -r line; do log "  $line"; done
}

# ── 17d. ENABLE DREAMING ──────────────────────────────────────────────────────
enable_dreaming() {
    log "Enabling dreaming (background memory consolidation)..."
    uas openclaw config set plugins.entries.memory-core.config.dreaming.enabled true 2>&1 \
        | while IFS= read -r line; do log "  config: $line"; done
    log "Dreaming enabled (daily sweep at 03:00 UTC)."
}

# ── 17e. ENSURE ACPX PLUGIN ENABLED ──────────────────────────────────────────
ensure_acpx_plugin_enabled() {
    log "Ensuring acpx stays enabled for Codex ACP runtime..."
    uas openclaw config set acp.enabled true --strict-json 2>&1 \
        | while IFS= read -r line; do log "  config: $line"; done
    uas openclaw config set acp.backend "acpx" 2>&1 \
        | while IFS= read -r line; do log "  config: $line"; done
    uas openclaw config set plugins.entries.acpx.enabled true --strict-json 2>&1 \
        | while IFS= read -r line; do log "  config: $line"; done
}
