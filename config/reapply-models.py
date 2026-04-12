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
        # OpenAI Codex Pro (OAuth)
        'openai-codex/gpt-5.4':               {'alias': 'gpt-5'},
        'openai-codex/gpt-5.4-mini':          {'alias': 'gpt-5-mini'},
        'openai-codex/gpt-5.3-codex':         {'alias': 'gpt-5-codex'},
        'openai-codex/gpt-5.2':               {'alias': 'gpt-5-2'},
        # MiniMax
        'minimax/MiniMax-M2.7':               {'alias': 'minimax'},
        'minimax/MiniMax-M2.5':               {'alias': 'minimax-m25'},
        'minimax/MiniMax-M2.1':               {'alias': 'minimax-m21'},
        'minimax/MiniMax-M2':                 {'alias': 'minimax-m2'},
        # Anthropic is intentionally removed from this setup repo.
        # Re-enable it explicitly with direct provider credentials if needed.
    }
    config.setdefault('agents', {}).setdefault('defaults', {})['models'] = catalog

    minimax_provider = {
        'baseUrl': 'https://api.minimax.io/anthropic',
        'api': 'anthropic-messages',
        'apiKey': {'source': 'env', 'provider': 'default', 'id': 'MINIMAX_API_KEY'},
        'models': [
            {'id': 'MiniMax-M2.7', 'name': 'MiniMax M2.7', 'reasoning': False, 'input': ['text'], 'contextWindow': 204800, 'maxTokens': 8192},
            {'id': 'MiniMax-M2.5', 'name': 'MiniMax M2.5', 'reasoning': False, 'input': ['text'], 'contextWindow': 204800, 'maxTokens': 8192},
            {'id': 'MiniMax-M2.1', 'name': 'MiniMax M2.1', 'reasoning': False, 'input': ['text'], 'contextWindow': 204800, 'maxTokens': 8192},
            {'id': 'MiniMax-M2', 'name': 'MiniMax M2', 'reasoning': True, 'input': ['text'], 'contextWindow': 204800, 'maxTokens': 8192},
        ],
    }

    # Add openai-codex provider (OAuth — no API key needed, uses auth profile)
    openai_codex_provider = {
        'baseUrl': 'https://chatgpt.com/backend-api',
        'api': 'openai-codex-responses',
        'models': [
            {'id': 'gpt-5.4',       'name': 'GPT-5.4',       'reasoning': True,  'input': ['text', 'image'], 'contextWindow': 1050000, 'contextTokens': 272000, 'maxTokens': 128000},
            {'id': 'gpt-5.4-mini',  'name': 'GPT-5.4 mini',  'reasoning': True,  'input': ['text', 'image'], 'contextWindow': 272000,  'maxTokens': 128000},
            {'id': 'gpt-5.3-codex', 'name': 'GPT-5.3 Codex', 'reasoning': False, 'input': ['text', 'image'], 'contextWindow': 128000,  'maxTokens': 65536},
            {'id': 'gpt-5.2',       'name': 'GPT-5.2',        'reasoning': False, 'input': ['text', 'image'], 'contextWindow': 128000,  'maxTokens': 65536},
        ],
    }
    providers = config.setdefault('models', {}).setdefault('providers', {})
    providers['openai-codex'] = openai_codex_provider
    providers['minimax'] = minimax_provider

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

    providers.pop('anthropic', None)
    providers.pop('google', None)
    providers.pop('ollama', None)

    dump_config(cfg, config)
    print('Model catalog written: ' + ', '.join(catalog.keys()))

if __name__ == '__main__':
    main()
