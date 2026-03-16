# Issue: Coding Agent Cannot Access External APIs (Supabase)

## 📋 Description
The coding agent, running inside a Docker sandbox (`sandbox.mode = non-main`), could not connect to Supabase or other external APIs despite DNS and network mode being correctly configured.

**Symptoms**:
- Supabase client calls from within the sandbox container failed (connection errors / undefined env vars).
- `SUPABASE_URL` was present in the top-level `env` section of `openclaw.json` but not in `docker.env`.
- `SUPABASE_ANON_KEY` was absent entirely from the live config.
- The GWS bind mount was missing, indicating the config had not been re-applied after recent commits.

## 🏁 Resolution

### 🔄 Before/After
- **Before**: `apply-config.py` wrote `SUPABASE_URL` and `SUPABASE_ANON_KEY` to `c['env']` (top-level), which is only visible to the non-sandboxed main agent. Sandboxed agents only receive vars from `agents.defaults.sandbox.docker.env`.
- **After**: Supabase vars are now also injected into `_sandbox_env` inside the `if _sandbox_mode != 'off':` block, using the same pattern as `TAVILY_API_KEY`. Both vars are present in `docker.env` and confirmed in the live `openclaw.json`.

### 🧪 Verification Evidence
```
SUPABASE_URL: https://araqigsimkjsmwhnjesv.supabase.co   ✓
SUPABASE_ANON_KEY: SET ✓
binds: ['/home/openclaw/.openclaw/agents/coding/workspace/projects:/projects:rw',
        '/home/openclaw/.config/gws:/home/sandbox/.config/gws:ro']
```
Verified by reading `openclaw.json` directly after re-applying config.

### 🛠️ Technical Details

**Root Cause**: `apply-config.py` lines 80–83 used `ds(c, 'env.SUPABASE_URL', ...)` which sets the top-level `env` object. In OpenClaw's config schema, `env` is for the host/main agent context. The sandbox receives a separate env block at `agents.defaults.sandbox.docker.env`, built from `_sandbox_env` and written at line 239. Supabase was never added to `_sandbox_env`.

**Fix** (`config/apply-config.py`):
```python
# Add Supabase to sandbox env
if _supabase_url and _supabase_url != 'REPLACE_ME':
    _sandbox_env['SUPABASE_URL'] = _supabase_url
if _supabase_key and _supabase_key != 'REPLACE_ME':
    _sandbox_env['SUPABASE_ANON_KEY'] = _supabase_key
```
Added after the Tavily injection block (line ~231), before `ds(c, 'agents.defaults.sandbox.docker.env', _sandbox_env)`.

The existing top-level `env` writes were kept for the main agent.
Config was re-applied by running `apply-config.py` directly with env vars sourced from `~/.openclaw/.env`.
