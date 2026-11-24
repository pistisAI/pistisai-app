/**
 * #895: the DEV_BYPASS_TOKEN auth bypass is active only when NODE_ENV is
 * exactly 'development'. Uses the real AuthService and the real
 * authenticateJWT middleware on an Express route.
 */
import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import express from 'express';
import request from 'supertest';
import { AuthService } from '../../services/api-backend/auth/auth-service.js';

const DEV_TOKEN = 'dev-bypass-token-for-tests';
const KEYS = ['NODE_ENV', 'DEV_BYPASS_TOKEN'];

describe('dev bypass token is development-only (#895)', () => {
  const saved = {};

  beforeEach(() => {
    for (const key of KEYS) {
      saved[key] = process.env[key];
    }
    process.env.DEV_BYPASS_TOKEN = DEV_TOKEN;
  });

  afterEach(() => {
    for (const key of KEYS) {
      if (saved[key] === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = saved[key];
      }
    }
  });

  it('is active when NODE_ENV is exactly development', () => {
    process.env.NODE_ENV = 'development';
    const service = new AuthService({});
    expect(service.isDevBypassToken(DEV_TOKEN)).toBe(true);
  });

  it.each([
    ['unset', undefined],
    ['test', 'test'],
    ['staging', 'staging'],
    ['production', 'production'],
    ['Development (wrong case)', 'Development'],
  ])('is inactive when NODE_ENV is %s', (_label, value) => {
    if (value === undefined) {
      delete process.env.NODE_ENV;
    } else {
      process.env.NODE_ENV = value;
    }
    const service = new AuthService({});
    expect(service.devBypassToken).toBeNull();
    expect(service.isDevBypassToken(DEV_TOKEN)).toBe(false);
  });

  it('authenticateJWT does not accept the bypass token when NODE_ENV is unset', async () => {
    delete process.env.NODE_ENV;
    // Fresh module instance so the middleware builds its AuthService now.
    const { authenticateJWT } = await import(
      `../../services/api-backend/middleware/auth.js?unset=${Date.now()}`
    );
    const app = express();
    app.get('/protected', authenticateJWT, (req, res) => {
      res.json({ ok: true });
    });

    const res = await request(app)
      .get('/protected')
      .set('Authorization', `Bearer ${DEV_TOKEN}`);

    expect(res.status).toBe(401);
  });
});
