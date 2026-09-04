#!/usr/bin/env python3
"""Sync pistisai.app /install.sh and /install.ps1 redirects to GitHub Releases."""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request

INSTALL_SH_URL = (
    "https://github.com/pistisAI/pistisai-app/releases/latest/download/install.sh"
)
INSTALL_PS1_BOOTSTRAP = (
    "https://raw.githubusercontent.com/pistisAI/pistisai-app/main/web/install.ps1"
)
HOST_EXPR = (
    '(http.host eq "pistisai.app" or http.host eq "www.pistisai.app" '
    'or http.host eq "app.pistisai.app")'
)


def cf_request(method: str, url: str, token: str, payload: dict | None = None) -> dict:
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "pistisai-sync-install-redirects",
        },
        method=method,
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def redirect_rule(name: str, expression: str, target: str) -> dict:
    return {
        "action": "redirect",
        "expression": expression,
        "description": name,
        "action_parameters": {
            "from_value": {
                "target_url": {"value": target},
                "status_code": {"value": 302},
                "preserve_query_string": {"value": True},
            }
        },
        "enabled": True,
    }


def sync_dynamic_redirect_rules(zone_id: str, token: str) -> None:
    api = (
        f"https://api.cloudflare.com/client/v4/zones/{zone_id}/rulesets/"
        "phases/http_request_dynamic_redirect/entrypoint"
    )
    rules = [
        redirect_rule(
            "Pistisai install.sh",
            f'{HOST_EXPR} and http.request.uri.path eq "/install.sh"',
            INSTALL_SH_URL,
        ),
        redirect_rule(
            "Pistisai install.ps1",
            f'{HOST_EXPR} and http.request.uri.path eq "/install.ps1"',
            INSTALL_PS1_BOOTSTRAP,
        ),
    ]
    payload = {"rules": rules}
    existing = cf_request("GET", api, token)
    ruleset_id = (existing.get("result") or {}).get("id")
    if ruleset_id:
        cf_request(
            "PUT",
            f"https://api.cloudflare.com/client/v4/zones/{zone_id}/rulesets/{ruleset_id}",
            token,
            payload,
        )
    else:
        cf_request("PUT", api, token, payload)
    print("Cloudflare dynamic redirect rules synced")


def sync_page_rules(zone_id: str, token: str) -> None:
    targets = [
        ("/install.sh", INSTALL_SH_URL),
        ("/install.ps1", INSTALL_PS1_BOOTSTRAP),
    ]
    list_url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/pagerules"
    existing = cf_request("GET", list_url, token).get("result") or []
    by_target = {}
    for rule in existing:
        for action in rule.get("actions") or []:
            if action.get("id") == "forwarding_url":
                by_target[action.get("value", {}).get("url")] = rule

    for path, target in targets:
        payload = {
            "targets": [
                {
                    "target": "url",
                    "constraint": {
                        "operator": "matches",
                        "value": f"*pistisai.app{path}*",
                    },
                }
            ],
            "actions": [
                {
                    "id": "forwarding_url",
                    "value": {"url": target, "status_code": 302},
                }
            ],
            "priority": 1,
            "status": "active",
        }
        current = next(
            (
                rule
                for rule in existing
                if any(
                    (action.get("id") == "forwarding_url")
                    and path in (action.get("value") or {}).get("url", "")
                    for action in rule.get("actions") or []
                )
            ),
            None,
        )
        if current:
            cf_request(
                "PATCH",
                f"{list_url}/{current['id']}",
                token,
                payload,
            )
        else:
            cf_request("POST", list_url, token, payload)
        print(f"Cloudflare page rule synced for {path}")


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: sync_cloudflare_install_redirects.py ZONE_ID TOKEN", file=sys.stderr)
        return 2

    zone_id, token = sys.argv[1:3]
    errors: list[str] = []

    for name, fn in (
        ("dynamic redirect rules", sync_dynamic_redirect_rules),
        ("page rules", sync_page_rules),
    ):
        try:
            fn(zone_id, token)
            return 0
        except urllib.error.HTTPError as exc:
            body = exc.read().decode(errors="replace")[:500]
            errors.append(f"{name}: HTTP {exc.code} {body}")
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{name}: {exc}")

    print("Cloudflare install redirect sync failed:", file=sys.stderr)
    for err in errors:
        print(f"  - {err}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
