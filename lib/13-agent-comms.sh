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

# ── 23. ORCHESTRATOR ──────────────────────────────────────────────────────────
setup_agent_comms() {
    log "Setting up agent communication infrastructure..."
    setup_agent_inbox
    deploy_memory_consolidation_script
    setup_memory_consolidation_timer
    ensure_agents_md_protocol
    log "Agent comms setup complete."
}
