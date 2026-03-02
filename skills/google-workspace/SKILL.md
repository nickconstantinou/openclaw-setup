# google-workspace Skill

_Reference for using gog (gogcli) for all Google Workspace operations._

---

## Setup Check

```bash
gog auth list
```

If empty, direct user to `~/.openclaw/workspace/google-auth-setup.md` for initial OAuth setup.

---

## Gmail

### Search Emails

```bash
gog gmail search 'is:unread newer_than:1d' --max 10 --json
```

### Get Thread

```bash
gog gmail thread get <threadId>
```

### Send Email

```bash
# Simple send
gog gmail send --to user@example.com --subject "Hi" --body "Hello"
```

```bash
# Multiline body from stdin
gog gmail send --to user@example.com --subject "Hi" --body-file - << 'EOF'
Multiline body here
More content
EOF
```

### Create Draft

```bash
gog gmail drafts create --to user@example.com --subject "Draft" --body-file ./draft.txt
```

---

## Calendar

### List Events

```bash
gog calendar events primary --from $(date -u +%Y-%m-%dT00:00:00Z) --to $(date -u +%Y-%m-%dT23:59:59Z) --json
```

### Create Event

```bash
gog calendar create primary --summary "Meeting" --from 2026-03-01T10:00:00Z --to 2026-03-01T11:00:00Z
```

### List Calendars

```bash
gog calendar calendars --json
```

---

## Drive

### List Files

```bash
gog drive ls --max 10 --json
```

### Search Files

```bash
gog drive search "quarterly report" --max 5 --json
```

### Upload File

```bash
gog drive upload ./report.pdf --parent <folderId>
```

### Download File

```bash
gog drive download <fileId> --out ./local-copy.pdf
```

---

## Sheets

### Get Range

```bash
gog sheets get <spreadsheetId> "Sheet1!A1:D10" --json
```

### Update Range

```bash
gog sheets update <spreadsheetId> "Sheet1!A1:B2" --values-json '[["Name","Score"],["Alice",95]]' --input USER_ENTERED
```

### Append Rows

```bash
gog sheets append <spreadsheetId> "Sheet1!A:C" --values-json '[["new","row","data"]]' --insert INSERT_ROWS
```

---

## Docs

### View Document

```bash
gog docs cat <docId>
```

### Export Document

```bash
gog docs export <docId> --format txt --out /tmp/doc.txt
```

---

## Rules

| ❌ Never Do | ✅ Instead |
|------------|-----------|
| Use Google Python API client directly | Use gog — handles auth and retries |
| Forget --json for scripted output | Always use --json and pipe to jq |
| Forget --no-input in automated contexts | Include --no-input flag |
| Use wrong timestamp format | Use RFC3339: `2026-03-01T10:00:00Z` |

---

## Quick-Reference

```bash
# Check auth
gog auth list

# Email
gog gmail search 'is:unread' --max 10 --json
gog gmail send --to x@y.com --subject "Subject" --body "Body"

# Calendar
gog calendar events primary --from 2026-03-01T00:00:00Z --to 2026-03-01T23:59:59Z --json
gog calendar create primary --summary "Event" --from 2026-03-01T10:00:00Z --to 2026-03-01T11:00:00Z

# Drive
gog drive ls --json
gog drive search "query" --max 5 --json

# Sheets
gog sheets get <id> "Sheet1!A1:D10" --json
gog sheets update <id> "A1:B2" --values-json '[["a","b"]]'

# Docs
gog docs cat <docId>
```

---

_Remember: Always use --json for scripted output, pipe to jq, and use RFC3339 timestamps for calendar._
