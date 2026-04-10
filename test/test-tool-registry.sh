#!/usr/bin/env bash
#
# @intent Automated tests for the modular tool registry refactor.
#         Safe to run anywhere — no system changes, no sudo, no network.
# @complexity 2
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Test framework ─────────────────────────────────────────────────────────────
_PASS=0; _FAIL=0
pass() { echo "  PASS  $1"; (( _PASS++ )) || true; }
fail() { echo "  FAIL  $1"; (( _FAIL++ )) || true; }
assert_eq()   { [[ "$2" == "$3" ]] && pass "$1" || { fail "$1 — got: $(printf '%q' "$3"), want: $(printf '%q' "$2")"; }; }
assert_has()  { [[ "$3" == *"$2"* ]] && pass "$1" || { fail "$1 — '$2' not found in: $3"; }; }
assert_not()  { [[ "$3" != *"$2"* ]] && pass "$1" || { fail "$1 — '$2' should NOT be in: $3"; }; }
assert_file() { [[ -f "$2" ]] && pass "$1" || fail "$1 — file not found: $2"; }

section() { echo; echo "── $1 ──────────────────────────────────────────────────"; }

# ── Runtime stubs (no real installs, no sudo) ──────────────────────────────────
ACTUAL_USER="$USER"
ACTUAL_HOME="$HOME"
_log_output=()
log() { _log_output+=("$*"); }          # capture log calls for assertions
wait_for_apt() { :; }
apt_install()  { :; }
uas()          { "$@" 2>/dev/null || true; }

# ── Temp workspace ─────────────────────────────────────────────────────────────
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ─────────────────────────────────────────────────────────────────────────────
section "1. Tool module files exist"
# ─────────────────────────────────────────────────────────────────────────────
assert_file "_base.sh exists"      "$SCRIPT_DIR/lib/tools/_base.sh"
assert_file "codex.sh exists"      "$SCRIPT_DIR/lib/tools/codex.sh"
assert_file "playwright.sh exists" "$SCRIPT_DIR/lib/tools/playwright.sh"
assert_file "gws.sh exists"        "$SCRIPT_DIR/lib/tools/gws.sh"
assert_file "pandoc.sh exists"     "$SCRIPT_DIR/lib/tools/pandoc.sh"

# ─────────────────────────────────────────────────────────────────────────────
section "2. Tool registry loads — TOOL_NAMES, rules, exports, placeholders"
# ─────────────────────────────────────────────────────────────────────────────

