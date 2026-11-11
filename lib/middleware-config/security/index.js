/**
 * Security Middleware Module
 *
 * Unified security configuration including CORS, RBAC, rate limiting, and tier checks
 */

// CORS Configuration
export {
  standardCorsOptions,
  adminCorsOptions,
  webhookCorsOptions,
  standardCors,
  adminCors,
  webhookCors,
  getAllowedOrigins,
  isOriginAllowed,
  logCorsRequest,
} from './cors-config.js';

// RBAC (Role-Based Access Control)
export {
  ROLES,
  PERMISSIONS,
  ROLE_PERMISSIONS,
  hasPermission,
  hasAnyPermission,
  requirePermission,
  authorizeRBAC,
  requireRole,
  requireAdmin,
  requireSuperAdmin,
} from './rbac.js';

// Tier-based Access Control
export {
  USER_TIERS,
  TIER_FEATURES,
  getUserTier,
  getTierFeatures,
  hasFeature,
  requireTier,
  requireFeature,
  addTierInfo,
  shouldUseDirectTunnel,
} from './tier-check.js';
