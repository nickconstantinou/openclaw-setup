# post-bridge Skill

_Reference for using Post Bridge for social media management._

---

## Setup Status Check

Before any social media task, confirm the API key is active:

```bash
curl -sf -H "Authorization: Bearer $POST_BRIDGE_API_KEY" \
  https://api.post-bridge.com/v1/account \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status','unknown'))"
```

If this returns an error or the key is the placeholder, direct the user to https://www.post-bridge.com/dashboard to get their API key, then update `POST_BRIDGE_API_KEY` in `~/.openclaw/.env`.

---

## Platforms Supported

- TikTok
- Instagram
- YouTube
- X (Twitter)
- LinkedIn
- Facebook
- Threads
- Bluesky
- Pinterest

---

## Posting

The agent instructs the Post Bridge skill in natural language — the skill handles the API calls.

### Examples of What to Say

- "Post this to all platforms."
- "Schedule this reel for tomorrow at 9am on Instagram, TikTok, and YouTube."
- "Post to X and LinkedIn only."
- "Create a draft for review before posting."

---

## Underlying API Patterns

### Post Immediately to Multiple Platforms

```bash
curl -X POST https://api.post-bridge.com/v1/posts \
  -H "Authorization: Bearer $POST_BRIDGE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Your caption here",
    "platforms": ["instagram","tiktok","youtube","x","linkedin"],
    "media_url": "https://example.com/video.mp4"
  }'
```

### Schedule for Later

```bash
curl -X POST https://api.post-bridge.com/v1/posts \
  -H "Authorization: Bearer $POST_BRIDGE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Caption",
    "platforms": ["instagram","tiktok"],
    "scheduled_at": "2026-03-01T09:00:00Z"
  }'
```

### Create Draft (Review Before Posting)

```bash
curl -X POST https://api.post-bridge.com/v1/drafts \
  -H "Authorization: Bearer $POST_BRIDGE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"content": "Caption", "platforms": ["x","linkedin"]}'
```

---

## Analytics

### Performance for a Specific Post

```bash
curl -sf -H "Authorization: Bearer $POST_BRIDGE_API_KEY" \
  https://api.post-bridge.com/v1/posts/<post_id>/analytics \
  | python3 -m json.tool
```

### Recent Posts List

```bash
curl -sf -H "Authorization: Bearer $POST_BRIDGE_API_KEY" \
  "https://api.post-bridge.com/v1/posts?limit=10" \
  | python3 -m json.tool
```

---

## Scheduled Posts

### List Upcoming Scheduled Posts

```bash
curl -sf -H "Authorization: Bearer $POST_BRIDGE_API_KEY" \
  "https://api.post-bridge.com/v1/posts?status=scheduled" \
  | python3 -m json.tool
```

### Cancel a Scheduled Post

```bash
curl -X DELETE -H "Authorization: Bearer $POST_BRIDGE_API_KEY" \
  https://api.post-bridge.com/v1/posts/<post_id>
```

---

## Rules

| ❌ Never Do | ✅ Instead |
|------------|-----------|
| Post to all platforms without confirmation | Ask user first |
| Skip draft mode for new content types | Use draft mode until user confirms |
| Use local time for scheduling | Always use UTC (ISO 8601: `2026-03-01T09:00:00Z`) |
| Proceed if API key is placeholder | Stop and ask user to set up account |

---

## Quick-Reference

```bash
# Check API status
curl -sf -H "Authorization: Bearer $POST_BRIDGE_API_KEY" https://api.post-bridge.com/v1/account

# Post to platforms
curl -X POST https://api.post-bridge.com/v1/posts -H "Authorization: Bearer $POST_BRIDGE_API_KEY" -H "Content-Type: application/json" -d '{"content":"msg","platforms":["instagram","x"]}'

# Schedule post
curl -X POST https://api.post-bridge.com/v1/posts -H "Authorization: Bearer $POST_BRIDGE_API_KEY" -H "Content-Type: application/json" -d '{"content":"msg","platforms":["instagram"],"scheduled_at":"2026-03-01T09:00:00Z"}'

# Create draft
curl -X POST https://api.post-bridge.com/v1/drafts -H "Authorization: Bearer $POST_BRIDGE_API_KEY" -H "Content-Type: application/json" -d '{"content":"msg","platforms":["x","linkedin"]}'

# Get analytics
curl -sf -H "Authorization: Bearer $POST_BRIDGE_API_KEY" https://api.post-bridge.com/v1/posts/<id>/analytics

# List scheduled
curl -sf -H "Authorization: Bearer $POST_BRIDGE_API_KEY" "https://api.post-bridge.com/v1/posts?status=scheduled"
```

---

_Remember: Always use draft mode first, get user confirmation before posting to all platforms, and use UTC timestamps._
