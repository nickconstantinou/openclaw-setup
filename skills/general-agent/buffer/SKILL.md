# Buffer GraphQL API Skill

## Description
Manage social media posting via Buffer's GraphQL API. Works with Free plan.

## API Reference
**Endpoint:** `https://api.buffer.com`  
**Auth:** Bearer token

---

## Free Plan Limits

| Feature | Free |
|---------|------|
| Channels | 3 max |
| Scheduled posts | 10 per channel |
| Ideas | 100 |
| Users | 1 |

---

## Commands

```bash
# Account & Status
node buffer.js account         # Account info + plan limits
node buffer.js limits          # Check quota usage
node buffer.js status          # Quick status

# Channels
node buffer.js channels        # List connected channels
node buffer.js channel [id]   # Channel details

# Posts & Ideas
node buffer.js posts [id] [n]          # List posts
node buffer.js post "text" [title]    # Create idea (100 max)
node buffer.js create [id] "text"     # Create post (10/day limit)
node buffer.js delete [post_id]       # Delete post
```

---

## Workflow (Free Plan)

1. **Add channels** in Buffer app (max 3)
2. **Create ideas** - drafts for review (100 max)
3. **Upgrade** to post more than 10/day

---

## Free vs Paid

| Feature | Free | Essentials ($5/mo) |
|---------|------|------------------|
| Channels | 3 | 1 (+ more) |
| Posts/day | 10/channel | Unlimited |
| Ideas | 100 | Unlimited |
| Analytics | Basic | Advanced |

---

## Environment
```
BUFFER_API_KEY=your_api_key
```

**Get key:** https://publish.buffer.com/settings/api

---

## Examples

```bash
# Check status
node buffer.js status

# Create idea
node buffer.js post "Exciting book launch news!" "Announcement"

# Create post (respects 10/day limit)
node buffer.js create abc123 "Check out my new book"
```

---

## Notes
- Free plan: 10 scheduled posts per channel
- Ideas are drafts - review in Buffer app before publishing
- Upgrade to Essentials for unlimited posts
