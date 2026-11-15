/**
 * Behavior tests for the user-tier route handler.
 */

import { describe, it, expect } from '@jest/globals';
import { userTierHandler } from '../../services/api-backend/routes/user-tier.js';

function mockRes() {
  return {
    statusCode: 200,
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

describe('user-tier route', () => {
  const handler = userTierHandler[0];

  it('returns free tier features for a user without tier metadata', () => {
    const res = mockRes();
    handler({ user: { sub: 'user-1' } }, res);
    expect(res.body.tier).toBe('free');
    expect(res.body.features).toBeTruthy();
    expect(res.body.upgradeUrl).toMatch(/upgrade/);
    expect(res.body.timestamp).toBeTruthy();
  });

  it('returns premium tier when user metadata includes it', () => {
    const res = mockRes();
    handler(
      {
        user: {
          sub: 'user-2',
          'https://Pistisai.com/user_metadata': { tier: 'premium' },
        },
      },
      res,
    );
    expect(res.body.tier).toBe('premium');
  });

  it('returns 500 when tier lookup throws', () => {
    const res = mockRes();
    const throwingUser = new Proxy(
      {},
      {
        get() {
          throw new Error('tier boom');
        },
      },
    );
    handler({ user: throwingUser }, res);
    expect(res.statusCode).toBe(500);
    expect(res.body.code).toBe('TIER_ERROR');
  });
});
