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
    sudo apt-get install -y -q apparmor apparmor-utils 2>/dev/null || true

    local profile_path="/etc/apparmor.d/openclaw-gateway"
    local template_path="$SCRIPT_DIR/templates/apparmor-gateway.profile"

    if [[ -f "$template_path" ]]; then
        sudo cp "$template_path" "$profile_path"
        sudo apparmor_parser -r "$profile_path" || log "WARNING: Failed to load AppArmor profile."
        log "AppArmor profile loaded: $profile_path"
    else
        log "WARNING: AppArmor template missing: $template_path"
    fi
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
