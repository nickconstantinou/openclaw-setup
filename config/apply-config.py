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

    # ── Model Architecture ────────────────────────────────────────────────────────
    _main_primary = 'minimax/MiniMax-M2.5'
    _fallbacks    = ['minimax/MiniMax-M2.1']
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
    # Add general-agent, coding-agent, and marketing-agent skills directories
    # These are shared across all agents (precedence: workspace > ~/.openclaw/skills > extraDirs > bundled)
    _skills_base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # openclaw-scripts root
    _gws_skills = f'{_home}/.openclaw/agents/coding/workspace/projects/cli/skills'
    ds(c, 'skills.load.extraDirs', [
        f'{_skills_base}/skills/general-agent',
        f'{_skills_base}/skills/coding-agent',
        f'{_skills_base}/skills/marketing-agent',
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
        'primary':   'minimax/MiniMax-M2.5',
        'fallbacks': ['minimax/MiniMax-M2.1'],
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

    _coding_primary     = 'minimax/MiniMax-M2.5'
    _coding_fallback    = ['minimax/MiniMax-M2.1']
    _marketing_primary  = 'minimax/MiniMax-M2.5'
    _marketing_fallback = ['minimax/MiniMax-M2.1']

    # ── TOOL REGISTRY ─────────────────────────────────────────────────────────
    # ADD NEW TOOLS HERE — tool_name (native OpenClaw tool) → agent IDs that can use it
    # NOTE: Skills (gws, tavily, etc.) are NOT tools. They're discovered via skills.load.extraDirs.
    # Only list native OpenClaw tools here (browser, message, etc.).
    TOOL_REGISTRY = {
        'browser':          ['coding', 'marketing'],
        'message':          ['coding', 'marketing'],
        # 'my-new-tool':   ['coding'],
    }

    def _agent_tools(agent_id, base_tools):
        return base_tools + [t for t, agents in TOOL_REGISTRY.items() if agent_id in agents]

    _home = os.environ.get('ACTUAL_HOME', os.path.expanduser('~'))

    _named_agents = [
        {
            'id':       'main',
            'default':  True,
            'name':     'Main',
            'workspace': f'{_home}/.openclaw/workspace',
            'agentDir':  f'{_home}/.openclaw/agents/main/agent',
            'model': {
                'primary':   os.environ.get('MINIMAX_DEFAULT', 'minimax/MiniMax-M2.5'),
                'fallbacks': _fallbacks,
            },
            'subagents': {'allowAgents': ['coding', 'marketing']},
            'tools': {'profile': 'full'},
        },
        {
            'id':       'coding',
            'name':     'Coder',
            'workspace': f'{_home}/.openclaw/agents/coding/workspace',
            'agentDir':  f'{_home}/.openclaw/agents/coding/agent',
            'model': {'primary': _coding_primary, 'fallbacks': _coding_fallback},
            'tools': {
                'allow': _agent_tools('coding', [
                    'read', 'write', 'edit', 'apply_patch', 'exec', 'process', 'bash',
                    'sessions_list', 'sessions_history', 'sessions_send', 'session_status'
                ])
            },
            'subagents': {'allowAgents': []},
            'identity': {'name': 'Coder', 'emoji': '💻'},
        },
        {
            'id':       'marketing',
            'name':     'Marketing',
            'workspace': f'{_home}/.openclaw/agents/marketing/workspace',
            'agentDir':  f'{_home}/.openclaw/agents/marketing/agent',
            'model': {'primary': _marketing_primary, 'fallbacks': _marketing_fallback},
            'tools': {
                'allow': _agent_tools('marketing', [
                    'read', 'write', 'exec', 'process', 'bash',
                    'sessions_list', 'sessions_history', 'sessions_send', 'sessions_spawn', 'session_status'
                ])
            },
            'subagents': {'allowAgents': ['coding']},
            'identity': {'name': 'Marketing', 'emoji': '📣'},
        },
        {
            'id':        'family',
            'name':      'Family',
            'workspace':  f'{_home}/.openclaw/agents/family/workspace',
            'agentDir':   f'{_home}/.openclaw/agents/family/agent',
            'model':     {'primary': 'minimax/MiniMax-M2.5', 'fallbacks': ['minimax/MiniMax-M2.1']},
            'subagents': {'allowAgents': []},
            'tools':     {'profile': 'messaging'},
            'identity':  {'name': 'Family', 'emoji': '🎪'},
        },
    ]

    existing_list = c.setdefault('agents', {}).setdefault('list', [])
    existing_ids  = {a.get('id') for a in existing_list}
    for agent in _named_agents:
        if agent['id'] not in existing_ids:
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

    # Enable cross-agent communication (hybrid collaboration model)
    ds(c, 'tools.sessions.visibility', 'agent')  # Each agent can see own sessions
    ds(c, 'tools.agentToAgent.enabled', True)
    ds(c, 'tools.agentToAgent.allow', ['main', 'coding', 'marketing'])

    ds(c, 'tools.profile', 'full')
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

    # ── Security: Sandbox defaults ────────────────────────────────────────────
    # OPENCLAW_SANDBOX_MODE: "off", "non-main" (default), or "all" (docker required)
    _sandbox_env = os.environ.get('OPENCLAW_SANDBOX_MODE', 'non-main')
    _sandbox_mode = _sandbox_env

    # Docker availability check: if mode != 'off' but docker is missing, fall back to 'off'
    if _sandbox_mode != 'off' and shutil.which('docker') is None:
        print(f"INFO: Docker not found. Falling back to sandbox.mode=off (requested: {_sandbox_mode})", file=sys.stderr)
        _sandbox_mode = 'off'

    ds(c, 'agents.defaults.sandbox.mode', _sandbox_mode)
    ds(c, 'tools.fs.workspaceOnly', True)

    if _sandbox_mode != 'off':
        ds(c, 'agents.defaults.sandbox.scope', 'session')
        ds(c, 'agents.defaults.sandbox.workspaceAccess', 'rw')
        ds(c, 'agents.defaults.sandbox.docker.network', 'bridge')
        # Add DNS for external API access (Supabase, etc.)
        ds(c, 'agents.defaults.sandbox.docker.dns', ['1.1.1.1', '8.8.8.8'])

        # Collect sandbox env from tool modules (passed as JSON by 08-config.sh)
        import json as _json
        _sandbox_env_raw = os.environ.get('SANDBOX_ENV_JSON', '{}')
        try:
            _sandbox_env = _json.loads(_sandbox_env_raw)
        except _json.JSONDecodeError:
            _sandbox_env = {}
            print(f"WARNING: Could not parse SANDBOX_ENV_JSON", file=sys.stderr)

        # Add Tavily (native skill, not a tool module)
        _tavily = os.environ.get('TAVILY_API_KEY', '')
        if _tavily:
            _sandbox_env['TAVILY_API_KEY'] = _tavily

        # Add Supabase to sandbox env
        if _supabase_url and _supabase_url != 'REPLACE_ME':
            _sandbox_env['SUPABASE_URL'] = _supabase_url
        if _supabase_key and _supabase_key != 'REPLACE_ME':
            _sandbox_env['SUPABASE_ANON_KEY'] = _supabase_key

        ds(c, 'agents.defaults.sandbox.docker.env', _sandbox_env)

        # Bind mount projects directory + gws credentials
        # gws needs rw access to write its token/discovery cache inside ~/.config/gws/
        _projects_dir = f'{_home}/.openclaw/agents/coding/workspace/projects'
        ds(c, 'agents.defaults.sandbox.docker.binds', [
            f'{_projects_dir}:/projects:rw',
            f'{_home}/.config/gws:/home/sandbox/.config/gws:rw',
        ])
        ds(c, 'agents.defaults.sandbox.docker.dangerouslyAllowExternalBindSources', True)

        # NOTE: agents.defaults.sandbox.resources (cpus, memory) and seccompProfile

    # Elevated mode configuration (allowFrom set after channel parsing below)

    # ── Exec Tool Configuration ─────────────────────────────────────────────────
    # Run exec on gateway (host) for tools that need host access (gws, claude_code)
    # NOTE: 'allowlist' blocks ALL exec commands not in exec-approvals.json, which
    # prevents agents from running basic commands (git, echo, etc.). Use 'full'
    # to allow normal exec; elevated commands are still gated by tools.elevated.
    ds(c, 'tools.exec.host', 'gateway')
    ds(c, 'tools.exec.security', 'full')

    # ── Multi-account Telegram (one bot per agent) ────────────────────────────────
    _tg_main      = os.environ.get('TELEGRAM_BOT_TOKEN', '')
    _tg_coding    = os.environ.get('TELEGRAM_BOT_TOKEN_CODING', '')
    _tg_marketing = os.environ.get('TELEGRAM_BOT_TOKEN_MARKETING', '')

    _sentinel_coding    = 'tg-REPLACE_ME_CODING'
    _sentinel_marketing = 'tg-REPLACE_ME_MARKETING'

    # Security: Get allowed user list from environment with per-bot granularity
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

        # Telegram user IDs and WhatsApp numbers are always numeric
        users = [uid for uid in candidates if uid.isdigit()]
        skipped = len(candidates) - len(users)
        if skipped > 0:
            print(f"WARNING: {env_var} contained {skipped} non-numeric entry(ies) that were skipped", file=sys.stderr)

        return users

    # Base allowlist for all Telegram bots (unless overridden)
    _tg_allowed_base = parse_allowed_users('TELEGRAM_ALLOWED_USERS')

    # Fallback: If no allowlist provided, use TELEGRAM_CHAT_ID (install notification recipient)
    # This allows solo users to access their own bot without manual allowlist configuration
    if not _tg_allowed_base:
        chat_id = os.environ.get('TELEGRAM_CHAT_ID', '').strip()
        if chat_id and chat_id.isdigit():
            _tg_allowed_base = [chat_id]
            print(f"INFO: Auto-populated allowlist with TELEGRAM_CHAT_ID={chat_id}", file=sys.stderr)

    # Per-bot allowlists (inherit from base if set to INHERIT)
    _tg_allowed_default = _tg_allowed_base  # Default bot always uses base list
    _tg_allowed_coding = parse_allowed_users('TELEGRAM_ALLOWED_USERS_CODING', _tg_allowed_base)
    _tg_allowed_marketing = parse_allowed_users('TELEGRAM_ALLOWED_USERS_MARKETING', _tg_allowed_base)

    tg_accounts = c.setdefault('channels', {}).setdefault('telegram', {}).setdefault('accounts', {})

    # Default bot configuration
    _dm_policy_default = 'allowlist' if _tg_allowed_default else 'pairing'
    _tg_default_acc = tg_accounts.get('default', {})
    _tg_default_acc.update({
        'botToken':    _tg_main,
        'dmPolicy':    _dm_policy_default,
        'groupPolicy': 'disabled',  # Groups disabled by default (use allowlist if needed)
        'allowFrom':   _tg_allowed_default,
    })
    # NOTE: dmScope='per-channel-peer' is defined in the security blueprint but NOT
    # yet recognized by OpenClaw's config schema (tested against 2026.3.7). Writing it
    # causes a crash loop. Re-enable when upstream adds schema support.
    tg_accounts['default'] = _tg_default_acc

    # Coding bot configuration (has bash/exec — should be most restricted!)
    if _tg_coding and _tg_coding != _sentinel_coding:
        _dm_policy_coding = 'allowlist' if _tg_allowed_coding else 'pairing'
        _tg_coding_acc = tg_accounts.get('coding', {})
        _tg_coding_acc.update({
            'botToken':    _tg_coding,
            'dmPolicy':    _dm_policy_coding,
            'groupPolicy': 'disabled',
            'allowFrom':   _tg_allowed_coding,
        })
        tg_accounts['coding'] = _tg_coding_acc

    # Marketing bot configuration
    if _tg_marketing and _tg_marketing != _sentinel_marketing:
        _dm_policy_marketing = 'allowlist' if _tg_allowed_marketing else 'pairing'
        _tg_marketing_acc = tg_accounts.get('marketing', {})
        _tg_marketing_acc.update({
            'botToken':    _tg_marketing,
            'dmPolicy':    _dm_policy_marketing,
            'groupPolicy': 'disabled',
            'allowFrom':   _tg_allowed_marketing,
        })
        tg_accounts['marketing'] = _tg_marketing_acc

    # ── WhatsApp multi-account (QR-linked, no token needed) ──────────────────────
    # Security: Get allowed WhatsApp numbers from environment (international format, no +)
    _wa_allowed_raw = os.environ.get('WHATSAPP_ALLOWED_USERS', '')
    # Filter out placeholder/sentinel values and empty strings
    _wa_allowed_users = [
        num.strip() for num in _wa_allowed_raw.split(',')
        if num.strip() and num.strip() != 'REPLACE_ME'
    ]

    # WhatsApp group configuration
    _wa_group_id = os.environ.get('WHATSAPP_GROUP_ID', '').strip()
    _wa_group_allow_from_raw = os.environ.get('WHATSAPP_GROUP_ALLOW_FROM', '')
    _wa_group_allow_from = [
        num.strip() for num in _wa_group_allow_from_raw.split(',')
        if num.strip() and num.strip() != 'REPLACE_ME'
    ]

    _wa_dm_policy = 'allowlist' if _wa_allowed_users else 'pairing'
    _wa_allow_from = _wa_allowed_users if _wa_allowed_users else []

    _wa_accounts = c.setdefault('channels', {}).setdefault('whatsapp', {}).setdefault('accounts', {})
    _wa_family = _wa_accounts.get('family', {})
    
    # Configure group policy - enable if WHATSAPP_GROUP_ID is set
    if _wa_group_id:
        _wa_group_policy = 'allowlist'
        _wa_groups = {_wa_group_id: {'requireMention': False}}
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

    # ── Bindings: route each Telegram account to the matching agent ───────────────
    bindings = c.setdefault('bindings', [])
    # Remove stale Telegram bindings before re-applying
    bindings[:] = [b for b in bindings if b.get('match', {}).get('channel') != 'telegram']
    bindings.append({'agentId': 'main', 'match': {'channel': 'telegram', 'accountId': 'default'}})
    if _tg_coding and _tg_coding != _sentinel_coding:
        bindings.append({'agentId': 'coding', 'match': {'channel': 'telegram', 'accountId': 'coding'}})
    if _tg_marketing and _tg_marketing != _sentinel_marketing:
        bindings.append({'agentId': 'marketing', 'match': {'channel': 'telegram', 'accountId': 'marketing'}})

    # WhatsApp binding — remove stale entries then re-apply
    bindings[:] = [b for b in bindings if b.get('match', {}).get('channel') != 'whatsapp']
    bindings.append({'agentId': 'family', 'match': {'channel': 'whatsapp', 'accountId': 'family'}})

    # Elevated allowFrom — use explicit user IDs (never wildcard) to avoid security audit CRITICAL.
    # Only users already in channel allowlists can use elevated mode.
    # If no allowlists are configured, elevated mode is disabled (fail-closed).
    _elevated_allow = {}
    if _tg_allowed_default:
        _elevated_allow['telegram'] = _tg_allowed_default
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
