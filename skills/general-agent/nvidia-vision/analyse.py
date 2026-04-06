#!/usr/bin/env python3
"""
NVIDIA NIM Image/GIF/Video Understanding — google/gemma-4-31b-it (vision)
API: https://integrate.api.nvidia.com/v1/chat/completions

Supports: JPEG, PNG, WebP, GIF (first frame), MP4/MOV/AVI/MKV/WebM (ffmpeg frame extraction)

Usage:
  python3 analyse.py --image /path/to/image.jpg --prompt "What is in this image?"
  python3 analyse.py --image /path/to/video.mp4 --prompt "What is happening?"
  python3 analyse.py --image /path/to/anim.gif   # GIF: first frame analysed
  python3 analyse.py --image /path/to/image.jpg  # uses default describe prompt
  python3 analyse.py --image /path/to/image.jpg --prompt "..." --json
"""
import argparse, base64, io, json, os, subprocess, sys, tempfile
import requests

NVIDIA_API_KEY = os.environ.get('NVIDIA_API_KEY', '')
API_URL = 'https://integrate.api.nvidia.com/v1/chat/completions'
MODEL   = 'google/gemma-4-31b-it'
MAX_SHORT_SIDE  = 768    # resize stills to this on longest side
MAX_VIDEO_SIDE  = 384    # smaller for video frames (multiple API calls)
VIDEO_FRAMES    = 4      # number of evenly-spaced frames to extract from video
VIDEO_EXTS      = {'.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v', '.3gp'}
DEFAULT_PROMPT  = 'Describe this in detail. What is shown, what is happening, and any text visible.'
DEFAULT_VIDEO_FRAME_PROMPT = 'Describe this video frame briefly: what is shown, any text, any people or objects.'
DEFAULT_VIDEO_SUMMARY_PROMPT = (
    'Here are descriptions of {n} frames sampled evenly from a video:\n\n{descriptions}\n\n'
    'Based on these frames, describe what is happening in the video overall. '
    'Note any motion, changes, text, or people visible.'
)


# ── Image loading ─────────────────────────────────────────────────────────────

def resize_jpeg(raw: bytes) -> bytes:
    """Resize raw image bytes to MAX_SHORT_SIDE and return as JPEG bytes."""
    try:
        from PIL import Image
        img = Image.open(io.BytesIO(raw))
        if img.mode not in ('RGB', 'L'):
            img = img.convert('RGB')
        if max(img.size) > MAX_SHORT_SIDE:
            img.thumbnail((MAX_SHORT_SIDE, MAX_SHORT_SIDE))
        buf = io.BytesIO()
        img.save(buf, format='JPEG', quality=80)
        return buf.getvalue()
    except ImportError:
        return raw  # Pillow not available — send as-is


def load_image(path: str) -> tuple[str, str]:
    """Load a still image (JPEG/PNG/WebP/GIF). Returns (base64, mime)."""
    with open(path, 'rb') as f:
        raw = f.read()

    suffix = os.path.splitext(path)[1].lower()
    if suffix == '.gif':
        # Extract first frame as JPEG so the API can read it reliably
        try:
            from PIL import Image
            img = Image.open(io.BytesIO(raw))
            img.seek(0)
            if img.mode not in ('RGB', 'L'):
                img = img.convert('RGB')
            img.thumbnail((MAX_SHORT_SIDE, MAX_SHORT_SIDE))
            buf = io.BytesIO()
            img.save(buf, format='JPEG', quality=80)
            return base64.b64encode(buf.getvalue()).decode(), 'image/jpeg'
        except ImportError:
            pass  # fall through and send raw GIF
        return base64.b64encode(raw).decode(), 'image/gif'

    # For JPEG/PNG/WebP — resize then encode
    resized = resize_jpeg(raw)
    return base64.b64encode(resized).decode(), 'image/jpeg'


def extract_video_frames(path: str, n: int = VIDEO_FRAMES) -> list[str]:
    """Use ffmpeg to extract n evenly-spaced frames. Returns list of base64 JPEG strings."""
    if not _ffmpeg_available():
        print('[ERROR] ffmpeg not found — required for video analysis.', file=sys.stderr)
        sys.exit(1)

    probe = subprocess.run(
        ['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
         '-of', 'default=noprint_wrappers=1:nokey=1', path],
        capture_output=True, text=True
    )
    try:
        duration = float(probe.stdout.strip())
    except ValueError:
        duration = 10.0

    frames_b64 = []
    with tempfile.TemporaryDirectory() as tmpdir:
        for i in range(n):
            t = duration * (0.05 + 0.9 * i / max(n - 1, 1))
            out = os.path.join(tmpdir, f'frame_{i:02d}.jpg')
            subprocess.run(
                ['ffmpeg', '-y', '-ss', str(t), '-i', path,
                 '-vframes', '1', '-vf', f'scale={MAX_VIDEO_SIDE}:-1', out],
                capture_output=True
            )
            if os.path.exists(out):
                with open(out, 'rb') as f:
                    frames_b64.append(base64.b64encode(f.read()).decode())

    if not frames_b64:
        print('[ERROR] ffmpeg failed to extract any frames.', file=sys.stderr)
        sys.exit(1)

    return frames_b64


