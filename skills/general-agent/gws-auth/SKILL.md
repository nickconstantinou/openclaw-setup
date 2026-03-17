---
name: gws-auth
description: >
  How to authenticate Google Workspace (gws CLI) when running on a remote server.
  Use this skill whenever the user asks to connect Google, authenticate gws,
  or when gws commands fail with "no credentials" or "not authenticated".
---

# SKILL: gws Google Workspace Authentication

## Critical: Do NOT use the browser tool for this

`gws auth login` opens its own local OAuth callback server. Do not attempt to use the
Chrome extension relay or browser automation tool — it will not work. The user
must complete the browser step manually on their own machine.

## Prerequisites

`gws` needs OAuth 2.0 credentials from a Google Cloud project. These are stored as
`GOOGLE_WORKSPACE_CLI_CLIENT_ID` and `GOOGLE_WORKSPACE_CLI_CLIENT_SECRET` in
`~/.openclaw/.env`.

If these variables are missing or still set to `REPLACE_ME`, ask the user to:
1. Go to https://console.cloud.google.com/ → APIs & Services → Credentials
2. Create an OAuth 2.0 client ID (type: Desktop app)
3. Add the values to `~/.openclaw/.env` and re-run the deploy script

## The problem

The server has no GUI. When `gws auth login` opens a browser for OAuth, it starts
a local HTTP server waiting for the Google redirect.
The user's browser is on a different machine, so `127.0.0.1:<port>` on their
machine goes nowhere — the callback never arrives.

## The solution: SSH port tunnel

You run the command. The user tunnels the port. Google redirects through the tunnel.

### Step 1 — one-time setup (configure OAuth client)

```bash
gws auth setup
```

This is interactive — it reads `GOOGLE_WORKSPACE_CLI_CLIENT_ID` and
`GOOGLE_WORKSPACE_CLI_CLIENT_SECRET` from the environment and writes them to
`~/.config/gws/`. Only needed once per machine.

> **Note:** If the install script ran successfully with credentials present,
> `gws auth setup` was already completed at install time and this step can be
> skipped.

### Step 2 — login (browser OAuth flow)

```bash
gws auth login
```

This starts a local callback server and prints a URL. Note the port number
(e.g. `http://localhost:3000`).

### Step 3 — SSH tunnel (user runs on their local machine)

```
ssh -L 3000:localhost:3000 user@server
```

Then the user opens the printed URL in their browser. Google redirects through
the tunnel, completing the OAuth flow. Credentials are saved to `~/.config/gws/`.

## Handling Auth Errors

If you encounter `Token expired` or `invalid_grant`:
1. Run `gws auth login`
2. Complete the OAuth flow again
3. Retry the operation

## Verification

```bash
gws gmail messages list --limit 1
```

A successful response confirms auth is working.

## Common errors

| Error | Cause | Fix |
|-------|-------|-----|
| `no credentials found` | Auth not completed | Run `gws auth setup` then `gws auth login` |
| `token expired` | OAuth token stale | Run `gws auth login` again |
| `redirect_uri_mismatch` | Port not in GCP OAuth allowed list | Add `http://localhost:<port>` to GCP Console → Credentials → OAuth client → Authorized redirect URIs |
| `invalid_client` | Wrong CLIENT_ID/SECRET | Check env vars match the GCP credentials |
