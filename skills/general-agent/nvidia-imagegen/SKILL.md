---
name: nvidia-imagegen
description: >
  Generate images using NVIDIA NIM-hosted FLUX.1-dev (primary, high quality)
  or Consistory (fallback, strong style/character consistency across images).
  Use this skill whenever the user requests image generation, illustration,
  artwork, visual concepts, or wants to see something created.
metadata: {"openclaw": {"requires": {"env": ["NVIDIA_API_KEY"], "bins": ["python3"]}, "primaryEnv": "NVIDIA_API_KEY", "os": ["linux", "darwin"]}}
---

# SKILL: NVIDIA Image Generation

## When to use this skill

Use this skill when the user asks to:
- Generate, create, draw, or illustrate any image
- Produce artwork, concept art, product mockups, or visual content
- Create images with consistent style across multiple generations (use Consistory)
- Visualize something described in words

**Do not use** for image analysis/understanding (use the `image` tool instead).

## How to invoke

```bash
python3 ~/.openclaw/workspace/skills/nvidia-imagegen/generate.py \
  --prompt "your detailed prompt here" \
  --output ~/.openclaw/workspace/images/output.png \
  [--model flux-dev|flux-schnell|consistory] \
  [--width 1024] \
  [--height 1024] \
  [--steps 30] \
  [--seed 42]
```

## Model selection guide

| Model | Flag | Best for |
|-------|------|----------|
| FLUX.1-dev | `--model flux-dev` | **Default.** Highest quality, photorealistic, complex scenes |
| FLUX.1-schnell | `--model flux-schnell` | Fast iteration, 4-step generation, good for drafts |
| Consistory | `--model consistory` | Multiple images with same character/object identity across scenes |

## Prompt writing guidelines

- **Be specific and detailed**: describe style, lighting, composition, color palette
- **For photorealism**: add "photorealistic, DSLR, natural lighting, sharp detail"
- **For illustration**: specify art style ("watercolor", "flat design", "line art", "oil painting")
- **For consistency** (Consistory): use a "subject token" like `{char}` in your prompt
  - First image defines the character/subject
  - Subsequent images reuse the same subject token

## Output

- Images are saved to `~/.openclaw/workspace/images/` by default
- The script prints the saved path on success
- Use the `read` tool or file path to share the image back

## Error handling

- If FLUX.1-dev fails (e.g., quota or model unavailable), the script auto-falls back to FLUX.1-schnell
- Pass `--model consistory` explicitly for multi-image character consistency
- Rate limit: NVIDIA NIM free tier has 40 RPM — space requests if needed

## Example prompts

```bash
# Photorealistic landscape
python3 ~/.openclaw/workspace/skills/nvidia-imagegen/generate.py \
  --prompt "A misty Scottish highland at dawn, rolling green hills, ancient stone ruins, dramatic clouds, golden hour light, photorealistic, 8K"

# UI mockup
python3 ~/.openclaw/workspace/skills/nvidia-imagegen/generate.py \
  --prompt "Minimalist mobile app dashboard UI, dark mode, fintech, glassmorphism, clean typography, Figma screenshot style"

# Consistent character across scenes (Consistory)
python3 ~/.openclaw/workspace/skills/nvidia-imagegen/generate.py \
  --model consistory \
  --prompt "A red fox {char} sitting in a cozy library, reading a book"
```
