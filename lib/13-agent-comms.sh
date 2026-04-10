#!/usr/bin/env bash
#
# @intent Final Telegram access adjustments for the OpenClaw deployment.
# @complexity 1
#

# Ensures openclaw.json's telegram.accounts.default allows the configured group.
setup_main_telegram_group() {
    local group_id="${TELEGRAM_AGENT_GROUP_ID:-}"
    local config="$ACTUAL_HOME/.openclaw/openclaw.json"

    if [[ -z "$group_id" ]] || [[ "$group_id" == "REPLACE_ME" ]]; then
        log "  TELEGRAM_AGENT_GROUP_ID not set — skipping Telegram group config."
        return
    fi
    if [[ ! -f "$config" ]]; then
        log "  openclaw.json not found — skipping Telegram group config."
        return
    fi

    log "Configuring Telegram group access for group ${group_id}..."
    python3 - <<PYEOF "$config" "$group_id"
import json, sys
f, gid = sys.argv[1], sys.argv[2]
with open(f) as fp:
    d = json.load(fp)
tg = d.get("channels", {}).get("telegram", {})
acct = tg.get("accounts", {}).get("default", {})
groups = acct.setdefault("groups", {})
if gid not in groups:
    acct["groupPolicy"] = "allowlist"
    allow_from = acct.get("allowFrom", [])
    if gid not in allow_from:
        allow_from.append(gid)
    groups[gid] = {"requireMention": False, "allowFrom": allow_from}
    with open(f, "w") as fp:
        json.dump(d, fp, indent=2)
    print(f"Added group {gid} to Telegram config")
else:
    print(f"Group {gid} already in Telegram config")
PYEOF
    log "  Telegram group config updated."
}

# ── 23. ORCHESTRATOR ──────────────────────────────────────────────────────────
setup_agent_comms() {
    log "Applying remaining Telegram access settings..."
    setup_main_telegram_group
    log "Agent comms setup complete."
}
