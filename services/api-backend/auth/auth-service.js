/**
 * @fileoverview Authentication Service for Pistisai Tunnel
 * Handles JWT validation, session management, and role-based access control
 * Migrated from Auth0 to Supabase Auth.
 */

import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import jwksClient from 'jwks-rsa';
import { TunnelLogger } from '../utils/logger.js';
import { DatabaseMigratorPG } from '../database/migrate-pg.js';

/**
 * Authentication service with JWT integration
 * Uses Supabase Auth for JWT validation (RS256)
 */
export class AuthService {
  constructor(config) {
    this.config = {
      SUPABASE_URL: process.env.SUPABASE_URL || 'https://bpqwsjshoqxvtdttzvbr.supabase.co',
      SUPABASE_JWKS_URI:
        process.env.SUPABASE_JWKS_URI ||
        `${process.env.SUPABASE_URL || 'https://bpqwsjshoqxvtdttzvbr.supabase.co'}/auth/v1/.well-known/jwks.json`,
      SESSION_TIMEOUT: parseInt(process.env.SESSION_TIMEOUT) || 3600000, // 1 hour
      MAX_SESSIONS_PER_USER: parseInt(process.env.MAX_SESSIONS_PER_USER) || 5,
      ...config,
    };

    this.logger = new TunnelLogger('auth-service');
    this.authDbMigrator = config.authDbMigrator || null;
    this.mainDbMigrator = config.dbMigrator || null;

    if (this.authDbMigrator) {
      this.db = this.authDbMigrator;
    } else if (this.mainDbMigrator) {
      this.db = this.mainDbMigrator;
    } else {
      this.db = new DatabaseMigratorPG();
    }

    this.initialized = false;

    // Initialize JWKS client for Supabase
    this.jwksClient = jwksClient({
      jwksUri: this.config.SUPABASE_JWKS_URI,
      cache: true,
      rateLimit: true,
      jwksRequestsPerMinute: 5,
    });
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
        'Authentication service initialized (Supabase RS256)',
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

  /**
   * Get signing key from JWKS
   */
  getKey(header, callback) {
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
   * Validate Supabase JWT token
   * Supabase JWTs: iss = {supabase_url}/auth/v1, aud = "authenticated", sub = user UUID
   */
  async validateToken(token, req = {}, preValidatedPayload = null) {
    try {
      let payload;

      if (preValidatedPayload) {
        this.logger.info('Using pre-validated token payload');
        payload = preValidatedPayload;
      } else if (
        token === 'mock_dev_access_token' &&
        process.env.NODE_ENV !== 'production'
      ) {
        this.logger.info('Using mock developer token bypass');
        payload = {
          iss: `${this.config.SUPABASE_URL}/auth/v1`,
          sub: '00000000-0000-0000-0000-000000000000',
          aud: 'authenticated',
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
      if (
        token === 'mock_dev_access_token' &&
        process.env.NODE_ENV !== 'production'
      ) {
        this.logger.info(
          'Bypassing WebSocket token verification for mock developer token',
        );
        return {
          iss: `${this.config.SUPABASE_URL}/auth/v1`,
          sub: '00000000-0000-0000-0000-000000000000',
          aud: 'authenticated',
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
   * Resolve internal user ID from Supabase user ID
   */
  async resolveUserId(supabaseId, userInfo = {}) {
    try {
      // 1. Try to find existing user by supabase_id
      const existingUser = await this.runQuery(
        'SELECT id FROM users WHERE supabase_id = $1',
        [supabaseId],
        'get',
      );

      if (existingUser) {
        return existingUser.id;
      }

      // 2. Try to find user by email
      if (!userInfo.email) {
        this.logger.error('Supabase userInfo missing email claim', { supabaseId });
        throw new Error('Invalid token: missing email claim in userInfo');
      }
      const userEmail = userInfo.email;
      const existingByEmail = await this.runQuery(
        'SELECT id FROM users WHERE email = $1',
        [userEmail],
        'get',
      );

      if (existingByEmail) {
        this.logger.info('Found existing user by email, linking supabase_id', {
          userId: existingByEmail.id,
          email: userEmail,
        });

        await this.runQuery(
          `UPDATE users SET 
             supabase_id = $1, 
             name = COALESCE($2, name),
             nickname = COALESCE($3, nickname),
             picture = COALESCE($4, picture),
             email_verified = $5, 
             locale = COALESCE($6, locale),
             updated_at = NOW() 
           WHERE id = $7`,
          [
            supabaseId,
            userInfo.name,
            userInfo.nickname,
            userInfo.picture,
            userInfo.email_verified || false,
            userInfo.locale,
            existingByEmail.id,
          ],
          'run',
        );
        return existingByEmail.id;
      }

      // 3. Create new user
      this.logger.info('Creating new user record for Supabase ID', { supabaseId });

      const newUser = await this.runQuery(
        `INSERT INTO users (supabase_id, email, name, nickname, picture, email_verified, locale, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW()) RETURNING id`,
        [
          supabaseId,
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
        return newUser.rows[0].id;
      }

      throw new Error('Failed to create user record');
    } catch (error) {
      this.logger.error('Failed to resolve user ID', {
        supabaseId,
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
