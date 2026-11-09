/**
 * @fileoverview Authentication Service for Pistisai Tunnel
 * Handles JWT validation, session management, and role-based access control
 * Identity is Cloudflare Access. Tokens are RS256 JWTs from the team certs.
 */

import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import jwksClient from 'jwks-rsa';
import { TunnelLogger } from '../utils/logger.js';
import { DatabaseMigratorPG } from '../database/migrate-pg.js';

function accessTeamDomain() {
  return (process.env.CF_ACCESS_TEAM_DOMAIN || '')
    .replace(/^https?:\/\//, '')
    .replace(/\/$/, '');
}

/**
 * Authentication service with JWT integration.
 * Uses Cloudflare Access certs for JWT validation (RS256).
 */
export class AuthService {
  constructor(config) {
    const teamDomain = accessTeamDomain();
    this.config = {
      ...config,
      CF_ACCESS_TEAM_DOMAIN: teamDomain,
      CF_ACCESS_AUD: process.env.CF_ACCESS_AUD || '',
      JWKS_URI: teamDomain
        ? `https://${teamDomain}/cdn-cgi/access/certs`
        : '',
      SESSION_TIMEOUT: parseInt(process.env.SESSION_TIMEOUT) || 3600000, // 1 hour
      MAX_SESSIONS_PER_USER: parseInt(process.env.MAX_SESSIONS_PER_USER) || 5,
    };

    this.logger = new TunnelLogger('auth-service');
    this.authDbMigrator = config.authDbMigrator || null;
    this.mainDbMigrator = config.dbMigrator || null;

    // Dev bypass token: only active when NODE_ENV !== 'production' AND
    // DEV_BYPASS_TOKEN is explicitly set. No hardcoded fallback — a known
    // literal in source would be a trivial auth bypass if NODE_ENV is mis-set.
    if (process.env.NODE_ENV !== 'production') {
      const configured = process.env.DEV_BYPASS_TOKEN;
      this.devBypassToken =
        typeof configured === 'string' && configured.length > 0
          ? configured
          : null;
    } else {
      this.devBypassToken = null;
    }

    if (this.authDbMigrator) {
      this.db = this.authDbMigrator;
    } else if (this.mainDbMigrator) {
      this.db = this.mainDbMigrator;
    } else {
      this.db = new DatabaseMigratorPG();
    }

    this.initialized = false;

    this.jwksClient = this.config.JWKS_URI
      ? jwksClient({
          jwksUri: this.config.JWKS_URI,
          cache: true,
          rateLimit: true,
          jwksRequestsPerMinute: 5,
        })
      : null;
  }

  /**
   * Returns true when the provided token matches the configured dev bypass token.
   * The bypass is only active when NODE_ENV !== 'production'.
   */
  isDevBypassToken(token) {
    if (!this.devBypassToken || !token) {
      return false;
    }
    return token === this.devBypassToken;
  }

  /**
   * Initialize authentication service
   */
  async initialize() {
    if (this.initialized) {
      return;
    }

    try {
      if (!this.authDbMigrator && !this.mainDbMigrator) {
        await this.db.initialize();
      }
      this.initialized = true;

      this.logger.info(
        'Authentication service initialized (Cloudflare Access RS256)',
      );

      this.startSessionCleanup();
    } catch (error) {
      this.logger.error('Failed to initialize authentication service', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Helper to execute queries on Postgres
   */
  async runQuery(sql, params = [], type = 'all') {
    const pgSql = sql.replace(/\?/g, (_, offset) => {
      const beforeSql = sql.substring(0, offset);
      const singleQuoteCount = (beforeSql.match(/'/g) || []).filter((_, i) => {
        if (i > 0 && beforeSql[i - 1] === '\\') {
          return false;
        }
        return true;
      }).length;
      if (singleQuoteCount % 2 === 1) {
        return '?';
      }
      const beforeReplaced = sql.substring(0, offset).replace(/\?/g, (_, o) => {
        const b = sql.substring(0, o);
        const sqc = (b.match(/'/g) || []).filter((_, i) => {
          if (i > 0 && b[i - 1] === '\\') {
            return false;
          }
          return true;
        }).length;
        return sqc % 2 === 0 ? 1 : 0;
      }).length;
      return `$${beforeReplaced + 1}`;
    });

    let finalSql = pgSql;
    if (
      type === 'run' &&
      sql.trim().toUpperCase().startsWith('INSERT') &&
      !sql.trim().toUpperCase().includes('RETURNING')
    ) {
      finalSql += ' RETURNING id';
    }

    try {
      const result = await this.db.pool.query(finalSql, params);

      if (type === 'run') {
        return {
          lastID: result.rows.length > 0 ? result.rows[0].id : null,
          changes: result.rowCount,
          rows: result.rows,
        };
      } else if (type === 'get') {
        return result.rows[0];
      } else {
        return result.rows;
      }
    } catch (err) {
      if (err.code === '23505') {
        const wrapper = new Error('UNIQUE constraint failed: ' + err.detail);
        wrapper.code = 'UNIQUE_VIOLATION';
        throw wrapper;
      }
      throw err;
    }
  }

  assertAccessAudience(payload) {
    const expected = this.config.CF_ACCESS_AUD;
    if (!expected) {
      return;
    }
    const aud = payload?.aud;
    const matches = Array.isArray(aud)
      ? aud.includes(expected)
      : aud === expected;
    if (!matches) {
      throw new Error('Cloudflare Access audience mismatch');
    }
  }

  /**
   * Get signing key from JWKS
   */
  getKey(header, callback) {
    if (!this.jwksClient) {
      callback(new Error('Cloudflare Access is not configured'));
      return;
    }
    this.jwksClient.getSigningKey(header.kid, (err, key) => {
      if (err) {
        callback(err);
        return;
      }
      const signingKey = key.getPublicKey();
      callback(null, signingKey);
    });
  }

  /**
   * Check if a token is valid and active in the database
   */
  async isTokenActive(userId, token) {
    const tokenHash = this.hashToken(token);
    try {
      const session = await this.runQuery(
        'SELECT is_active FROM user_sessions WHERE user_id = $1 AND jwt_token_hash = $2',
        [userId, tokenHash],
        'get',
      );

      if (session) {
        return session.is_active === true;
      }

      return false;
    } catch (error) {
      this.logger.error('Failed to check token status', {
        userId,
        error: error.message,
      });
      return false;
    }
  }

  /**
   * Synchronize session state from a validated JWT
   */
  async syncSession(tokenPayload, token, req) {
    return this.createOrUpdateSession(tokenPayload, token, req);
  }

  /**
   * Validate a Cloudflare Access JWT.
   * Access JWTs: iss is the team host, aud is the application audience.
   */
  async validateToken(token, req = {}, preValidatedPayload = null) {
    try {
      let payload;

      if (preValidatedPayload) {
        this.logger.info('Using pre-validated token payload');
        payload = preValidatedPayload;
      } else if (this.isDevBypassToken(token)) {
        this.logger.info('Using dev bypass token');
        payload = {
          iss: this.config.CF_ACCESS_TEAM_DOMAIN
            ? `https://${this.config.CF_ACCESS_TEAM_DOMAIN}`
            : 'cloudflare-access',
          sub: '00000000-0000-0000-0000-000000000000',
          aud: this.config.CF_ACCESS_AUD,
          email: '<EMAIL>',
          name: 'Christopher (Dev)',
          nickname: 'rightguy',
          exp: Math.floor(Date.now() / 1000) + 3600 * 24 * 365,
          iat: Math.floor(Date.now() / 1000),
          role: 'authenticated',
          app_metadata: { role: 'admin' },
          user_metadata: { name: 'Christopher (Dev)', nickname: 'rightguy' },
          scope: 'openid profile email admin',
        };
      } else {
        const decoded = jwt.decode(token, { complete: true });
        if (!decoded || !decoded.header) {
          throw new Error('Invalid token structure');
        }

        const alg = decoded.header.alg;
        this.logger.info(`Starting token validation (Alg: ${alg})`);

        payload = await new Promise((resolve, reject) => {
          jwt.verify(
            token,
            this.getKey.bind(this),
            { algorithms: ['RS256'] },
            (err, decodedToken) => {
              if (err) {
                reject(err);
              } else {
                resolve(decodedToken);
              }
            },
          );
        });

        this.assertAccessAudience(payload);
        this.logger.info('Token verification successful');
      }

      const session = await this.createOrUpdateSession(payload, token, req);

      this.logger.info('Token validated successfully', {
        userId: payload.sub,
        sessionId: session.id,
      });

      return {
        valid: true,
        payload: payload,
        session: session,
      };
    } catch (error) {
      this.logger.warn(`Token validation failed: ${error.message}`, {
        error: error.message,
        ip: req.ip,
      });

      await this.logSecurityEvent('token_validation_failure', {
        error: error.message,
        ip: req.ip,
        userAgent: req.headers?.['user-agent'],
      });

      return {
        valid: false,
        error: error.message,
      };
    }
  }

  /**
   * Validate JWT token for WebSocket connections
   */
  async validateTokenForWebSocket(token) {
    try {
      if (this.isDevBypassToken(token)) {
        this.logger.info('Bypassing WebSocket token verification for dev token');
        return {
          iss: this.config.CF_ACCESS_TEAM_DOMAIN
            ? `https://${this.config.CF_ACCESS_TEAM_DOMAIN}`
            : 'cloudflare-access',
          sub: '00000000-0000-0000-0000-000000000000',
          aud: this.config.CF_ACCESS_AUD,
          email: '<EMAIL>',
          name: 'Christopher (Dev)',
          nickname: 'rightguy',
          exp: Math.floor(Date.now() / 1000) + 3600 * 24 * 365,
          iat: Math.floor(Date.now() / 1000),
          role: 'authenticated',
          app_metadata: { role: 'admin' },
          user_metadata: { name: 'Christopher (Dev)', nickname: 'rightguy' },
          scope: 'openid profile email admin',
        };
      }

      const decoded = jwt.decode(token, { complete: true });
      if (!decoded || !decoded.header) {
        throw new Error('Invalid token structure');
      }

      const verified = await new Promise((resolve, reject) => {
        jwt.verify(
          token,
          this.getKey.bind(this),
          { algorithms: ['RS256'] },
          (err, decodedToken) => {
            if (err) {
              reject(err);
            } else {
              resolve(decodedToken);
            }
          },
        );
      });

      this.assertAccessAudience(verified);
      this.logger.info('WebSocket token verification successful', {
        userId: verified.sub,
        exp: verified.exp,
      });

      return verified;
    } catch (error) {
      this.logger.warn('WebSocket token validation failed', {
        error: error.message,
      });

      throw error;
    }
  }

  /**
   * Link an Access subject to an internal user without clobbering the primary id.
   */
  async linkAuthSubject(userId, accessSub) {
    await this.runQuery(
      `INSERT INTO user_auth_subjects (subject, user_id)
       VALUES ($1, $2)
       ON CONFLICT (subject) DO UPDATE SET user_id = EXCLUDED.user_id`,
      [accessSub, userId],
      'run',
    );
  }

  /**
   * Resolve internal user ID from a Cloudflare Access subject (`sub`).
   * Same email with a new Access sub (OTP then Google) maps to one user.
   * Never overwrites users.supabase_id once set — that would orphan rows keyed
   * by the previous subject. Additional subjects are stored in user_auth_subjects.
   */
  async resolveUserId(accessSub, userInfo = {}) {
    try {
      // 1. Primary subject column
      const existingUser = await this.runQuery(
        'SELECT id FROM users WHERE supabase_id = $1',
        [accessSub],
        'get',
      );
      if (existingUser) {
        await this.linkAuthSubject(existingUser.id, accessSub);
        return existingUser.id;
      }

      // 2. Previously linked alternate Access subject
      const bySubject = await this.runQuery(
        'SELECT user_id AS id FROM user_auth_subjects WHERE subject = $1',
        [accessSub],
        'get',
      );
      if (bySubject) {
        return bySubject.id;
      }

      // 3. Same email, different Access sub (OTP / Google / GitHub)
      if (!userInfo.email) {
        this.logger.error('Access userInfo missing email claim', { accessSub });
        throw new Error('Invalid token: missing email claim in userInfo');
      }
      const userEmail = userInfo.email;
      const existingByEmail = await this.runQuery(
        'SELECT id, supabase_id FROM users WHERE email = $1',
        [userEmail],
        'get',
      );

      if (existingByEmail) {
        this.logger.info('Found existing user by email; linking Access subject', {
          userId: existingByEmail.id,
          email: userEmail,
        });

        // Keep the original supabase_id. Only refresh profile fields.
        await this.runQuery(
          `UPDATE users SET
             name = COALESCE($1, name),
             nickname = COALESCE($2, nickname),
             picture = COALESCE($3, picture),
             email_verified = $4,
             locale = COALESCE($5, locale),
             updated_at = NOW()
           WHERE id = $6`,
          [
            userInfo.name,
            userInfo.nickname,
            userInfo.picture,
            userInfo.email_verified || false,
            userInfo.locale,
            existingByEmail.id,
          ],
          'run',
        );
        await this.linkAuthSubject(existingByEmail.id, accessSub);
        return existingByEmail.id;
      }

      // 4. Create new user; first subject becomes supabase_id
      this.logger.info('Creating new user record for Access subject', { accessSub });

      const newUser = await this.runQuery(
        `INSERT INTO users (supabase_id, email, name, nickname, picture, email_verified, locale, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW()) RETURNING id`,
        [
          accessSub,
          userEmail,
          userInfo.name,
          userInfo.nickname,
          userInfo.picture,
          userInfo.email_verified || false,
          userInfo.locale,
        ],
        'run',
      );

      if (newUser && newUser.rows && newUser.rows.length > 0) {
        const userId = newUser.rows[0].id;
        await this.linkAuthSubject(userId, accessSub);
        return userId;
      }

      throw new Error('Failed to create user record');
    } catch (error) {
      this.logger.error('Failed to resolve user ID', {
        accessSub,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Create or update user session
   */
  async createOrUpdateSession(tokenPayload, token, req) {
    this.logger.info('Creating/updating session', { tokenType: typeof token });
    const supabaseId = tokenPayload.sub;
    const tokenHash = this.hashToken(token);
    const expiresAt = new Date(tokenPayload.exp * 1000).toISOString();
    const ip = req.ip || req.socket?.remoteAddress;
    const userAgent = req.headers?.['user-agent'];

    try {
      const userId = await this.resolveUserId(supabaseId, tokenPayload);

      const existingSession = await this.runQuery(
        'SELECT * FROM user_sessions WHERE user_id = $1 AND jwt_token_hash = $2',
        [userId, tokenHash],
        'get',
      );

      if (existingSession) {
        await this.runQuery(
          'UPDATE user_sessions SET last_activity = NOW(), expires_at = $1 WHERE id = $2',
          [expiresAt, existingSession.id],
          'run',
        );
        return existingSession;
      }

      await this.cleanupUserSessions(userId);

      await this.runQuery(
        'INSERT INTO user_sessions (user_id, jwt_token_hash, expires_at, ip_address, user_agent, session_token)' +
          'VALUES ($1, $2, $3, $4, $5, $6)',
        [userId, tokenHash, expiresAt, ip, userAgent, this.generateSessionId()],
        'run',
      );

      const newSession = await this.runQuery(
        'SELECT * FROM user_sessions WHERE user_id = $1 AND jwt_token_hash = $2',
        [userId, tokenHash],
        'get',
      );

      return newSession;
    } catch (error) {
      this.logger.error('Failed to create/update session', {
        error: error.message,
        supabaseId,
      });
      throw error;
    }
  }

  /**
   * Clean up expired sessions for a user
   */
  async cleanupUserSessions(userId) {
    try {
      // Keep only the most recent sessions up to MAX_SESSIONS_PER_USER
      await this.runQuery(
        `DELETE FROM user_sessions 
         WHERE user_id = $1 
         AND id NOT IN (
           SELECT id FROM user_sessions 
           WHERE user_id = $1 
           ORDER BY last_activity DESC 
           LIMIT $2
         )`,
        [userId, this.config.MAX_SESSIONS_PER_USER],
        'run',
      );

      // Also clean up expired sessions
      await this.runQuery(
        'DELETE FROM user_sessions WHERE expires_at < NOW()',
        [],
        'run',
      );
    } catch (error) {
      this.logger.error('Failed to clean up user sessions', {
        userId,
        error: error.message,
      });
    }
  }

  /**
   * Start periodic session cleanup
   */
  startSessionCleanup() {
    setInterval(async () => {
      try {
        await this.runQuery(
          'DELETE FROM user_sessions WHERE expires_at < NOW()',
          [],
          'run',
        );
      } catch (error) {
        this.logger.error('Session cleanup failed', {
          error: error.message,
        });
      }
    }, 15 * 60 * 1000); // Every 15 minutes
  }

  /**
   * Hash a token for secure storage
   */
  hashToken(token) {
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  /**
   * Generate a unique session ID
   */
  generateSessionId() {
    return crypto.randomBytes(32).toString('hex');
  }

  /**
   * Log a security event
   */
  async logSecurityEvent(eventType, details) {
    try {
      await this.runQuery(
        `INSERT INTO security_events (event_type, details, ip_address, created_at)
         VALUES ($1, $2::jsonb, $3, NOW())`,
        [eventType, JSON.stringify(details), details.ip || null],
        'run',
      );
    } catch (error) {
      this.logger.error('Failed to log security event', {
        eventType,
        error: error.message,
      });
    }
  }

  /**
   * Verify JWT token (alias for validateToken) - returns promise
   */
  verifyToken(token, req = {}) {
    return this.validateToken(token, req);
  }
}
