# Sign-In Setup — Cloudflare Access (formerly "Google OAuth Client Setup")

> **This guide replaces the old Google OAuth client-ID instructions.** `lib/config/app_config.dart` has no `googleClientId`, `googleClientIdWeb` or `googleClientIdDesktop` constants, and there is no `google_sign_in` dependency in `pubspec.yaml`. Creating Google OAuth client IDs therefore cannot fix a "401: invalid_client" error in the current app.

## Current authentication model

Sign-in exists only for tunnel/sync. Local desktop hub use needs no sign-in and must not call Cloudflare Access or any cloud auth provider until the user opts in.

- **Free tier**: Cloudflare Access (Google, GitHub and other Access IdPs) in front of `pistisai.app` tunnel endpoints, then sync across the user's devices.
- **Business / Enterprise**: a customer-owned VPN or Tailscale; those deployments do not have to use the `pistisai.app` tunnel.
- Supabase is not an auth or API provider.

Source: `docs/development/AUTHENTICATION_QUICK_REFERENCE.md` and `lib/config/app_config.dart`.

## Configuration that actually applies

Frontend (brand bake / dart-defines in `lib/config/app_config.dart`):

```dart
AppConfig.cloudflareAccessTeamDomain // CF_ACCESS_TEAM_DOMAIN
AppConfig.cloudflareAccessAud        // CF_ACCESS_AUD
```

Provider: `lib/auth/providers/cloudflare_access_auth_provider.dart`.

Backend (`services/api-backend` and `services/streaming-proxy`):

```bash
CF_ACCESS_TEAM_DOMAIN=pistisai.cloudflareaccess.com
CF_ACCESS_AUD=<Access application AUD>
# optional:
CF_ACCESS_JWKS_URI=https://pistisai.cloudflareaccess.com/cdn-cgi/access/certs
```

The browser-facing Access challenge returns a JWT on the callback (`cf_jwt` / `token`); it is stored by `lib/services/auth_service.dart` and used as a Bearer token for `api.pistisai.app`. `services/api-backend/middleware/auth.js` and `services/streaming-proxy/src/middleware/cloudflare-access-validator.ts` validate it against the team JWKS and audience.

## Troubleshooting "401: invalid_client"

1. Confirm you are following the Cloudflare Access flow above rather than a Google OAuth flow; Google client IDs are not read by the app.
2. Check `CF_ACCESS_TEAM_DOMAIN` and `CF_ACCESS_AUD` match the Access application.
3. Confirm the callback forwards `cf_jwt` / `token` and that the backend can reach the JWKS URI.
4. For local-only use, skip sign-in entirely — the hub uses loopback services.

`DEV_BYPASS_TOKEN` is development-only and honoured only when it is explicitly set and `NODE_ENV` is exactly `development`; unset, empty, or any other `NODE_ENV` disables it.

## Related documentation

- [Authentication Quick Reference](../development/AUTHENTICATION_QUICK_REFERENCE.md) — canonical auth configuration
- [Secrets Management](SECRETS_MANAGEMENT.md) — CI/CD secrets (no Google/JWT secrets)
- [Deployment Overview](DEPLOYMENT_OVERVIEW.md)
