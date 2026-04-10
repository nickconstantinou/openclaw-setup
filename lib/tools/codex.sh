#!/usr/bin/env bash
#
# @intent OpenAI Codex CLI tool module — non-interactive code generation agent.
# @complexity 2
#

TOOL_APPARMOR_RULES[codex]=$(cat <<'RULES'
  # ── OpenAI Codex CLI ─────────────────────────────────────────────────────────
  # Codex runs as a Node.js process via npm global install
  /usr/bin/env                         ix,
  /usr/bin/node                        ix,
  /usr/bin/npm                         ix,
  /usr/bin/npx                         ix,
  # npm global bin location (codex binary symlink)
  /usr/local/bin/codex                 ix,
  @{HOME}/.local/bin/codex             ix,
  # Codex state directory (~/.codex): config, auth, session cache
  @{HOME}/.codex/                      rw,
  @{HOME}/.codex/**                    rw,
  # ACP Codex adapter is fetched and executed via npx using the user's npm cache
  @{HOME}/.npm/                        rw,
  @{HOME}/.npm/**                      mrwix,
  # npm global package install location
  /usr/lib/node_modules/@openai/       r,
  /usr/lib/node_modules/@openai/**     mrwix,
  @{HOME}/.local/lib/node_modules/@openai/   r,
  @{HOME}/.local/lib/node_modules/@openai/** mrwix,
RULES
)

TOOL_ENV_PLACEHOLDERS[codex]=""
TOOL_SYSTEMD_EXPORTS[codex]=""
TOOL_SANDBOX_ENV[codex]=""

scrub_codex_api_key_auth() {
    local auth_file="$ACTUAL_HOME/.codex/auth.json"
    [[ -f "$auth_file" ]] || return 0

    local result
    result=$(uas python3 - "$auth_file" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception:
    print("invalid")
    raise SystemExit(0)

changed = False
for key in ("OPENAI_API_KEY", "CODEX_API_KEY"):
    value = data.get(key)
    if isinstance(value, str) and value:
        data.pop(key, None)
        changed = True

if data.get("auth_mode") == "apikey":
    data.pop("auth_mode", None)
    changed = True

if not any(
    isinstance(data.get(key), str) and data.get(key)
    for key in ("OPENAI_API_KEY", "CODEX_API_KEY")
):
    pass

if not changed:
    print("unchanged")
elif data:
    path.write_text(json.dumps(data, indent=2) + "\n")
    print("updated")
else:
    path.unlink()
    print("deleted")
PY
)

    case "$result" in
        updated|deleted)
            log "Removed API-key Codex auth from $auth_file to keep Codex on OAuth-only auth."
            ;;
        invalid)
            log "WARNING: Could not parse $auth_file while checking for placeholder Codex auth."
            ;;
    esac
}

codex_oauth_ready() {
    local auth_file="$ACTUAL_HOME/.codex/auth.json"
    [[ -f "$auth_file" ]] || return 1

    uas python3 - "$auth_file" <<'PY' >/dev/null 2>&1
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception:
    raise SystemExit(1)

if data.get("auth_mode") == "apikey":
    raise SystemExit(1)

for key in ("OPENAI_API_KEY", "CODEX_API_KEY"):
    value = data.get(key)
    if isinstance(value, str) and value:
        raise SystemExit(1)

raise SystemExit(0 if data else 1)
PY
}

prewarm_codex_acp_adapter() {
    local user_path
    user_path=$(build_user_path)

    mkdir -p "$ACTUAL_HOME/.npm" "$ACTUAL_HOME/.codex"
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ACTUAL_HOME/.npm" "$ACTUAL_HOME/.codex" 2>/dev/null || true
    scrub_codex_api_key_auth

    if ! codex_oauth_ready; then
        log "Skipping Codex ACP prewarm until Codex OAuth is configured."
        return 0
    fi

    log "Prewarming Codex ACP adapter..."
    if timeout 20 sudo -u "$ACTUAL_USER" env \
        HOME="$ACTUAL_HOME" \
        PATH="$user_path" \
        npm_config_cache="$ACTUAL_HOME/.npm" \
        npx @zed-industries/codex-acp@^0.11.1 --help >/dev/null 2>&1; then
        log "Codex ACP adapter is ready."
    else
        log "WARNING: Codex ACP adapter prewarm failed. ACP Codex sessions may need a manual retry."
    fi
}

# ── INSTALL CODEX CLI ─────────────────────────────────────────────────────────
install_codex() {
    local codex_bin
    codex_bin=$(command -v codex 2>/dev/null || true)

    if [[ -n "$codex_bin" ]]; then
        local current_ver; current_ver=$("$codex_bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        local latest_ver;  latest_ver=$(uas npm view @openai/codex version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")

        if [[ "$current_ver" == "$latest_ver" ]] && [[ "$current_ver" != "unknown" ]]; then
            log "Codex CLI already installed ($current_ver) and up-to-date. Skipping."
        else
            log "Codex CLI update available: $current_ver → $latest_ver. Upgrading..."
            HOME=/root npm install -g @openai/codex@latest --quiet 2>&1 \
                && log "Codex CLI upgraded to $latest_ver." \
                || log "WARNING: Codex CLI upgrade failed — continuing with existing version."
        fi
    else
        log "Installing Codex CLI (@openai/codex)..."
        # Node 22+ required — check before installing
        local node_major; node_major=$(node --version 2>/dev/null | grep -oE '^v[0-9]+' | tr -d 'v' || echo "0")
        if [[ "$node_major" -lt 22 ]]; then
            log "WARNING: Codex CLI requires Node.js 22+. Current: v${node_major}. Skipping install."
            return
        fi

        HOME=/root npm install -g @openai/codex --quiet 2>&1 \
            && log "Codex CLI installed: $(command -v codex 2>/dev/null || echo 'location unknown')" \
            || log "WARNING: Codex CLI install failed. ACP Codex sessions may be unavailable until the CLI is installed."
    fi

    if codex_oauth_ready; then
        log "Codex CLI OAuth auth detected in ~/.codex/auth.json."
    else
        log "INFO: Codex CLI OAuth is not configured yet."
        log "  Run as $ACTUAL_USER: codex login"
    fi

    prewarm_codex_acp_adapter
}

register_tool codex
