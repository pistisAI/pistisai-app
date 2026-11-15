/**
 * Authentication configuration for Cloudflare Access JWT validation.
 */

export interface AuthConfig {
  cloudflareAccess: {
    teamDomain: string;
    audience: string;
    jwksUri: string;
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
 * Load authentication configuration from environment variables.
 * Requires CF_ACCESS_TEAM_DOMAIN and CF_ACCESS_AUD (no hardcoded fallbacks).
 */
export function loadAuthConfig(): AuthConfig {
  const teamDomain = (process.env.CF_ACCESS_TEAM_DOMAIN || '')
    .trim()
    .replace(/^https?:\/\//, '')
    .replace(/\/$/, '');
  const audience = (process.env.CF_ACCESS_AUD || '').trim();

  const missing: string[] = [];
  if (!teamDomain) missing.push('CF_ACCESS_TEAM_DOMAIN');
  if (!audience) missing.push('CF_ACCESS_AUD');
  if (missing.length > 0) {
    throw new Error(
      `CRITICAL: Missing Cloudflare Access configuration: ${missing.join(
        ', '
      )}. Zero-fallback policy in effect.`
    );
  }

  const jwksUri =
    process.env.CF_ACCESS_JWKS_URI?.trim() ||
    `https://${teamDomain}/cdn-cgi/access/certs`;
  const issuer = `https://${teamDomain}`;

  return {
    cloudflareAccess: {
      teamDomain,
      audience,
      jwksUri,
      issuer,
    },
    cache: {
      validationDuration: parseInt(process.env.AUTH_CACHE_DURATION || '300000', 10),
      jwksDuration: parseInt(process.env.JWKS_CACHE_DURATION || '3600000', 10),
    },
    bruteForce: {
      threshold: parseInt(process.env.BRUTE_FORCE_THRESHOLD || '5', 10),
      window: parseInt(process.env.BRUTE_FORCE_WINDOW || '300000', 10),
      blockDuration: parseInt(process.env.BRUTE_FORCE_BLOCK_DURATION || '3600000', 10),
    },
    audit: {
      maxHistorySize: parseInt(process.env.AUDIT_MAX_HISTORY || '10000', 10),
      retentionDays: parseInt(process.env.AUDIT_RETENTION_DAYS || '90', 10),
    },
  };
}

/**
 * Validate authentication configuration
 */
export function validateAuthConfig(config: AuthConfig): void {
  if (!config.cloudflareAccess.jwksUri) {
    throw new Error('Cloudflare Access JWKS URI is required');
  }
  if (!config.cloudflareAccess.audience) {
    throw new Error('Cloudflare Access audience is required');
  }
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
  return loadAuthConfig();
}
