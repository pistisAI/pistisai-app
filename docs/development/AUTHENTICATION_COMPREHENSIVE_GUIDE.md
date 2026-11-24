# Pistisai Authentication Comprehensive Guide

**Last Updated**: December 15, 2025 (historical incident report)
**Status**: ⚠️ HISTORICAL — the retired Auth0 bridge script fix described below is no longer in the code

> **Verified against code (2026-11-24):** the Auth0 bridge script formerly under `web/` does **not** exist in this repository. The only auth provider in `lib/auth/providers/` is `cloudflare_access_auth_provider.dart`; sign-in uses Cloudflare Access, with brand-baked team domain/AUD and `CF_ACCESS_*` dart defines (see `AUTHENTICATION_QUICK_REFERENCE.md`). The Auth0-audience incident below is retained only as a historical troubleshooting record — do not follow it as current configuration.

> **Historical scope**: the Auth0 bridge and service-worker initializer described below were removed from `web/`; the file names in that section refer to a historical fix and are not present in the tree. Current authentication is handled in Dart (see `docs/architecture/UNIFIED_FLUTTER_WEB.md`).

> **Current orientation**: This authentication guide includes older `/ollama/bridge/status` verification examples. Treat those as legacy/support-provider endpoint checks. They do not imply Ollama is the primary app runtime; the main channel must use the selected agent runtime.

---

## Quick Start (historical Auth0 incident — see current orientation above)

**New to authentication issues?** Start here:

1. **Problem**: Auth0 login succeeded but API calls failed with 401 errors
2. **Root Cause**: Token audience mismatch between frontend and backend
3. **Solution**: Updated frontend to request tokens with correct audience
4. **Status**: ✅ FIXED - All systems operational

---

## What Was Wrong (historical Auth0 incident)

After successful Auth0 login, all API calls failed with 401 errors because:

- **Frontend** requested tokens with audience: `https://example.us.auth0.com/api/v2/` (Auth0 Management API)
- **Backend** expected tokens with audience: `https://api.example.com` (Application API)
- **Result**: Audience mismatch → Backend rejected tokens → 401 Unauthorized

## What Was Fixed (historical; the retired Auth0 bridge script is not in the repo)

### Single Critical Change

**File (historical; not present in repo)**: an Auth0 bridge script under `web/` (removed)

```javascript
// BEFORE (WRONG)
const AUTH0_AUDIENCE = 'https://example.us.auth0.com/api/v2/';

// AFTER (CORRECT)  
const AUTH0_AUDIENCE = 'https://api.example.com';
```

**That's it.** This single change fixed all authentication issues.

### Service Worker Simplification

**Removed**: Unnecessary service worker patches
**Reason**: Flutter web automatically manages service workers - no manual intervention needed

---

## Current Architecture

### Token Flow (historical Auth0 flow; current sign-in is Cloudflare Access)

```
User Login
    ↓
Auth0 OAuth Flow  
    ↓
Auth0 Issues Token (Audience: https://api.example.com)
    ↓
Frontend Stores Token
    ↓
API Request with Authorization Header
    ↓
Backend Validates Token
    ├─ Signature: ✅ Valid
    ├─ Audience: ✅ Matches  
    └─ Expiry: ✅ Valid
    ↓
✅ API Response (200/201)
```

### Components (current)

> **Verified against code:** `lib/auth/providers/` contains only `cloudflare_access_auth_provider.dart` (there is no Auth0 bridge script under `web/`). `services/api-backend/middleware/auth.js:14,52-54` reads `CF_ACCESS_TEAM_DOMAIN` and validates the Cloudflare Access JWT issuer. The Auth0 Domain / Client ID / audience / JWKS values in the historical sections were removed with the retired Auth0 bridge and no longer apply.

#### Frontend (current: `lib/auth/providers/cloudflare_access_auth_provider.dart`)

- Cloudflare Access team domain and application AUD are baked at build time; override with `--dart-define=CF_ACCESS_TEAM_DOMAIN` / `--dart-define=CF_ACCESS_AUD` (see `AUTHENTICATION_QUICK_REFERENCE.md`)
- Local desktop use skips sign-in and does not call Access

#### Backend (`services/api-backend/middleware/auth.js`)

- **Issuer**: `https://${CF_ACCESS_TEAM_DOMAIN}` (or `cloudflare-access` when unset), `auth.js:52-54`
- **Validation**: Cloudflare Access JWT verification (no Auth0 audience check)

---

## Environment Configuration

### Backend Environment Variables

```bash
# Cloudflare Access (free pistisai.app tunnel)
CF_ACCESS_TEAM_DOMAIN=pistisai.cloudflareaccess.com
CF_ACCESS_AUD=<Access application AUD>
# optional:
CF_ACCESS_JWKS_URI=https://pistisai.cloudflareaccess.com/cdn-cgi/access/certs
```

