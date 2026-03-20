---
name: web-qa
description: Web UI QA - verify deployed pages work correctly with visual screenshots
metadata:
  {
    "openclaw":
      {
        "emoji": "🔍",
        "requires": { "bins": ["curl"] },
      },
  }
---

# Web QA Skill

Always verify deployed web features work correctly. Use this skill after making changes to any website.

## CRITICAL: Never Just Check HTTP 200

A page returning 200 does NOT mean it works! You MUST verify:
1. HTML structure is complete (<head>, <body>, styles)
2. Visual rendering via canvas screenshot
3. External resources load (CSS, fonts, images)

## Checklist

### 1. HTML Structure Checks (MANDATORY)
```bash
# Check page has proper HTML structure
curl -s "https://example.com" | head -20

# Must contain these elements:
# - <!DOCTYPE html> or <html
# - <head> (not just content)
# - <body>
# - CSS (inline or linked)
# - <footer> or <header>

# Check for broken HTML (symptoms of rebuild errors)
curl -s "https://example.com" | grep -E "^<html|<head|<body|<style" | wc -l
```

### 2. Visual Verification (MANDATORY)
```bash
# Take a screenshot of the page - THIS IS MANDATORY
canvas(action=present, url="https://example.com", width=1280, height=800)

# Check for visual anomalies:
# - Text overflow
# - Missing images/icons
# - Broken layouts (no styles = unstyled text)
# - Color/contrast issues
```

### 3. Resource Loading
```bash
# Check CSS loads (inline or external)
curl -s "https://example.com" | grep -iE "style|<css"

# Check fonts load
curl -s "https://example.com" | grep -iE "font|googleapis"

# Check for unstyled content (symptom of missing CSS)
curl -s "https://example.com" | grep -E "^<a href=.*class=\"post\"" | head -3
```

### 4. Basic HTTP Check
```bash
# Just for reference - NOT ENOUGH ON ITS OWN
curl -s -o /dev/null -w "%{http_code}" "https://example.com"
```

## QA Process (Follow This Order)

1. **Fetch HTML** - `curl -s "URL" | head -30`
2. **Verify structure** - Check for `<html>`, `<head>`, `<body>`, styles
3. **Canvas screenshot** - MANDATORY visual check
4. **Check resources** - CSS, fonts, images load
5. **Test key pages** - Homepage, main features

## Red Flags (Stop and Fix)

- ❌ Page starts with `<a href=` (missing HTML wrapper)
- ❌ No `<head>` in first 50 lines
- ❌ No `<style>` or CSS link
- ❌ Screenshot shows unstyled/raw HTML
- ❌ Missing logo/header visual
- ❌ Text running together (no CSS)

## Common Issues

| Issue | Check |
|-------|-------|
| Nav missing | Check HTML has `<nav>` tag |
| Styles broken | Verify CSS CDN or inline styles |
| Links dead | Test each link returns 200 |
| Visual broken | Take screenshot, check canvas output |

## Example QA Output

```
=== Website QA ===
1. HTML Structure:
   - Has DOCTYPE: YES
   - Has <head>: YES  
   - Has styles: YES
2. Visual (canvas):
   - Screenshot captured: YES
   - Looks styled: YES
3. Resources:
   - CSS loads: YES
   - Fonts: YES
```

## Always Remember

- **HTTP 200 =/= Working** - Must verify structure
- **Screenshot EVERY page** - Visual proof matters
- **Check first 30 lines** - Catch rebuild errors early
- **Verify styles** - Look for <style> or .css links
