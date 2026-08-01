#!/usr/bin/env python3
"""
Camoufox + DuckDuckGo Research Script
Performs anti-detect browser research searches using Camoufox and DuckDuckGo HTML.
"""

import sys
from camoufox.sync_api import Camoufox

def search_duckduckgo(query: str, max_results: int = 5):
    print(f"[Camoufox] Searching DuckDuckGo for: '{query}'...")
    with Camoufox(headless='virtual') as browser:
        page = browser.new_page()
        page.goto("https://html.duckduckgo.com/html/")
        page.fill("input[name='q']", query)
        page.press("input[name='q']", "Enter")
        page.wait_for_selector(".result", timeout=10000)
        
        results = []
        for el in page.locator(".result__title").all()[:max_results]:
            results.append(el.inner_text().strip())
        
        page.close()
        return results

if __name__ == "__main__":
    query = sys.argv[1] if len(sys.argv) > 1 else "PistisAI local first companion"
    results = search_duckduckgo(query)
    print("\nSearch Results:")
    for i, r in enumerate(results, 1):
        print(f"{i}. {r}")
