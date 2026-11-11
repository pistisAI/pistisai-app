/**
 * Validation Middleware Module
 *
 * Request validation, schema validation, and API versioning
 */

// Request Validation
export {
  createRequestValidationMiddleware,
  requestValidationMiddleware,
} from './request-validation.js';

// Schema Validation
export {
  validateSchema,
  commonSchemas,
} from './schema-validation.js';

// API Versioning
export {
  API_VERSIONS,
  DEFAULT_API_VERSION,
  apiVersioningMiddleware,
  backwardCompatibilityMiddleware,
  extractVersionFromPath,
  getVersionInfoHandler,
  createVersionedRouter,
  versionRouter,
  mountVersionedRoutes,
} from './api-versioning.js';
