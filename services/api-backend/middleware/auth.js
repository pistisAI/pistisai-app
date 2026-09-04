/**
 * Authentication Middleware for Pistisai API Backend
 *
 * Provides JWT authentication and authorization for API endpoints
 * with user ID extraction utilities.
 *
 * Migrated from Auth0 to Supabase Auth.
 */

import { AuthService } from '../auth/auth-service.js';
import logger from '../logger.js';

// JWT configuration - Supabase Auth
const SUPABASE_URL =
  process.env.SUPABASE_URL || 'https://bpqwsjshoqxvtdttzvbr.supabase.co';
const SUPABASE_JWKS_URI =
  process.env.SUPABASE_JWKS_URI ||
  `${SUPABASE_URL}/auth/v1/.well-known/jwks.json`;

let authService = null;

function getAuthService() {
  if (!authService) {
    authService = new AuthService({
      SUPABASE_URL,
      SUPABASE_JWKS_URI,
    });
  }
  return authService;
}

/**
 * Express middleware for JWT authentication
 */
export const authenticateJwt = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization || req.headers.Authorization;
    const token =
      authHeader && authHeader.startsWith('Bearer ')
        ? authHeader.substring(7)
        : null;

    if (!token) {
      return res.status(401).json({
        error: 'Authorization header missing or invalid',
        code: 'AUTH_HEADER_MISSING',
      });
    }

    // Mock developer token bypass (non-production only)
    if (token === 'mock_dev_access_token' && process.env.NODE_ENV !== 'production') {
      logger.info(' [Auth] Bypassing authentication for mock developer token');
      req.auth = {
        token: 'mock_dev_access_token',
        payload: {
          iss: `${SUPABASE_URL}/auth/v1`,
          sub: '00000000-0000-0000-0000-000000000000',
          aud: 'authenticated',
          email: 'dev@pistisai.app',
          name: 'Christopher (Dev)',
          nickname: 'rightguy',
          exp: Math.floor(Date.now() / 1000) + 3600 * 24 * 365,
          iat: Math.floor(Date.now() / 1000),
          role: 'authenticated',
          app_metadata: { role: 'admin' },
          user_metadata: { name: 'Christopher (Dev)', nickname: 'rightguy' },
          scope: 'openid profile email admin',
        },
      };
      return next();
    }

    // Validate token via AuthService
    const service = getAuthService();
    const result = await service.validateToken(token, req);

    if (!result.valid) {
      logger.warn(' [Auth] JWT verification failed', {
        error: result.error,
        path: req.path,
      });

      // Differentiate expired vs invalid
      if (result.error?.includes('expired') || result.error?.includes('exp')) {
        return res.status(401).json({
          error: 'Token expired',
          code: 'TOKEN_EXPIRED',
        });
      }

      return res.status(401).json({
        error: 'Invalid token',
        code: 'TOKEN_INVALID',
      });
    }

    req.auth = {
      token,
      payload: result.payload,
      session: result.session,
    };
    req.user = result.payload;

    next();
  } catch (error) {
    logger.error(' [Auth] Middleware error', {
      error: error.message,
      path: req.path,
    });
    return res.status(500).json({
      error: 'Authentication error',
      code: 'AUTH_ERROR',
    });
  }
};

/**
 * Extract user ID from request (set by authenticateJwt middleware)
 */
export const extractUserId = (req, res, next) => {
  if (!req.auth?.payload?.sub) {
    return res.status(401).json({
      error: 'User ID not available',
      code: 'USER_ID_MISSING',
    });
  }

  req.userId = req.auth.payload.sub;
  next();
};

/**
 * Synchronize validated JWT sessions with the auth service when a raw bearer
 * token is available on the request.
 */
export async function syncSession(req, res, next) {
  try {
    if (process.env.NODE_ENV === 'test') {
      return next();
    }

    if (req.auth?.payload) {
      req.user = req.auth.payload;
      req.userId = req.auth.payload.sub;
    }

    const userId = req.userId || req.auth?.payload?.sub;
    if (!userId) {
      logger.warn(' [Auth] No sub claim in token');
      return res.status(401).json({ error: 'Invalid token: missing sub' });
    }

    const authHeader = req.headers.authorization || req.headers.Authorization;
    const bearerToken =
      typeof authHeader === 'string' && authHeader.startsWith('Bearer ')
        ? authHeader.substring(7)
        : null;
    const token = bearerToken || req.auth?.token;

    if (typeof token !== 'string' || token.length === 0) {
      logger.debug(
        ' [Auth] Raw token unavailable; skipping session synchronization',
      );
      return next();
    }

    const service = getAuthService();
    let timeoutId;
    try {
      const result = await Promise.race([
        service.syncSession(req.auth.payload, token, req),
        new Promise((_, reject) => {
          timeoutId = setTimeout(() => reject(new Error('Timeout')), 2000);
        }),
      ]);

      if (!result.success) {
        logger.warn(' [Auth] Session sync failed', {
          userId,
          reason: result.error,
        });
      }
    } catch (syncError) {
      logger.error(' [Auth] Session sync error or timeout (continuing)', {
        userId,
        error: syncError.message,
      });
    } finally {
      clearTimeout(timeoutId);
    }

    next();
  } catch (error) {
    logger.error(' [Auth] syncSession error', { error: error.message });
    res.status(401).json({ error: 'Authentication failed' });
  }
}

/**
 * Require admin role middleware (requires authenticateJwt first)
 */
export const requireAdmin = (req, res, next) => {
  const roles = req.auth?.payload?.['https://pistisai.app/roles'] || [];
  const appRole = req.auth?.payload?.app_metadata?.role;
  const isAdmin =
    roles.includes('admin') === true ||
    appRole === 'admin' ||
    req.auth?.payload?.role === 'admin';

  if (!isAdmin) {
    logger.warn(' [Auth] Admin access denied', {
      userId: req.auth?.payload?.sub,
      path: req.path,
    });
    return res.status(403).json({
      error: 'Admin access required',
      code: 'FORBIDDEN',
    });
  }

  next();
};

/**
 * Optional auth middleware — attaches user if token present, does not reject
 */
export const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization || req.headers.Authorization;
    const token =
      authHeader && authHeader.startsWith('Bearer ')
        ? authHeader.substring(7)
        : null;

    if (!token) {
      req.auth = null;
      req.user = null;
      return next();
    }

    if (token === 'mock_dev_access_token' && process.env.NODE_ENV !== 'production') {
      req.auth = {
        token: 'mock_dev_access_token',
        payload: {
          iss: `${SUPABASE_URL}/auth/v1`,
          sub: '00000000-0000-0000-0000-000000000000',
          aud: 'authenticated',
          email: 'dev@pistisai.app',
          name: 'Christopher (Dev)',
          nickname: 'rightguy',
          exp: Math.floor(Date.now() / 1000) + 3600 * 24 * 365,
          iat: Math.floor(Date.now() / 1000),
          role: 'authenticated',
          app_metadata: { role: 'admin' },
          user_metadata: { name: 'Christopher (Dev)', nickname: 'rightguy' },
          scope: 'openid profile email admin',
        },
      };
      req.user = req.auth.payload;
      return next();
    }

    const service = getAuthService();
    const result = await service.validateToken(token, req);

    if (result.valid) {
      req.auth = {
        token,
        payload: result.payload,
        session: result.session,
      };
      req.user = result.payload;
    } else {
      req.auth = null;
      req.user = null;
    }
  } catch {
    req.auth = null;
    req.user = null;
  }
  next();
};

export const checkJwt = authenticateJwt;

export { getAuthService };
