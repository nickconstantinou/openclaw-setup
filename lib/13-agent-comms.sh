#!/usr/bin/env bash
#
# @intent Agent communication infrastructure: shared inbox, memory consolidation cron (§23).
# @complexity 1
#

# ── 23.1 AGENT INBOX ──────────────────────────────────────────────────────────
setup_agent_inbox() {
    local workspace="$ACTUAL_HOME/.openclaw/workspace"
    local inbox="$workspace/agent-inbox.md"

    log "Setting up agent inbox..."

    uas mkdir -p "$workspace"

    if [[ ! -f "$inbox" ]]; then
        uas tee "$inbox" > /dev/null <<'EOF'
# Agent Inbox

Shared message queue between Claude Code and Chas.

**Format:** `[FROM: Agent] [TO: Agent] [YYYY-MM-DD HH:MM] Message`

Both agents should check this file at session start and clear messages addressed to them after reading.

---

EOF
        log "  Agent inbox created: $inbox"
    else
        log "  Agent inbox already exists."
    fi
}

# ── 23.2 MEMORY CONSOLIDATION SCRIPT ─────────────────────────────────────────
deploy_memory_consolidation_script() {
    local scripts_dir="$ACTUAL_HOME/.openclaw/workspace/scripts"
    local dest="$scripts_dir/memory-consolidation.sh"

    log "Deploying memory-consolidation.sh..."
    uas mkdir -p "$scripts_dir"
    uas cp "$SCRIPT_DIR/scripts/memory-consolidation.sh" "$dest"
    chmod 755 "$dest"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$dest"
    log "  Deployed: $dest"
}

