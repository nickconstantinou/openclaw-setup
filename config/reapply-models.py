#!/usr/bin/env python3
"""
@intent Re-apply model catalog and media config after onboard wipes them.
@complexity 2
"""
import sys
import argparse

from json5_io import dump_config, load_config

def main():
    parser = argparse.ArgumentParser(description='Re-apply OpenClaw model catalog.')
    parser.add_argument('--config', required=True, help='Path to openclaw.json')
    args = parser.parse_args()

    cfg = args.config
    config = load_config(cfg)

    catalog = {
        # OpenAI Codex Pro (OAuth) — gpt-5 family
        'openai-codex/gpt-5.4':               {'alias': 'gpt-5'},
        'openai-codex/gpt-5.4-pro':           {'alias': 'gpt-5-pro'},
        'openai-codex/gpt-5.4-mini':          {'alias': 'gpt-5-mini'},
        'openai-codex/gpt-5.4-nano':          {'alias': 'gpt-5-nano'},
        'openai-codex/gpt-5.3-codex-spark':   {'alias': 'codex-spark'},
        'openai-codex/gpt-5.2-codex':         {'alias': 'codex-52'},
        'openai-codex/gpt-5.2':               {'alias': 'gpt-52'},
        'openai-codex/gpt-5.1-codex':         {'alias': 'codex-51'},
        # MiniMax
        'minimax/MiniMax-M2.7':               {'alias': 'minimax'},
        'minimax/MiniMax-M2.5':               {'alias': 'minimax-m25'},
        'minimax/MiniMax-M2.1':               {'alias': 'minimax-m21'},
        'minimax/MiniMax-M2':                 {'alias': 'minimax-m2'},
        # Anthropic
        'anthropic/claude-opus-4-6':          {'alias': 'claude-opus'},
        'anthropic/claude-sonnet-4-6':        {'alias': 'claude-sonnet'},
        'anthropic/claude-haiku-4-5-20251001': {'alias': 'claude-haiku'},
    }
    config.setdefault('agents', {}).setdefault('defaults', {})['models'] = catalog

    # Add openai-codex provider (OAuth — no API key needed, uses auth profile)
    openai_codex_provider = {
        'baseUrl': 'https://chatgpt.com/backend-api',
        'api': 'openai-codex-responses',
        'models': [
            {'id': 'gpt-5.4',             'name': 'GPT-5.4',              'reasoning': False, 'input': ['text', 'image'], 'contextWindow': 128000, 'maxTokens': 16384},
            {'id': 'gpt-5.4-pro',         'name': 'GPT-5.4 Pro',         'reasoning': False, 'input': ['text', 'image'], 'contextWindow': 128000, 'maxTokens': 16384},
            {'id': 'gpt-5.4-mini',        'name': 'GPT-5.4 Mini',        'reasoning': False, 'input': ['text', 'image'], 'contextWindow': 128000, 'maxTokens': 16384},
            {'id': 'gpt-5.4-nano',        'name': 'GPT-5.4 Nano',        'reasoning': False, 'input': ['text'],          'contextWindow': 128000, 'maxTokens': 8192},
            {'id': 'gpt-5.3-codex-spark', 'name': 'Codex Spark',         'reasoning': True,  'input': ['text'],          'contextWindow': 128000, 'maxTokens': 32768},
            {'id': 'gpt-5.2-codex',       'name': 'GPT-5.2 Codex',       'reasoning': True,  'input': ['text'],          'contextWindow': 128000, 'maxTokens': 32768},
            {'id': 'gpt-5.2',             'name': 'GPT-5.2',             'reasoning': False, 'input': ['text', 'image'], 'contextWindow': 128000, 'maxTokens': 16384},
            {'id': 'gpt-5.1-codex',       'name': 'GPT-5.1 Codex',       'reasoning': True,  'input': ['text'],          'contextWindow': 128000, 'maxTokens': 32768},
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
