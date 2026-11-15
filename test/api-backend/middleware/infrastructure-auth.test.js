/**
 * Behavior tests for infrastructure authentication middleware.
 */

import { describe, it, expect, jest, beforeEach, afterEach } from '@jest/globals';
import {
  authenticateInfrastructure,
  optionalInfrastructureAuth,
} from '../../../services/api-backend/middleware/infrastructure-auth.js';

function mockRes() {
  return {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

describe('infrastructure-auth middleware', () => {
  let next;
  const previousKey = process.env.INFRASTRUCTURE_API_KEY;

  beforeEach(() => {
    next = jest.fn();
  });

  afterEach(() => {
    if (previousKey === undefined) {
      delete process.env.INFRASTRUCTURE_API_KEY;
    } else {
      process.env.INFRASTRUCTURE_API_KEY = previousKey;
    }
  });

  describe('authenticateInfrastructure', () => {
    it('returns 503 when INFRASTRUCTURE_API_KEY is not configured', () => {
      delete process.env.INFRASTRUCTURE_API_KEY;
      const req = {
        headers: { 'x-infrastructure-key': 'anything' },
        ip: '127.0.0.1',
        path: '/infra',
      };
      const res = mockRes();
      authenticateInfrastructure(req, res, next);
      expect(res.statusCode).toBe(503);
      expect(res.body.code).toBe('INFRA_NOT_CONFIGURED');
      expect(next).not.toHaveBeenCalled();
    });

    it('returns 401 when the header is missing', () => {
      process.env.INFRASTRUCTURE_API_KEY = 'secret-infra-key';
      const req = { headers: {}, ip: '127.0.0.1', path: '/infra' };
      const res = mockRes();
      authenticateInfrastructure(req, res, next);
      expect(res.statusCode).toBe(401);
      expect(res.body.code).toBe('MISSING_API_KEY');
      expect(next).not.toHaveBeenCalled();
    });

    it('returns 401 for an invalid key', () => {
      process.env.INFRASTRUCTURE_API_KEY = 'secret-infra-key';
      const req = {
        headers: { 'x-infrastructure-key': 'wrong' },
        ip: '127.0.0.1',
        path: '/infra',
      };
      const res = mockRes();
      authenticateInfrastructure(req, res, next);
      expect(res.statusCode).toBe(401);
      expect(res.body.code).toBe('INVALID_API_KEY');
      expect(next).not.toHaveBeenCalled();
    });

    it('calls next for a valid key', () => {
      process.env.INFRASTRUCTURE_API_KEY = 'secret-infra-key';
      const req = {
        headers: { 'x-infrastructure-key': 'secret-infra-key' },
        ip: '127.0.0.1',
        path: '/infra',
        method: 'POST',
      };
      const res = mockRes();
      authenticateInfrastructure(req, res, next);
      expect(next).toHaveBeenCalledTimes(1);
      expect(res.statusCode).toBeNull();
    });
  });

  describe('optionalInfrastructureAuth', () => {
    it('marks unauthenticated and continues when header is absent', () => {
      const req = { headers: {} };
      const res = mockRes();
      optionalInfrastructureAuth(req, res, next);
      expect(req.infraAuthenticated).toBe(false);
      expect(next).toHaveBeenCalledTimes(1);
    });

    it('marks authenticated for a matching key', () => {
      process.env.INFRASTRUCTURE_API_KEY = 'secret-infra-key';
      const req = {
        headers: { 'x-infrastructure-key': 'secret-infra-key' },
        ip: '127.0.0.1',
        path: '/infra',
      };
      const res = mockRes();
      optionalInfrastructureAuth(req, res, next);
      expect(req.infraAuthenticated).toBe(true);
      expect(next).toHaveBeenCalledTimes(1);
    });

    it('returns 401 when an invalid key is provided', () => {
      process.env.INFRASTRUCTURE_API_KEY = 'secret-infra-key';
      const req = {
        headers: { 'x-infrastructure-key': 'nope' },
        ip: '127.0.0.1',
        path: '/infra',
      };
      const res = mockRes();
      optionalInfrastructureAuth(req, res, next);
      expect(res.statusCode).toBe(401);
      expect(res.body.code).toBe('INVALID_API_KEY');
      expect(next).not.toHaveBeenCalled();
    });
  });
});
