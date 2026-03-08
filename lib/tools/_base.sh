#!/usr/bin/env bash
#
# @intent Tool registry base — shared arrays and dispatcher functions.
# @complexity 2
#

declare -a  TOOL_NAMES=()
declare -A  TOOL_APPARMOR_RULES=()
declare -A  TOOL_ENV_PLACEHOLDERS=()   # "KEY=sentinel\nKEY2=sentinel2"
declare -A  TOOL_SYSTEMD_EXPORTS=()    # "VAR1 VAR2" (space-separated)

register_tool() {
    local name="$1"
    # Idempotent — skip if already registered
    local t
    for t in "${TOOL_NAMES[@]:-}"; do
        [[ "$t" == "$name" ]] && return 0
    done
    TOOL_NAMES+=("$name")
}

install_all_tools() {
    for name in "${TOOL_NAMES[@]:-}"; do
        if declare -f "install_${name}" >/dev/null 2>&1; then
            "install_${name}"
        else
            log "WARNING: No install_${name}() for tool: $name"
        fi
    done
}

load_tool_modules() {
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/tools/_base.sh" 2>/dev/null || true
    local _f
    for _f in "$SCRIPT_DIR"/lib/tools/*.sh; do
        [[ "$(basename "$_f")" == "_base.sh" ]] && continue
        # shellcheck source=/dev/null
        source "$_f"
    done
    unset _f
}
