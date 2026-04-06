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
    log "DEBUG: TOOL_NAMES has ${#TOOL_NAMES[@]} items: ${TOOL_NAMES[*]:-}"
    for name in "${TOOL_NAMES[@]:-}"; do
        [[ -n "${TOOL_APPARMOR_RULES[$name]:-}" ]] && tool_rules+="${TOOL_APPARMOR_RULES[$name]}"$'\n'
    done
    log "DEBUG: Collected tool_rules length: ${#tool_rules}"

    # Inject nvm read/exec rules if nvm is in use.
    # NVM_NODE_DIR is e.g. /home/openclaw/.nvm/versions/node/v24.14.1/bin — set by lib/01-env.sh.
    # The gateway binary lives under the sibling lib/node_modules/ directory, so AppArmor
    # needs read access there and ix permission on the binaries.
    if [[ -n "${NVM_NODE_DIR:-}" ]]; then
        local nvm_base
        nvm_base="$(dirname "$NVM_NODE_DIR")"   # .../versions/node/v24.14.1
        local nvm_rules
        nvm_rules="  # ── nvm node — gateway runtime path\n"
        nvm_rules+="  ${nvm_base}/lib/node_modules/openclaw/**  r,\n"
        nvm_rules+="  ${NVM_NODE_DIR}/**  rix,\n"
        tool_rules="${nvm_rules}${tool_rules}"
        log "DEBUG: Injected nvm AppArmor rules for: $nvm_base"
    fi

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

# ── 10b. DOCKER PATCHING (DEPRECATED) ──────────────────────────────────────────
# Docker rules are now built natively into the apparmor-gateway.profile template.
# The patch_apparmor_docker function has been removed.

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
