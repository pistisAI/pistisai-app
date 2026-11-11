/**
 * Authentication Middleware Module
 *
 * Unified authentication middleware for PistisAI services
 * Supports JWT, API keys, admin auth, and infrastructure auth
 */

// JWT Authentication
export {
  authenticateJWT,
  checkJwt,
  optionalAuth,
  extractUserId,
  syncSession,
  requireAdmin,
  getAuthService,
} from './jwt-authenticator.js';

// Admin Authentication & Authorization
export {
  adminAuth,
  requireRole,
  requireSuperAdmin,
  checkPermissions,
  closeDbPool,
  ROLE_PERMISSIONS,
} from './admin-auth.js';

// API Key Authentication
export {
  authenticateApiKey,
  optionalApiKeyAuth,
  requireApiKeyScope,
  apiKeyAuth,
} from './api-key-auth.js';

// Infrastructure Authentication
export {
  authenticateInfrastructure,
  optionalInfrastructureAuth,
} from './infrastructure-auth.js';

// Composite Authentication
export { authenticateComposite } from './composite-auth.js';
