#!/usr/bin/env python3
"""
@intent Patch OpenClaw configuration to remove stale keys and ensure core provider blocks.
@complexity 3
"""
import sys
import os
import argparse

from json5_io import dump_config, load_config

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

    config = load_config(cfg)

    # Remove stale keys that fail schema validation
    config.get('commands', {}).pop('ownerDisplay', None)

    # Remove keys that were set by older deploy versions but don't exist in
    # this OpenClaw schema (2026.2.21-2). Gateway refuses to start if present.
    config.get('tools', {}).pop('files', None)                       # tools.files.*

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
    config.get('plugins', {}).pop('load', None)                      # plugins.load.paths
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
                'id': 'MiniMax-M2.7',
                'name': 'MiniMax M2.7',
                'reasoning': False,
                'input': ['text'],
                'cost': {'input': 30, 'output': 120, 'cacheRead': 6, 'cacheWrite': 38},
                'contextWindow': 204800,
                'maxTokens': 8192
            },
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
        'minimax/MiniMax-M2.7': {'alias': 'minimax'},
        'minimax/MiniMax-M2.5': {'alias': 'minimax-m25'},
        'minimax/MiniMax-M2.1': {'alias': 'minimax-m21'},
        'minimax/MiniMax-M2':   {'alias': 'minimax-m2'},
    }

    desired_anthropic = {
        'baseUrl': 'https://api.anthropic.com',
        'api': 'anthropic-messages',
        'apiKey': {'source': 'env', 'provider': 'default', 'id': 'ANTHROPIC_API_KEY'},
        'models': [
            {
                'id': 'claude-opus-4-6',
                'name': 'Claude Opus 4.6',
                'reasoning': False,
                'input': ['text', 'image'],
                'cost': {'input': 15, 'output': 75, 'cacheRead': 1.5, 'cacheWrite': 18.75},
                'contextWindow': 200000,
                'maxTokens': 32000,
            },
            {
                'id': 'claude-sonnet-4-6',
                'name': 'Claude Sonnet 4.6',
                'reasoning': False,
                'input': ['text', 'image'],
                'cost': {'input': 3, 'output': 15, 'cacheRead': 0.3, 'cacheWrite': 3.75},
                'contextWindow': 200000,
                'maxTokens': 16000,
            },
            {
                'id': 'claude-haiku-4-5-20251001',
                'name': 'Claude Haiku 4.5',
                'reasoning': False,
                'input': ['text', 'image'],
                'cost': {'input': 0.8, 'output': 4, 'cacheRead': 0.08, 'cacheWrite': 1},
                'contextWindow': 200000,
                'maxTokens': 8192,
            },
        ]
    }

    config.setdefault('models', {})['mode'] = 'merge'
    providers = config['models'].setdefault('providers', {})
    providers['minimax'] = desired_minimax
    providers['anthropic'] = desired_anthropic
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

    desired_anthropic_catalog = {
        'anthropic/claude-opus-4-6':         {'alias': 'claude-opus'},
        'anthropic/claude-sonnet-4-6':       {'alias': 'claude-sonnet'},
        'anthropic/claude-haiku-4-5-20251001': {'alias': 'claude-haiku'},
    }

    existing_catalog = config.get('agents', {}).get('defaults', {}).get('models', {})
    # Remove any stale nvidia entries from the catalog
    for k in list(existing_catalog.keys()):
        if k.startswith('nvidia/'):
            del existing_catalog[k]
    existing_catalog.update(desired_models_catalog)
    existing_catalog.update(desired_anthropic_catalog)
    config.setdefault('agents', {}).setdefault('defaults', {})['models'] = existing_catalog

    dump_config(cfg, config)
    print('Config patched OK.')

if __name__ == '__main__':
    main()
