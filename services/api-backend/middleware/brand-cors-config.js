/**
 * Brand-Aware CORS Configuration Middleware
 *
 * Provides per-brand CORS policy enforcement:
 * - Brand-specific origin whitelists
 * - Tenant isolation via strict origin validation
 * - Configuration loading from environment or brand manifest
 * - Policy fallback to safe defaults
 *
 * Issue #385: CORS policy enforcement for whitelabel builds
 */

import cors from 'cors';
import logger from '../logger.js';

/**
 * Brand CORS Configuration Schema
 *
 * Each brand can define:
 * - origins: array of allowed origins
 * - credentials: whether credentials are allowed
 * - methods: allowed HTTP methods
 * - allowedHeaders: headers the client can send
 * - exposedHeaders: headers the API sends to client
 * - maxAge: preflight cache duration (seconds)
 */

/**
 * Default CORS policy for all brands (conservative, secure)
 */
const DEFAULT_BRAND_CORS_POLICY = {
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'X-Requested-With',
    'Accept',
    'Origin',
    'Sentry-Trace',
    'Baggage',
  ],
  exposedHeaders: [
    'Content-Length',
    'Content-Type',
    'X-RateLimit-Limit',
    'X-RateLimit-Remaining',
    'X-RateLimit-Reset',
  ],
  maxAge: 86400, // 24 hours
  optionsSuccessStatus: 200,
};

/**
 * Brand CORS policies registry
 * Can be loaded from database, files, or environment variables
 *
 * Format:
 * {
 *   "brand-id": {
 *     origins: ["https://app.brand.com", "https://api.brand.com"],
 *     credentials: true,
 *     methods: [...],
 *     allowedHeaders: [...],
 *     exposedHeaders: [...],
 *     maxAge: 86400,
 *   }
 * }
 */
const BRAND_CORS_POLICIES = {};

/**
 * Initialize brand CORS policies from environment
 * Reads BRAND_CORS_POLICIES_JSON environment variable
 *
 * @returns {void}
 */
function initializeBrandCORSPolicies() {
  // Load from environment variable if provided
  if (process.env.BRAND_CORS_POLICIES_JSON) {
    try {
      const policies = JSON.parse(process.env.BRAND_CORS_POLICIES_JSON);
      Object.assign(BRAND_CORS_POLICIES, policies);
      logger.info('Loaded brand CORS policies from environment', {
        brandCount: Object.keys(policies).length,
      });
    } catch (error) {
      logger.error('Failed to parse BRAND_CORS_POLICIES_JSON', {
        error: error.message,
      });
    }
  }

  // Ensure default brand exists for backward compatibility
  if (!BRAND_CORS_POLICIES['default']) {
    BRAND_CORS_POLICIES['default'] = {
      origins: [
        'https://app.pistisai.app',
        'https://pistisai.app',
        'https://docs.pistisai.app',
        'https://admin.pistisai.app',
        'https://api.pistisai.app',
        ...(process.env.NODE_ENV === 'development'
          ? [
              'http://localhost:3000',
              'http://localhost:8080',
              'http://localhost:5000',
              'http://127.0.0.1:3000',
              'http://127.0.0.1:8080',
              'http://127.0.0.1:5000',
            ]
          : []),
        ...(process.env.ADDITIONAL_CORS_ORIGINS
          ? process.env.ADDITIONAL_CORS_ORIGINS.split(',').map((o) => o.trim())
          : []),
      ],
    };
  }
}

/**
 * Register or update a brand's CORS policy
 * @param {string} brandId - The brand identifier
 * @param {Object} policy - CORS policy configuration
 * @returns {void}
 */
function registerBrandCORSPolicy(brandId, policy) {
  BRAND_CORS_POLICIES[brandId] = {
    ...DEFAULT_BRAND_CORS_POLICY,
    ...policy,
  };
  logger.info(`Registered CORS policy for brand: ${brandId}`, {
    origins: BRAND_CORS_POLICIES[brandId].origins?.length || 0,
  });
}

