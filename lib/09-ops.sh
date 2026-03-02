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

# ── 17. ONBOARDING ────────────────────────────────────────────────────────────
onboard_gateway() {
    log "Running onboard setup..."
    oc onboard --non-interactive --accept-risk || true
}

# ── 17b. RE-APPLY MODELS ──────────────────────────────────────────────────────
reapply_models() {
    log "Re-applying model catalog and media config (post-onboard)..."
    local config_file="$ACTUAL_HOME/.openclaw/openclaw.json"
    uas python3 "$SCRIPT_DIR/config/reapply-models.py" --config "$config_file"
}
