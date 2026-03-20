---
name: "lightpanda"
description: "Fast headless browser automation via LightPanda CDP server — 10x faster than Chrome with 10x less memory."
metadata:
  {
    "openclaw": {
      "emoji": "🐼",
      "requires": { "tools": ["exec", "read", "write"] }
    }
  }
---

# LightPanda Browser Skill

Use LightPanda as a CDP-compatible headless browser for web scraping, automation, and testing. It is significantly faster and lighter than Chromium while remaining fully compatible with Playwright's CDP API.

## Preconditions

- LightPanda must be installed: `~/.openclaw/tools/lightpanda/node_modules/@lightpanda/browser/`
- If missing, re-run the OpenClaw install script to trigger `install_lightpanda`.
- `playwright` Python package must be available: `pip install playwright`

## Quick Start

### JavaScript (direct API)

```javascript
import { lightpanda } from '@lightpanda/browser';

const proc = await lightpanda.serve({ host: '127.0.0.1', port: 9222 });
// ... your automation ...
proc.kill();
```

### Python (via browser.py wrapper)

```python
from browser import LightPandaBrowser

with LightPandaBrowser() as browser:
    browser.goto('https://example.com')
    print(browser.title)
    browser.screenshot('example.png')
```

### Playwright CDP connection

```javascript
import { chromium } from 'playwright';
import { lightpanda } from '@lightpanda/browser';

const proc = await lightpanda.serve({ host: '127.0.0.1', port: 9222 });
const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
const page = await browser.newPage();
await page.goto('https://example.com');
const title = await page.title();
await browser.close();
proc.kill();
```

## Configuration

| Variable          | Default     | Description                         |
| ----------------- | ----------- | ----------------------------------- |
| LIGHTPANDA_HOST   | 127.0.0.1   | Host the CDP server binds to        |
| LIGHTPANDA_PORT   | 9222        | Port for CDP connections            |

Override via environment or `.env`:

```bash
LIGHTPANDA_HOST=127.0.0.1
LIGHTPANDA_PORT=9222
```

## CLI Usage

```bash
python3 browser.py https://example.com --screenshot /tmp/shot.png
python3 browser.py https://example.com  # prints title and URL
```

## Common Failure Modes

- **Binary not found**: Re-run OpenClaw install or check `~/.openclaw/tools/lightpanda/node_modules/@lightpanda/browser/bin/`
- **Port already in use**: Change `LIGHTPANDA_PORT` in `.env` and re-deploy
- **CDP connection refused**: LightPanda needs ~500ms to start; the wrapper retries automatically
- **JS not supported**: LightPanda is fast but may not support all JS features — fall back to Playwright/Chromium for complex SPAs

## Cleanup

Always kill the LightPanda server process when done:

```python
# Context manager handles cleanup automatically
with LightPandaBrowser() as browser:
    ...

# Manual cleanup
browser = LightPandaBrowser()
browser.start()
# ...
browser.close()  # kills server + disconnects Playwright
```
