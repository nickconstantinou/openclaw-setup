#!/usr/bin/env bash
# OpenClaw Script Refactoring: Advanced Verification Suite
# Verifies syntax, ShellCheck, env coverage, and function resolution.

set -Eeuo pipefail

# Pathing
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

log() { echo -e "\033[1;34m[TEST]\033[0m $1"; }
pass() { echo -e "\033[1;32m[PASS]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
fail() { echo -e "\033[1;31m[FAIL]\033[0m $1"; exit 1; }

echo "==================================================================="
echo "  OPENCLAW ADVANCED REPO VERIFICATION"
echo "==================================================================="

# 1. BASH SYNTAX CHECK
log "Running bash -n syntax checks..."
for f in lib/*.sh openclaw-self-heal.sh install.sh; do
    if bash -n "$f"; then
        pass "  $f"
    else
        fail "  Syntax error in $f"
    fi
done

# 2. SHELLCHECK (STATIC ANALYSIS)
if command -v shellcheck >/dev/null 2>&1; then
    log "Running ShellCheck analysis..."
    # SC1090/1091: ignore non-literal/relative sourcing
    if shellcheck -x -e SC1090,SC1091 lib/*.sh openclaw-self-heal.sh install.sh; then
        pass "  ShellCheck passed"
    else
        warn "  ShellCheck detected potential issues. Review output above."
    fi
else
    warn "  ShellCheck not installed (apt install shellcheck). Skipping static analysis."
fi

# 3. PYTHON SYNTAX CHECK
log "Running python3 -m py_compile checks..."
while IFS= read -r -d '' f; do
    if python3 -m py_compile "$f" >/dev/null 2>&1; then
        pass "  $f"
    else
        fail "  Syntax error in $f"
    fi
done < <(find config skills -type f -name '*.py' -print0 2>/dev/null)

# 4. FUNCTION RESOLUTION AUDIT
log "Auditing function call resolution..."
ORCH_CALLS=$(grep -oP '^\s+\K[a-z_]+(?=\b)' openclaw-self-heal.sh | grep -vE '^(log|die|main|source|trap|set|export|source|if|then|else|fi|main|while|do|done|case|esac|return|exit|echo|cat|rm|mkdir|chown|chmod|sleep|ss|seq|head|grep|while|read)$' | sort -u)
LIB_DEFS=$(grep -hP '^\w+\(\)' lib/*.sh lib/tools/*.sh 2>/dev/null | sed 's/().*//' | sort -u)

MISSING_DEFS=$(comm -23 <(echo "$ORCH_CALLS") <(echo "$LIB_DEFS"))

if [[ -z "$MISSING_DEFS" ]]; then
    pass "  All orchestrator-called functions are defined in lib/"
else
    echo "  MISSING FUNCTIONS DETECTED:"
    echo "$MISSING_DEFS"
    fail "  Orchestrator calls undefined functions!"
fi

# 5. ENVIRONMENT VARIABLE COVERAGE
log "Verifying environment variable coverage..."
# All ${VAR} or $VAR in lib/*.sh
USED_VARS=$(grep -rhPo '\$\{\K[A-Z_0-9]+(?=\})|\$\K[A-Z_0-9]+' lib/*.sh | sort -u)

# Whitelist of internal/system vars
WHITELIST='^(PIPESTATUS|LINENO|BASH_SOURCE|IFS|ACTUAL_USER|ACTUAL_HOME|ACTUAL_UID|SCRIPT_DIR|SCRIPT_VERSION|LOG_FILE|SUDO_USER|USER|VAR|ENTRIES|RETRY|SECS|I|KEY|VAL|P|REQUIRED|HOST|DNS_NAME|DASHBOARD|SSH_URL|STATUS|MSG|CONFIG_FILE|DB|UNIT|EXEC_LINE|EXEC_CMD|DROPIN_DIR|DROPIN_FILE|JOURNAL|REQUIRED_CORE|HOSTNAME|BASH_REMATCH|HOME|PATH|LANG|PWD|TERM|SHELL|EDITOR|UID|PID|PPID|SECONDS|RANDOM|BASH_COMMAND|BASH_EXECUTION_STRING|BASH_SUBSHELL|XDG_RUNTIME_DIR|GH_CONFIG_DIR|GH_IDENTITY|OPENCLAW_GATEWAY_TOKEN|WAITED|MAX_WAIT|1|2|4|_)$'

# Defined/Validated vars in lib/01-env.sh
DEFINED_VARS=$(grep -hPo '\b[A-Z_0-9]+(?==)|(?<=required\()|(?<=placeholders\()|(?<=\$\{)[A-Z_0-9]+(?=\})' lib/01-env.sh | sort -u)
# Pull from required array block
REQUIRED_VARS=$(sed -n '/local required=(/,/)/p' lib/01-env.sh | grep -oP '\b[A-Z_0-9]+\b' | grep -v 'required' || true)
# Pull from placeholders block
PLACEHOLDER_VARS=$(sed -n '/local placeholders=(/,/)/p' lib/01-env.sh | grep -oP '\b[A-Z_0-9]+(?==)' || true)

ALL_DEFINED=$(echo -e "${DEFINED_VARS}\n${REQUIRED_VARS}\n${PLACEHOLDER_VARS}\nLOG_FILE\nSCRIPT_VERSION\nSCRIPT_DIR" | sort -u)

GAPS=$(comm -23 <(echo "$USED_VARS") <(echo "$ALL_DEFINED") | grep -vE "$WHITELIST" || true)

if [[ -z "$GAPS" ]]; then
    pass "  All referenced env vars are defined or have known defaults"
else
    warn "  Potentially unvalidated env vars discovered:"
    echo "$GAPS"
    echo "  (Verification: ensure these are either system vars or defined in .env)"
fi

# 6. IDEMPOTENCY SCAN
log "Scanning for non-idempotent operations..."
# Find apt/pip/curl without guards. 
# We ignore lines containing 'missing' (array-based guard), 'uas' (user context wrapper), or explicit checks.
NON_IDEMPOTENT=$(grep -rnE 'apt-get install|pip install|curl -o|curl -L' lib/*.sh \
    | grep -vE 'wait_for_apt|uas|if \[\[ -f|if command -v|if dpkg -s|missing|installer_path' || true)

if [[ -z "$NON_IDEMPOTENT" ]]; then
    pass "  No obvious non-idempotent installers found"
else
    warn "  Manual review suggested for these potential raw installs:"
    echo "$NON_IDEMPOTENT"
fi

# 7. ASSET PRESENCE
log "Verifying mandatory assets..."
ASSETS=(
    "templates/apparmor-gateway.profile"
    "config/apply-config.py"
    "config/patch-stale-keys.py"
    "config/reapply-models.py"
    "skills/general-agent/transcription/SKILL.md"
    "skills/general-agent/ffmpeg/SKILL.md"
    "skills/general-agent/nvidia-imagegen/SKILL.md"
    "skills/general-agent/nvidia-imagegen/generate.py"
)

for asset in "${ASSETS[@]}"; do
    if [[ -s "$asset" ]]; then
        pass "  $asset"
    else
        fail "  Missing mandatory asset: $asset"
    fi
done

echo "==================================================================="
pass "VERIFICATION COMPLETE."
echo "==================================================================="
