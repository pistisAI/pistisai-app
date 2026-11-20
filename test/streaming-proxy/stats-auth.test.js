/**
 * streaming-proxy /stats must not be publicly readable.
 */

import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import { isProxyStatsAuthorized } from '../../services/streaming-proxy/stats-auth.js';

describe('isProxyStatsAuthorized', () => {
  const saved = process.env.PROXY_STATS_TOKEN;

  beforeEach(() => {
    delete process.env.PROXY_STATS_TOKEN;
  });

  afterEach(() => {
    if (saved === undefined) {
      delete process.env.PROXY_STATS_TOKEN;
    } else {
      process.env.PROXY_STATS_TOKEN = saved;
    }
  });

  it('denies when PROXY_STATS_TOKEN is unset (fail closed)', () => {
    expect(
      isProxyStatsAuthorized({ authorization: 'Bearer anything' }),
    ).toBe(false);
  });

  it('denies when Authorization header is missing', () => {
    process.env.PROXY_STATS_TOKEN = 'stats-secret-token';
    expect(isProxyStatsAuthorized({})).toBe(false);
  });

  it('denies wrong bearer token', () => {
    process.env.PROXY_STATS_TOKEN = 'stats-secret-token';
    expect(
      isProxyStatsAuthorized({ authorization: 'Bearer wrong-token-here' }),
    ).toBe(false);
  });

  it('allows matching bearer token', () => {
    process.env.PROXY_STATS_TOKEN = 'stats-secret-token';
    expect(
      isProxyStatsAuthorized({
        authorization: 'Bearer stats-secret-token',
      }),
    ).toBe(true);
  });
});
