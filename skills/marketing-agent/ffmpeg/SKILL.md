---
name: ffmpeg
description: >
  Audio and video processing with ffmpeg. Use this skill for any format
  conversion, clipping, trimming, splitting, merging, or media inspection task.
---

# SKILL: FFmpeg Media Processing

## Inspect
```bash
ffprobe -v quiet -print_format json -show_format -show_streams input.mp4 | python3 -m json.tool
```

## Extract audio from video
```bash
ffmpeg -i video.mp4 -vn -acodec libmp3lame -q:a 4 audio.mp3          # mp3
ffmpeg -i video.mp4 -vn -acodec pcm_s16le -ar 16000 audio.wav         # wav 16kHz (best for Whisper)
```

## Convert / trim
```bash
ffmpeg -i input.m4a output.mp3
ffmpeg -i input.mp3 -ss 00:01:30 -to 00:04:00 -c copy clip.mp3        # trim 1:30–4:00
ffmpeg -i input.mp3 -t 600 -c copy first10min.mp3                     # first 10 min
```

## Split into chunks
```bash
ffmpeg -i long.mp3 -f segment -segment_time 600 -c copy chunks/chunk%03d.mp3
```

## Merge
```bash
printf "file '%s'\n" chunk*.mp3 > concat_list.txt
ffmpeg -f concat -safe 0 -i concat_list.txt -c copy merged.mp3
```

## Rules
- Use -v quiet or -loglevel error in scripts to suppress progress output
- Prefer -c copy when format is already correct — avoids re-encode loss
- Use -ss before -i for fast seek, after -i for exact seek
- Never output to same file as input — ffmpeg will truncate the source
