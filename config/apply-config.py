#!/usr/bin/env python3
"""
@intent Apply core JSON configuration to openclaw.json including API keys, models, agents, and security policies.
@complexity 5
"""
import json
import os
import sys
import argparse
import shutil

def ds(obj, dotted_path, value):
    """Deep-set a dotted key path, creating intermediate dicts as needed."""
    keys = dotted_path.split('.')
    for k in keys[:-1]:
        obj = obj.setdefault(k, {})
    obj[keys[-1]] = value

def main():
    parser = argparse.ArgumentParser(description='Apply OpenClaw configuration.')
    parser.add_argument('--config', required=True, help='Path to openclaw.json')
    args = parser.parse_args()

    cfg = args.config
    if not os.path.exists(cfg):
        print(f"Error: {cfg} not found.")
        sys.exit(1)

    with open(cfg) as f:
        c = json.load(f)

    _home = os.environ.get('ACTUAL_HOME', os.path.expanduser('~'))

    # ── Model Architecture ────────────────────────────────────────────────────────
    _main_primary = 'minimax/MiniMax-M2.7'
    _fallbacks    = ['minimax/MiniMax-M2.5', 'minimax/MiniMax-M2.1']
    ds(c, 'agents.defaults.model.primary',   _main_primary)
    ds(c, 'agents.defaults.model.fallbacks', _fallbacks)

    # ── API keys (skills only — provider keys come from environment.d via systemd) ──────────────
    pb_key = os.environ.get('POST_BRIDGE_API_KEY', '')
    if pb_key and pb_key != 'pb_REPLACE_ME_WHEN_READY':
        skill_key = 'post-bridge-social-manager'
        ds(c, f'skills.entries.{skill_key}.enabled', True)
        ds(c, f'skills.entries.{skill_key}.apiKey', {"source": "env", "provider": "default", "id": "POST_BRIDGE_API_KEY"})

    tavily_key = os.environ.get('TAVILY_API_KEY', '')
    if tavily_key and tavily_key != 'tvly-REPLACE_ME_WHEN_READY':
        ds(c, 'skills.entries.tavily.enabled', True)
        ds(c, 'skills.entries.tavily.apiKey', {"source": "env", "provider": "default", "id": "TAVILY_API_KEY"})

    # ── Skills Discovery ──────────────────────────────────────────────────────────
    # general-agent skills are shared by main and family agents
    _skills_base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # openclaw-scripts root
    _gws_skills = f'{_home}/.openclaw/agents/coding/workspace/projects/cli/skills'
    ds(c, 'skills.load.extraDirs', [
        f'{_skills_base}/skills/general-agent',
        f'{_skills_base}/skills/family-agent',
        _gws_skills,
    ])

    ds(c, 'agents.defaults.memorySearch.enabled',          True)
    ds(c, 'agents.defaults.memorySearch.provider',         'openai')
    ds(c, 'agents.defaults.memorySearch.model',            'nomic-embed-text')
    ds(c, 'agents.defaults.memorySearch.remote.baseUrl',   'http://127.0.0.1:11434/v1')
    ds(c, 'agents.defaults.memorySearch.remote.apiKey',    'ollama-local')  # dummy placeholder; Ollama ignores API keys for local access

    ds(c, 'agents.defaults.compaction.mode', 'safeguard')

    ds(c, 'agents.defaults.subagents.model', {
        'primary':   'minimax/MiniMax-M2.7',
        'fallbacks': ['minimax/MiniMax-M2.5', 'minimax/MiniMax-M2.1'],
    })
    ds(c, 'agents.defaults.subagents.maxConcurrent', 4)
    ds(c, 'agents.defaults.subagents.maxSpawnDepth', 2)
    ds(c, 'agents.defaults.subagents.maxChildrenPerAgent', 5)
    ds(c, 'agents.defaults.subagents.runTimeoutSeconds', 900)

    # ── Supabase Configuration ───────────────────────────────────────────────────
    _supabase_url = os.environ.get('SUPABASE_URL', '').strip()
    _supabase_key = os.environ.get('SUPABASE_ANON_KEY', '').strip()
    if _supabase_url and _supabase_url != 'REPLACE_ME':
        ds(c, 'env.SUPABASE_URL', _supabase_url)
    if _supabase_key and _supabase_key != 'REPLACE_ME':
        ds(c, 'env.SUPABASE_ANON_KEY', _supabase_key)

    # ── TOOL REGISTRY ─────────────────────────────────────────────────────────
    # ADD NEW TOOLS HERE — tool_name (native OpenClaw tool) → agent IDs that can use it
    # NOTE: Skills (gws, tavily, etc.) are NOT tools. They're discovered via skills.load.extraDirs.
    # Only list native OpenClaw tools here (browser, message, etc.).
    TOOL_REGISTRY = {
        # 'my-new-tool': ['main'],
    }

    def _agent_tools(agent_id, base_tools):
        return base_tools + [t for t, agents in TOOL_REGISTRY.items() if agent_id in agents]

    # ── Family agent sandbox (Docker) ─────────────────────────────────────────
    # The family agent is the only agent that runs in a Docker sandbox.
    # Collect sandbox env vars from tool modules (passed as JSON by 08-config.sh)
    import json as _json
    _sandbox_env_raw = os.environ.get('SANDBOX_ENV_JSON', '{}')
    try:
        _sandbox_env = _json.loads(_sandbox_env_raw)
    except _json.JSONDecodeError:
        _sandbox_env = {}
        print(f"WARNING: Could not parse SANDBOX_ENV_JSON", file=sys.stderr)

    # Add Tavily to family sandbox (API skill used by family agent)
    _tavily = os.environ.get('TAVILY_API_KEY', '')
    if _tavily:
        _sandbox_env['TAVILY_API_KEY'] = _tavily

    # Add Supabase to sandbox env if configured
    if _supabase_url and _supabase_url != 'REPLACE_ME':
        _sandbox_env['SUPABASE_URL'] = _supabase_url
    if _supabase_key and _supabase_key != 'REPLACE_ME':
        _sandbox_env['SUPABASE_ANON_KEY'] = _supabase_key

    # Check Docker availability for family sandbox
    _docker_available = shutil.which('docker') is not None
    if not _docker_available:
        print("WARNING: Docker not found. Family agent will run without sandbox.", file=sys.stderr)

    _family_sandbox = {
        'mode': 'all' if _docker_available else 'off',
        'scope': 'session',
        'workspaceAccess': 'rw',
        'docker': {
            'network': 'bridge',
            'dns': ['1.1.1.1', '8.8.8.8'],
            'env': _sandbox_env,
        }
    }

    _named_agents = [
        {
            'id':       'main',
            'default':  True,
            'name':     'Main',
            'workspace': f'{_home}/.openclaw/workspace',
            'agentDir':  f'{_home}/.openclaw/agents/main/agent',
            'model': {
                'primary':   os.environ.get('MINIMAX_DEFAULT', 'minimax/MiniMax-M2.7'),
                'fallbacks': _fallbacks,
            },
            'subagents': {'allowAgents': []},  # uses anonymous subagent spawning
            'tools': {'profile': 'full'},
        },
        {
            'id':        'family',
            'name':      'Family',
            'workspace':  f'{_home}/.openclaw/agents/family/workspace',
            'agentDir':   f'{_home}/.openclaw/agents/family/agent',
            'model':     {'primary': 'minimax/MiniMax-M2.7', 'fallbacks': ['minimax/MiniMax-M2.5', 'minimax/MiniMax-M2.1']},
            'subagents': {'allowAgents': []},
            'tools':     {'profile': 'messaging'},
            'identity':  {'name': 'Family', 'emoji': '🎪'},
            'sandbox':   _family_sandbox,
        },
    ]

    existing_list = c.setdefault('agents', {}).setdefault('list', [])
    existing_ids  = {a.get('id') for a in existing_list}

    # Remove stale coding/marketing agents if present from a previous deploy
    existing_list[:] = [a for a in existing_list if a.get('id') not in ('coding', 'marketing')]

    for agent in _named_agents:
        if agent['id'] not in {a.get('id') for a in existing_list}:
            existing_list.append(agent)
        else:
            for entry in existing_list:
                if entry.get('id') == agent['id']:
                    entry['name']      = agent['name']
                    entry['model']     = agent['model']
                    entry['workspace'] = agent['workspace']
                    entry['agentDir']  = agent['agentDir']
                    entry['tools']     = agent['tools']
                    entry['subagents'] = agent['subagents']
                    entry['identity']  = agent.get('identity', entry.get('identity', {}))
                    entry['sandbox']   = agent.get('sandbox', entry.get('sandbox', {}))

    # No sandbox at the defaults level — only family agent is sandboxed (per-agent config above)
    ds(c, 'agents.defaults.sandbox.mode', 'off')

    # Cross-agent communication — main agent only
    ds(c, 'tools.sessions.visibility', 'agent')
    ds(c, 'tools.agentToAgent.enabled', True)
    ds(c, 'tools.agentToAgent.allow', ['main'])

    ds(c, 'tools.profile', 'full')
    ds(c, 'tools.fs.workspaceOnly', True)

    # Append group:automation to subagent tool deny list if not already present
    _subagent_deny = c.get('tools', {}).get('subagents', {}).get('tools', {}).get('deny', [])
    if "group:automation" not in _subagent_deny:
        _subagent_deny.append("group:automation")
    ds(c, 'tools.subagents.tools.deny', _subagent_deny)

    ds(c, 'gateway.mode',           'local')
    ds(c, 'gateway.bind',           'loopback')
    ds(c, 'gateway.auth.mode',      'token')
    ds(c, 'gateway.auth.token',     os.environ.get('OPENCLAW_GATEWAY_TOKEN', ''))

    # Loopback-only gateway — no reverse proxies to trust
    ds(c, 'gateway.trustedProxies', [])

    ds(c, 'browser.headless', True)

    # ── Exec Tool Configuration ─────────────────────────────────────────────────
    # Run exec on gateway (host) for tools that need host access (gws, claude_code)
    ds(c, 'tools.exec.host', 'gateway')
    ds(c, 'tools.exec.security', 'full')

    # ── Web Tool Configuration ───────────────────────────────────────────────────
    # web_search: disabled — Gemini auto-detected but blocked; use Tavily skill instead
    # web_fetch:  disabled — plain HTTP fetcher unreliable; use LightPanda skill instead
    ds(c, 'tools.web.search.enabled', False)
    ds(c, 'tools.web.fetch.enabled',  False)

    # ── Single Telegram account → main agent ─────────────────────────────────────
    _tg_main = os.environ.get('TELEGRAM_BOT_TOKEN', '')

    def parse_allowed_users(env_var, default_list=None):
        """Parse allowed users from env var, handling REPLACE_ME, INHERIT, and empty values."""
        raw = os.environ.get(env_var, '')

        # If explicitly set to INHERIT, use default list
        if raw.strip() == 'INHERIT' and default_list is not None:
            return default_list

        # Parse comma-separated list, filtering out sentinels
        candidates = [
            uid.strip() for uid in raw.split(',')
            if uid.strip() and uid.strip() not in ('REPLACE_ME', 'INHERIT')
        ]

        # Telegram user IDs are always numeric
        users = [uid for uid in candidates if uid.isdigit()]
        skipped = len(candidates) - len(users)
        if skipped > 0:
            print(f"WARNING: {env_var} contained {skipped} non-numeric entry(ies) that were skipped", file=sys.stderr)

        return users

    _tg_allowed = parse_allowed_users('TELEGRAM_ALLOWED_USERS')

    # Fallback: If no allowlist provided, use TELEGRAM_CHAT_ID (install notification recipient)
    if not _tg_allowed:
        chat_id = os.environ.get('TELEGRAM_CHAT_ID', '').strip()
        if chat_id and chat_id.isdigit():
            _tg_allowed = [chat_id]
            print(f"INFO: Auto-populated allowlist with TELEGRAM_CHAT_ID={chat_id}", file=sys.stderr)

    tg_accounts = c.setdefault('channels', {}).setdefault('telegram', {}).setdefault('accounts', {})

    # Remove stale coding/marketing bot accounts from a previous deploy
    for stale in ('coding', 'marketing'):
        tg_accounts.pop(stale, None)

    _dm_policy = 'allowlist' if _tg_allowed else 'pairing'
    _tg_default_acc = tg_accounts.get('default', {})
    _tg_default_acc.update({
        'botToken':    _tg_main,
        'dmPolicy':    _dm_policy,
        'groupPolicy': 'disabled',
        'allowFrom':   _tg_allowed,
    })
    tg_accounts['default'] = _tg_default_acc

    # ── WhatsApp multi-account (QR-linked, no token needed) ──────────────────────
    _wa_allowed_raw = os.environ.get('WHATSAPP_ALLOWED_USERS', '')
    _wa_allowed_users = [
        num.strip() for num in _wa_allowed_raw.split(',')
        if num.strip() and num.strip() != 'REPLACE_ME'
    ]

    _wa_group_ids_raw = os.environ.get('WHATSAPP_GROUP_ID', '').strip()
    _wa_group_ids = [
        g.strip() for g in _wa_group_ids_raw.split(',')
        if g.strip() and g.strip() != 'REPLACE_ME'
    ]
    _wa_group_allow_from_raw = os.environ.get('WHATSAPP_GROUP_ALLOW_FROM', '')
    _wa_group_allow_from = [
        num.strip() for num in _wa_group_allow_from_raw.split(',')
        if num.strip() and num.strip() != 'REPLACE_ME'
    ]

    _wa_dm_policy = 'allowlist' if _wa_allowed_users else 'pairing'
    _wa_allow_from = _wa_allowed_users if _wa_allowed_users else []

    _wa_accounts = c.setdefault('channels', {}).setdefault('whatsapp', {}).setdefault('accounts', {})
    _wa_family = _wa_accounts.get('family', {})

    if _wa_group_ids:
        _wa_group_policy = 'allowlist'
        _wa_groups = {gid: {'requireMention': False} for gid in _wa_group_ids}
    else:
        _wa_group_policy = 'disabled'
        _wa_groups = {}

    _wa_family.update({
        'dmPolicy': _wa_dm_policy,
        'groupPolicy': _wa_group_policy,
        'allowFrom': _wa_allow_from,
        'groupAllowFrom': _wa_group_allow_from,
        'groups': _wa_groups
    })
    _wa_accounts['family'] = _wa_family
    ds(c, 'channels.whatsapp.defaultAccount', 'family')
    # Disable top-level groupPolicy so the gateway Doctor doesn't create an
    # accounts.default entry with groupPolicy="allowlist" + empty groupAllowFrom,
    # which silently drops all group messages. Per-account policy lives in accounts.family.
    ds(c, 'channels.whatsapp.groupPolicy', 'disabled')

    # ── Bindings: single Telegram bot → main agent ────────────────────────────────
    bindings = c.setdefault('bindings', [])
    # Remove all stale Telegram bindings before re-applying
    bindings[:] = [b for b in bindings if b.get('match', {}).get('channel') != 'telegram']
    bindings.append({'agentId': 'main', 'match': {'channel': 'telegram', 'accountId': 'default'}})

    # WhatsApp binding — remove stale entries then re-apply
    bindings[:] = [b for b in bindings if b.get('match', {}).get('channel') != 'whatsapp']
    bindings.append({'agentId': 'family', 'match': {'channel': 'whatsapp', 'accountId': 'family'}})

    # Elevated allowFrom — use explicit user IDs (never wildcard)
    _elevated_allow = {}
    if _tg_allowed:
        _elevated_allow['telegram'] = _tg_allowed
    if _wa_allow_from:
        _elevated_allow['whatsapp'] = _wa_allow_from

    if _elevated_allow:
        ds(c, 'tools.elevated.enabled', True)
        ds(c, 'tools.elevated.allowFrom', _elevated_allow)
    else:
        ds(c, 'tools.elevated.enabled', False)
        if 'tools' in c and 'elevated' in c['tools']:
            c['tools']['elevated'].pop('allowFrom', None)
        print("WARNING: [SEC-002] Elevated mode disabled — no channel allowlists configured.", file=sys.stderr)

    with open(cfg, 'w') as f:
        json.dump(c, f, indent=2)

    print('ok')

if __name__ == '__main__':
    main()
