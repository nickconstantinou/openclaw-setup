#!/usr/bin/env python3
"""
@intent Apply core JSON configuration to openclaw.json including API keys, models, agents, and security policies.
@complexity 5
"""
import json
import os
import sys
import argparse

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

    _coding_primary     = 'minimax/MiniMax-M2.5'
    _coding_fallback    = ['minimax/MiniMax-M2.1']
    _marketing_primary  = 'minimax/MiniMax-M2.5'
    _marketing_fallback = ['minimax/MiniMax-M2.1']

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
                'allow': ['read', 'write', 'edit', 'apply_patch', 'exec', 'process', 'bash', 'sessions_list', 'sessions_history', 'sessions_send', 'session_status', 'google-workspace', 'browser', 'tavily', 'claude-code']
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
                'allow': ['read', 'write', 'exec', 'process', 'bash', 'sessions_list', 'sessions_history', 'sessions_send', 'session_status', 'google-workspace', 'browser', 'tavily']
            },
            'subagents': {'allowAgents': []},
            'identity': {'name': 'Marketing', 'emoji': '📣'},
        },
        {
            'id':        'family',
            'name':      'Family',
            'workspace':  f'{_home}/.openclaw/agents/family/workspace',
            'agentDir':   f'{_home}/.openclaw/agents/family/agent',
            'model':     {'primary': 'minimax/MiniMax-M2.5', 'fallbacks': ['minimax/MiniMax-M2.1']},
            'subagents': {'allowAgents': []},
            'tools':     {'profile': 'full'},
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

    ds(c, 'tools.sessions.visibility', 'tree')
    ds(c, 'tools.profile', 'full')
    ds(c, 'tools.subagents.tools.deny', [])

    ds(c, 'gateway.mode',           'local')
    ds(c, 'gateway.bind',           'loopback')
    ds(c, 'gateway.auth.mode',      'token')
    ds(c, 'gateway.auth.token',     os.environ.get('OPENCLAW_GATEWAY_TOKEN', ''))

    # Loopback-only gateway — no reverse proxies to trust
    ds(c, 'gateway.trustedProxies', [])

    ds(c, 'browser.headless', True)

    # ── Security: Sandbox defaults (all agents confined to their workspace) ───
    ds(c, 'agents.defaults.sandbox.mode', 'all')
    ds(c, 'tools.fs.workspaceOnly', True)

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
    tg_accounts['default'] = {
        'botToken':    _tg_main,
        'dmPolicy':    _dm_policy_default,
        'groupPolicy': 'disabled',  # Groups disabled by default (use allowlist if needed)
        'allowFrom':   _tg_allowed_default,
    }

    # Coding bot configuration (has bash/exec — should be most restricted!)
    if _tg_coding and _tg_coding != _sentinel_coding:
        _dm_policy_coding = 'allowlist' if _tg_allowed_coding else 'pairing'
        tg_accounts['coding'] = {
            'botToken':    _tg_coding,
            'dmPolicy':    _dm_policy_coding,
            'groupPolicy': 'disabled',
            'allowFrom':   _tg_allowed_coding,
        }

    # Marketing bot configuration
    if _tg_marketing and _tg_marketing != _sentinel_marketing:
        _dm_policy_marketing = 'allowlist' if _tg_allowed_marketing else 'pairing'
        tg_accounts['marketing'] = {
            'botToken':    _tg_marketing,
            'dmPolicy':    _dm_policy_marketing,
            'groupPolicy': 'disabled',
            'allowFrom':   _tg_allowed_marketing,
        }

    # ── WhatsApp multi-account (QR-linked, no token needed) ──────────────────────
    # Security: Get allowed WhatsApp numbers from environment (international format, no +)
    _wa_allowed_raw = os.environ.get('WHATSAPP_ALLOWED_USERS', '')
    # Filter out placeholder/sentinel values and empty strings
    _wa_allowed_users = [
        num.strip() for num in _wa_allowed_raw.split(',')
        if num.strip() and num.strip() != 'REPLACE_ME'
    ]

    _wa_dm_policy = 'allowlist' if _wa_allowed_users else 'pairing'
    _wa_allow_from = _wa_allowed_users if _wa_allowed_users else []

    ds(c, 'channels.whatsapp.accounts.family', {
        'dmPolicy': _wa_dm_policy,
        'groupPolicy': 'disabled',  # Groups disabled by default (use allowlist if needed)
        'allowFrom': _wa_allow_from
    })
    ds(c, 'channels.whatsapp.defaultAccount', 'family')

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

    with open(cfg, 'w') as f:
        json.dump(c, f, indent=2)

    print('ok')

if __name__ == '__main__':
    main()
