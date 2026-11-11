/**
 * @pistisai/middleware-config
 *
 * Unified middleware configuration for all PistisAI backend services
 *
 * Usage:
 * ```javascript
 * // Import everything
 * import * as middlewareConfig from '@pistisai/middleware-config';
 *
 * // Or import specific modules
 * import { setupMiddlewarePipeline } from '@pistisai/middleware-config/pipeline';
 * import { authenticateJWT, optionalAuth } from '@pistisai/middleware-config/auth';
 * import { standardCors, authorizeRBAC } from '@pistisai/middleware-config/security';
 * import { requestLoggingMiddleware } from '@pistisai/middleware-config/logging';
 * import { validateSchema } from '@pistisai/middleware-config/validation';
 * import { createGracefulShutdownManager } from '@pistisai/middleware-config/operational';
 * ```
 */

// Main pipeline setup
export { setupMiddlewarePipeline } from './pipeline/index.js';

// Auth exports
export * as auth from './auth/index.js';
export {
  authenticateJWT,
  checkJwt,
  optionalAuth,
  extractUserId,
  syncSession,
  requireAdmin,
  getAuthService,
  adminAuth,
  requireRole,
  requireSuperAdmin,
  checkPermissions,
  closeDbPool,
  ROLE_PERMISSIONS as AUTH_ROLE_PERMISSIONS,
  authenticateApiKey,
  optionalApiKeyAuth,
  requireApiKeyScope,
  apiKeyAuth,
  authenticateInfrastructure,
  optionalInfrastructureAuth,
  authenticateComposite,
} from './auth/index.js';

// Security exports
export * as security from './security/index.js';
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
  ROLES,
  PERMISSIONS,
  ROLE_PERMISSIONS as RBAC_ROLE_PERMISSIONS,
  hasPermission,
  hasAnyPermission,
  requirePermission,
  authorizeRBAC,
  requireAdmin as requireAdminRBAC,
  requireSuperAdmin as requireSuperAdminRBAC,
  USER_TIERS,
  TIER_FEATURES,
  getUserTier,
  getTierFeatures,
  hasFeature,
  requireTier,
  requireFeature,
  addTierInfo,
  shouldUseDirectTunnel,
} from './security/index.js';

// Logging exports
export * as logging from './logging/index.js';
export {
  createRequestLoggingMiddleware,
  requestLoggingMiddleware,
  createMetricsCollectionMiddleware,
  metricsCollectionMiddleware,
  adminMetricsRegistry,
  adminApiRequestsTotal,
  adminApiResponseTimeMs,
  adminMetricsMiddleware,
  getAdminMetricsRegistry,
  initializeAdminMetrics,
  trackAdminAction,
  trackAuthAttempt,
  trackDatabaseQuery,
  trackStripeApiCall,
  trackStripeApiError,
  updateDbPoolMetrics,
  updateErrorRate,
  updatePaymentRates,
  exportAdminMetricsAsText,
} from './logging/index.js';

// Validation exports
export * as validation from './validation/index.js';
export {
  createRequestValidationMiddleware,
  requestValidationMiddleware,
  validateSchema,
  commonSchemas,
  API_VERSIONS,
  DEFAULT_API_VERSION,
  apiVersioningMiddleware,
  backwardCompatibilityMiddleware,
  extractVersionFromPath,
  getVersionInfoHandler,
  createVersionedRouter,
  versionRouter,
  mountVersionedRoutes,
} from './validation/index.js';

// Operational exports
export * as operational from './operational/index.js';
export {
  createGracefulShutdownManager,
  setupGracefulShutdown,
  createRequestTimeoutMiddleware,
  requestTimeoutMiddleware,
  createRequestQueuingMiddleware,
  createQueueStatusMiddleware,
  createQueueStatusHandler,
  createQueueDrainHandler,
  createGracefulShutdown,
  createAdminRateLimiter,
  adminRateLimiter,
  adminReadOnlyLimiter,
  adminExpensiveLimiter,
  adminBurstLimiter,
  adminCriticalLimiter,
  getRateLimitStats,
  combineRateLimiters,
  webhookRateLimiterMiddleware,
  webhookRateLimitConfigMiddleware,
  createEndpointRateLimiter,
  createEndpointRateLimiters,
  createTieredRateLimiter,
  getRateLimitMetrics,
  ENDPOINT_LIMITS,
} from './operational/index.js';

export const version = '1.0.0';
