import { test } from 'node:test';
import assert from 'node:assert/strict';
import jwt from 'jsonwebtoken';
import {
  EXAMPLE_JWT_SECRET,
  buildTargetUrl,
  checkJwtSecret,
  validateTargetIp,
  verifyRelayToken,
} from '../src/relay-checks.js';

const SECRET = 'test-only-relay-secret-0123456789abcdef';

test('validateTargetIp accepts addresses in 100.64.0.0/10', () => {
  for (const ip of ['100.64.0.1', '100.100.100.100', '100.127.255.254']) {
    assert.equal(validateTargetIp(ip), ip);
  }
});

test('validateTargetIp rejects anything that is not a plain tailnet IPv4', () => {
  const rejected = [
    undefined,
    null,
    '',
    '127.0.0.1',
    'localhost',
    '10.0.0.5',
    '192.168.1.10',
    '169.254.169.254',
    '100.63.255.255',
    '100.128.0.1',
    '100.64.0.1:8080',
    '100.64.0.1/admin',
    '100.64.0.1?x=1',
    '100.64.0.1#frag',
    'user@100.64.0.1',
    '100.064.0.1',
    ' 100.64.0.1',
    'example.com',
    'fd7a:115c:a1e0::1',
  ];
  for (const value of rejected) {
    assert.equal(validateTargetIp(value), null, `expected ${JSON.stringify(value)} to be rejected`);
  }
});

test('buildTargetUrl uses fixed port and path', () => {
  assert.equal(buildTargetUrl('100.64.1.2').href, 'http://100.64.1.2:11434/api/generate');
  assert.throws(() => buildTargetUrl('127.0.0.1:1/x'));
});

test('checkJwtSecret refuses missing and placeholder secrets', () => {
  assert.match(checkJwtSecret(undefined), /required/);
  assert.match(checkJwtSecret(''), /required/);
  assert.match(checkJwtSecret(EXAMPLE_JWT_SECRET), /placeholder/);
  assert.equal(checkJwtSecret(SECRET), null);
});

test('verifyRelayToken accepts an HS256 token with exp and sub', () => {
  const token = jwt.sign({ sub: 'user-1' }, SECRET, { algorithm: 'HS256', expiresIn: 60 });
  assert.equal(verifyRelayToken(token, SECRET).userId, 'user-1');
});

test('verifyRelayToken rejects a token without exp', () => {
  const token = jwt.sign({ sub: 'user-1' }, SECRET, { algorithm: 'HS256' });
  assert.throws(() => verifyRelayToken(token, SECRET), /expiry/);
});

test('verifyRelayToken rejects other algorithms, expired tokens, wrong secrets and missing subject', () => {
  const hs512 = jwt.sign({ sub: 'u' }, SECRET, { algorithm: 'HS512', expiresIn: 60 });
  assert.throws(() => verifyRelayToken(hs512, SECRET));
  const expired = jwt.sign({ sub: 'u', exp: Math.floor(Date.now() / 1000) - 10 }, SECRET);
  assert.throws(() => verifyRelayToken(expired, SECRET));
  const wrong = jwt.sign({ sub: 'u' }, 'another-secret-value-abcdef', { expiresIn: 60 });
  assert.throws(() => verifyRelayToken(wrong, SECRET));
  const noSub = jwt.sign({ role: 'x' }, SECRET, { expiresIn: 60 });
  assert.throws(() => verifyRelayToken(noSub, SECRET), /subject/);
});
