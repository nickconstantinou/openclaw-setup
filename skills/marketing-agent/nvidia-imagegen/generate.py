#!/usr/bin/env python3
"""
NVIDIA NIM Image Generation — FLUX.1-dev (primary) + Consistory (fallback/explicit)
Docs: https://docs.api.nvidia.com/nim/reference/black-forest-labs-flux_1-schnell
"""
import argparse, base64, json, os, pathlib, sys, time, urllib.request, urllib.error

NVIDIA_API_KEY = os.environ.get('NVIDIA_API_KEY', '')
BASE_URL = 'https://integrate.api.nvidia.com/v1'

MODELS = {
    'flux-dev':     'black-forest-labs/flux_1-dev',
    'flux-schnell': 'black-forest-labs/flux_1-schnell',
    'consistory':   'nvidia/consistory',
}

DEFAULT_OUTPUT = pathlib.Path.home() / '.openclaw' / 'workspace' / 'images'


def call_nvidia_infer(model_id: str, payload: dict) -> dict:
    """POST to NVIDIA NIM /v1/infer, return parsed JSON response."""
    url = f'{BASE_URL}/infer'
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            'Authorization': f'Bearer {NVIDIA_API_KEY}',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'NVCF-INPUT-ASSET-REFERENCES': '',
            'NVCF-FUNCTION-ASSET-REFERENCES': '',
        },
        method='POST',
    )
    # Some NVIDIA endpoints return 202 Accepted with a polling URL
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = resp.read()
            return json.loads(body)
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors='replace')
        raise RuntimeError(f'NVIDIA API error {e.code}: {body}') from e


def generate(prompt: str, model: str, width: int, height: int,
             steps: int, seed: int, output: pathlib.Path) -> pathlib.Path:
    if not NVIDIA_API_KEY or NVIDIA_API_KEY == 'nvapi-REPLACE_ME_WHEN_READY':
        print('[ERROR] NVIDIA_API_KEY not set. Add it to ~/.openclaw/.env', file=sys.stderr)
        sys.exit(1)

    model_id = MODELS.get(model)
    if not model_id:
        print(f'[ERROR] Unknown model "{model}". Choose: {", ".join(MODELS)}', file=sys.stderr)
        sys.exit(1)

    payload = {
        'model': model_id,
        'prompt': prompt,
        'width': width,
        'height': height,
        'num_inference_steps': steps,
        'seed': seed,
        'guidance_scale': 3.5 if 'dev' in model else 0.0,
    }

    models_to_try = [model]
    if model == 'flux-dev':
        models_to_try.append('flux-schnell')  # auto-fallback

    last_error = None
    for attempt_model in models_to_try:
        payload['model'] = MODELS[attempt_model]
        if attempt_model != model:
            print(f'[INFO] Falling back to {attempt_model}...')
        try:
            result = call_nvidia_infer(MODELS[attempt_model], payload)
            break
        except RuntimeError as e:
            last_error = e
            print(f'[WARN] {attempt_model} failed: {e}', file=sys.stderr)
    else:
        print(f'[ERROR] All models failed. Last error: {last_error}', file=sys.stderr)
        sys.exit(1)

    # Extract base64 image
    artifacts = result.get('artifacts') or result.get('images') or []
    if not artifacts:
        print(f'[ERROR] No image in response: {json.dumps(result)[:500]}', file=sys.stderr)
        sys.exit(1)

    img_b64 = artifacts[0].get('base64') or artifacts[0].get('b64_json', '')
    img_bytes = base64.b64decode(img_b64)

    # Save
    output.mkdir(parents=True, exist_ok=True)
    ts = int(time.time())
    filename = output / f'nvidia-{attempt_model}-{ts}.png'
    filename.write_bytes(img_bytes)
    print(f'[OK] Image saved: {filename}')
    return filename


def main():
    parser = argparse.ArgumentParser(description='NVIDIA NIM Image Generation')
    parser.add_argument('--prompt',  required=True, help='Image generation prompt')
    parser.add_argument('--model',   default='flux-dev',
                        choices=list(MODELS), help='Model to use (default: flux-dev)')
    parser.add_argument('--output',  default=str(DEFAULT_OUTPUT),
                        help='Output directory (default: ~/.openclaw/workspace/images)')
    parser.add_argument('--width',   type=int, default=1024)
    parser.add_argument('--height',  type=int, default=1024)
    parser.add_argument('--steps',   type=int, default=30)
    parser.add_argument('--seed',    type=int, default=0)
    args = parser.parse_args()

    generate(
        prompt=args.prompt,
        model=args.model,
        width=args.width,
        height=args.height,
        steps=args.steps,
        seed=args.seed,
        output=pathlib.Path(args.output),
    )


if __name__ == '__main__':
    main()
