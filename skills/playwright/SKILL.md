---
name: playwright
description: Browser automation using Playwright - alternative to CDP browser
metadata:
  {
    "openclaw": {
      "emoji": "🎭",
      "requires": { "pip": ["playwright"] }
    }
  }
---

# Playwright Browser Skill

Alternative browser automation using Playwright - more reliable than CDP for complex automation tasks.

## When to use

Use this skill when you need:
- **Reliable automation** - More stable than CDP
- **Form filling** - Fill, submit, handle forms
- **PDF generation** - Export pages as PDF
- **Multi-browser** - Test across Chromium, Firefox, WebKit
- **Network interception** - Capture/modify requests
- **Video recording** - Record browser sessions

## Quick Start

```python
from browser import PlaywrightBrowser

with PlaywrightBrowser() as browser:
    browser.goto("https://example.com")
    browser.screenshot("example.png")
```

## Examples

### Screenshot
```python
with PlaywrightBrowser(headless=True) as browser:
    browser.goto("https://github.com")
    path = browser.screenshot("github.png")
    print(f"Saved to: {path}")
```

### Fill Form
```python
with PlaywrightBrowser() as browser:
    browser.goto("https://example.com/login")
    browser.fill("#username", "myuser")
    browser.fill("#password", "mypass")
    browser.click("#login-button")
```

### Extract Links
```python
with PlaywrightBrowser() as browser:
    browser.goto("https://news.ycombinator.com")
    links = browser.get_links()
    for link in links[:5]:
        print(f"{link['text'][:50]}: {link['href']}")
```

### Generate PDF
```python
with PlaywrightBrowser() as browser:
    browser.goto("https://example.com/article")
    path = browser.pdf("article.pdf")
```

## API Reference

### Initialization

| Method | Args | Description |
|--------|------|-------------|
| `PlaywrightBrowser()` | `browser`, `headless` | Create browser instance |

### Navigation

| Method | Args | Description |
|--------|------|-------------|
| `goto()` | `url` | Navigate to URL |
| `reload()` | - | Reload page |
| `back()` | - | Go back |
| `forward()` | - | Go forward |

### Actions

| Method | Args | Description |
|--------|------|-------------|
| `click()` | `selector` | Click element |
| `type()` | `selector, text` | Type with delay |
| `fill()` | `selector, value` | Fill input field |
| `press()` | `selector, key` | Press key |
| `hover()` | `selector` | Hover element |
| `scroll_down()` | `pixels` | Scroll down |

### Content

| Method | Args | Description |
|--------|------|-------------|
| `title` | property | Get page title |
| `url` | property | Get current URL |
| `content()` | - | Get HTML |
| `text()` | `selector` | Get element text |
| `attribute()` | `selector, attr` | Get attribute |
| `get_links()` | - | Get all links |
| `get_images()` | - | Get all image URLs |

### Screenshot & PDF

| Method | Args | Description |
|--------|------|-------------|
| `screenshot()` | `name, full_page` | Save screenshot |
| `pdf()` | `path, format` | Generate PDF |

### Waiting

| Method | Args | Description |
|--------|------|-------------|
| `wait_for_selector()` | `selector, timeout` | Wait for element |
| `wait_for_load_state()` | `state` | Wait for load state |
| `wait_for_url()` | `url` | Wait for URL |

## Installation

```bash
pip install playwright
playwright install chromium
```

## Browser Options

```python
# Different browsers
browser = PlaywrightBrowser("chromium")  # Default
browser = PlaywrightBrowser("firefox")
browser = PlaywrightBrowser("webkit")

# Headed mode (visible browser)
browser = PlaywrightBrowser(headless=False)
```
