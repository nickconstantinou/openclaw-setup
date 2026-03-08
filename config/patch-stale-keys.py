#!/usr/bin/env python3
"""
@intent Patch OpenClaw configuration to remove stale keys and ensure core provider blocks.
@complexity 3
"""
import json
import sys
import os
import argparse

def ds(obj, dotted_path, value):
    """Deep-set a dotted key path, creating intermediate dicts as needed."""
    keys = dotted_path.split('.')
    for k in keys[:-1]:
        obj = obj.setdefault(k, {})
    obj[keys[-1]] = value

def strip_bad_models(lst, bad):
    return [m for m in lst if m not in bad] if isinstance(lst, list) else lst

def main():
    parser = argparse.ArgumentParser(description='Patch OpenClaw configuration.')
    parser.add_argument('--config', required=True, help='Path to openclaw.json')
    args = parser.parse_args()

    cfg = args.config
    if not os.path.exists(cfg):
        print(f"Error: {cfg} not found.")
        sys.exit(1)

    with open(cfg, 'r') as f:
        config = json.load(f)

    # Remove stale keys that fail schema validation
    config.get('commands', {}).pop('ownerDisplay', None)
    config.get('channels', {}).get('telegram', {}).pop('streaming', None)

    # Remove stale top-level telegram channel keys (old single-account format).
    # apply-config.py writes channels.telegram.accounts.* — top-level groupPolicy/dmPolicy etc. are stale.
    _tg = config.get('channels', {}).get('telegram', {})
    for _stale_tg_key in ('groupPolicy', 'dmPolicy', 'allowFrom', 'groupAllowFrom', 'botToken'):
        _tg.pop(_stale_tg_key, None)

    # Remove channels.whatsapp.accounts.default — created by doctor migration from old top-level format.
    # apply-config.py uses accounts.family; accounts.default is stale and triggers groupPolicy warnings.
    config.get('channels', {}).get('whatsapp', {}).get('accounts', {}).pop('default', None)

    # Remove keys that were set by older deploy versions but don't exist in
    # this OpenClaw schema (2026.2.21-2). Gateway refuses to start if present.
    config.pop('acp', None)                                          # acp.* namespace
    config.get('tools', {}).pop('exec', None)                        # tools.exec.policy
    config.get('tools', {}).pop('files', None)                       # tools.files.*
    config.get('agents', {}).get('defaults', {}).pop('sandbox', None)  # agents.defaults.sandbox.mode

    _bad_models = {
        'minimax/MiniMax-M2.5-highspeed',
        'minimax/MiniMax-M2.1-highspeed',
        'nvidia/mistralai/devstral-2-123b-instruct-2512',
        'nvidia/moonshotai/kimi-k2-thinking',
        'nvidia/qwen/qwen3.5-397b-a17b',
        'nvidia/qwen/qwen3-coder-480b-a35b-instruct',
        'nvidia/deepseek-ai/deepseek-v3.1-terminus',
        'nvidia/z-ai/glm4.7',
    }
    _defaults = config.get('agents', {}).get('defaults', {})
    _model = _defaults.get('model', {})
    if isinstance(_model.get('fallbacks'), list):
        _model['fallbacks'] = strip_bad_models(_model['fallbacks'], _bad_models)
    _sub = _defaults.get('subagents', {}).get('model', {})
    if isinstance(_sub.get('fallbacks'), list):
        _sub['fallbacks'] = strip_bad_models(_sub['fallbacks'], _bad_models)
    for agent in config.get('agents', {}).get('list', []):
        _am = agent.get('model', {})
        if isinstance(_am.get('fallbacks'), list):
            _am['fallbacks'] = strip_bad_models(_am['fallbacks'], _bad_models)
        # Strip per-agent keys that aren't in the schema
        agent.get('subagents', {}).pop('maxConcurrent', None)
        # sandbox.mode is only valid at agents.defaults level, not per-agent
        agent.pop('sandbox', None)

    # Strip agents.defaults.sandbox.mode if it was written with an invalid value
    _defaults = config.get('agents', {}).get('defaults', {})
    _defaults.get('sandbox', {}).pop('mode', None)
    if _defaults.get('sandbox') == {}:
        _defaults.pop('sandbox', None)
    config.get('plugins', {}).pop('load', None)                      # plugins.load.paths
    config.get('plugins', {}).get('entries', {}).pop('acpx', None)   # plugins.entries.acpx (stale from failed deploy)
    # Clean up empty dicts left behind
    if config.get('tools') == {}: config.pop('tools', None)
    if config.get('plugins', {}) == {}: config.pop('plugins', None)

    # MiniMax — custom provider via Anthropic-compatible endpoint
    desired_minimax = {
        'baseUrl': 'https://api.minimax.io/anthropic',
        'api': 'anthropic-messages',
        'apiKey': {"source": "env", "provider": "default", "id": "MINIMAX_API_KEY"},
        'models': [
            {
                'id': 'MiniMax-M2.5',
                'name': 'MiniMax M2.5',
                'reasoning': False,
                'input': ['text'],
                'cost': {'input': 15, 'output': 60, 'cacheRead': 2, 'cacheWrite': 10},
                'contextWindow': 204800,
                'maxTokens': 8192
            },
            {
                'id': 'MiniMax-M2.1',
                'name': 'MiniMax M2.1',
                'reasoning': False,
                'input': ['text'],
                'cost': {'input': 8, 'output': 30, 'cacheRead': 1, 'cacheWrite': 5},
                'contextWindow': 204800,
                'maxTokens': 8192
            },
            {
                'id': 'MiniMax-M2',
                'name': 'MiniMax M2',
                'reasoning': True,
                'input': ['text'],
                'cost': {'input': 5, 'output': 20, 'cacheRead': 1, 'cacheWrite': 3},
                'contextWindow': 204800,
                'maxTokens': 8192
            }
        ]
    }

    desired_models_catalog = {
        'minimax/MiniMax-M2.5': {'alias': 'minimax'},
        'minimax/MiniMax-M2.1': {'alias': 'minimax-m21'},
        'minimax/MiniMax-M2':   {'alias': 'minimax-m2'},
    }

    config.setdefault('models', {})['mode'] = 'merge'
    providers = config['models'].setdefault('providers', {})
    providers['minimax'] = desired_minimax
    providers.pop('nvidia', None)
    providers.pop('ollama', None)
    providers.pop('google', None)

    config.setdefault('tools', {}).setdefault('media', {}).update({
        'concurrency': 2,
        'models': [
            {
                'provider': 'google',
                'model': 'gemini-3-flash-preview',
                'capabilities': ['image', 'audio', 'video'],
            }
        ],
        'image': {'enabled': True, 'maxBytes': 10485760, 'maxChars': 1000},
        'audio': {
            'enabled': True, 'maxBytes': 20971520, 'maxChars': 2000,
            'attachments': {'mode': 'all', 'maxAttachments': 2},
        },
        'video': {'enabled': True, 'maxBytes': 52428800, 'maxChars': 500},
    })

    existing_catalog = config.get('agents', {}).get('defaults', {}).get('models', {})
    # Remove any stale nvidia entries from the catalog
    for k in list(existing_catalog.keys()):
        if k.startswith('nvidia/'):
            del existing_catalog[k]
    existing_catalog.update(desired_models_catalog)
    config.setdefault('agents', {}).setdefault('defaults', {})['models'] = existing_catalog

    with open(cfg, 'w') as f:
        json.dump(config, f, indent=2)
    print('Config patched OK.')

if __name__ == '__main__':
    main()
