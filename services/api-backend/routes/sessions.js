import express from 'express';
import { z } from 'zod';
const router = express.Router();
import db from '../database/db-pool.js';
import { authenticateJWT } from '../middleware/auth.js';
import { adminAuth } from '../middleware/admin-auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import logger from '../logger.js';

const updateSessionTokensSchema = {
  body: z.object({
    sessionToken: z.string().min(1, 'sessionToken is required'),
    accessToken: z.string().optional(),
    idToken: z.string().optional(),
    refreshToken: z.string().optional(),
  }),
};

const tokenParamSchema = {
  params: z.object({
    token: z.string().min(1, 'token is required'),
  }),
};

const bodyTokenSchema = {
  body: z.object({
    sessionToken: z.string().min(1, 'sessionToken is required'),
  }),
};

/**
 * Resolve the internal users.id for the authenticated Access subject.
 *
 * Sessions are keyed by users.id, not by the session token: every session
 * read or mutation must be scoped to the caller. A valid JWT for one account
 * must never be able to look up, overwrite or invalidate another account's
 * session just by supplying that session's token.
 */
async function resolveSessionOwnerId(req) {
  const fromSession = req.auth?.session?.user_id ?? req.auth?.session?.userId;
  if (fromSession) {
    return fromSession;
  }

  const sub = req.user?.sub ?? req.auth?.payload?.sub;
  if (!sub) {
    return null;
  }

  const result = await db.query(
    `SELECT u.id FROM users u
     WHERE u.jwt_id = $1
        OR u.access_subject::text = $1
        OR u.id::text = $1
        OR EXISTS (
             SELECT 1 FROM user_auth_subjects s
             WHERE s.user_id = u.id AND s.subject = $1
           )
     LIMIT 1`,
    [sub],
  );
  return result.rows[0]?.id ?? null;
}

/**
 * POST /auth/sessions
 * Legacy endpoint - now deprecated.
 * Sessions are now automatically synchronized via authenticateJWT middleware.
 */
router.post('/', async (req, res) => {
  res.status(410).json({
    error: 'Gone',
    message:
      'This manual session registration endpoint is deprecated. Sessions are now handled automatically via JWT middleware.',
  });
});

/**
 * GET /auth/sessions/current
 * Get current session for the authenticated user
 */
router.get('/current', authenticateJWT, async (req, res) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    // The syncSession middleware already ensured the session exists
    const result = await db.query(
      `SELECT s.id, s.session_token, s.expires_at,
              s.jwt_access_token, s.jwt_id_token, s.refresh_token,
              s.created_at, s.last_activity, s.is_active,
              u.id as user_id, u.jwt_id, u.email, u.name, u.nickname, u.picture
       FROM user_sessions s
       JOIN users u ON s.user_id = u.id
       WHERE u.jwt_id = $1 AND s.is_active = true AND s.expires_at > NOW()
       ORDER BY s.last_activity DESC LIMIT 1`,
      [req.user.sub],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Session not found' });
    }

    const session = result.rows[0];

    res.json({
      session: {
        id: session.id,
        token: session.session_token,
        expiresAt: session.expires_at,
        jwtAccessToken: session.jwt_access_token,
        jwtIdToken: session.jwt_id_token,
        refreshToken: session.refresh_token,
        createdAt: session.created_at,
        lastActivity: session.last_activity,
        isActive: session.is_active,
      },
      user: {
        id: session.jwt_id,
        email: session.email,
        name: session.name,
        nickname: session.nickname,
        picture: session.picture,
      },
    });
  } catch (error) {
    logger.error('Error getting current session:', error);
    res.status(500).json({ error: 'Failed to get current session' });
  }
});

/**
 * Validate a session, but only for the authenticated owner of that session.
 * The caller's JWT sub is resolved to users.id and both the lookup and the
 * last-activity update are scoped to it. Stored IdP tokens are only returned
 * here after that ownership check succeeds.
 */
async function validateOwnedSession(req, res, token) {
  try {
    const ownerId = await resolveSessionOwnerId(req);
    if (!ownerId) {
      return res.status(401).json({
        error: 'Invalid token: no user identity',
        code: 'USER_ID_MISSING',
      });
    }

    const result = await db.query(
      `SELECT s.id, s.session_token, s.expires_at,
              s.jwt_access_token, s.jwt_id_token, s.refresh_token,
              s.created_at, s.last_activity, s.is_active,
              u.id as user_id, u.jwt_id, u.email, u.name, u.nickname, u.picture
       FROM user_sessions s
       JOIN users u ON s.user_id = u.id
       WHERE s.session_token = $1
         AND s.user_id = $2
         AND s.is_active = true
         AND s.expires_at > NOW()`,
      [token, ownerId],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Session not found or expired' });
    }

    const session = result.rows[0];

    // Update last activity for this owner's session only
    await db.query(
      'UPDATE user_sessions SET last_activity = NOW() WHERE id = $1 AND user_id = $2',
      [session.id, ownerId],
    );

    res.json({
      session: {
        id: session.id,
        token: session.session_token,
        expiresAt: session.expires_at,
        jwtAccessToken: session.jwt_access_token,
        jwtIdToken: session.jwt_id_token,
        refreshToken: session.refresh_token,
        createdAt: session.created_at,
        lastActivity: session.last_activity,
        isActive: session.is_active,
      },
      user: {
        id: session.jwt_id,
        email: session.email,
        name: session.name,
        nickname: session.nickname,
        picture: session.picture,
      },
    });
  } catch (error) {
    logger.error('Error validating session:', error);
    res.status(500).json({ error: 'Failed to validate session' });
  }
}

