/**
 * Behavior tests for CORS configuration middleware helpers and origin validators.
 */

import { describe, it, expect, jest, beforeEach } from '@jest/globals';

const {
  standardCorsOptions,
  adminCorsOptions,
  webhookCorsOptions,
  getAllowedOrigins,
  isOriginAllowed,
  logCorsRequest,
} = await import('../../../services/api-backend/middleware/cors-config.js');

function invokeOrigin(validator, origin) {
  return new Promise((resolve) => {
    validator(origin, (err, allowed) => {
      resolve({ err, allowed });
    });
  });
}

describe('cors-config', () => {
  describe('standardCorsOptions.origin', () => {
    it('allows requests with no origin', async () => {
      const result = await invokeOrigin(standardCorsOptions.origin, undefined);
      expect(result.err).toBeNull();
      expect(result.allowed).toBe(true);
    });

    it('allows primary production origins', async () => {
      for (const origin of [
        'https://app.pistisai.app',
        'https://api.pistisai.app',
        'https://pistisai.app',
      ]) {
        const result = await invokeOrigin(standardCorsOptions.origin, origin);
        expect(result.err).toBeNull();
        expect(result.allowed).toBe(true);
      }
    });

    it('rejects unauthorized origins', async () => {
      const result = await invokeOrigin(
        standardCorsOptions.origin,
        'https://evil.example.com',
      );
      expect(result.err).toBeInstanceOf(Error);
      expect(result.err.message).toMatch(/Not allowed by CORS/);
      expect(result.allowed).toBeUndefined();
    });
  });

  describe('adminCorsOptions.origin', () => {
    it('requires an origin for admin endpoints', async () => {
      const result = await invokeOrigin(adminCorsOptions.origin, undefined);
      expect(result.err).toBeInstanceOf(Error);
      expect(result.err.message).toMatch(/Origin required/);
    });

    it('allows admin and app origins', async () => {
      for (const origin of [
        'https://admin.pistisai.app',
        'https://app.pistisai.app',
      ]) {
        const result = await invokeOrigin(adminCorsOptions.origin, origin);
        expect(result.err).toBeNull();
        expect(result.allowed).toBe(true);
      }
    });

    it('rejects non-admin origins', async () => {
      const result = await invokeOrigin(
        adminCorsOptions.origin,
        'https://docs.pistisai.app',
      );
      expect(result.err).toBeInstanceOf(Error);
      expect(result.err.message).toMatch(/admin access only/);
    });
  });

  describe('webhookCorsOptions.origin', () => {
    it('allows requests with no origin (provider callbacks)', async () => {
      const result = await invokeOrigin(webhookCorsOptions.origin, undefined);
      expect(result.err).toBeNull();
      expect(result.allowed).toBe(true);
    });

    it('allows Stripe webhook origins', async () => {
      for (const origin of [
        'https://api.stripe.com',
        'https://hooks.stripe.com',
      ]) {
        const result = await invokeOrigin(webhookCorsOptions.origin, origin);
        expect(result.err).toBeNull();
        expect(result.allowed).toBe(true);
      }
    });

    it('rejects non-webhook origins', async () => {
      const result = await invokeOrigin(
        webhookCorsOptions.origin,
        'https://app.pistisai.app',
      );
      expect(result.err).toBeInstanceOf(Error);
      expect(result.err.message).toMatch(/webhook access only/);
    });
  });

  describe('getAllowedOrigins / isOriginAllowed', () => {
    it('returns a copy of allowed origins including production hosts', () => {
      const origins = getAllowedOrigins();
      expect(origins).toContain('https://app.pistisai.app');
      expect(origins).toContain('https://pistisai.app');
      origins.push('https://should-not-mutate.example.com');
      expect(getAllowedOrigins()).not.toContain(
        'https://should-not-mutate.example.com',
      );
    });

    it('reports membership via isOriginAllowed', () => {
      expect(isOriginAllowed('https://app.pistisai.app')).toBe(true);
      expect(isOriginAllowed('https://evil.example.com')).toBe(false);
    });
  });

  describe('logCorsRequest', () => {
    let next;

    beforeEach(() => {
      next = jest.fn();
    });

    it('calls next when no origin header is present', () => {
      const req = { headers: {}, method: 'GET', path: '/api/health' };
      logCorsRequest(req, {}, next);
      expect(next).toHaveBeenCalledTimes(1);
    });

    it('calls next when an origin header is present', () => {
      const req = {
        headers: { origin: 'https://app.pistisai.app' },
        method: 'GET',
        path: '/api/health',
      };
      logCorsRequest(req, {}, next);
      expect(next).toHaveBeenCalledTimes(1);
    });
  });

  describe('option shapes', () => {
    it('exposes expected methods and credential settings', () => {
      expect(standardCorsOptions.credentials).toBe(true);
      expect(standardCorsOptions.methods).toContain('GET');
      expect(adminCorsOptions.credentials).toBe(true);
      expect(adminCorsOptions.maxAge).toBe(3600);
      expect(webhookCorsOptions.credentials).toBe(false);
      expect(webhookCorsOptions.methods).toEqual(['POST', 'OPTIONS']);
    });
  });
});
