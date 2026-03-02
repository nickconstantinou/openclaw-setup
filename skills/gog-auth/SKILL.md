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
gog auth add chas.constantinou@gmail.com --services all --port 38625
```

Leave the process running. It will print a URL and wait.

### Step 2 — tell the user to open a tunnel

Tell the user:
> Open a new terminal on your local machine and run:
> ```
> ssh -N -L 38625:127.0.0.1:38625 openclaw@talons.tail7e0e6e.ts.net
> ```
> Keep that terminal open, then click the Google auth link I showed you.

### Step 3 — wait for callback

Once the user clicks the link and approves in Google, the callback hits their
local port 38625, the tunnel forwards it to the server, and gog captures it.
The exec command will print "Authentication successful" and exit.

### Step 4 — verify

```bash
gog accounts list
gog calendar list --account chas.constantinou@gmail.com --limit 3
```

## If --port flag isn't supported

Some gogcli versions don't support `--port`. In that case:
1. Run `gog auth add chas.constantinou@gmail.com --services all`
2. Read the redirect_uri from the URL it prints (the port after `127.0.0.1:`)
3. Tell the user to tunnel THAT port, then click the link

## Re-authenticating / refreshing tokens

```bash
gog auth refresh chas.constantinou@gmail.com
```

## Checking what's authenticated

```bash
gog accounts list
gog accounts status chas.constantinou@gmail.com
```

## Common errors

| Error | Cause | Fix |
|-------|-------|-----|
| `no credentials for account` | Not authenticated | Run auth flow above |
| `token expired` | OAuth token stale | Run `gog auth refresh` |
| `authorization canceled: context deadline exceeded` | Tunnel not open when user clicked link | Re-run auth, open tunnel FIRST, then click |
| `redirect_uri_mismatch` | Port not in GCP OAuth allowed list | Add `http://127.0.0.1:38625/oauth2/callback` to GCP Console → Credentials → OAuth client → Authorized redirect URIs |
