#!/usr/bin/env python3
"""
NVIDIA NIM Image Understanding — google/gemma-4-31b-it (vision)
API: https://integrate.api.nvidia.com/v1/chat/completions
Usage:
  python3 analyse.py --image /path/to/image.jpg --prompt "What is in this image?"
  python3 analyse.py --image /path/to/image.jpg  # uses default describe prompt
  python3 analyse.py --image /path/to/image.jpg --prompt "..." --json  # JSON output
"""
import argparse, base64, io, json, os, sys
import requests

NVIDIA_API_KEY = os.environ.get('NVIDIA_API_KEY', '')
API_URL = 'https://integrate.api.nvidia.com/v1/chat/completions'
MODEL = 'google/gemma-4-31b-it'
MAX_SHORT_SIDE = 768   # resize if larger, keeps payload under ~100KB
DEFAULT_PROMPT = 'Describe this image in detail. What is shown, what is happening, and any text visible.'


def load_image(path: str) -> tuple[str, str]:
    """Load image from file path, resize if needed. Returns (base64_str, mime_type)."""
    with open(path, 'rb') as f:
        raw = f.read()

    # Determine mime type
    suffix = path.lower().split('.')[-1]
    mime_map = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
                'gif': 'image/gif', 'webp': 'image/webp'}
    mime = mime_map.get(suffix, 'image/jpeg')

    # Resize with Pillow if available and image is large
    try:
        from PIL import Image
        img = Image.open(io.BytesIO(raw))
        if max(img.size) > MAX_SHORT_SIDE:
            img.thumbnail((MAX_SHORT_SIDE, MAX_SHORT_SIDE))
            buf = io.BytesIO()
            fmt = 'JPEG' if mime == 'image/jpeg' else 'PNG'
            quality = {'JPEG': 75}.get(fmt, None)
            img.save(buf, format=fmt, **({'quality': quality} if quality else {}))
            raw = buf.getvalue()
            mime = 'image/jpeg' if fmt == 'JPEG' else 'image/png'
    except ImportError:
        pass  # Pillow not available — send as-is

    return base64.b64encode(raw).decode(), mime


def analyse(image_path: str, prompt: str, max_tokens: int = 512) -> dict:
    """Call NVIDIA NIM vision API. Returns dict with 'content' and 'model'."""
    if not NVIDIA_API_KEY or NVIDIA_API_KEY == 'nvapi-REPLACE_ME_WHEN_READY':
        print('[ERROR] NVIDIA_API_KEY not set. Add it to ~/.openclaw/.env', file=sys.stderr)
        sys.exit(1)

    img_b64, mime = load_image(image_path)

    resp = requests.post(
        API_URL,
        headers={
            'Authorization': f'Bearer {NVIDIA_API_KEY}',
            'Content-Type': 'application/json',
        },
        json={
            'model': MODEL,
            'messages': [{
                'role': 'user',
                'content': [
                    {'type': 'text', 'text': prompt},
                    {'type': 'image_url', 'image_url': {'url': f'data:{mime};base64,{img_b64}'}},
                ],
            }],
            'max_tokens': max_tokens,
        },
        timeout=60,
    )

    if resp.status_code != 200:
        print(f'[ERROR] API returned {resp.status_code}: {resp.text[:300]}', file=sys.stderr)
        sys.exit(1)

    data = resp.json()
    content = data['choices'][0]['message']['content']
    return {'content': content, 'model': MODEL, 'image': image_path}


def main():
    parser = argparse.ArgumentParser(description='NVIDIA NIM Image Understanding (gemma-3-27b-it)')
    parser.add_argument('--image',      required=True, help='Path to image file (jpg/png/webp)')
    parser.add_argument('--prompt',     default=DEFAULT_PROMPT, help='Question or instruction about the image')
    parser.add_argument('--max-tokens', type=int, default=512, help='Max tokens in response (default: 512)')
    parser.add_argument('--json',       action='store_true', help='Output as JSON')
    args = parser.parse_args()

    result = analyse(args.image, args.prompt, args.max_tokens)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(result['content'])


if __name__ == '__main__':
    main()
