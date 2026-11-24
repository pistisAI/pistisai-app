# Authentication Quick Reference

## Product rules

- Sign-in exists only for tunnel/sync. Local desktop hub use needs no sign-in and must not call Cloudflare Access or any cloud auth provider until the user opts in.
- **Free:** Cloudflare Access (Google, GitHub, and other Access IdPs) in front of `pistisai.app` tunnel endpoints, then sync across the user's devices.
- **Business / Enterprise:** customer-owned VPN or Tailscale. They do not have to use the `pistisai.app` tunnel.
- Supabase is not an auth or API provider.

## Key configuration

### Frontend (Flutter)

```dart
// lib/config/app_config.dart — brand bake + optional dart-defines
AppConfig.cloudflareAccessTeamDomain // CF_ACCESS_TEAM_DOMAIN
AppConfig.cloudflareAccessAud        // CF_ACCESS_AUD
```

Provider: `lib/auth/providers/cloudflare_access_auth_provider.dart`

### Backend (api-backend + streaming-proxy)

```bash
CF_ACCESS_TEAM_DOMAIN=pistisai.cloudflareaccess.com
CF_ACCESS_AUD=<Access application AUD>
# optional:
CF_ACCESS_JWKS_URI=https://pistisai.cloudflareaccess.com/cdn-cgi/access/certs
```

## Authentication flow (free tunnel)

```
User chooses "Sign in to sync devices"
    ↓
Desktop opens app URL → Cloudflare Access challenge (Google/GitHub/…)
    ↓
Access JWT returned on callback (`cf_jwt` / `token`)
    ↓
Stored in flutter_secure_storage; used as Bearer for api.pistisai.app
    ↓
api-backend / streaming-proxy validate RS256 via team JWKS + AUD
```

Local-only path: skip sign-in → hub uses loopback services only.

## Environment variables

| Variable | Purpose |
|----------|---------|
| `CF_ACCESS_TEAM_DOMAIN` | Access team host (no scheme) |
| `CF_ACCESS_AUD` | Access application audience |
| `CF_ACCESS_JWKS_URI` | Optional JWKS override |
| `DEV_BYPASS_TOKEN` | Development-only API bypass: honoured only when it is explicitly set and `NODE_ENV` is exactly `development`; an unset, empty or any other `NODE_ENV` (including `test` and `production`) disables it. Applies to `backend/auth/` and, with PR #958, to api-backend |

## Files to know

| File | Purpose |
|------|---------|
| `lib/auth/providers/cloudflare_access_auth_provider.dart` | Desktop/web Access login |
| `lib/services/auth_service.dart` | App auth facade |
| `services/api-backend/middleware/auth.js` | API JWT middleware |
| `services/api-backend/auth/auth-service.js` | Token validation + session |
| `services/streaming-proxy/src/middleware/cloudflare-access-validator.ts` | Proxy JWT validation |

## Notes

- `users.supabase_id` remains a legacy column name for the primary Access subject link; it is not a Supabase integration.
- Paid plans that use Tailscale/VPN do not require Access on the customer network path.
