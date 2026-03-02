#!/usr/bin/env python3
"""
@intent Re-apply model catalog and media config after onboard wipes them.
@complexity 2
"""
import json
import os
import sys
import argparse

def main():
    parser = argparse.ArgumentParser(description='Re-apply OpenClaw model catalog.')
    parser.add_argument('--config', required=True, help='Path to openclaw.json')
    args = parser.parse_args()

    cfg = args.config
    try:
        with open(cfg) as f:
            config = json.load(f)
    except Exception:
        config = {}

    catalog = {
        'minimax/MiniMax-M2.5':               {'alias': 'minimax'},
        'minimax/MiniMax-M2.1':               {'alias': 'minimax-m21'},
        'minimax/MiniMax-M2':                  {'alias': 'minimax-m2'},
        'nvidia/moonshotai/kimi-k2-instruct':  {'alias': 'kimi'},
        'nvidia/qwen/qwen3-235b-a22b':         {'alias': 'qwen3'},
    }
    config.setdefault('agents', {}).setdefault('defaults', {})['models'] = catalog

    config.setdefault('agents', {}).setdefault('defaults', {})['memorySearch'] = {
        'enabled': True,
        'provider': 'openai',
        'model': 'nomic-embed-text',
        'remote': {
            'baseUrl': 'http://127.0.0.1:11434/v1',
            'apiKey': 'ollama-local',
        },
    }

    media_cfg = {
        'concurrency': 2,
        'models': [{'provider': 'google', 'model': 'gemini-3-flash-preview',
                    'capabilities': ['image', 'audio', 'video']}],
        'image':  {'enabled': True,  'maxBytes': 10485760, 'maxChars': 1000},
        'audio':  {'enabled': True,  'maxBytes': 20971520, 'maxChars': 2000,
                   'attachments': {'mode': 'all', 'maxAttachments': 2}},
        'video':  {'enabled': True,  'maxBytes': 52428800, 'maxChars': 500},
    }
    config.setdefault('tools', {}).setdefault('media', {}).update(media_cfg)

    config.setdefault('models', {}).setdefault('providers', {}).pop('google', None)
    config.setdefault('models', {}).setdefault('providers', {}).pop('ollama', None)

    with open(cfg, 'w') as f:
        json.dump(config, f, indent=2)
    print('Model catalog written: ' + ', '.join(catalog.keys()))

if __name__ == '__main__':
    main()
