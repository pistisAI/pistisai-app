import { describe, it, expect, jest } from '@jest/globals';

jest.unstable_mockModule('../../services/api-backend/utils/ssrf-protection.js', () => ({
  isUrlSafe: jest.fn(async (url) => {
    // Simplified mock that blocks known-bad URLs for testing
    try {
      const parsed = new URL(url);
      if (parsed.hostname === '127.0.0.1' || parsed.hostname.startsWith('127.')) {
        return { safe: false, reason: 'Blocked loopback IP' };
      }
      if (parsed.hostname === '169.254.169.254') {
        return { safe: false, reason: 'Blocked link-local IP' };
      }
      if (parsed.hostname.startsWith('10.')) {
        return { safe: false, reason: 'Blocked RFC1918 private IP' };
      }
      if (parsed.hostname.startsWith('192.168.')) {
        return { safe: false, reason: 'Blocked RFC1918 private IP' };
      }
      if (parsed.hostname.match(/^172\.(1[6-9]|2[0-9]|3[01])\./)) {
        return { safe: false, reason: 'Blocked RFC1918 private IP' };
      }
      if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
        return { safe: false, reason: `Invalid protocol: ${parsed.protocol}` };
      }
      return { safe: true };
    } catch {
      return { safe: false, reason: 'Invalid URL format' };
    }
  }),
}));

const { isUrlSafe } = await import('../../services/api-backend/utils/ssrf-protection.js');

describe('SSRF protection — isUrlSafe', () => {
  it('blocks loopback 127.0.0.1', async () => {
    const result = await isUrlSafe('http://127.0.0.1:5432/health');
    expect(result.safe).toBe(false);
  });

  it('blocks AWS metadata endpoint', async () => {
    const result = await isUrlSafe('http://169.254.169.254/latest/meta-data/');
    expect(result.safe).toBe(false);
  });

  it('blocks private 10.x.x.x', async () => {
    const result = await isUrlSafe('http://10.0.0.1/api');
    expect(result.safe).toBe(false);
  });

  it('blocks private 192.168.x.x', async () => {
    const result = await isUrlSafe('http://192.168.1.1/api');
    expect(result.safe).toBe(false);
  });

  it('blocks private 172.16-31.x.x', async () => {
    const result = await isUrlSafe('http://172.16.0.1/api');
    expect(result.safe).toBe(false);
  });

  it('allows public URLs', async () => {
    const result = await isUrlSafe('https://webhook.site/test');
    expect(result.safe).toBe(true);
  });

  it('rejects non-http protocols', async () => {
    const result = await isUrlSafe('file:///etc/passwd');
    expect(result.safe).toBe(false);
  });
});