def _ffmpeg_available() -> bool:
    return subprocess.run(['which', 'ffmpeg'], capture_output=True).returncode == 0


# ── API call ──────────────────────────────────────────────────────────────────

def _call_api(content_blocks: list, max_tokens: int) -> str:
    """Send a vision request with given content blocks. Returns response text."""
    if not NVIDIA_API_KEY or NVIDIA_API_KEY == 'nvapi-REPLACE_ME_WHEN_READY':
        print('[ERROR] NVIDIA_API_KEY not set. Add it to ~/.openclaw/.env', file=sys.stderr)
        sys.exit(1)

    resp = requests.post(
        API_URL,
        headers={'Authorization': f'Bearer {NVIDIA_API_KEY}', 'Content-Type': 'application/json'},
        json={
            'model': MODEL,
            'messages': [{'role': 'user', 'content': content_blocks}],
            'max_tokens': max_tokens,
        },
        timeout=90,
    )
    if resp.status_code != 200:
        print(f'[ERROR] API returned {resp.status_code}: {resp.text[:300]}', file=sys.stderr)
        sys.exit(1)
    return resp.json()['choices'][0]['message']['content']


def analyse(path: str, prompt: str | None, max_tokens: int = 512, n_frames: int = VIDEO_FRAMES) -> dict:
    """Analyse an image, GIF, or video file. Returns dict with content and metadata."""
    suffix = os.path.splitext(path)[1].lower()
    is_video = suffix in VIDEO_EXTS

    if is_video:
        frames = extract_video_frames(path, n_frames)
        frame_prompt = prompt or DEFAULT_VIDEO_FRAME_PROMPT
        # Analyse each frame individually then synthesise — avoids multi-image API timeout
        descriptions = []
        for i, fb64 in enumerate(frames):
            blocks: list = [
                {'type': 'text', 'text': f'Frame {i+1} of {len(frames)}: {frame_prompt}'},
                {'type': 'image_url', 'image_url': {'url': f'data:image/jpeg;base64,{fb64}'}},
            ]
            desc = _call_api(blocks, 200)
            descriptions.append(f'Frame {i+1}: {desc}')
        # Final synthesis call (text only)
        summary_prompt = DEFAULT_VIDEO_SUMMARY_PROMPT.format(
            n=len(frames), descriptions='\n'.join(descriptions)
        )
        content = _call_api([{'type': 'text', 'text': summary_prompt}], max_tokens)
        return {'content': content, 'model': MODEL, 'file': path,
                'type': 'video', 'frames_extracted': len(frames)}
    else:
        img_b64, mime = load_image(path)
        used_prompt = prompt or DEFAULT_PROMPT
        blocks = [
            {'type': 'text', 'text': used_prompt},
            {'type': 'image_url', 'image_url': {'url': f'data:{mime};base64,{img_b64}'}},
        ]
        content = _call_api(blocks, max_tokens)
        file_type = 'gif' if suffix == '.gif' else 'image'
        return {'content': content, 'model': MODEL, 'file': path, 'type': file_type}


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description='NVIDIA NIM Vision — analyse images, GIFs, and videos (gemma-4-31b-it)'
    )
    parser.add_argument('--image',      required=True,
                        help='Path to image (jpg/png/webp/gif) or video (mp4/mov/avi/mkv/webm)')
    parser.add_argument('--prompt',     default=None,
                        help='Question or instruction (uses smart default if omitted)')
    parser.add_argument('--frames',     type=int, default=VIDEO_FRAMES,
                        help=f'Frames to extract from video (default: {VIDEO_FRAMES})')
    parser.add_argument('--max-tokens', type=int, default=512,
                        help='Max tokens in response (default: 512)')
    parser.add_argument('--json',       action='store_true', help='Output as JSON')
    args = parser.parse_args()

    result = analyse(args.image, args.prompt, args.max_tokens, args.frames)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(result['content'])


if __name__ == '__main__':
    main()
