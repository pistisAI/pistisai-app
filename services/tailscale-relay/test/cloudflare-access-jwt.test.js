import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import test from 'node:test';
import jwt from 'jsonwebtoken';
import {
  accessSettings,
  authorizeTunnelRequest,
  cloudflareAccessDefaults,
  verifyAccessJwt,
} from '../src/cloudflare-access-jwt.js';

const audience = cloudflareAccessDefaults.audience;
const issuer = cloudflareAccessDefaults.issuer;

function keyPair(kid) {
  const { publicKey, privateKey } = generateKeyPairSync('rsa', {
    modulusLength: 2048,
  });
  const jwk = publicKey.export({ format: 'jwk' });
  jwk.kid = kid;
  jwk.alg = 'RS256';
  jwk.use = 'sig';
  return { jwk, privateKey };
}

const primary = keyPair('test-key');
const other = keyPair('other-key');

function mint(claims = {}, signingKey = primary.privateKey, kid = 'test-key') {
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      email: 'ada@example.com',
      sub: 'user-ada',
      aud: audience,
      iss: issuer,
      iat: now - 10,
      nbf: now - 10,
      exp: now + 120,
      ...claims,
    },
    signingKey,
    { algorithm: 'RS256', keyid: kid },
  );
}

function verify(token, keys = [primary.jwk]) {
  return verifyAccessJwt(token, { keys, audience, issuer });
}

test('accepts a token signed by the configured JWKS', () => {
  const result = verify(mint());
  assert.equal(result.email, 'ada@example.com');
  assert.equal(result.sub, 'user-ada');
});

test('rejects the wrong audience', () => {
  assert.throws(
    () => verify(mint({ aud: 'not-the-api-app' })),
    (error) => error.code === 'wrong_aud',
  );
});

test('rejects the wrong issuer', () => {
  assert.throws(
    () => verify(mint({ iss: 'https://example.invalid' })),
    (error) => error.code === 'wrong_iss',
  );
});

test('rejects an expired token', () => {
  const now = Math.floor(Date.now() / 1000);
  assert.throws(
    () => verify(mint({ iat: now - 120, nbf: now - 120, exp: now - 30 })),
    (error) => error.code === 'expired',
  );
});

test('rejects a bad signature', () => {
  assert.throws(
    () => verify(mint({}, other.privateKey, 'other-key')),
    (error) => error.code === 'bad_signature',
  );
});

test('customer network mode does not require a token or a JWKS', () => {
  const result = authorizeTunnelRequest({
    headers: {},
    customerNetwork: true,
    keys: [],
    audience,
    issuer,
  });
  assert.equal(result.ok, true);
  assert.equal(result.mode, 'customer');
});

test('access mode rejects an unsigned request', () => {
  const result = authorizeTunnelRequest({
    headers: {},
    customerNetwork: false,
    keys: [primary.jwk],
    audience,
    issuer,
  });
  assert.equal(result.ok, false);
  assert.equal(result.code, 'missing');
});

test('access mode accepts cf-access-token and returns the email', () => {
  const token = mint();
  const result = authorizeTunnelRequest({
    headers: { 'cf-access-token': token },
    keys: [primary.jwk],
    audience,
    issuer,
  });
  assert.equal(result.ok, true);
  assert.equal(result.email, 'ada@example.com');
});

test('defaults target the api.pistisai.app Access app', () => {
  const settings = accessSettings({});
  assert.equal(settings.tunnelHost, 'api.pistisai.app');
  assert.equal(settings.audience, cloudflareAccessDefaults.audience);
  assert.equal(settings.issuer, 'https://pistisai.cloudflareaccess.com');
  assert.equal(cloudflareAccessDefaults.appHost, 'app.pistisai.app');
});
