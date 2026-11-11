#!/usr/bin/env python3
"""
Issue a whitelabel licence.

The private key NEVER leaves the licensor's machine and never enters this
repository. The public key is embedded in lib/brand/brand_licence.dart.

Usage:
    python3 tool/issue_licence.py --brand acme --licensee "Acme Labs" \
        --expires 2027-12-31 --seats 5 --key /path/to/private.key \
        --out acme.licence

The output licence is passed to the bake step:
    tool/brand.sh acme --license acme.licence
"""
import argparse
import base64
import json
import sys
from datetime import datetime, timezone

try:
    import nacl.signing
except ImportError:
    sys.exit("pynacl required: python3 -m pip install pynacl")


def b64url_decode(data: str) -> bytes:
    pad = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + pad)


def b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def canonical_payload(payload: dict) -> bytes:
    """Deterministic serialization — must match lib/brand/brand_licence.dart.

    ensure_ascii=False is essential: Dart's jsonEncode emits literal UTF-8
    (for example a licensee name containing "é"), while Python's default
    escapes it to "\\u00e9". The two produce different bytes and the
    signature would not verify.
    """
    return json.dumps(
        payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(description="Issue a whitelabel licence")
    ap.add_argument("--key", required=True, help="Path to the Ed25519 private key")
    ap.add_argument("--brand", required=True, help="Brand id this licence unlocks")
    ap.add_argument("--licensee", required=True, help="Licensee name")
    ap.add_argument("--plan", default="whitelabel", help="Plan id")
    ap.add_argument("--issued", default=None, help="ISO date issued (default now, UTC)")
    ap.add_argument("--expires", required=True, help="ISO expiry date, e.g. 2027-12-31")
    ap.add_argument("--seats", type=int, default=1, help="Number of seats")
    ap.add_argument("--notes", default="", help="Free-text note")
    ap.add_argument("--out", default="licence.licence", help="Output licence file")
    args = ap.parse_args()

    with open(args.key) as f:
        sk = nacl.signing.SigningKey(b64url_decode(f.read().strip()))

    now = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    issued = args.issued or now

    payload = {
        "brand": args.brand,
        "format": "pistisai-whitelabel-1",
        "issued": issued,
        "licensee": args.licensee,
        "plan": args.plan,
        "seats": args.seats,
        "expires": args.expires,
    }
    if args.notes:
        payload["notes"] = args.notes

    sig = sk.sign(canonical_payload(payload)).signature

    licence = {
        "payload": payload,
        "signature": b64url_encode(sig),
        "signing_key_id": "pistisai-whitelabel-2026",
    }

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(licence, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Licence written: {args.out}")
    print(f"  brand    : {args.brand}")
    print(f"  licensee : {args.licensee}")
    print(f"  plan     : {args.plan}")
    print(f"  issued   : {issued}")
    print(f"  expires  : {args.expires}")
    print(f"  seats    : {args.seats}")
    print()
    print(f"Bake with: tool/brand.sh {args.brand} --license {args.out}")


if __name__ == "__main__":
    main()
