# Tunnel and sync sign-in

Sign-in exists for the tunnel and sync system. A desktop session on the client's own computer starts without an account and does not call Cloudflare.

Product context: [PistisAI and IAClé](../PRODUCT.md).

## Hosts

| Host | Role |
| --- | --- |
| `app.pistisai.app` | Web app. Behind Cloudflare Access. Not the tunnel audience. |
| `api.pistisai.app` | API and the free-tier tunnel. This is the Access application the desktop tunnel verifies. |

Both hosts answer today with a redirect to `pistisai.cloudflareaccess.com`. `adminmatrix.pistisai.app` was removed on 7 November 2026. `pistisai.app` and `docs.pistisai.app` are not current hosts.

## Tiers

| Tier | Behavior |
| --- | --- |
| Free | Syncs through the pistisai.app tunnel at `api.pistisai.app`. The client signs in with Cloudflare Access. |
| Business | Uses the customer's Tailscale network or VPN. The relay sets `PISTISAI_TUNNEL_AUTH=customer` and does not contact Cloudflare. |
| Enterprise | Same customer network as Business. |
| Premium | Older tier name still present in the app. It uses the customer network, the same as Business and Enterprise. |

Access login does not choose an identity provider. The current Access application sends a one-time email PIN.

Team domain: `pistisai.cloudflareaccess.com`. Issuer: `https://pistisai.cloudflareaccess.com`. JWKS: `https://pistisai.cloudflareaccess.com/cdn-cgi/access/certs`.

## Implementation status

Open pull request [#550](https://github.com/pistisAI/pistisai-app/pull/550) replaces Supabase tunnel sign-in with this Cloudflare Access flow. Until that pull request merges, `main` still contains Supabase client code. Do not document Supabase as the sign-in provider, and do not extend it.

`backend/auth/` is an older CommonJS JWT service. It is not the product sign-in described here. [#550](https://github.com/pistisAI/pistisai-app/pull/550) does not modify that directory.

The stored user key on the API is still the column `users.supabase_id`. [#550](https://github.com/pistisAI/pistisai-app/pull/550) writes the Access subject into that column. Renaming the column needs a database migration this repository does not ship.
