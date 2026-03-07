# google-workspace Skill

_Reference for using gws (@googleworkspace/cli) for all Google Workspace operations._

---

## Setup Check

```bash
gws gmail messages list --limit 1
```

If this fails with an auth error, direct user to the `gws-auth` skill for initial
OAuth setup (`gws auth setup && gws auth login`).

---

## Gmail

### Search / List Emails

```bash
gws gmail messages list --query 'is:unread newer_than:1d' --limit 10
```

### Get Message

```bash
gws gmail messages get --id <messageId>
```

### Send Email

```bash
gws gmail messages send --to user@example.com --subject "Hi" --body "Hello"
```

### Create Draft

```bash
gws gmail drafts create --to user@example.com --subject "Draft" --body "$(cat ./draft.txt)"
```

---

## Calendar

### List Events

```bash
gws calendar events list --calendar primary \
  --time-min $(date -u +%Y-%m-%dT00:00:00Z) \
  --time-max $(date -u +%Y-%m-%dT23:59:59Z)
```

### Create Event

```bash
gws calendar events create --calendar primary \
  --summary "Meeting" \
  --start 2026-03-01T10:00:00Z \
  --end 2026-03-01T11:00:00Z
```

### List Calendars

```bash
gws calendar calendars list
```

---

## Drive

### List Files

```bash
gws drive files list --limit 10
```

### Search Files

```bash
gws drive files list --query "name contains 'quarterly report'" --limit 5
```

### Upload File

```bash
gws drive files upload --file ./report.pdf --parent <folderId>
```

### Download File

```bash
gws drive files download --id <fileId> --output ./local-copy.pdf
```

---

## Sheets

### Get Range

```bash
gws sheets values get --spreadsheet-id <spreadsheetId> --range "Sheet1!A1:D10"
```

### Update Range

```bash
gws sheets values update --spreadsheet-id <spreadsheetId> \
  --range "Sheet1!A1:B2" \
  --values '[["Name","Score"],["Alice",95]]'
```

### Append Rows

```bash
gws sheets values append --spreadsheet-id <spreadsheetId> \
  --range "Sheet1!A:C" \
  --values '[["new","row","data"]]'
```

---

## Docs

### Get Document Content

```bash
gws docs documents get --id <docId>
```

---

## MCP Server

`gws` ships a built-in MCP server for AI agent integration:

```bash
gws mcp
```

This exposes all Workspace operations as MCP tools, enabling structured tool-call
access without shell exec round-trips.

---

## Rules

| Never Do | Instead |
|----------|---------|
| Use Google Python API client directly | Use gws — handles auth and retries |
| Skip auth check before operations | Verify with `gws gmail messages list --limit 1` |
| Use wrong timestamp format | Use RFC3339: `2026-03-01T10:00:00Z` |

---

## Quick-Reference

```bash
# Check auth
gws gmail messages list --limit 1

# Email
gws gmail messages list --query 'is:unread' --limit 10
gws gmail messages send --to x@y.com --subject "Subject" --body "Body"

# Calendar
gws calendar events list --calendar primary \
  --time-min 2026-03-01T00:00:00Z --time-max 2026-03-01T23:59:59Z
gws calendar events create --calendar primary \
  --summary "Event" --start 2026-03-01T10:00:00Z --end 2026-03-01T11:00:00Z

# Drive
gws drive files list
gws drive files list --query "name contains 'query'" --limit 5

# Sheets
gws sheets values get --spreadsheet-id <id> --range "Sheet1!A1:D10"
gws sheets values update --spreadsheet-id <id> --range "A1:B2" --values '[["a","b"]]'

# Docs
gws docs documents get --id <docId>
```

---

## AI Assistant Workflows

### Daily Inbox Triage & Drafts Workflow
1. Get recent unread messages: `gws gmail messages list --query 'is:unread' --limit 20`
2. For important threads, retrieve full message: `gws gmail messages get --id <messageId>`
3. Draft a natural reply locally to `/tmp/drafts/reply.txt`
4. Create the draft in Gmail for user review: `gws gmail drafts create --to <address> --subject "Re: ..." --body "$(cat /tmp/drafts/reply.txt)"`
5. Summarize actions taken to the user.

### Calendar Scheduling Workflow
1. Look up existing events: `gws calendar events list --calendar primary --time-min $(date -u +%Y-%m-%dT00:00:00Z) --time-max $(date -u -d '+7 days' +%Y-%m-%dT23:59:59Z)`
2. Identify a free slot matching the user's request.
3. Create the event: `gws calendar events create --calendar primary --summary "Project Sync" --start 2026-03-02T14:00:00Z --end 2026-03-02T15:00:00Z`
4. Confirm scheduling with the user.

---

_Note: gws is v0.4.x (pre-1.0) — flag names may evolve. Check `gws <command> --help` if a command fails._
