'use strict';

/**
 * QUARANTINED — legacy Auth0 JWT handler.
 *
 * This file is not an authentication service and does not bind a port.
 * Active auth is Cloudflare Access in services/api-backend
 * (middleware/auth.js and auth/auth-service.js).
 *
 * Running this file exits non-zero. Requiring it throws.
 * Retained so an old `node handlers.js` start fails closed instead of
 * serving Auth0 JWTs.
 */

const QUARANTINE_NOTICE =
  'backend/auth is quarantined and is not an active auth service. ' +
  'Cloudflare Access in services/api-backend is the active auth path. ' +
  'This legacy Auth0 handler does not start and does not validate tokens.';

if (require.main === module) {
  console.error(QUARANTINE_NOTICE);
  process.exit(1);
}

throw new Error(QUARANTINE_NOTICE);
