/**
 * #892: a revoked session must be found by the internal user id and must
 * stay revoked when the same token is presented again.
 */
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import { AuthService } from '../../services/api-backend/auth/auth-service.js';

describe('AuthService session revocation (#892)', () => {
  let auth;

  beforeEach(() => {
    auth = new AuthService({});
    auth.logger = { info: jest.fn(), warn: jest.fn(), error: jest.fn() };
    auth.logSecurityEvent = jest.fn(async () => {});
  });

  it('revokeSession matches sessions by the internal user id', async () => {
    auth.resolveUserId = jest.fn(async () => 'internal-user-1');
    auth.runQuery = jest.fn(async () => ({ changes: 1 }));

    const ok = await auth.revokeSession('access-sub-1', 'session-1', {
      email: 'user@example.com',
    });

    expect(ok).toBe(true);
    expect(auth.resolveUserId).toHaveBeenCalledWith('access-sub-1', {
      email: 'user@example.com',
    });
    const [sql, params] = auth.runQuery.mock.calls[0];
    expect(sql).toMatch(/UPDATE user_sessions SET is_active = false/);
    expect(sql).not.toMatch(/jwt_id/);
    expect(params).toEqual(['session-1', 'internal-user-1']);
  });

  it('revokeSession reports false when nothing matched', async () => {
    auth.resolveUserId = jest.fn(async () => 'internal-user-1');
    auth.runQuery = jest.fn(async () => ({ changes: 0 }));
    expect(await auth.revokeSession('sub', 'missing')).toBe(false);
  });

  it('validateToken rejects a token whose session was revoked', async () => {
    const payload = {
      sub: 'access-sub-1',
      exp: Math.floor(Date.now() / 1000) + 600,
    };
    auth.resolveUserId = jest.fn(async () => 'internal-user-1');
    auth.runQuery = jest.fn(async () => ({ is_suspended: false }));
    auth.createOrUpdateSession = jest.fn(async () => ({
      id: 'session-1',
      is_active: false,
    }));

    const result = await auth.validateToken('token', { ip: '127.0.0.1' }, payload);

    expect(result.valid).toBe(false);
    expect(result.code).toBe('SESSION_REVOKED');
  });

  it('validateToken still accepts an active session', async () => {
    const payload = {
      sub: 'access-sub-1',
      exp: Math.floor(Date.now() / 1000) + 600,
    };
    auth.resolveUserId = jest.fn(async () => 'internal-user-1');
    auth.runQuery = jest.fn(async () => ({ is_suspended: false }));
    auth.createOrUpdateSession = jest.fn(async () => ({
      id: 'session-1',
      is_active: true,
    }));

    const result = await auth.validateToken('token', { ip: '127.0.0.1' }, payload);

    expect(result.valid).toBe(true);
  });
});
