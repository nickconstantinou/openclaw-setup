#!/usr/bin/env bash
# memory-consolidation.sh
# Daily memory consolidation — runs at 3:30am via systemd timer.
# Initialises the day's memory file and reports on system state.
# Both Chas and Claude Code append session notes to the same dated file.

set -euo pipefail

DATE=$(date "+%Y-%m-%d")
WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
MEMORY_DIR="$WORKSPACE/memory"
MEMORY_FILE="$MEMORY_DIR/${DATE}.md"
INBOX_FILE="$WORKSPACE/agent-inbox.md"

mkdir -p "$MEMORY_DIR"

# ── Only initialise if the file doesn't exist yet ────────────────────────────
if [[ ! -f "$MEMORY_FILE" ]]; then
    cat > "$MEMORY_FILE" <<EOF
# Memory — ${DATE}

## Sessions Summary

_No session notes yet. Agents append here during the day._

## Systems Status

- Content crawler: $(cd "$WORKSPACE/projects/content-crawler" 2>/dev/null && git log --oneline -1 2>/dev/null || echo 'unknown')
- Personal blog:   $(cd "$WORKSPACE/projects/personal-blog" 2>/dev/null && git log --oneline -1 2>/dev/null || echo 'unknown')
- Agent inbox:     $(wc -l < "$INBOX_FILE" 2>/dev/null || echo '0') lines

## Open Questions / Pending

_Carry forward unresolved items from yesterday here._

EOF
    echo "[memory-consolidation] Initialised $MEMORY_FILE"
else
    echo "[memory-consolidation] $MEMORY_FILE already exists — skipping init."
fi

# ── Ensure agent-inbox.md exists ─────────────────────────────────────────────
if [[ ! -f "$INBOX_FILE" ]]; then
    cat > "$INBOX_FILE" <<'EOF'
# Agent Inbox

Shared message queue between Claude Code and Chas.

**Format:** `[FROM: Agent] [TO: Agent] [YYYY-MM-DD HH:MM] Message`

Both agents should check this file at session start and clear messages addressed to them after reading.

---

EOF
    echo "[memory-consolidation] Initialised agent-inbox.md"
fi

echo "[memory-consolidation] Done."
