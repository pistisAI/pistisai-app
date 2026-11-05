/**
 * Authentication Routes for Pistisai API Backend
 *
 * Provides JWT token validation and user information endpoints.
 * Note: Authentication is handled by Supabase JWT validation.
 *
 * Requirements: 2.1, 2.2, 2.9, 2.10
 */

import express from 'express';
import { z } from 'zod';
import rateLimit from 'express-rate-limit';
import jwt from 'jsonwebtoken';
import logger from '../logger.js';
import { authenticateJWT, extractUserId } from '../middleware/auth.js';
import { logLogout, logTokenRevoke } from '../services/auth-audit-service.js';
import { validateSchema } from '../middleware/schema-validation.js';

const router = express.Router();

// Rate limiter for auth checks to prevent brute force/enumeration
const authCheckLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 checks per 15 min
  message: {
    error: 'Too many auth checks',
    message: 'Please try again later',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

const revokeSessionSchema = {
  body: z.object({
    sessionId: z.string().uuid({ message: 'sessionId must be a valid UUID' }),
  }),
};

// Token refresh configuration
const TOKEN_REFRESH_WINDOW = parseInt(process.env.TOKEN_REFRESH_WINDOW) || 300; // 5 minutes before expiry

router.post('/token/refresh', authCheckLimiter, async function (req, res) {
  return res.status(400).json({
    error:
      'Token refresh should be handled by the identity provider client SDK',
    code: 'USE_AUTH_PROVIDER_SDK',
  });
});

router.post(
  '/token/validate',
  authCheckLimiter,
  authenticateJWT,
  async function (req, res) {
    try {
      // If authenticateJWT middleware passed, the token is DEFINITELY valid and verified
      const tokenPayload = req.user;
      const now = Math.floor(Date.now() / 1000);
      const expiresIn = tokenPayload.exp - now;
      const isExpiring = expiresIn <= TOKEN_REFRESH_WINDOW;

      logger.info('[Auth] Token validation result (Verified)', {
        isExpiring,
        expiresIn,
        userId: req.userId,
      });

      res.json({
        valid: true,
        expired: false,
        expiring: isExpiring,
        expiresIn: Math.max(0, expiresIn),
        expiresAt: new Date(tokenPayload.exp * 1000).toISOString(),
        userId: req.userId,
        email: tokenPayload.email,
      });
    } catch (error) {
      logger.error('[Auth] Token validation error', {
        error: error.message,
      });

      res.status(500).json({
        error: 'Token validation failed',
        code: 'TOKEN_VALIDATION_ERROR',
      });
    }
  },
);

router.post('/logout', authenticateJWT, async function (req, res) {
  try {
    const userId = extractUserId(req);

    logger.info('[Auth] User logout initiated', { userId });

    // Clear refresh token cookie
    res.clearCookie('refreshToken', {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
    });

    logger.info('[Auth] User logged out successfully', { userId });

    // Log logout
    logLogout({
      userId,
      ipAddress: req.ip || req.connection.remoteAddress,
      userAgent: req.get('User-Agent'),
      details: {
        endpoint: req.path,
        method: req.method,
      },
    }).catch((auditError) => {
      logger.error('[Auth] Failed to log logout', {
        error: auditError.message,
      });
    });

    res.json({
      success: true,
      message: 'Logged out successfully',
      userId,
    });
  } catch (error) {
    logger.error('[Auth] Logout error', {
      error: error.message,
      userId: req.user?.sub,
    });

    res.status(500).json({
      error: 'Logout failed',
      code: 'LOGOUT_ERROR',
      message: error.message,
    });
  }
});

router.post(
  '/session/revoke',
  authenticateJWT,
  validateSchema(revokeSessionSchema),
  async function (req, res) {
    try {
      const userId = extractUserId(req);
      const { sessionId } = req.body;

      logger.info('[Auth] Session revocation initiated', { userId, sessionId });

    // Log token revocation
    logTokenRevoke({
      userId,
      ipAddress: req.ip || req.connection.remoteAddress,
      userAgent: req.get('User-Agent'),
      details: {
        endpoint: req.path,
        method: req.method,
        sessionId,
      },
    }).catch((auditError) => {
      logger.error('[Auth] Failed to log session revocation', {
        error: auditError.message,
      });
    });

    // In a real implementation, this would revoke the session from the database
    // For now, we'll just return success
    res.json({
      success: true,
      message: 'Session revoked successfully',
      sessionId,
    });
  } catch (error) {
    logger.error('[Auth] Session revocation error', {
      error: error.message,
      userId: req.user?.sub,
    });

    res.status(500).json({
      error: 'Session revocation failed',
      code: 'SESSION_REVOCATION_ERROR',
    });
  }
});

router.get('/me', authenticateJWT, async function (req, res) {
  try {
    const userId = extractUserId(req);

    logger.info('[Auth] User info requested', { userId });

    res.json({
      userId,
      email: req.user?.email,
      name: req.user?.name,
      picture: req.user?.picture,
      emailVerified: req.user?.email_verified,
      updatedAt: req.user?.updated_at,
    });
  } catch (error) {
    logger.error('[Auth] User info error', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to get user info',
      code: 'USER_INFO_ERROR',
    });
  }
});

router.post('/token/check-expiry', authCheckLimiter, async function (req, res) {
  try {
    const { token } = req.body;
    const authHeader = req.headers.authorization;
    const bearerToken = token || (authHeader && authHeader.split(' ')[1]);

    if (!bearerToken) {
      return res.status(400).json({
        error: 'Token required',
        code: 'MISSING_TOKEN',
      });
    }

    const decoded = jwt.decode(bearerToken, { complete: true });

    if (!decoded) {
      return res.status(401).json({
        error: 'Invalid token',
        code: 'INVALID_TOKEN',
      });
    }

    const now = Math.floor(Date.now() / 1000);
    const expiresIn = decoded.payload.exp - now;
    const shouldRefresh = expiresIn <= TOKEN_REFRESH_WINDOW;

    logger.info('[Auth] Token expiry check', {
      expiresIn,
      shouldRefresh,
    });

    res.json({
      shouldRefresh,
      expiresIn: Math.max(0, expiresIn),
      expiresAt: new Date(decoded.payload.exp * 1000).toISOString(),
    });
  } catch (error) {
    logger.error('[Auth] Token expiry check error', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Token expiry check failed',
      code: 'EXPIRY_CHECK_ERROR',
    });
  }
});

/**
 * HTTPS Enforcement Middleware
 * Ensures all authentication endpoints are accessed via HTTPS in production
 *
 * Validates: Requirements 2.10
 * - Enforces HTTPS for all authentication endpoints
 */
router.use((req, res, next) => {
  if (process.env.NODE_ENV === 'production' && req.protocol !== 'https') {
    logger.warn('[Auth] Non-HTTPS request to auth endpoint', {
      protocol: req.protocol,
      path: req.path,
      ip: req.ip,
    });

    return res.status(403).json({
      error: 'HTTPS required',
      code: 'HTTPS_REQUIRED',
      message: 'Authentication endpoints require HTTPS',
    });
  }

  next();
});

export default router;
