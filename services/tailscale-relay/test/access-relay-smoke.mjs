/**
 * Runtime smoke: start the relay with a mocked JWKS. A minted Access token
 * is accepted. An unsigned request is rejected. No Cloudflare call.
 */
import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { cloudflareAccessDefaults } from '../src/cloudflare-access-jwt.js';
import { createRelayServer } from '../src/server.js';

const audience = cloudflareAccessDefaults.audience;
const issuer = cloudflareAccessDefaults.issuer;

const { publicKey, privateKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
});
const jwk = publicKey.export({ format: 'jwk' });
jwk.kid = 'smoke-key';
jwk.alg = 'RS256';
jwk.use = 'sig';

const now = Math.floor(Date.now() / 1000);
const token = jwt.sign(
  {
    email: 'smoke@example.com',
    sub: 'smoke-user',
    aud: audience,
    iss: issuer,
    iat: now,
    exp: now + 300,
  },
  privateKey,
  { algorithm: 'RS256', keyid: 'smoke-key' },
);

const relay = createRelayServer({
  customerNetwork: false,
  keysProvider: async () => [jwk],
  settings: {
    audience,
    issuer,
    jwksUrl: 'http://127.0.0.1/unused',
    teamDomain: cloudflareAccessDefaults.teamDomain,
    tunnelHost: cloudflareAccessDefaults.tunnelHost,
  },
});

await new Promise((resolve) => relay.server.listen(0, '127.0.0.1', resolve));
const { port } = relay.server.address();
const base = `http://127.0.0.1:${port}`;

try {
  const unsigned = await fetch(`${base}/tunnel/whoami`);
  assert.equal(unsigned.status, 401);

  const signed = await fetch(`${base}/tunnel/whoami`, {
    headers: { 'cf-access-token': token },
  });
  assert.equal(signed.status, 200);
  const body = await signed.json();
  assert.equal(body.email, 'smoke@example.com');
  assert.equal(body.mode, 'access');
  console.log('Access relay smoke passed');
} finally {
  await new Promise((resolve, reject) => {
    relay.server.close((error) => (error ? reject(error) : resolve()));
  });
}