/**
 * GET /auth/sessions/validate/:token
 * @deprecated The token in the URL is recorded by request logging. Use POST
 * /auth/sessions/validate with the token in the JSON body instead. This route
 * is kept for older app versions and is still scoped to the authenticated
 * owner.
 */
router.get('/validate/:token', validateSchema(tokenParamSchema), authenticateJWT, (req, res) =>
  validateOwnedSession(req, res, req.params.token),
);

/**
 * POST /auth/sessions/validate
 * Preferred validation route: the session token travels in the request body
 * instead of the URL path.
 */
router.post('/validate', validateSchema(bodyTokenSchema), authenticateJWT, (req, res) =>
  validateOwnedSession(req, res, req.body.sessionToken),
);

/**
 * PUT /auth/sessions/tokens
 * Update tokens for the current session
 */
router.put('/tokens', validateSchema(updateSessionTokensSchema), authenticateJWT, async (req, res) => {
  try {
    const ownerId = await resolveSessionOwnerId(req);
    if (!ownerId) {
      return res.status(401).json({
        error: 'Invalid token: no user identity',
        code: 'USER_ID_MISSING',
      });
    }

    const { sessionToken, accessToken, idToken, refreshToken } = req.body;

    const result = await db.query(
      `UPDATE user_sessions
       SET jwt_access_token = $1,
           jwt_id_token = $2,
           refresh_token = $3,
           last_activity = NOW()
       WHERE session_token = $4 AND user_id = $5 AND is_active = true
       RETURNING id`,
      [accessToken, idToken, refreshToken, sessionToken, ownerId],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Session not found or inactive' });
    }

    res.json({ message: 'Tokens updated successfully' });
  } catch (error) {
    logger.error('Error updating session tokens:', error);
    res.status(500).json({ error: 'Failed to update session tokens' });
  }
});

/**
 * Deactivate a session, but only if it belongs to the authenticated caller.
 */
async function invalidateOwnedSession(req, res, token) {
  try {
    const ownerId = await resolveSessionOwnerId(req);
    if (!ownerId) {
      return res.status(401).json({
        error: 'Invalid token: no user identity',
        code: 'USER_ID_MISSING',
      });
    }

    const result = await db.query(
      'UPDATE user_sessions SET is_active = false WHERE session_token = $1 AND user_id = $2',
      [token, ownerId],
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Session not found' });
    }

    res.status(204).send();
  } catch (error) {
    logger.error('Error invalidating session:', error);
    res.status(500).json({ error: 'Failed to invalidate session' });
  }
}

/**
 * DELETE /auth/sessions/:token
 * @deprecated The token in the URL is recorded by request logging. Use POST
 * /auth/sessions/invalidate with the token in the JSON body instead. This
 * route is kept for older app versions and is still scoped to the owner.
 */
router.delete('/:token', validateSchema(tokenParamSchema), authenticateJWT, (req, res) =>
  invalidateOwnedSession(req, res, req.params.token),
);

/**
 * POST /auth/sessions/invalidate
 * Preferred invalidation route: the session token stays out of the URL.
 */
router.post('/invalidate', validateSchema(bodyTokenSchema), authenticateJWT, (req, res) =>
  invalidateOwnedSession(req, res, req.body.sessionToken),
);

/**
 * POST /auth/sessions/cleanup
 * Delete expired sessions. Admin only: the delete covers every user.
 *
 * Revoked sessions (is_active = false) are kept until they expire, because
 * token validation looks them up to keep the revoked token rejected (#892).
 */
router.post('/cleanup', adminAuth(['terminate_sessions']), async (req, res) => {
  try {
    const result = await db.query(
      'DELETE FROM user_sessions WHERE expires_at < NOW()',
    );

    res.json({ deleted: result.rowCount });
  } catch (error) {
    logger.error('Error cleaning up sessions:', error);
    res.status(500).json({ error: 'Failed to cleanup sessions' });
  }
});

export default router;
