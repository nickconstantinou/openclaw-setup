# systemd-timer-scheduler Skill

_Reference for scheduling recurring and one-shot tasks on this server using systemd user timers._

---

## Why Systemd Timers Instead of Crontab?

- **crontab is blocked by AppArmor** — writing to crontab would spawn jobs unconfined, breaking the sandbox
- **User timers stay sandboxed** — run inside the same AppArmor profile as the gateway (`openclaw-gateway`)
- **Better observability** — logging via `journalctl --user`, failure tracking, `systemctl --user list-timers`

## Environment Facts

| Fact | Value |
|------|-------|
| User | `openclaw` |
| Unit directory | `~/.config/systemd/user/` |
| Linger | **Enabled** (timers survive session end) |
| AppArmor profile | `openclaw-gateway` |
| Scope | `--user` only (never --system) |

---

## 1. Creating a One-Shot Timer

Creates a timer that fires **once** at a specific datetime.

### Files to Create

**`~/.config/systemd/user/openclaw-example-once.timer`**
```ini
[Unit]
Description=Run once at a specific time

[Timer]
OnCalendar=2026-03-01 14:30:00
Persistent=true

[Install]
WantedBy=timers.target
```

**`~/.config/systemd/user/openclaw-example-once.service`**
```ini
[Unit]
Description=One-shot task example
Type=oneshot

[Service]
ExecStart=/usr/bin/echo "Task executed at $(date)"
User=openclaw
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

### Enable and Start

```bash
systemctl --user daemon-reload
systemctl --user enable --now openclaw-example-once.timer
```

### Verify Registration

```bash
# Check timer status
systemctl --user list-timers --all | grep openclaw-example-once

# Check next run time
systemctl --user list-timers
```

---

## 2. Creating a Recurring Timer

Creates a timer that fires on a schedule (cron-equivalent).

### Files to Create

**`~/.config/systemd/user/openclaw-vault-backup-daily.timer`**
```ini
[Unit]
Description=Run vault backup daily at 1am

[Timer]
OnCalendar=*-*-* 01:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

**`~/.config/systemd/user/openclaw-vault-backup-daily.service`**
```ini
[Unit]
Description=Backup Obsidian vault to GitHub
Type=oneshot

[Service]
ExecStart=/home/openclaw/.openclaw/workspace/projects/clawsync/scripts/push-obsidian.js
User=openclaw
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

### Common OnCalendar Patterns

| Schedule | OnCalendar Value |
|----------|------------------|
| Every 5 minutes | `*:0/5` |
| Every 30 minutes | `*:0/30` |
| Daily at 1am | `*-*-* 01:00:00` |
| Daily at 7am | `*-*-* 07:00:00` |
| Weekly Monday 9am | `Mon *-*-* 09:00:00` |
| First day of month at midnight | `*-01-01 00:00:00` |
| Every hour | `hourly` (shorthand) |
| Every day at noon | `daily` (shorthand) |

### Enable and Start

```bash
systemctl --user daemon-reload
systemctl --user enable --now openclaw-vault-backup-daily.timer
```

---

## 3. Anatomy of a Safe Service Unit

```ini
[Unit]
Description=Meaningful description of what this does
# DO NOT use Type=notify or Type=forking for short tasks

[Service]
Type=oneshot                    # Required for most scheduled tasks
User=openclaw                   # Explicit user (belt)
ExecStart=/absolute/path/to/command --args
StandardOutput=journal          # Log to user journal
StandardError=journal           # Log errors to user journal
# Optional:
# Restart=on-failure            # Auto-restart on non-zero exit
# OnFailure=alert@%n.service    # Chain to alerting service

[Install]
WantedBy=default.target
```

**Critical rules:**
- Always use **absolute paths** in `ExecStart`
- Use `Type=oneshot` for tasks that complete
- Never use `RemainAfterExit=yes` unless you specifically need the service to stay active (rare)

---

## 4. Listing, Inspecting and Removing Timers

### List All Timers

```bash
systemctl --user list-timers --all
```

### Check Next Trigger Time

```bash
systemctl --user list-timers
```

### View Logs for a Specific Timer

```bash
# View logs from the last run
journalctl --user -u openclaw-vault-backup-daily.service -n 50

