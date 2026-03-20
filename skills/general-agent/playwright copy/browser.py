#!/usr/bin/env python3
"""
Playwright Browser Wrapper
Simple high-level API for browser automation
"""
import os
import sys
from pathlib import Path
from typing import Optional, List, Dict

try:
    from playwright.sync_api import sync_playwright, Page, Browser, BrowserContext
except ImportError:
    print("Playwright not installed. Run: pip install playwright && playwright install chromium")
    sys.exit(1)


class PlaywrightBrowser:
    """Simple Playwright wrapper for browser automation"""
    
    def __init__(self, browser_type: str = "chromium", headless: bool = True):
        self.browser_type = browser_type
        self.headless = headless
        self.playwright = None
        self.browser: Optional[Browser] = None
        self.context: Optional[BrowserContext] = None
        self.page: Optional[Page] = None
        self.screenshots_dir = Path.home() / "openclaw-screenshots"
        self.screenshots_dir.mkdir(exist_ok=True)
    
    def __enter__(self):
        self.start()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
    
    def start(self):
        """Start the browser"""
        self.playwright = sync_playwright().start()
        
        # Use system Chrome if available
        chrome_path = "/usr/bin/google-chrome-stable"
        
        if self.browser_type == "chromium":
            self.browser = self.playwright.chromium.launch(
                headless=self.headless,
                executable_path=chrome_path if os.path.exists(chrome_path) else None,
                args=['--no-sandbox', '--disable-setuid-sandbox']
            )
        elif self.browser_type == "firefox":
            self.browser = self.playwright.firefox.launch(headless=self.headless)
        elif self.browser_type == "webkit":
            self.browser = self.playwright.webkit.launch(headless=self.headless)
        else:
            raise ValueError(f"Unknown browser: {self.browser_type}")
        
        self.context = self.browser.new_context()
        self.page = self.context.new_page()
        return self
    
    def close(self):
        """Close the browser"""
        if self.page:
            self.page.close()
        if self.context:
            self.context.close()
        if self.browser:
            self.browser.close()
        if self.playwright:
            self.playwright.stop()
    
    # === Navigation ===
    
    def goto(self, url: str, wait_until: str = "load"):
        """Navigate to URL"""
        self.page.goto(url, wait_until=wait_until)
        return self
    
    def reload(self):
        """Reload the page"""
        self.page.reload()
        return self
    
    def back(self):
        """Go back in history"""
        self.page.go_back()
        return self
    
    def forward(self):
        """Go forward in history"""
        self.page.go_forward()
        return self
    
    # === Actions ===
    
    def click(self, selector: str, **kwargs):
        """Click an element"""
        self.page.click(selector, **kwargs)
        return self
    
    def type(self, selector: str, text: str, delay: int = 0):
        """Type text into an element"""
        self.page.type(selector, text, delay=delay)
        return self
    
    def fill(self, selector: str, value: str):
        """Fill an input field"""
        self.page.fill(selector, value)
        return self
    
    def press(self, selector: str, key: str):
        """Press a key"""
        self.page.press(selector, key)
        return self
    
    def hover(self, selector: str):
        """Hover over an element"""
        self.page.hover(selector)
        return self
    
    def scroll_down(self, pixels: int = 500):
        """Scroll down"""
        self.page.evaluate(f"window.scrollBy(0, {pixels})")
        return self
    
    def scroll_to_bottom(self):
        """Scroll to bottom of page"""
        self.page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
        return self
    
    def scroll_to_top(self):
        """Scroll to top of page"""
        self.page.evaluate("window.scrollTo(0, 0)")
        return self
    
    # === Content Extraction ===
    
    @property
    def url(self) -> str:
        """Get current URL"""
        return self.page.url
    
    @property
    def title(self) -> str:
        """Get page title"""
        return self.page.title()
    
    def content(self) -> str:
        """Get full HTML content"""
        return self.page.content()
    
    def text(self, selector: str) -> str:
        """Get text content of element"""
        return self.page.text_content(selector) or ""
    
    def attribute(self, selector: str, attr: str) -> str:
        """Get element attribute"""
        return self.page.get_attribute(selector, attr) or ""
    
    def inner_html(self, selector: str) -> str:
        """Get inner HTML of element"""
        return self.page.inner_html(selector)
    
    def inner_text(self, selector: str) -> str:
        """Get inner text of element"""
        return self.page.inner_text(selector)
    
    # === Screenshot & PDF ===
    
    def screenshot(self, name: str = None, full_page: bool = False) -> str:
        """Take a screenshot"""
        if name is None:
            from datetime import datetime
            name = f"screenshot_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        
        path = self.screenshots_dir / name
        self.page.screenshot(path=str(path), full_page=full_page)
        return str(path)
    
    def pdf(self, path: str = None, format: str = "A4") -> bytes:
        """Generate PDF of page"""
        if path is None:
            from datetime import datetime
            path = str(self.screenshots_dir / f"page_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf")
        
        self.page.pdf(path=path, format=format)
        return path
    
    # === Waiting ===
    
    def wait_for_selector(self, selector: str, timeout: int = 30000):
        """Wait for element to appear"""
        self.page.wait_for_selector(selector, timeout=timeout)
        return self
    
    def wait_for_load_state(self, state: str = "load"):
        """Wait for page to load"""
        self.page.wait_for_load_state(state)
        return self
    
    def wait_for_url(self, url: str):
        """Wait for URL to match pattern"""
        self.page.wait_for_url(url)
        return self
    
    def wait_for_function(self, js_function: str):
        """Wait for JavaScript function to return true"""
        self.page.wait_for_function(js_function)
        return self
    
    # === Advanced ===
    
    def evaluate(self, js: str):
        """Execute JavaScript"""
        return self.page.evaluate(js)
    
    def get_links(self) -> List[Dict[str, str]]:
        """Get all links from page"""
        links = self.page.eval_on_selector_all("a[href]", """
            els => els.map(el => ({
                text: el.innerText.trim(),
                href: el.href,
                title: el.title
            }))
        """)
        return links
    
    def get_images(self) -> List[str]:
        """Get all image URLs"""
        images = self.page.eval_on_selector_all("img[src]", "els => els.map(el => el.src)")
        return images
    
    def get_forms(self) -> List[Dict]:
        """Get all forms"""
        forms = self.page.eval_on_selector_all("form", """
            el => ({
                action: el.action,
                method: el.method,
                inputs: Array.from(el.querySelectorAll('input')).map(i => ({
                    name: i.name,
                    type: i.type,
                    value: i.value
                }))
            })
        """)
        return forms
    
    def submit_form(self, selector: str):
        """Submit a form"""
        self.page.dispatch_event(selector, "submit")
        return self
    
    # === Context Management ===
    
    def new_tab(self, url: str = "about:blank"):
        """Open new tab"""
        new_page = self.context.new_page()
        new_page.goto(url)
        return new_page
    
    def switch_tab(self, page_index: int):
        """Switch to tab by index"""
        pages = self.context.pages
        if 0 <= page_index < len(pages):
            self.page = pages[page_index]
        return self


# CLI helper
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Playwright Browser CLI")
    parser.add_argument("url", help="URL to navigate to")
    parser.add_argument("--screenshot", "-s", help="Screenshot output path")
    parser.add_argument("--full", "-f", action="store_true", help="Full page screenshot")
    parser.add_argument("--headless", action="store_true", default=True, help="Run headless")
    parser.add_argument("--browser", "-b", default="chromium", choices=["chromium", "firefox", "webkit"])
    
    args = parser.parse_args()
    
    with PlaywrightBrowser(browser_type=args.browser, headless=args.headless) as browser:
        browser.goto(args.url)
        
        if args.screenshot:
            path = browser.screenshot(args.screenshot, full_page=args.full)
            print(f"Screenshot saved to: {path}")
        else:
            print(f"Title: {browser.title}")
            print(f"URL: {browser.url}")
