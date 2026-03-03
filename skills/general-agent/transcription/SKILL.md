---
name: transcription
description: >
  Audio and video transcription using faster-whisper, yt-dlp, and ffmpeg.
  Use this skill for any task involving speech-to-text, podcast transcription,
  meeting notes, or audio extraction from video files.
---

# SKILL: Transcription

Tools: faster-whisper (speech-to-text), yt-dlp (download), ffmpeg (audio processing).

## Download audio
```bash
yt-dlp -x --audio-format mp3 -o "/tmp/%(title)s.%(ext)s" "<URL>"
# Extract audio from a local video file:
ffmpeg -i video.mp4 -vn -acodec libmp3lame -q:a 4 audio.mp3
```

## Transcribe
```python
from faster_whisper import WhisperModel
model = WhisperModel("base", device="cpu", compute_type="int8")
segments, info = model.transcribe("audio.mp3", beam_size=5)
transcript = "\n".join(seg.text.strip() for seg in segments)
```

## Full pipeline (URL → text file)
```python
import subprocess, os
from faster_whisper import WhisperModel
url = "https://youtube.com/watch?v=..."
audio = "/tmp/audio.mp3"
subprocess.run(["yt-dlp", "-x", "--audio-format", "mp3", "-o", audio, url], check=True)
model = WhisperModel("base", device="cpu", compute_type="int8")
segments, info = model.transcribe(audio, beam_size=5)
transcript = "\n".join(seg.text.strip() for seg in segments)
with open("/tmp/transcript.txt", "w") as f:
    f.write(transcript)
os.remove(audio)
```

## Model sizes
| Model  | Size  | Use for |
|--------|-------|---------|
| tiny   | 75MB  | Fast drafts |
| base   | 150MB | General ← default |
| small  | 500MB | Accents / jargon |

## Rules
- device="cpu", compute_type="int8" always — no GPU on this server
- Delete audio files after transcription — they are large
- For files >30 min: chunk first with ffmpeg -f segment -segment_time 600
- Never pass video directly to WhisperModel — extract audio first
- Models download to ~/.cache/huggingface/ on first use
