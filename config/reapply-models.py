#!/usr/bin/env python3
"""
@intent Re-apply model catalog and media config after onboard wipes them.
@complexity 2
"""
import argparse

from json5_io import dump_config, load_config

def main():
    parser = argparse.ArgumentParser(description='Re-apply OpenClaw model catalog.')
    parser.add_argument('--config', required=True, help='Path to openclaw.json')
    args = parser.parse_args()

    cfg = args.config
    config = load_config(cfg)

    catalog = {
        # OpenAI Codex Pro (OAuth) — confirmed available models only
        # gpt-5.4 is the only confirmed Codex Pro model; codex-spark is entitlement-dependent
        'openai-codex/gpt-5.4':               {'alias': 'gpt-5'},
        'openai-codex/gpt-5.3-codex-spark':   {'alias': 'codex-spark'},
        # MiniMax
        'minimax/MiniMax-M2.7':               {'alias': 'minimax'},
        'minimax/MiniMax-M2.5':               {'alias': 'minimax-m25'},
        'minimax/MiniMax-M2.1':               {'alias': 'minimax-m21'},
        'minimax/MiniMax-M2':                 {'alias': 'minimax-m2'},
        # Anthropic removed — claude-cli path requires Extra Usage (notice 2026-04-04).
        # Use Anthropic API key path if Anthropic models are needed.
    }
    config.setdefault('agents', {}).setdefault('defaults', {})['models'] = catalog

    # Add openai-codex provider (OAuth — no API key needed, uses auth profile)
    # Only confirmed-available Codex Pro models listed here.
    openai_codex_provider = {
        'baseUrl': 'https://chatgpt.com/backend-api',
        'api': 'openai-codex-responses',
        'models': [
            {'id': 'gpt-5.4',             'name': 'GPT-5.4',      'reasoning': False, 'input': ['text', 'image'], 'contextWindow': 128000, 'maxTokens': 16384},
            {'id': 'gpt-5.3-codex-spark', 'name': 'Codex Spark',  'reasoning': True,  'input': ['text'],          'contextWindow': 128000, 'maxTokens': 32768},
        ],
    }
    config.setdefault('models', {}).setdefault('providers', {})['openai-codex'] = openai_codex_provider

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

    dump_config(cfg, config)
    print('Model catalog written: ' + ', '.join(catalog.keys()))

if __name__ == '__main__':
    main()