# ── 23.3 SYSTEMD TIMER FOR MEMORY CONSOLIDATION ───────────────────────────────
setup_memory_consolidation_timer() {
    local unit_dir="$ACTUAL_HOME/.config/systemd/user"
    local script="$ACTUAL_HOME/.openclaw/workspace/scripts/memory-consolidation.sh"

    log "Installing memory-consolidation systemd timer (3:30am daily)..."
    uas mkdir -p "$unit_dir"

    # Service unit
    uas tee "$unit_dir/openclaw-memory-consolidation.service" > /dev/null <<EOF
[Unit]
Description=OpenClaw Daily Memory Consolidation
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash $script
StandardOutput=journal
StandardError=journal
Environment=OPENCLAW_WORKSPACE=$ACTUAL_HOME/.openclaw/workspace
EOF

    # Timer unit
    uas tee "$unit_dir/openclaw-memory-consolidation.timer" > /dev/null <<EOF
[Unit]
Description=OpenClaw Daily Memory Consolidation Timer

[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Enable and start the timer
    uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" \
        systemctl --user daemon-reload 2>/dev/null || true
    uas env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" \
        systemctl --user enable --now openclaw-memory-consolidation.timer 2>/dev/null \
        && log "  Timer enabled: openclaw-memory-consolidation.timer" \
        || log "  WARNING: Could not enable timer (will activate on next login)."
}

# ── 23.4 ENSURE AGENTS.MD HAS MEMORY + INBOX PROTOCOL ────────────────────────
ensure_agents_md_protocol() {
    local agents_md="$ACTUAL_HOME/.openclaw/workspace/AGENTS.md"

    if [[ ! -f "$agents_md" ]]; then
        log "  AGENTS.md not found — skipping protocol injection."
        return
    fi

    # Only inject if the inbox section isn't already present
    if ! grep -q "Agent Inbox" "$agents_md" 2>/dev/null; then
        log "  Injecting Agent Inbox and Memory Protocol into AGENTS.md..."
        uas tee -a "$agents_md" > /dev/null <<'EOF'

---

## Agent Inbox

Check `~/.openclaw/workspace/agent-inbox.md` at the start of each session for messages from Claude Code. Clear messages addressed to you after reading. To leave a message for Claude Code, append:

```
[FROM: Chas] [TO: Claude Code] [YYYY-MM-DD HH:MM] Your message here
```

Claude Code can invoke you indirectly by writing tasks here. You can invoke Claude Code directly via `cc "task"`.

---

## Memory Protocol

After any session that changes project state, append a section to today's log:

```
~/.openclaw/workspace/memory/YYYY-MM-DD.md
```

Include: what changed, what's pending, non-obvious context. Claude Code writes to the same file under its own heading — never overwrite the other agent's section.
EOF
        log "  Memory protocol injected."
    else
        log "  AGENTS.md already has inbox/memory protocol."
    fi
}

# ── 23.5 CLAUDE CODE TELEGRAM PLUGIN ─────────────────────────────────────────
setup_claude_code_telegram() {
    local claude_bin="$ACTUAL_HOME/.local/bin/claude"
    local bot_token="${TELEGRAM_BOT_TOKEN_CC:-}"
    local allowed_users="${TELEGRAM_ALLOWED_USERS:-}"

    # Skip if Claude Code is not installed or token is placeholder/unset
    if [[ ! -x "$claude_bin" ]]; then
        log "  Claude Code not installed — skipping Telegram plugin setup."
        return
    fi
    if [[ -z "$bot_token" ]] || [[ "$bot_token" == tg-REPLACE_ME* ]]; then
        log "  TELEGRAM_BOT_TOKEN_CC not set — skipping Claude Code Telegram plugin."
        return
    fi

    log "Setting up Claude Code Telegram plugin..."

    # 1. Install the plugin if not already installed
    local plugin_dir="$ACTUAL_HOME/.claude/plugins"
    if ! uas HOME="$ACTUAL_HOME" "$claude_bin" plugin list 2>/dev/null | grep -q "telegram"; then
        log "  Installing telegram plugin..."
        uas HOME="$ACTUAL_HOME" "$claude_bin" plugin install telegram@claude-plugins-official --yes 2>&1 \
            | while IFS= read -r line; do log "  plugin: $line"; done \
            || log "  WARNING: Plugin install failed — may already be installed."
    else
        log "  Telegram plugin already installed."
    fi

    # 2. Write bot token
    local channel_dir="$ACTUAL_HOME/.claude/channels/telegram"
    uas mkdir -p "$channel_dir"
    uas tee "$channel_dir/.env" > /dev/null <<EOF
TELEGRAM_BOT_TOKEN=${bot_token}
EOF
    chmod 600 "$channel_dir/.env"
    chown "$ACTUAL_USER:$ACTUAL_USER" "$channel_dir/.env"
    log "  Bot token written."

    # 3. Write access.json — allowlist from TELEGRAM_ALLOWED_USERS (comma or space separated)
    local allow_json="[]"
    if [[ -n "$allowed_users" ]] && [[ "$allowed_users" != "REPLACE_ME" ]]; then
        # Convert comma/space separated user IDs to JSON array of strings
        allow_json=$(python3 -c "
import sys, json, re
raw = sys.argv[1]
ids = [x.strip() for x in re.split(r'[,\s]+', raw) if x.strip()]
print(json.dumps(ids))
" "$allowed_users" 2>/dev/null || echo '[]')
    fi

    # Build groups JSON if TELEGRAM_AGENT_GROUP_ID is set
    local group_id="${TELEGRAM_AGENT_GROUP_ID:-}"
    local groups_json="{}"
    if [[ -n "$group_id" ]] && [[ "$group_id" != "REPLACE_ME" ]]; then
        groups_json=$(python3 -c "
import sys, json
gid = sys.argv[1]
# Ensure all allowed users are also in group allowFrom
allow_from = json.loads(sys.argv[2]) if sys.argv[2] != '[]' else []
if gid not in allow_from:
    allow_from.append(gid)
print(json.dumps({gid: {'requireMention': False, 'allowFrom': allow_from}}, indent=2))
" "$group_id" "$allow_json" 2>/dev/null || echo "{}")
    fi

    local access_file="$channel_dir/access.json"
    if [[ ! -f "$access_file" ]]; then
        uas tee "$access_file" > /dev/null <<EOF
{
  "dmPolicy": "pairing",
  "allowFrom": ${allow_json},
  "groups": ${groups_json},
  "pending": {}
}
EOF
        chown "$ACTUAL_USER:$ACTUAL_USER" "$access_file"
        log "  access.json created with allowFrom: ${allow_json}, groups: ${group_id:-none}"
    else
        # Update group entry in existing access.json if group ID is set
        if [[ -n "$group_id" ]] && [[ "$group_id" != "REPLACE_ME" ]]; then
            python3 - <<PYEOF "$access_file" "$group_id" "$allow_json"
import json, sys
f, gid, allow_raw = sys.argv[1], sys.argv[2], sys.argv[3]
with open(f) as fp:
    d = json.load(fp)
groups = d.setdefault("groups", {})
if gid not in groups:
    import re
    allow = json.loads(allow_raw) if allow_raw != '[]' else []
    if gid not in allow:
        allow.append(gid)
    groups[gid] = {"requireMention": False, "allowFrom": allow}
    with open(f, "w") as fp:
        json.dump(d, fp, indent=2)
    print(f"Added group {gid} to access.json")
else:
    print(f"Group {gid} already in access.json")
PYEOF
            chown "$ACTUAL_USER:$ACTUAL_USER" "$access_file"
            log "  Group ${group_id} ensured in access.json."
        else
            log "  access.json already exists — preserving existing access rules."
        fi
    fi

    # 4. Ensure approved/ and inbox/ dirs exist
    uas mkdir -p "$channel_dir/approved" "$channel_dir/inbox"
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$channel_dir"

    # 5. Add MCP permission to settings.local.json
    local settings_local="$ACTUAL_HOME/.claude/settings.local.json"
    if [[ ! -f "$settings_local" ]]; then
        uas tee "$settings_local" > /dev/null <<'EOF'
{"permissions":{"allow":["mcp__plugin_telegram_telegram__reply"]}}
EOF
        chown "$ACTUAL_USER:$ACTUAL_USER" "$settings_local"
        log "  Created settings.local.json with Telegram MCP permission."
    elif ! grep -q "mcp__plugin_telegram_telegram__reply" "$settings_local" 2>/dev/null; then
        python3 - <<PYEOF "$settings_local"
import json, sys
f = sys.argv[1]
with open(f) as fp:
    d = json.load(fp)
perms = d.setdefault("permissions", {})
allow = perms.setdefault("allow", [])
perm = "mcp__plugin_telegram_telegram__reply"
if perm not in allow:
    allow.append(perm)
    with open(f, "w") as fp:
        json.dump(d, fp, indent=4)
    print(f"Added {perm} to {f}")
else:
    print(f"{perm} already present")
PYEOF
        chown "$ACTUAL_USER:$ACTUAL_USER" "$settings_local"
        log "  Telegram MCP permission added to settings.local.json."
    else
        log "  Telegram MCP permission already present."
    fi

    log "Claude Code Telegram plugin setup complete."
}

# ── 23.6 CHAS TELEGRAM GROUP ACCESS ──────────────────────────────────────────
# Ensures openclaw.json's telegram.accounts.default allows the agent comms group.
setup_chas_telegram_group() {
    local group_id="${TELEGRAM_AGENT_GROUP_ID:-}"
    local config="$ACTUAL_HOME/.openclaw/openclaw.json"

    if [[ -z "$group_id" ]] || [[ "$group_id" == "REPLACE_ME" ]]; then
        log "  TELEGRAM_AGENT_GROUP_ID not set — skipping Chas group config."
        return
    fi
    if [[ ! -f "$config" ]]; then
        log "  openclaw.json not found — skipping Chas group config."
        return
    fi

    log "Configuring Chas Telegram group access for group ${group_id}..."
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
    print(f"Added group {gid} to Chas Telegram config")
else:
    print(f"Group {gid} already in Chas Telegram config")
PYEOF
    log "  Chas Telegram group config updated."
}

# ── 23. ORCHESTRATOR ──────────────────────────────────────────────────────────
setup_agent_comms() {
    log "Setting up agent communication infrastructure..."
    setup_agent_inbox
    deploy_memory_consolidation_script
    setup_memory_consolidation_timer
    ensure_agents_md_protocol
    setup_claude_code_telegram
    setup_chas_telegram_group
    log "Agent comms setup complete."
}
