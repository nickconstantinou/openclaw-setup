---
name: content-research
description: >
  Full research pipeline from URL to published content. Use this skill for
  blog posts, video summaries, newsletters, or research documents that start
  from audio/video source material.
---

# SKILL: Content Research Pipeline

Full pipeline: URL → download → transcribe → summarise → draft → vault.

## Step 1: Download audio
```bash
yt-dlp -x --audio-format mp3 -o "/tmp/research_audio.mp3" "<URL>"
```

## Step 2: Transcribe
```python
from faster_whisper import WhisperModel
model = WhisperModel("base", device="cpu", compute_type="int8")
segments, info = model.transcribe("/tmp/research_audio.mp3", beam_size=5)
transcript = "\n".join(seg.text.strip() for seg in segments)
with open("/tmp/transcript.txt", "w") as f:
    f.write(transcript)
import os; os.remove("/tmp/research_audio.mp3")
```

## Step 3: Summarise
Ask the agent:
```
Summarise this transcript into:
1. One-paragraph TL;DR
2. 5 key points (bullet list)
3. Interesting quotes worth highlighting
4. Suggested blog post angle

[paste transcript]
```

## Step 4: Blog post prompt
```
Write a blog post for a technical founder audience.
Tone: direct, practical, no filler.
Source: [summary or transcript]

Include:
- Headline (5-8 words, benefit-driven)
- Subheadline (one sentence)
- Introduction (2 paragraphs)
- 3 main sections with subheadings
- Conclusion with CTA
- Meta description (155 chars max)
Format as markdown.
```

## Step 5: Save to vault
```bash
pandoc /tmp/draft.md -o "$HOME/obsidian/vault/Behind The Scenes/Post - $(date +%Y-%m-%d) - Title.docx"
# Or save as markdown note directly:
cp /tmp/draft.md "$HOME/obsidian/vault/Behind The Scenes/Post - $(date +%Y-%m-%d) - Title.md"
```

## Rules
- Always transcribe — never use YouTube auto-captions (Whisper is dramatically more accurate)
- Always delete audio files after transcription
- Chunk audio >30 min before Whisper: ffmpeg -i long.mp3 -f segment -segment_time 600 chunk%03d.mp3
- Cap transcript input at ~8000 chars per summarise call
- Save finished research to vault, not /tmp
