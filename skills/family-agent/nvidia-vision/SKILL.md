---
name: nvidia-vision
description: >
  Understand, describe, and answer questions about images using NVIDIA NIM-hosted
  google/gemma-4-31b-it (vision). Use this skill whenever the user sends a photo
  or asks about the contents of an image — what's in it, what it says, what's
  happening, who/what is shown, or any visual question.
metadata: {"openclaw": {"requires": {"env": ["NVIDIA_API_KEY"], "bins": ["python3"]}, "primaryEnv": "NVIDIA_API_KEY", "os": ["linux", "darwin"]}}
---

# SKILL: NVIDIA Image Understanding (Vision)

## When to use this skill

Use this skill when the user:
- Sends a photo and asks what's in it
- Asks you to read or transcribe text visible in an image
- Wants to know what's happening in a picture
- Asks about a chart, diagram, screenshot, or document image
- Sends a photo of food, a place, a person, an object and wants it identified/described
- Asks any question that requires looking at an image

**Do not use** for image generation (use the `nvidia-imagegen` skill instead).

## How to invoke

```bash
# Describe an image (default)
python3 ~/.openclaw/workspace/skills/nvidia-vision/analyse.py \
  --image /path/to/image.jpg

# Ask a specific question about an image
python3 ~/.openclaw/workspace/skills/nvidia-vision/analyse.py \
  --image /path/to/image.jpg \
  --prompt "What text is visible in this image?"

# Read a receipt / document
python3 ~/.openclaw/workspace/skills/nvidia-vision/analyse.py \
  --image /path/to/receipt.jpg \
  --prompt "List every item and price shown on this receipt."

# Identify objects or people
python3 ~/.openclaw/workspace/skills/nvidia-vision/analyse.py \
  --image /path/to/photo.jpg \
  --prompt "What objects are in this photo and where are they positioned?"

# JSON output (for further processing)
python3 ~/.openclaw/workspace/skills/nvidia-vision/analyse.py \
  --image /path/to/image.png \
  --prompt "Describe the image." \
  --json
```

## Handling Telegram/WhatsApp image attachments

When a user sends a photo via Telegram or WhatsApp, the image arrives as a file path
in the message (e.g. `image_path="/tmp/..."` or via `download_attachment`).
Use that path directly as `--image`.

```bash
# After downloading/receiving the image at /tmp/photo.jpg
python3 ~/.openclaw/workspace/skills/nvidia-vision/analyse.py \
  --image /tmp/photo.jpg \
  --prompt "What's in this photo?"
```

## Model

- **Model**: `google/gemma-4-31b-it` via NVIDIA NIM
- **Auth**: `NVIDIA_API_KEY` from environment
- Images are automatically resized to ≤768px on the longest side before sending
- Supports: JPEG, PNG, GIF, WebP

## Example prompts

| Use case | Prompt |
|----------|--------|
| General description | *(default — leave blank)* |
| Read text in image | `"Transcribe all text visible in this image."` |
| Identify food | `"What food is shown? Give an approximate recipe or dish name."` |
| Read a receipt | `"List every line item and price from this receipt."` |
| Describe a chart | `"What does this chart show? Summarise the key data points."` |
| Identify location | `"Where might this photo have been taken? What clues are visible?"` |
| Check a document | `"What type of document is this and what does it say?"` |

## Error handling

- If `NVIDIA_API_KEY` is missing, the script exits with a clear error message
- If the image file doesn't exist or can't be read, Python raises an IOError
- Rate limit: NVIDIA NIM free tier has 40 RPM — space requests if needed
