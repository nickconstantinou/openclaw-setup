#!/usr/bin/env python3
"""
LightPanda Browser Wrapper
Starts a LightPanda CDP server and connects via Playwright's chromium.connectOverCDP().
"""
import os
import sys
import subprocess
import time
from pathlib import Path
from typing import Optional, List, Dict

try:
    from playwright.sync_api import sync_playwright, Page, Browser, BrowserContext
except ImportError:
    print("Playwright not installed. Run: pip install playwright")
    sys.exit(1)


_DEFAULT_HOST = os.environ.get("LIGHTPANDA_HOST", "127.0.0.1")
_DEFAULT_PORT = int(os.environ.get("LIGHTPANDA_PORT", "9222"))
_INSTALL_DIR = Path.home() / ".openclaw" / "tools" / "lightpanda"


def _find_lightpanda_bin() -> Optional[Path]:
    """Locate the lightpanda binary.

    Search order:
    1. LIGHTPANDA_EXECUTABLE_PATH env var (explicit override)
    2. ~/.cache/lightpanda-node/lightpanda  (npm postinstall download location)
    3. ~/.openclaw/tools/lightpanda node_modules bin dir (our custom install)
    """
    env_path = os.environ.get("LIGHTPANDA_EXECUTABLE_PATH")
    if env_path:
        p = Path(env_path)
        if p.is_file():
            return p

    cache_bin = Path.home() / ".cache" / "lightpanda-node" / "lightpanda"
    if cache_bin.is_file():
        return cache_bin

    # Fallback: scan our npm prefix install dir
    bin_dir = _INSTALL_DIR / "node_modules" / "@lightpanda" / "browser" / "bin"
    for candidate in bin_dir.glob("lightpanda*"):
        if candidate.is_file():
            return candidate

    return None


class LightPandaBrowser:
    """Playwright wrapper that drives LightPanda as its CDP backend."""

    def __init__(self, host: str = _DEFAULT_HOST, port: int = _DEFAULT_PORT):
        self.host = host
        self.port = port
        self._proc: Optional[subprocess.Popen] = None
        self._playwright = None
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
        """Start LightPanda server and connect Playwright via CDP."""
        binary = _find_lightpanda_bin()
        if binary is None:
            raise RuntimeError(
                f"LightPanda binary not found. Checked: ~/.cache/lightpanda-node/, {_INSTALL_DIR}/node_modules/@lightpanda/browser/bin/, LIGHTPANDA_EXECUTABLE_PATH. "
                "Re-run the OpenClaw install script to install it."
            )

        node_bin = _INSTALL_DIR / "node_modules" / ".bin"
        env = {**os.environ, "PATH": f"{node_bin}:{os.environ.get('PATH', '')}"}

        self._proc = subprocess.Popen(
            [str(binary), "--cdp-host", self.host, "--cdp-port", str(self.port)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=env,
        )

        # Wait for the CDP endpoint to become available
        cdp_url = f"http://{self.host}:{self.port}"
        self._wait_for_cdp(cdp_url)

        self._playwright = sync_playwright().start()
        self.browser = self._playwright.chromium.connect_over_cdp(cdp_url)
        self.context = self.browser.new_context()
        self.page = self.context.new_page()
        return self

    def _wait_for_cdp(self, url: str, attempts: int = 10, delay: float = 0.5):
        """Poll the CDP endpoint until it responds."""
        import urllib.request
        import urllib.error

        for i in range(attempts):
            try:
                urllib.request.urlopen(f"{url}/json/version", timeout=2)
                return
            except (urllib.error.URLError, OSError):
                if i < attempts - 1:
                    time.sleep(delay)
        raise RuntimeError(f"LightPanda CDP endpoint at {url} did not respond after {attempts} attempts.")

    def close(self):
        """Close the Playwright connection and terminate the LightPanda server."""
        if self.page:
            self.page.close()
        if self.context:
            self.context.close()
        if self.browser:
            self.browser.close()
        if self._playwright:
            self._playwright.stop()
        if self._proc and self._proc.poll() is None:
            self._proc.terminate()
            try:
                self._proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self._proc.kill()

    # === Navigation ===

    def goto(self, url: str, wait_until: str = "load"):
        self.page.goto(url, wait_until=wait_until)
        return self

    def reload(self):
        self.page.reload()
        return self

    def back(self):
        self.page.go_back()
        return self

    def forward(self):
        self.page.go_forward()
        return self

    # === Actions ===

    def click(self, selector: str, **kwargs):
        self.page.click(selector, **kwargs)
        return self

    def fill(self, selector: str, value: str):
        self.page.fill(selector, value)
        return self

    def type(self, selector: str, text: str, delay: int = 0):
        self.page.type(selector, text, delay=delay)
        return self

    def press(self, selector: str, key: str):
        self.page.press(selector, key)
        return self

    def hover(self, selector: str):
        self.page.hover(selector)
        return self

    def scroll_down(self, pixels: int = 500):
        self.page.evaluate(f"window.scrollBy(0, {pixels})")
        return self

    def scroll_to_bottom(self):
        self.page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
        return self

    # === Content Extraction ===

    @property
    def url(self) -> str:
        return self.page.url

    @property
    def title(self) -> str:
        return self.page.title()

    def content(self) -> str:
        return self.page.content()

    def text(self, selector: str) -> str:
        return self.page.text_content(selector) or ""

    def attribute(self, selector: str, attr: str) -> str:
        return self.page.get_attribute(selector, attr) or ""

    def inner_html(self, selector: str) -> str:
        return self.page.inner_html(selector)

    def inner_text(self, selector: str) -> str:
        return self.page.inner_text(selector)

    def get_links(self) -> List[Dict[str, str]]:
        return self.page.eval_on_selector_all("a[href]", """
            els => els.map(el => ({ text: el.innerText.trim(), href: el.href, title: el.title }))
        """)

    # === Screenshot ===

    def screenshot(self, name: str = None, full_page: bool = False) -> str:
        if name is None:
            from datetime import datetime
            name = f"screenshot_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        path = self.screenshots_dir / name
        self.page.screenshot(path=str(path), full_page=full_page)
        return str(path)

    # === Waiting ===

    def wait_for_selector(self, selector: str, timeout: int = 30000):
        self.page.wait_for_selector(selector, timeout=timeout)
        return self

    def wait_for_load_state(self, state: str = "load"):
        self.page.wait_for_load_state(state)
        return self

    def evaluate(self, js: str):
        return self.page.evaluate(js)


# CLI helper
if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="LightPanda Browser CLI")
    parser.add_argument("url", help="URL to navigate to")
    parser.add_argument("--screenshot", "-s", help="Screenshot output path")
    parser.add_argument("--full", "-f", action="store_true", help="Full page screenshot")
    parser.add_argument("--host", default=_DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=_DEFAULT_PORT)
    args = parser.parse_args()

    with LightPandaBrowser(host=args.host, port=args.port) as browser:
        browser.goto(args.url)
        if args.screenshot:
            path = browser.screenshot(args.screenshot, full_page=args.full)
            print(f"Screenshot saved to: {path}")
        else:
            print(f"Title: {browser.title}")
            print(f"URL:   {browser.url}")