/**
 * Get CORS policy for a brand
 * @param {string} brandId - The brand identifier
 * @returns {Object} CORS policy for the brand
 */
function getBrandCORSPolicy(brandId) {
  const policy = BRAND_CORS_POLICIES[brandId] || BRAND_CORS_POLICIES['default'];

  if (!policy) {
    logger.warn(`No CORS policy found for brand: ${brandId}, using default`);
    return {
      ...DEFAULT_BRAND_CORS_POLICY,
      origins: [],
    };
  }

  return {
    ...DEFAULT_BRAND_CORS_POLICY,
    ...policy,
  };
}

/**
 * Extract brand ID from request
 *
 * Attempts to extract brand from (in priority order):
 * 1. X-Brand-ID header
 * 2. Subdomain from Host header
 * 3. Hostname from origin/referer
 * 4. Query parameter
 * 5. Default brand
 *
 * @param {Object} req - Express request object
 * @returns {string} Brand ID
 */
function extractBrandFromRequest(req) {
  // 1. Check for explicit brand header
  if (req.headers['x-brand-id']) {
    return req.headers['x-brand-id'];
  }

  // 2. Extract from Host header subdomain
  const host = req.hostname || req.headers.host || '';
  const hostParts = host.split('.');

  if (hostParts.length >= 2) {
    const subdomain = hostParts[0];
    // If subdomain is not a reserved word, use it as brand ID
    if (!['www', 'api', 'admin', 'app', 'localhost', '127'].includes(subdomain)) {
      return subdomain;
    }
  }

  // 3. Try to extract from origin header
  const origin = req.headers.origin || req.headers.referer || '';
  if (origin) {
    try {
      const url = new URL(origin);
      const urlParts = url.hostname.split('.');
      if (urlParts.length >= 2) {
        const subdomain = urlParts[0];
        if (!['www', 'api', 'admin', 'app', 'localhost', '127'].includes(subdomain)) {
          return subdomain;
        }
      }
    } catch {
      // Invalid URL, continue to next strategy
    }
  }

  // 4. Check query parameter
  if (req.query?.brandId) {
    return req.query.brandId;
  }

  // 5. Default to 'default' brand
  return 'default';
}

/**
 * Create a brand-aware CORS origin validator
 * @param {string} brandId - The brand identifier
 * @returns {Function} CORS origin validator function
 */
function createBrandCorsOriginValidator(brandId) {
  return (origin, callback) => {
    // Allow requests without origin (mobile apps, curl)
    if (!origin) {
      return callback(null, true);
    }

    const policy = getBrandCORSPolicy(brandId);
    const allowedOrigins = policy.origins || [];

    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      logger.warn(
        `CORS: Blocked request from unauthorized origin for brand ${brandId}`,
        {
          origin,
          brandId,
          allowedCount: allowedOrigins.length,
        },
      );
      callback(new Error(`Not allowed by CORS for brand: ${brandId}`));
    }
  };
}

/**
 * Create brand-aware CORS middleware factory
 * @param {string} brandId - The brand identifier
 * @returns {Function} Express middleware
 */
function createBrandCorsMiddleware(brandId) {
  const policy = getBrandCORSPolicy(brandId);

  const corsOptions = {
    ...policy,
    origin: createBrandCorsOriginValidator(brandId),
  };

  return cors(corsOptions);
}

/**
 * Middleware to dynamically apply brand-specific CORS policies
 * Extracts brand from request and applies appropriate CORS rules
 *
 * Must be placed BEFORE body parsing and other middleware
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 * @returns {void}
 */
