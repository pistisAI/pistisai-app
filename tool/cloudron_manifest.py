#!/usr/bin/env python3
"""Render CloudronManifest.json from a brand's brand.yaml.

Usage:
    python3 tool/cloudron_manifest.py <brand-id> [--check] [--out PATH]

Without --check, writes the manifest (default: CloudronManifest.json at the
repo root). With --check, exits non-zero if the file on disk does not match
what the brand would produce, so CI can catch drift.

The manifest publishes the brand's identity to Cloudron. Every identity
field is read from brand.yaml so a second brand never ships pistisai's id.
"""

import argparse
import json
import pathlib
import sys

import yaml

REPO = pathlib.Path(__file__).resolve().parent.parent


def build_manifest(brand: dict) -> dict:
    """Map brand.yaml fields onto the Cloudron manifest."""
    return {
        "id": brand["app_id"],
        "title": brand["product_name"],
        "author": brand["company_name"],
        "description": "Pistisai is a local-first companion for your AI agent.",
        "version": "1.0.0",
        "healthCheckPath": "/",
        "httpPort": 3000,
        "addons": {"postgresql": {}, "redis": {}},
        "manifestVersion": 2,
        "website": brand["website_url"],
        "contactEmail": brand["support_email"],
        "icon": "https://raw.githubusercontent.com/pistisAI/pistisai-app/main/"
        + brand["icon_asset"],
        "tags": ["ai", "agent", "desktop-control", "webrtc"],
        "tcpPorts": {"streaming": {"port": 3001}},
        "minBoxVersion": "8.0.0",
    }


def render(manifest: dict) -> str:
    return json.dumps(manifest, indent=4, ensure_ascii=False)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("brand")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--out", default=str(REPO / "CloudronManifest.json"))
    args = parser.parse_args()

    brand_file = REPO / "brand" / args.brand / "brand.yaml"
    brand = yaml.safe_load(brand_file.read_text(encoding="utf-8"))
    expected = render(build_manifest(brand))  # original file has no trailing newline

    out = pathlib.Path(args.out)
    if args.check:
        current = out.read_text(encoding="utf-8") if out.exists() else ""
        if current != expected:
            print(f"DRIFT: {out} does not match brand '{args.brand}'", file=sys.stderr)
            return 1
        print(f"OK: {out} matches brand '{args.brand}'")
        return 0

    out.write_text(expected, encoding="utf-8")
    print(f"wrote {out} from brand '{args.brand}'")
    return 0


if __name__ == "__main__":
    sys.exit(main())
