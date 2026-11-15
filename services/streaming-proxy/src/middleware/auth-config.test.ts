/**
 * Cloudflare Access auth-config loader tests
 */

import { afterEach, describe, expect, it } from '@jest/globals';
import { loadAuthConfig, validateAuthConfig } from './auth-config';

const ORIGINAL_ENV = { ...process.env };

afterEach(() => {
  process.env = { ...ORIGINAL_ENV };
  delete process.env.CF_ACCESS_TEAM_DOMAIN;
  delete process.env.CF_ACCESS_AUD;
  delete process.env.CF_ACCESS_JWKS_URI;
});

describe('loadAuthConfig', () => {
  it('requires CF_ACCESS_TEAM_DOMAIN and CF_ACCESS_AUD', () => {
    expect(() => loadAuthConfig()).toThrow(/CF_ACCESS_TEAM_DOMAIN/);
  });

  it('builds JWKS URI and issuer from the team domain', () => {
    process.env.CF_ACCESS_TEAM_DOMAIN = 'https://pistisai.cloudflareaccess.com/';
    process.env.CF_ACCESS_AUD = 'aud-value';

    const config = loadAuthConfig();
    validateAuthConfig(config);

    expect(config.cloudflareAccess.teamDomain).toBe(
      'pistisai.cloudflareaccess.com'
    );
    expect(config.cloudflareAccess.audience).toBe('aud-value');
    expect(config.cloudflareAccess.issuer).toBe(
      'https://pistisai.cloudflareaccess.com'
    );
    expect(config.cloudflareAccess.jwksUri).toBe(
      'https://pistisai.cloudflareaccess.com/cdn-cgi/access/certs'
    );
  });

  it('allows CF_ACCESS_JWKS_URI override', () => {
    process.env.CF_ACCESS_TEAM_DOMAIN = 'pistisai.cloudflareaccess.com';
    process.env.CF_ACCESS_AUD = 'aud-value';
    process.env.CF_ACCESS_JWKS_URI = 'https://example.com/jwks';

    const config = loadAuthConfig();
    expect(config.cloudflareAccess.jwksUri).toBe('https://example.com/jwks');
  });
});
