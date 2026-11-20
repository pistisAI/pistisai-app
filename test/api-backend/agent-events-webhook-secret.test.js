/**
 * OpenClaw agent-events webhook must use a dedicated secret only —
 * never fall back to JWT_SECRET.
 */

import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import { resolveOpenClawWebhookSecret } from '../../services/api-backend/routes/openclaw-webhook-secret.js';

describe('resolveOpenClawWebhookSecret', () => {
  const saved = {};

  beforeEach(() => {
    for (const key of ['OPENCLAW_WEBHOOK_SECRET', 'JWT_SECRET']) {
      saved[key] = process.env[key];
      delete process.env[key];
    }
  });

  afterEach(() => {
    for (const key of Object.keys(saved)) {
      if (saved[key] === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = saved[key];
      }
    }
  });

  it('returns OPENCLAW_WEBHOOK_SECRET when set', () => {
    process.env.OPENCLAW_WEBHOOK_SECRET = 'openclaw-dedicated-secret';
    process.env.JWT_SECRET = 'jwt-should-not-be-used';
    expect(resolveOpenClawWebhookSecret()).toBe('openclaw-dedicated-secret');
  });

  it('does not fall back to JWT_SECRET when OPENCLAW_WEBHOOK_SECRET is unset', () => {
    process.env.JWT_SECRET = 'jwt-should-not-be-used';
    expect(resolveOpenClawWebhookSecret()).toBeNull();
  });

  it('returns null when neither secret is set', () => {
    expect(resolveOpenClawWebhookSecret()).toBeNull();
  });
});
