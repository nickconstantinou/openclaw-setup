#!/usr/bin/env python3
"""
NVIDIA NIM Image Generation — Stable Diffusion 3 Medium (primary)
API: https://ai.api.nvidia.com/v1/genai/stabilityai/stable-diffusion-3-medium
"""
import argparse, base64, json, os, pathlib, sys, time
import requests

NVIDIA_API_KEY = os.environ.get('NVIDIA_API_KEY', '')
SD3_URL = 'https://ai.api.nvidia.com/v1/genai/stabilityai/stable-diffusion-3-medium'
NIM_URL = 'https://integrate.api.nvidia.com/v1/infer'

MODELS = {
    'sd3': 'stable-diffusion-3-medium',
    'flux-schnell': 'black-forest-labs/flux_1-schnell',
}

DEFAULT_OUTPUT = pathlib.Path.home() / '.openclaw' / 'workspace' / 'images'


def generate_sd3(prompt: str, seed: int) -> bytes:
    """Generate image using Stable Diffusion 3 Medium."""
    headers = {
        'Authorization': f'Bearer {NVIDIA_API_KEY}',
        'Accept': 'application/json',
    }
    payload = {
        'prompt': prompt,
        'seed': seed,
    }
    response = requests.post(SD3_URL, headers=headers, json=payload, timeout=120)
    response.raise_for_status()
    data = response.json()
    
    img_data = data.get('image', '')
    if not img_data:
        raise RuntimeError(f'No image in response: {data}')
    
    if ',' in img_data:
        img_data = img_data.split(',')[1]
    
    return base64.b64decode(img_data)


def generate_nim(model_id: str, prompt: str, width: int, height: int, steps: int, seed: int) -> bytes:
    """Generate image using old NIM endpoint (flux)."""
    payload = {
        'model': model_id,
        'prompt': prompt,
        'width': width,
        'height': height,
        'num_inference_steps': steps,
        'seed': seed,
        'guidance_scale': 3.5,
    }
    
    headers = {
        'Authorization': f'Bearer {NVIDIA_API_KEY}',
        'Content-Type': 'application/json',
    }
    
    response = requests.post(NIM_URL, headers=headers, json=payload, timeout=120)
    response.raise_for_status()
    data = response.json()
    
    artifacts = data.get('artifacts') or []
    if not artifacts:
        raise RuntimeError(f'No image in response: {data}')
    
    img_b64 = artifacts[0].get('base64', '')
    return base64.b64decode(img_b64)


def generate(prompt: str, model: str, width: int, height: int,
             steps: int, seed: int, output: pathlib.Path) -> pathlib.Path:
    if not NVIDIA_API_KEY or NVIDIA_API_KEY == 'nvapi-REPLACE_ME_WHEN_READY':
        print('[ERROR] NVIDIA_API_KEY not set. Add it to ~/.openclaw/.env', file=sys.stderr)
        sys.exit(1)

    # Default to SD3
    if model == 'flux-dev' or model == 'sd3':
        model = 'sd3'

    try:
        if model == 'sd3':
            img_bytes = generate_sd3(prompt, seed)
            model_used = 'sd3'
        else:
            model_id = MODELS.get(model, MODELS['flux-schnell'])
            img_bytes = generate_nim(model_id, prompt, width, height, steps, seed)
            model_used = model
    except Exception as e:
        print(f'[ERROR] Generation failed: {e}', file=sys.stderr)
        sys.exit(1)

    # Save
    output = pathlib.Path(args.output) if 'args' in dir() and args.output else output
    if str(output).endswith('.png') or str(output).endswith('.jpg'):
        filename = output
        filename.parent.mkdir(parents=True, exist_ok=True)
    else:
        output.mkdir(parents=True, exist_ok=True)
        ts = int(time.time())
        filename = output / f'nvidia-{model_used}-{ts}.png'
    
    filename.write_bytes(img_bytes)
    print(f'[OK] Image saved: {filename}')
    return filename


def main():
    parser = argparse.ArgumentParser(description='NVIDIA NIM Image Generation')
    parser.add_argument('--prompt',  required=True, help='Image generation prompt')
    parser.add_argument('--model',   default='sd3',
                        choices=list(MODELS), 
                        help='Model to use (default: sd3)')
    parser.add_argument('--output',  default=str(DEFAULT_OUTPUT),
                        help='Output file or directory')
    parser.add_argument('--width',   type=int, default=1024)
    parser.add_argument('--height',  type=int, default=1024)
    parser.add_argument('--steps',   type=int, default=50)
    parser.add_argument('--seed',    type=int, default=0)
    global args
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