function dynamicBrandCorsMiddleware(req, res, next) {
  // Extract brand from request
  const brandId = extractBrandFromRequest(req);

  // Store brand ID for use in downstream middleware
  req.brandId = brandId;

  // Get CORS policy for this brand
  const policy = getBrandCORSPolicy(brandId);

  // Allow requests without origin
  const origin = req.headers.origin;
  if (!origin) {
    // For requests without origin, apply standard CORS headers
    res.header('Access-Control-Allow-Credentials', 'true');
    return next();
  }

  // Validate origin against brand policy
  const allowedOrigins = policy.origins || [];

  if (allowedOrigins.includes(origin)) {
    // Origin is allowed
    res.header('Access-Control-Allow-Origin', origin);
    res.header('Access-Control-Allow-Credentials', policy.credentials ? 'true' : 'false');

    if (req.method === 'OPTIONS') {
      // Handle preflight request
      res.header(
        'Access-Control-Allow-Methods',
        (policy.methods || DEFAULT_BRAND_CORS_POLICY.methods).join(', '),
      );
      res.header(
        'Access-Control-Allow-Headers',
        (policy.allowedHeaders || DEFAULT_BRAND_CORS_POLICY.allowedHeaders).join(', '),
      );
      res.header(
        'Access-Control-Expose-Headers',
        (policy.exposedHeaders || DEFAULT_BRAND_CORS_POLICY.exposedHeaders).join(', '),
      );
      res.header('Access-Control-Max-Age', policy.maxAge || DEFAULT_BRAND_CORS_POLICY.maxAge);

      return res.status(policy.optionsSuccessStatus || 200).end();
    }

    // For actual requests, set exposed headers
    res.header(
      'Access-Control-Expose-Headers',
      (policy.exposedHeaders || DEFAULT_BRAND_CORS_POLICY.exposedHeaders).join(', '),
    );
  } else {
    // Origin not allowed for this brand
    logger.warn(`CORS rejected for brand ${brandId}`, {
      origin,
      brandId,
      allowedCount: allowedOrigins.length,
    });

    if (req.method === 'OPTIONS') {
      // Reject preflight
      return res.status(403).json({
        error: 'CORS policy violation',
        message: `Origin ${origin} not allowed for brand ${brandId}`,
      });
    }

    // For actual requests, don't set Access-Control-Allow-Origin
    // Browser will block the response
  }

  next();
}

/**
 * Middleware to log CORS decisions per brand
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 * @returns {void}
 */
function logBrandCorsDecisions(req, res, next) {
  const origin = req.headers.origin;
  const brandId = req.brandId || extractBrandFromRequest(req);

  if (origin) {
    const policy = getBrandCORSPolicy(brandId);
    const allowed = (policy.origins || []).includes(origin);

    logger.debug(`CORS Decision: ${req.method} ${req.path}`, {
      origin,
      brandId,
      allowed,
      originCount: (policy.origins || []).length,
    });
  }

  next();
}

/**
 * Get all registered brands and their policies (for admin/debugging)
 * @returns {Object} Map of brand IDs to policy summaries
 */
function getAllBrandPolicies() {
  const result = {};

  Object.entries(BRAND_CORS_POLICIES).forEach(([brandId, policy]) => {
    result[brandId] = {
      originCount: (policy.origins || []).length,
      credentials: policy.credentials,
      methods: policy.methods,
      origins: policy.origins?.slice(0, 3), // Show first 3 for summary
    };
  });

  return result;
}

/**
 * Check if an origin is allowed for a specific brand
 * @param {string} brandId - The brand identifier
 * @param {string} origin - The origin to validate
 * @returns {boolean} True if origin is allowed
 */
function isOriginAllowedForBrand(brandId, origin) {
  // Allow requests without origin (null/undefined)
  // But reject empty strings (malformed requests)
  if (origin === null || origin === undefined) {
    return true;
  }

  if (origin === '') {
    return false; // Reject empty string
  }

  const policy = getBrandCORSPolicy(brandId);
  return (policy.origins || []).includes(origin);
}

// Initialize policies on module load
initializeBrandCORSPolicies();

// Named exports for better tree-shaking and explicit imports
export {
  DEFAULT_BRAND_CORS_POLICY,
  initializeBrandCORSPolicies,
  registerBrandCORSPolicy,
  getBrandCORSPolicy,
  extractBrandFromRequest,
  createBrandCorsMiddleware,
  dynamicBrandCorsMiddleware,
  logBrandCorsDecisions,
  getAllBrandPolicies,
  isOriginAllowedForBrand,
};