### Frontend Configuration

- `CloudflareAccessAuthProvider` (`lib/auth/providers/cloudflare_access_auth_provider.dart`)
- Brand bake supplies team domain and AUD; override with `--dart-define=CF_ACCESS_*`
- Local desktop use skips sign-in and does not call Access

---

## Testing & Verification

### Manual Testing Checklist

```
1. ✅ Clear browser cache
2. ✅ Navigate to app
3. ✅ Click login button
4. ✅ Complete Cloudflare Access sign-in  
5. ✅ Verify app loads without timeout warnings
6. ✅ Check API calls return 200/201 (not 401)
7. ✅ Verify user data loads correctly
```

### API Endpoints Verified

- ✅ `POST /auth/sessions` - Create authenticated session
- ✅ `GET /user/tier` - Get user tier information
- ✅ `GET /ollama/bridge/status` - Get legacy/support-provider bridge status
- ✅ `PUT /conversations/:id` - Update conversations
- ✅ All other protected endpoints

### Backend Log Verification

Look for: `Token verification successful (Audience verified)`

---

## Troubleshooting

### Still Getting 401 Errors?

1. **Clear browser cache completely**
   - DevTools → Application → Clear Storage
   - Close all browser tabs and reopen

2. **Verify backend configuration**
   - Check `CF_ACCESS_TEAM_DOMAIN` (used by `services/api-backend/middleware/auth.js:14`); there is no `AUTH0_AUDIENCE` variable
   - Restart backend service if needed

3. **Check Cloudflare Access configuration**
   - Verify the team domain and application AUD baked into the build (`CF_ACCESS_TEAM_DOMAIN` / `CF_ACCESS_AUD`)

### Token Validation Fails?

1. **Test JWKS endpoint**

   ```bash
   curl https://example.us.auth0.com/.well-known/jwks.json
   ```

2. **Check token expiration**
   - Decode token at jwt.io
   - Verify `exp` claim is not expired

3. **Verify audience claim**
   - Decode token and check `aud` field
   - Should be: `https://api.example.com`

---

## Deployment

### Build and Deploy

```bash
# Build web app
flutter build web --release

# Flutter web build only; Cloudflare Access is configured at the edge
# (there is no web/auth0-bridge.js in this repo)
# Done!
```

### Rollback Plan

If issues occur:

1. Revert the Cloudflare Access configuration change (the historical Auth0 bridge script under `web/` was removed, so there is nothing to restore there)
2. Clear CDN cache
3. Notify users to clear browser cache
4. Investigate and fix root cause

---

## Files Modified

| File | Change | Status |
|------|--------|--------|
| Auth0 bridge (historical; under `web/`) | Historical audience fix — file no longer exists | ⚠️ HISTORICAL |
| Service-worker initializer (historical; under `web/`) | Deleted | ✅ SIMPLIFIED |
| `web/index.html` | Removed SW patch | ✅ CLEANED |

---

## Related Documentation

### Technical Details

- `docs/development/AUTHENTICATION_QUICK_REFERENCE.md` - Current Cloudflare Access reference (the historical `docs/DEVELOPMENT/AUTH0_AUDIENCE_FIX.md` no longer exists)
- `services/api-backend/middleware/auth.js` - Backend authentication code

### External Resources

- [Auth0 Documentation](https://auth0.com/docs)
- [JWT.io](https://jwt.io) - JWT debugging
- [JWKS Specification](https://tools.ietf.org/html/rfc7517)

---

## Support & Escalation

### For Developers

1. Check browser console for error messages
2. Review backend logs for token validation details
3. Verify environment variables are set correctly
4. Test JWKS endpoint accessibility

### For Production Issues

1. Check monitoring dashboards
2. Review error logs and authentication success rates
3. Verify Cloudflare Access status
4. Escalate with logs and reproduction steps

---

## Status Summary

**✅ ALL SYSTEMS OPERATIONAL**

| Component | Status | Details |
|-----------|--------|---------|
| Frontend auth | ✅ OPERATIONAL | Cloudflare Access via `cloudflare_access_auth_provider.dart`; no retired Auth0 bridge script |
| Backend Token Validation | ✅ OPERATIONAL | Cloudflare Access JWT issuer verification (`middleware/auth.js:52-54`) |
| API Endpoints | ✅ PROTECTED | All endpoints properly secured |
| Service Workers | ✅ SIMPLIFIED | Flutter manages automatically |
| Error Handling | ✅ COMPREHENSIVE | Detailed error messages |
| Documentation | ✅ COMPLETE | Comprehensive guides available |

**Ready for Production**: ✅ YES  
**Confidence Level**: ✅ HIGH  
**Recommendation**: System is fully operational and ready for production use.

---

**Last Updated**: December 15, 2025  
**Status**: READY FOR PRODUCTION ✅
