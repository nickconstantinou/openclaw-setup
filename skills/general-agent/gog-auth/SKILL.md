---
name: gog-auth
description: >
  How to authenticate Google Workspace (gog CLI) when running on a remote server.
  Use this skill whenever the user asks to connect Google, authenticate gog,
  or when gog commands fail with "no credentials" or "not authenticated".
---

# SKILL: gog Google Workspace Authentication

## Critical: Do NOT use the browser tool for this

`gog auth` opens its own local OAuth callback server. Do not attempt to use the
Chrome extension relay or browser automation tool — it will not work. The user
must complete the browser step manually on their own machine.

## The problem

The server has no GUI. When `gog auth add` opens a browser for OAuth, it starts
a local HTTP server (e.g. on port 38625) waiting for the Google redirect.
The user's browser is on a different machine, so `127.0.0.1:38625` on their
machine goes nowhere — the callback never arrives.

## The solution: SSH port tunnel

You run the command. The user tunnels the port. Google redirects through the tunnel.

### Step 1 — pick a fixed port and run auth

Use the exec tool to run:
```bash
gog auth add user@example.com --services all --port 38625
```

Leave the process running. It will print a URL and wait.
### 1. Add account

```bash
gog auth add user@example.com --services all --port 38625
```
This triggers an OAuth web flow. Ensure the proxy intercepts the callback if running remotely.

### 2. Add multiple services at once

```bash
gog auth add user@example.com --services drive,gmail,calendar
```

### 3. Set standard defaults

By default, without the `-a` flag, gog commands fail if there are multiple accounts. You can configure defaults via environment aliases or shell wrappers, but `gog` core requires you to either have 1 account or specify `-a`.

If working extensively, create aliases for the session:
```bash
alias gcalendar="gog calendar list --account user@example.com"
gog calendar list --account user@example.com --limit 3
```

## Handling Auth Errors

If you encounter `Token expired` or `invalid_grant`:
1. Run `gog auth add user@example.com --services all`
2. Complete the OAuth flow again
3. Retry the operation

If `gog` hangs on commands:
- Check token status:
```bash
gog auth refresh user@example.com
```

## Verification

To verify current state:
```bash
gog auth list
gog accounts status user@example.com
```

## Common errors

| Error | Cause | Fix |
|-------|-------|-----|
| `no credentials for account` | Not authenticated | Run auth flow above |
| `token expired` | OAuth token stale | Run `gog auth refresh` |
| `authorization canceled: context deadline exceeded` | Tunnel not open when user clicked link | Re-run auth, open tunnel FIRST, then click |
| `redirect_uri_mismatch` | Port not in GCP OAuth allowed list | Add `http://127.0.0.1:38625/oauth2/callback` to GCP Console → Credentials → OAuth client → Authorized redirect URIs |
