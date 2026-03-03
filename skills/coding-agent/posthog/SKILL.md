---
name: posthog
description: Manage PostHog analytics, A/B tests, and feature flags
metadata:
  {
    "openclaw": {
      "emoji": "📊",
      "requires": { "env": ["POSTHOG_PROJECT_ID", "POSTHOG_PERSONAL_API_KEY"] }
    }
  }
---

# PostHog Skill

Manage PostHog analytics, A/B tests, and feature flags.

## Credentials

Credentials are stored in `~/.openclaw/.env`:

```
POSTHOG_PROJECT_ID=316789
POSTHOG_PERSONAL_API_KEY=phx_...
```

## Usage

### Set credentials (if not already set):

```bash
source ~/.openclaw/.env
export POSTHOG_API_KEY="$POSTHOG_PERSONAL_API_KEY"
```

### Check if configured:

```bash
source ~/.openclaw/.env
echo $POSTHOG_PROJECT_ID
```

### Common tasks:
- List A/B tests
- Check feature flags
- View analytics events
