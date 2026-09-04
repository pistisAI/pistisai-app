/**
 * Authentication Configuration
 * Centralized configuration for authentication middleware (Supabase)
 */

export interface AuthConfig {
  supabase: {
    jwksUri: string;
    audience: string;
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
  const supabaseAudience = process.env.SUPABASE_AUDIENCE || 'authenticated';
  const supabaseUrl = process.env.SUPABASE_URL || 'https://bpqwsjshoqxvtdttzvbr.supabase.co';

  // Derive JWKS URI with no hardcoded fallback
  const supabaseJwksUri =
    process.env.SUPABASE_JWKS_URI ||
    `${supabaseUrl}/auth/v1/.well-known/jwks.json`;

  if (!supabaseJwksUri) {
    const missing = [];
    if (!supabaseAudience) missing.push('SUPABASE_AUDIENCE');
    if (!supabaseJwksUri) missing.push('SUPABASE_JWKS_URI (or SUPABASE_URL)');
    throw new Error(
      `CRITICAL: Missing Supabase configuration: ${missing.join(
        ', '
      )}. Zero-fallback policy in effect.`
    );
  }

  return {
    supabase: {
      jwksUri: supabaseJwksUri,
      audience: supabaseAudience,
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
