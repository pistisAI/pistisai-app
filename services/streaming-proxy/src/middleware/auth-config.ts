/**
 * Authentication configuration for Cloudflare Access.
 * Defaults are the public pistisai.app tunnel application. Override with
 * CF_ACCESS_* env vars. No secrets.
 */

export interface AuthConfig {
  access: {
    jwksUri: string;
    audience: string;
    issuer: string;
  };
  cache: {
    validationDuration: number; // milliseconds
    jwksDuration: number; // milliseconds
  };
  bruteForce: {
    threshold: number; // failed attempts
    window: number; // milliseconds
    blockDuration: number; // milliseconds
  };
  audit: {
    maxHistorySize: number;
    retentionDays: number;
  };
}

/**
 * Load authentication configuration from environment variables
 */
export function loadAuthConfig(): AuthConfig {
  const audience =
    process.env.CF_ACCESS_AUD ||
    'c0134585f8067b43908572f93046917aedfb9b8d111f3ed716e3fc204e8fe7d3';
  const issuer =
    process.env.CF_ACCESS_ISSUER || 'https://pistisai.cloudflareaccess.com';
  const jwksUri =
    process.env.CF_ACCESS_JWKS_URL ||
    'https://pistisai.cloudflareaccess.com/cdn-cgi/access/certs';

  return {
    access: {
      jwksUri,
      audience,
      issuer,
    },
    cache: {
      validationDuration: parseInt(process.env.AUTH_CACHE_DURATION || '300000'), // 5 minutes
      jwksDuration: parseInt(process.env.JWKS_CACHE_DURATION || '3600000'), // 1 hour
    },
    bruteForce: {
      threshold: parseInt(process.env.BRUTE_FORCE_THRESHOLD || '5'),
      window: parseInt(process.env.BRUTE_FORCE_WINDOW || '300000'), // 5 minutes
      blockDuration: parseInt(process.env.BRUTE_FORCE_BLOCK_DURATION || '3600000'), // 1 hour
    },
    audit: {
      maxHistorySize: parseInt(process.env.AUDIT_MAX_HISTORY || '10000'),
      retentionDays: parseInt(process.env.AUDIT_RETENTION_DAYS || '90'),
    },
  };
}

/**
 * Validate authentication configuration
 */
export function validateAuthConfig(config: AuthConfig): void {
  if (config.cache.validationDuration < 0) {
    throw new Error('Validation cache duration must be positive');
  }

  if (config.bruteForce.threshold < 1) {
    throw new Error('Brute force threshold must be at least 1');
  }

  if (config.bruteForce.window < 1000) {
    throw new Error('Brute force window must be at least 1 second');
  }

  if (config.audit.maxHistorySize < 100) {
    throw new Error('Audit history size must be at least 100');
  }
}

/**
 * Get default authentication configuration
 */
export function getDefaultAuthConfig(): AuthConfig {
  // Return configuration based on environment without fallbacks
  return loadAuthConfig();
}
