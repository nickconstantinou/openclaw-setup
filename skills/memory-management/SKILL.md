---
name: memory-management
description: >
  OpenClaw memory database management using SQLite. Use this skill for
  memory search, memory repair, database maintenance, WAL mode, backups,
  or when the agent encounters locked database errors.
---

# SKILL: Memory Management

SQLite at ~/.openclaw/memory/main.sqlite. WAL journal mode enabled.

## Primary interface
```bash
oc memory search "query terms"
oc memory index        # rebuild search index
oc memory list --limit 20
```

## Inspect directly
```bash
DB="$HOME/.openclaw/memory/main.sqlite"
sqlite3 "$DB" "PRAGMA journal_mode;"           # should be: wal
sqlite3 "$DB" "SELECT COUNT(*) FROM memories;"
sqlite3 "$DB" "SELECT id, substr(content,1,80), created_at FROM memories ORDER BY created_at DESC LIMIT 10;"
sqlite3 "$DB" "PRAGMA integrity_check;"
```

## Fix locked database
```bash
DB="$HOME/.openclaw/memory/main.sqlite"
systemctl --user stop openclaw-gateway.service
rm -f "${DB}-wal" "${DB}-shm"
sqlite3 "$DB" "PRAGMA integrity_check;"
systemctl --user start openclaw-gateway.service
oc memory index
```

## Enable WAL mode (if not set)
```bash
systemctl --user stop openclaw-gateway.service
sqlite3 "$HOME/.openclaw/memory/main.sqlite" "PRAGMA journal_mode=WAL;"
systemctl --user start openclaw-gateway.service
```

## Backup memory
```bash
# Safe online backup — no need to stop gateway
sqlite3 "$HOME/.openclaw/memory/main.sqlite" ".backup $HOME/obsidian/vault/memory-backup-$(date +%Y%m%d).sqlite"
```

## Rules
- Never delete main.sqlite unless instructed by the user — it is the agent memory
- Always stop gateway before VACUUM or journal_mode change
- WAL/SHM deletion is safe only while gateway is stopped
- Use oc memory search for normal use; sqlite3 only for inspection and repair
