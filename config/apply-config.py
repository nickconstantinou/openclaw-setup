#!/usr/bin/env python3
"""
@intent Apply core JSON configuration to openclaw.json including API keys, models, and agents.
@complexity 3
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
    _nvidia_key = os.environ.get('NVIDIA_API_KEY', '')
    _nvidia_active = bool(_nvidia_key and _nvidia_key not in ('', 'nvapi-REPLACE_ME_WHEN_READY'))

    _main_primary = 'minimax/MiniMax-M2.5'
    _fallbacks = (
        ['minimax/MiniMax-M2.1', 'nvidia/moonshotai/kimi-k2-thinking', 'nvidia/qwen/qwen3.5-397b-a17b',
         'nvidia/qwen/qwen3-coder-480b-a35b-instruct', 'nvidia/deepseek-ai/deepseek-v3.1-terminus',
         'nvidia/z-ai/glm4.7']
        if _nvidia_active else
        ['minimax/MiniMax-M2.1']
    )
    ds(c, 'agents.defaults.model.primary',   _main_primary)
    ds(c, 'agents.defaults.model.fallbacks', _fallbacks)

    # ── API keys (env block) ──────────────────────────────────────────────────────
    ds(c, 'env.MINIMAX_API_KEY',   os.environ.get('MINIMAX_API_KEY', ''))
    ds(c, 'env.GEMINI_API_KEY',    os.environ.get('GEMINI_API_KEY', ''))
    ds(c, 'env.GOOGLE_API_KEY',    os.environ.get('GEMINI_API_KEY', ''))
    ds(c, 'env.ANTHROPIC_API_KEY', os.environ.get('ANTHROPIC_API_KEY', ''))
    if _nvidia_active:
        ds(c, 'env.NVIDIA_API_KEY', _nvidia_key)

    gog_account  = os.environ.get('GOG_ACCOUNT', '')
    gog_password = os.environ.get('GOG_KEYRING_PASSWORD', '')
    if gog_account and gog_account != 'your@gmail.com':
        ds(c, 'env.GOG_ACCOUNT', gog_account)
    if gog_password and gog_password != 'REPLACE_ME':
        ds(c, 'env.GOG_KEYRING_PASSWORD', gog_password)
    ds(c, 'env.GOG_KEYRING_BACKEND', 'file')

    pb_key = os.environ.get('POST_BRIDGE_API_KEY', '')
    if pb_key and pb_key != 'pb_REPLACE_ME_WHEN_READY':
        ds(c, 'env.POST_BRIDGE_API_KEY', pb_key)
        skill_key = 'post-bridge-social-manager'
        ds(c, f'skills.entries.{skill_key}.enabled', True)
        ds(c, f'skills.entries.{skill_key}.apiKey', {"source": "env", "provider": "default", "id": "POST_BRIDGE_API_KEY"})

    tavily_key = os.environ.get('TAVILY_API_KEY', '')
    if tavily_key and tavily_key != 'tvly-REPLACE_ME_WHEN_READY':
        ds(c, 'env.TAVILY_API_KEY', tavily_key)
        ds(c, 'skills.entries.tavily.enabled', True)
        ds(c, 'skills.entries.tavily.apiKey', {"source": "env", "provider": "default", "id": "TAVILY_API_KEY"})

    if _nvidia_active:
        ds(c, 'skills.entries.nvidia-imagegen.enabled', True)
        ds(c, 'skills.entries.nvidia-imagegen.apiKey', {"source": "env", "provider": "default", "id": "NVIDIA_API_KEY"})

    ds(c, 'agents.defaults.memorySearch.enabled',          True)
    ds(c, 'agents.defaults.memorySearch.provider',         'openai')
    ds(c, 'agents.defaults.memorySearch.model',            'nomic-embed-text')
    ds(c, 'agents.defaults.memorySearch.remote.baseUrl',   'http://127.0.0.1:11434/v1')

    ds(c, 'agents.defaults.compaction.mode', 'safeguard')

    ds(c, 'agents.defaults.subagents.model', {
        'primary':   'minimax/MiniMax-M2.5',
        'fallbacks': ['minimax/MiniMax-M2.1'],
    })
    ds(c, 'agents.defaults.subagents.maxConcurrent', 4)

    if _nvidia_active:
        _coding_primary   = 'nvidia/moonshotai/kimi-k2-thinking'
        _coding_fallback  = ['minimax/MiniMax-M2.5', 'minimax/MiniMax-M2.1', 'nvidia/qwen/qwen3.5-397b-a17b',
                             'nvidia/qwen/qwen3-coder-480b-a35b-instruct', 'nvidia/deepseek-ai/deepseek-v3.1-terminus',
                             'nvidia/z-ai/glm4.7']
        _frontend_primary  = 'nvidia/moonshotai/kimi-k2-thinking'
        _frontend_fallback = ['minimax/MiniMax-M2.5', 'minimax/MiniMax-M2.1', 'nvidia/qwen/qwen3.5-397b-a17b',
                              'nvidia/qwen/qwen3-coder-480b-a35b-instruct', 'nvidia/deepseek-ai/deepseek-v3.1-terminus',
                              'nvidia/z-ai/glm4.7']
    else:
        _coding_primary   = 'minimax/MiniMax-M2.5'
        _coding_fallback  = ['minimax/MiniMax-M2.1']
        _frontend_primary  = 'minimax/MiniMax-M2.5'
        _frontend_fallback = ['minimax/MiniMax-M2.1']

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
            'subagents': {'allowAgents': ['coding', 'frontend']},
            'tools': {'profile': 'full'},
        },
        {
            'id':       'coding',
            'name':     'Coder',
            'workspace': f'{_home}/.openclaw/workspace-coding',
            'agentDir':  f'{_home}/.openclaw/agents/coding/agent',
            'model': {'primary': _coding_primary, 'fallbacks': _coding_fallback},
            'tools':    {'profile': 'coding'},
            'subagents': {'allowAgents': ['*']},
            'identity': {'name': 'Coder', 'emoji': '💻'},
        },
        {
            'id':       'frontend',
            'name':     'Frontend',
            'workspace': f'{_home}/.openclaw/workspace-frontend',
            'agentDir':  f'{_home}/.openclaw/agents/frontend/agent',
            'model': {'primary': _frontend_primary, 'fallbacks': _frontend_fallback},
            'tools':    {'profile': 'coding'},
            'subagents': {'allowAgents': ['*']},
            'identity': {'name': 'Frontend', 'emoji': '🎨'},
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
                    entry['model']    = agent['model']
                    entry['agentDir'] = agent['agentDir']
                    entry.setdefault('tools',    agent['tools'])
                    entry.setdefault('subagents', agent['subagents'])
                    entry.get('subagents', {}).pop('maxConcurrent', None)

    ds(c, 'tools.sessions.visibility', 'tree')
    ds(c, 'tools.subagents.tools.deny', [])

    ds(c, 'gateway.mode',           'local')
    ds(c, 'gateway.bind',           'loopback')
    ds(c, 'gateway.trustedProxies',  ['127.0.0.1', '::1'])
    ds(c, 'gateway.auth.mode',      'token')
    ds(c, 'gateway.auth.token',     os.environ.get('OPENCLAW_GATEWAY_TOKEN', ''))
    
    # Reset trusted proxies to empty as per original script's final override
    ds(c, 'gateway.trustedProxies', [])

    ds(c, 'browser.headless', True)

    with open(cfg, 'w') as f:
        json.dump(c, f, indent=2)

    print('ok')

if __name__ == '__main__':
    main()
