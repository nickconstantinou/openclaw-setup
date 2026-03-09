#!/usr/bin/env bash
# 
# @intent AppArmor security profile management (§10, §11c).
# @complexity 3
# 

# ── 10. APPARMOR PROFILE ──────────────────────────────────────────────────────
setup_apparmor() {
    if ! command -v apparmor_status >/dev/null 2>&1 && ! apt-cache show apparmor-utils >/dev/null 2>&1; then
        log "AppArmor not available on this system. Skipping."
        return
    fi

    log "Installing and configuring AppArmor profile..."
    wait_for_apt
    apt_install apparmor apparmor-utils || log "WARNING: AppArmor install failed."

    local profile_path="/etc/apparmor.d/openclaw-gateway"
    local template_path="$SCRIPT_DIR/templates/apparmor-gateway.profile"

    if [[ ! -f "$template_path" ]]; then
        log "WARNING: AppArmor template missing: $template_path"
        return
    fi

    # Collect rules from loaded tool modules
    local tool_rules=""
    local name
    for name in "${TOOL_NAMES[@]:-}"; do
        [[ -n "${TOOL_APPARMOR_RULES[$name]:-}" ]] && tool_rules+="${TOOL_APPARMOR_RULES[$name]}"$'\n'
    done

    # Inject tool rules between markers using python3
    sudo python3 - "$template_path" "$profile_path" "$tool_rules" <<'PYEOF'
import sys, re
tmpl, out, rules = sys.argv[1], sys.argv[2], sys.argv[3]
content = open(tmpl).read()
pat = re.compile(r'  # ── TOOL_RULES_BEGIN.*?  # ── TOOL_RULES_END[^\n]*\n', re.DOTALL)
replacement = "  # ── TOOL_RULES_BEGIN\n" + rules + "  # ── TOOL_RULES_END\n"
open(out, 'w').write(pat.sub(replacement, content))
PYEOF

    sudo apparmor_parser -r "$profile_path" || log "WARNING: Failed to load AppArmor profile."
    log "AppArmor profile assembled and loaded: $profile_path"
}

# ── 10b. DOCKER PATCHING ──────────────────────────────────────────────────────
# Ensures the deployed AppArmor profile allows docker execution (sandbox support).
# Idempotent: no-op if rules already present.
patch_apparmor_docker() {
    # Only patch docker rules if sandbox mode is enabled
    if [[ "${OPENCLAW_SANDBOX_MODE:-}" == "off" ]]; then
        log "Skipping AppArmor docker patch (sandbox disabled)."
        return 0
    fi
    local profile_path="/etc/apparmor.d/openclaw-gateway"

    if [[ ! -f "$profile_path" ]]; then
        log "AppArmor profile not found at $profile_path. Skipping docker patch."
        return
    fi

    if sudo grep -qF "/usr/bin/docker" "$profile_path"; then
        log "AppArmor profile already includes docker rules."
        return
    fi

    log "Patching AppArmor profile to allow docker execution..."
    sudo sed -i 's|  # ── Network / ip|  # ── Docker (sandbox execution) ─────────────────────────────────────────────\n  # OpenClaw spawns docker to run agent sandboxes (agents.defaults.sandbox)\n  /usr/bin/docker                      ix,\n  /var/run/docker.sock                 rw,\n\n  # ── Network / ip|' "$profile_path"
    sudo apparmor_parser -r "$profile_path" && log "AppArmor profile updated with docker rules." || log "WARNING: AppArmor profile reload failed."
}

# ── 11c. VAULT PATCHING ───────────────────────────────────────────────────────
patch_apparmor_vault() {
    local profile_path="/etc/apparmor.d/openclaw-gateway"
    local vault_path="${1%/}"

    if [[ ! -f "$profile_path" ]]; then
        log "WARNING: AppArmor profile not found at $profile_path. Skipping vault patch."
        return
    fi

    if sudo grep -qF "$vault_path" "$profile_path"; then
        log "AppArmor profile already includes vault path."
        return
    fi

    log "Patching AppArmor profile with vault path: $vault_path"
    
    # Python-based patcher (modular version of the monolith logic)
    sudo python3 - <<EOF "$profile_path" "$vault_path"
import sys
profile_path = sys.argv[1]
vault_path   = sys.argv[2]
with open(profile_path, "r") as fh:
    lines = fh.readlines()
insert_at = None
for i in range(len(lines) - 1, -1, -1):
    if lines[i].strip() == "}":
        insert_at = i
        break
if insert_at is None:
    sys.exit(1)
new_rules = [
    "\n",
    "  # Obsidian vault read/write\n",
    "  " + vault_path + "/   rw,\n",
    "  " + vault_path + "/** rw,\n",
]
lines[insert_at:insert_at] = new_rules
with open(profile_path, "w") as fh:
    fh.writelines(lines)
EOF

    sudo apparmor_parser -r "$profile_path" && log "AppArmor profile updated." || log "WARNING: AppArmor profile reload failed."
}
