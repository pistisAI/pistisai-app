#!/usr/bin/env python3
"""Stamp the Flutter web entry scripts with a content hash.

Flutter web output keeps fixed file names (main.dart.js, flutter_bootstrap.js),
so a browser that cached an older build can keep running it. This rewrites:
  - flutter_bootstrap.js: "mainJsPath":"main.dart.js" -> "main.dart.js?v=<hash>"
  - index.html:           flutter_bootstrap.js?v=...  -> flutter_bootstrap.js?v=<hash>
The hash covers main.dart.js, so every new build gets new URLs.
Usage: web_cache_bust.py <build/web dir>
"""
import hashlib
import pathlib
import re
import sys


def main(web_dir: str) -> None:
    web = pathlib.Path(web_dir)
    digest = hashlib.sha256((web / "main.dart.js").read_bytes()).hexdigest()[:12]

    bootstrap = web / "flutter_bootstrap.js"
    text = bootstrap.read_text()
    text, n = re.subn(r'"mainJsPath":"main\.dart\.js(\?v=[^"]*)?"',
                      f'"mainJsPath":"main.dart.js?v={digest}"', text)
    if n == 0:
        sys.exit("web_cache_bust: mainJsPath not found in flutter_bootstrap.js")
    bootstrap.write_text(text)

    index = web / "index.html"
    html = index.read_text()
    html, n = re.subn(r'flutter_bootstrap\.js(\?v=[^"]*)?"',
                      f'flutter_bootstrap.js?v={digest}"', html)
    if n != 1:
        sys.exit(f"web_cache_bust: expected 1 flutter_bootstrap.js tag in index.html, found {n}")
    index.write_text(html)
    print(f"web_cache_bust: stamped v={digest}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "build/web")