# Source _base.sh + all tool files in a subshell to get a clean state
eval "$(bash -c "
    set -euo pipefail
    source '$SCRIPT_DIR/lib/tools/_base.sh'
    log() { :; }; wait_for_apt() { :; }; apt_install() { :; }; uas() { \"\$@\" 2>/dev/null || true; }
    ACTUAL_USER='$USER'; ACTUAL_HOME='$HOME'; SCRIPT_DIR='$SCRIPT_DIR'
    for _f in '$SCRIPT_DIR'/lib/tools/*.sh; do
        [[ \"\$(basename \"\$_f\")\" == '_base.sh' ]] && continue
        source \"\$_f\"
    done
    echo \"TOOL_NAMES_EXPORT=(\${TOOL_NAMES[*]})\"
    echo \"TOOL_APPARMOR_KEYS=(\${!TOOL_APPARMOR_RULES[*]})\"
    printf 'TOOL_SYSTEMD_GWS=%q\n'     \"\${TOOL_SYSTEMD_EXPORTS[gws]}\"
    printf 'TOOL_SYSTEMD_CODEX=%q\n'   \"\${TOOL_SYSTEMD_EXPORTS[codex]}\"
    printf 'TOOL_SANDBOX_GWS=%q\n'     \"\${TOOL_SANDBOX_ENV[gws]}\"
    printf 'TOOL_SANDBOX_CODEX=%q\n'   \"\${TOOL_SANDBOX_ENV[codex]}\"
    printf 'TOOL_PLACEHOLDER_GWS_KEYS=%q\n' \"\$(echo \"\${TOOL_ENV_PLACEHOLDERS[gws]}\" | cut -d= -f1 | tr '\n' ' ')\"
    printf 'TOOL_PLACEHOLDER_CODEX_KEYS=%q\n' \"\$(echo \"\${TOOL_ENV_PLACEHOLDERS[codex]}\" | cut -d= -f1 | tr '\n' ' ')\"
    printf 'CODEX_RULES=%q\n'          \"\${TOOL_APPARMOR_RULES[codex]}\"
    printf 'PLAYWRIGHT_RULE=%q\n'       \"\${TOOL_APPARMOR_RULES[playwright]:0:40}\"
" 2>/dev/null)"

TOOL_NAMES_EXPORT_STR="${TOOL_NAMES_EXPORT[*]:-}"
TOOL_APPARMOR_KEYS_STR="${TOOL_APPARMOR_KEYS[*]:-}"

assert_has "codex registered"       "codex"         "$TOOL_NAMES_EXPORT_STR"
assert_has "playwright registered"  "playwright"  "$TOOL_NAMES_EXPORT_STR"
assert_has "gws registered"         "gws"          "$TOOL_NAMES_EXPORT_STR"
assert_has "pandoc registered"      "pandoc"       "$TOOL_NAMES_EXPORT_STR"

assert_has "codex AppArmor key"       "codex"         "$TOOL_APPARMOR_KEYS_STR"
assert_has "playwright AppArmor key"  "playwright"  "$TOOL_APPARMOR_KEYS_STR"
assert_has "gws AppArmor key"         "gws"          "$TOOL_APPARMOR_KEYS_STR"
assert_has "pandoc AppArmor key"      "pandoc"       "$TOOL_APPARMOR_KEYS_STR"

assert_has "gws systemd exports CLIENT_ID"     "GOOGLE_WORKSPACE_CLI_CLIENT_ID"    "$TOOL_SYSTEMD_GWS"
assert_has "gws systemd exports CLIENT_SECRET" "GOOGLE_WORKSPACE_CLI_CLIENT_SECRET" "$TOOL_SYSTEMD_GWS"
assert_not "codex systemd does not export OPENAI_API_KEY" "OPENAI_API_KEY" "$TOOL_SYSTEMD_CODEX"
assert_not "codex systemd does not export CODEX_API_KEY"  "CODEX_API_KEY"  "$TOOL_SYSTEMD_CODEX"

assert_has "gws sandbox exports CLIENT_ID"     "GOOGLE_WORKSPACE_CLI_CLIENT_ID"    "$TOOL_SANDBOX_GWS"
assert_has "gws sandbox exports CLIENT_SECRET" "GOOGLE_WORKSPACE_CLI_CLIENT_SECRET" "$TOOL_SANDBOX_GWS"
assert_not "codex sandbox does not export OPENAI_API_KEY" "OPENAI_API_KEY" "$TOOL_SANDBOX_CODEX"
assert_not "codex sandbox does not export CODEX_API_KEY"  "CODEX_API_KEY"  "$TOOL_SANDBOX_CODEX"

assert_has "gws placeholder CLIENT_ID"     "GOOGLE_WORKSPACE_CLI_CLIENT_ID"     "$TOOL_PLACEHOLDER_GWS_KEYS"
assert_has "gws placeholder CLIENT_SECRET" "GOOGLE_WORKSPACE_CLI_CLIENT_SECRET" "$TOOL_PLACEHOLDER_GWS_KEYS"
assert_not "codex placeholder removed"     "OPENAI_API_KEY"                     "$TOOL_PLACEHOLDER_CODEX_KEYS"

assert_has "codex AppArmor rules include npm cache" ".npm/" "$CODEX_RULES"
assert_has "playwright AppArmor rule mentions Chromium" "Chromium" "$PLAYWRIGHT_RULE"

# ─────────────────────────────────────────────────────────────────────────────
section "3. register_tool is idempotent (no duplicate entries)"
# ─────────────────────────────────────────────────────────────────────────────

_dup_count=$(bash -c "
    source '$SCRIPT_DIR/lib/tools/_base.sh'
    log() { :; }; wait_for_apt() { :; }; apt_install() { :; }; uas() { :; }
    ACTUAL_USER='$USER'; ACTUAL_HOME='$HOME'; SCRIPT_DIR='$SCRIPT_DIR'
    for _f in '$SCRIPT_DIR'/lib/tools/*.sh; do
        [[ \"\$(basename \"\$_f\")\" == '_base.sh' ]] && continue
        source \"\$_f\"
    done
    # Source again — register_tool should not duplicate
    for _f in '$SCRIPT_DIR'/lib/tools/*.sh; do
        [[ \"\$(basename \"\$_f\")\" == '_base.sh' ]] && continue
        source \"\$_f\"
    done
    playwright_count=0
    for t in \"\${TOOL_NAMES[@]:-}\"; do [[ \"\$t\" == playwright ]] && (( playwright_count++ )) || true; done
    echo \$playwright_count
" 2>/dev/null)

assert_eq "playwright registered exactly once after double-source" "1" "$_dup_count"

# ─────────────────────────────────────────────────────────────────────────────
section "4. AppArmor marker injection"
# ─────────────────────────────────────────────────────────────────────────────

_tmpl="$SCRIPT_DIR/templates/apparmor-gateway.profile"
_out="$TMP/test-profile.conf"

# Verify marker exists in template
assert_has "template has TOOL_RULES_BEGIN marker" "TOOL_RULES_BEGIN" "$(cat "$_tmpl")"
assert_has "template has TOOL_RULES_END marker"   "TOOL_RULES_END"   "$(cat "$_tmpl")"
assert_not "template no longer has inline chromium rule" \
    "/usr/bin/chromium" "$(grep -v TOOL_RULES "$_tmpl" || true)"

# Run the injection script with a sentinel rule
_sentinel_rule="  /tmp/test-sentinel-12345  r,"
python3 - "$_tmpl" "$_out" "$_sentinel_rule" <<'PYEOF'
import sys, re
tmpl, out, rules = sys.argv[1], sys.argv[2], sys.argv[3]
content = open(tmpl).read()
pat = re.compile(r'  # ── TOOL_RULES_BEGIN.*?  # ── TOOL_RULES_END[^\n]*\n', re.DOTALL)
replacement = "  # ── TOOL_RULES_BEGIN\n" + rules + "\n  # ── TOOL_RULES_END\n"
open(out, 'w').write(pat.sub(replacement, content))
PYEOF

assert_has "injected rule appears in output"          "$_sentinel_rule"    "$(cat "$_out")"
assert_has "TOOL_RULES_BEGIN preserved in output"     "TOOL_RULES_BEGIN"   "$(cat "$_out")"
assert_has "TOOL_RULES_END preserved in output"       "TOOL_RULES_END"     "$(cat "$_out")"
assert_has "DENY block still present after injection" "deny /usr/bin/sudo" "$(cat "$_out")"

# ─────────────────────────────────────────────────────────────────────────────
section "5. apply-config.py — codex ACP target replaces deprecated native agents"
# ─────────────────────────────────────────────────────────────────────────────

# Create a minimal openclaw.json
cat > "$TMP/openclaw.json" << 'EOF'
{"agents": {}, "channels": {}, "bindings": []}
EOF

MINIMAX_API_KEY=x GEMINI_API_KEY=x ANTHROPIC_API_KEY=x \
  OPENCLAW_GATEWAY_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
  TELEGRAM_BOT_TOKEN=x TELEGRAM_CHAT_ID=12345 \
  ACTUAL_HOME="$HOME" \
  python3 "$SCRIPT_DIR/config/apply-config.py" --config "$TMP/openclaw.json" > /dev/null

_agent_ids=$(python3 -c "
import json
c = json.load(open('$TMP/openclaw.json'))
print(' '.join(sorted(a['id'] for a in c['agents']['list'])))
")

_main_allow_agents=$(python3 -c "
import json
c = json.load(open('$TMP/openclaw.json'))
for a in c['agents']['list']:
    if a['id'] == 'main':
        print(' '.join(a.get('subagents', {}).get('allowAgents', [])))
")

_codex_runtime=$(python3 -c "
import json
c = json.load(open('$TMP/openclaw.json'))
for a in c['agents']['list']:
    if a['id'] == 'codex':
        runtime = a.get('runtime', {})
        print(runtime.get('type', ''), runtime.get('acp', {}).get('agent', ''), runtime.get('acp', {}).get('backend', ''))
")

assert_has "main agent present"             "main"             "$_agent_ids"
assert_has "codex agent present"            "codex"            "$_agent_ids"
assert_has "family agent present"           "family"           "$_agent_ids"
assert_not "coding agent removed"           "coding"           "$_agent_ids"
assert_not "marketing agent removed"        "marketing"        "$_agent_ids"
assert_eq  "main may spawn codex"           "codex"            "$_main_allow_agents"
assert_eq  "codex agent uses ACP runtime"   "acp codex acpx"   "$_codex_runtime"

# ─────────────────────────────────────────────────────────────────────────────
section "6. Dummy tool integration — add one file, no other edits needed"
# ─────────────────────────────────────────────────────────────────────────────

_dummy="$TMP/zz_test_dummy.sh"
cat > "$_dummy" << 'DUMMYEOF'
TOOL_APPARMOR_RULES[test_dummy]='  /tmp/test-dummy-sentinel  r,'
TOOL_ENV_PLACEHOLDERS[test_dummy]="TEST_DUMMY_KEY=dummy-sentinel"
TOOL_SYSTEMD_EXPORTS[test_dummy]="TEST_DUMMY_KEY"
_test_dummy_install_called=0
install_test_dummy() { _test_dummy_install_called=1; log "test_dummy: install called"; }
register_tool test_dummy
DUMMYEOF
trap 'rm -rf "$TMP"' EXIT

# Verify registration picks it up
_dummy_registered=$(bash -c "
    source '$SCRIPT_DIR/lib/tools/_base.sh'
    log() { :; }; wait_for_apt() { :; }; apt_install() { :; }; uas() { :; }
    ACTUAL_USER='$USER'; ACTUAL_HOME='$HOME'; SCRIPT_DIR='$SCRIPT_DIR'
    for _f in '$SCRIPT_DIR'/lib/tools/*.sh; do
        [[ \"\$(basename \"\$_f\")\" == '_base.sh' ]] && continue
        source \"\$_f\"
    done
    source '$_dummy'
    printf '%s\n' \"\${TOOL_NAMES[@]:-}\"
" 2>/dev/null | grep -c test_dummy || true)

assert_eq "dummy tool auto-registered by load_tool_modules" "1" "$_dummy_registered"

# Verify install_all_tools calls install_test_dummy without pulling in the real
# tool installers from this repo.
_dummy_log=$(bash -c "
    source '$SCRIPT_DIR/lib/tools/_base.sh'
    _log=''
    log() { _log=\"\$_log \$*\"; }; wait_for_apt() { :; }; apt_install() { :; }; uas() { :; }
    ACTUAL_USER='$USER'; ACTUAL_HOME='$HOME'; SCRIPT_DIR='$SCRIPT_DIR'
    source '$_dummy'
    install_all_tools
    echo \"\$_log\"
" 2>/dev/null)

assert_has "install_all_tools called install_test_dummy" "test_dummy: install called" "$_dummy_log"

# Verify AppArmor rule appears in assembled profile
_dummy_profile="$TMP/dummy-assembled.conf"
_dummy_rules="  /tmp/test-dummy-sentinel  r,"  # matches what zz_test_dummy.sh sets
python3 - "$SCRIPT_DIR/templates/apparmor-gateway.profile" "$_dummy_profile" "$_dummy_rules" <<'PYEOF'
import sys, re
tmpl, out, rules = sys.argv[1], sys.argv[2], sys.argv[3]
content = open(tmpl).read()
pat = re.compile(r'  # ── TOOL_RULES_BEGIN.*?  # ── TOOL_RULES_END[^\n]*\n', re.DOTALL)
replacement = "  # ── TOOL_RULES_BEGIN\n" + rules + "\n  # ── TOOL_RULES_END\n"
open(out, 'w').write(pat.sub(replacement, content))
PYEOF

assert_has "dummy AppArmor rule appears in assembled profile" \
    "/tmp/test-dummy-sentinel" "$(cat "$_dummy_profile")"

# ─────────────────────────────────────────────────────────────────────────────
section "Results"
# ─────────────────────────────────────────────────────────────────────────────
echo
echo "  Passed: $_PASS"
echo "  Failed: $_FAIL"
echo

if (( _FAIL > 0 )); then
    echo "FAIL — $_FAIL test(s) failed."
    exit 1
else
    echo "OK — all $_PASS tests passed."
fi