# Follow logs in real-time
journalctl --user -u openclaw-vault-backup-daily.service -f

# View since a specific time
journalctl --user -u openclaw-vault-backup-daily.service --since "1 hour ago"
```

### Check if Last Run Failed

```bash
systemctl --user list-timers --all
# Look for "n/a" in "Left" column or red/alert status
# Or check last unit exit status:
systemctl --user status openclaw-vault-backup-daily.service
```

### Disable and Remove a Timer Cleanly

```bash
# Stop and disable
systemctl --user stop openclaw-vault-backup-daily.timer
systemctl --user disable openclaw-vault-backup-daily.timer

# Remove the unit files
rm ~/.config/systemd/user/openclaw-vault-backup-daily.timer
rm ~/.config/systemd/user/openclaw-vault-backup-daily.service

# Reload systemd to pick up changes
systemctl --user daemon-reload
```

---

## 5. Naming Convention

Use consistent naming so timers are identifiable:

```
openclaw-<purpose>-<frequency>.timer
openclaw-<purpose>-<frequency>.service
```

**Examples:**

| Timer Name | Purpose | Frequency |
|------------|---------|-----------|
| `openclaw-vault-backup-daily.timer` | Backup Obsidian vault | Daily |
| `openclaw-content-crawl-daily.timer` | Fetch content | Daily |
| `openclaw-reminder-weekly.timer` | Send weekly reminder | Weekly |
| `openclaw-rotate-logs-monthly.timer` | Rotate logs | Monthly |

---

## 6. Failure Handling

### Auto-Restart on Failure

Add to service unit:

```ini
[Service]
Restart=on-failure
RestartSec=30
```

### Chain to Alerting Service

```ini
[Unit]
OnFailure=alert-telegram@%n.service
```

Create `alert-telegram@.service` that uses `ExecStart` to notify you of failures.

### Check Failures

```bash
# View failed units
systemctl --user list-units --failed

# Check specific service status
systemctl --user status openclaw-example.service
```

---

## 7. What NOT to Do (Critical Guardrails)

| ❌ Never Do | ✅ Instead |
|------------|-----------|
| Write to `/var/spool/cron` or `crontab -e` | Use systemd timers |
| Use `sudo systemctl` or `--system` | Use `systemctl --user` |
| Use `RemainAfterExit=yes` on long-running tasks | Use `Type=oneshot` and let timer re-trigger |
| Assume timer ran if not in `list-timers` | Always verify with `systemctl --user list-timers` |
| Hardcode paths like `/home/openclaw` | Use `~` or check actual paths |

**Critical:** Using crontab would spawn unconfined jobs outside the AppArmor sandbox — this is a security risk and explicitly blocked.

---

## 8. Quick-Reference Cheat Sheet

```bash
# Reload after creating/editing units
systemctl --user daemon-reload

# Enable and start a timer
systemctl --user enable --now openclaw-name.timer

# Stop a timer
systemctl --user stop openclaw-name.timer

# Disable a timer
systemctl --user disable openclaw-name.timer

# List all timers with next run time
systemctl --user list-timers --all

# View logs for a service
journalctl --user -u openclaw-name.service -n 50

# Check status
systemctl --user status openclaw-name.timer

# Check failed units
systemctl --user list-units --failed

# Remove completely (after stopping/disabling)
rm ~/.config/systemd/user/openclaw-name.timer
rm ~/.config/systemd/user/openclaw-name.service
systemctl --user daemon-reload
```

---

## Summary Workflow

1. **Create** `~/.config/systemd/user/openclaw-<name>.service` (the work)
2. **Create** `~/.config/systemd/user/openclaw-<name>.timer` (the schedule)
3. **Run** `systemctl --user daemon-reload`
4. **Enable** `systemctl --user enable --now openclaw-<name>.timer`
5. **Verify** `systemctl --user list-timers`
6. **Monitor** `journalctl --user -u openclaw-<name>.service`

---

_Remember: Always use absolute paths, stay in `--user` scope, and never touch crontab._
