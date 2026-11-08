# Tunnel and sync sign-in

Sign-in is for the tunnel and sync system. A desktop session on the client's own computer starts without an account.

Product page: [PistisAI and IAClé](../PRODUCT.md).

## Hosts

| Host | Role |
| --- | --- |
| `app.pistisai.app` | Web app. Behind Cloudflare Access. |
| `api.pistisai.app` | API and the free-tier tunnel. |

## Tiers

| Tier | Behavior |
| --- | --- |
| Free | Syncs through the tunnel at `api.pistisai.app`. The client signs in with Cloudflare Access. |
| Business | Uses the customer's Tailscale network or VPN. The relay sets `PISTISAI_TUNNEL_AUTH=customer`. |
| Enterprise | Uses the customer's Tailscale network or VPN. The relay sets `PISTISAI_TUNNEL_AUTH=customer`. |

Access sends a one-time email PIN.

Team domain: `pistisai.cloudflareaccess.com`. Issuer: `https://pistisai.cloudflareaccess.com`. JWKS: `https://pistisai.cloudflareaccess.com/cdn-cgi/access/certs`.
