// Pure input checks for the Tailscale relay. Kept free of I/O so they can be
// unit-tested without starting the server.
import net from 'node:net';
import jwt from 'jsonwebtoken';

// The placeholder shipped in config/docker-compose.env.example. A relay
// started with it would accept tokens anyone can mint.
export const EXAMPLE_JWT_SECRET = 'your-super-secret-jwt-key-change-this';

// Port and path on the target device are fixed; the caller only picks the
// device address.
export const TARGET_PORT = 11434;
export const TARGET_PATH = '/api/generate';

/**
 * Returns an error message when the secret must not be used, otherwise null.
 * @param {string | undefined} secret
 * @returns {string | null}
 */
export function checkJwtSecret(secret) {
  if (typeof secret !== 'string' || secret.length === 0) {
    return 'JWT_SECRET environment variable is required';
  }
  if (secret === EXAMPLE_JWT_SECRET || secret.includes('change-this')) {
    return 'JWT_SECRET still holds the example placeholder; set a real secret';
  }
  return null;
}

/**
 * Accepts only a plain IPv4 address inside the Tailscale CGNAT range
 * 100.64.0.0/10. Anything else (hostnames, ports, paths, other ranges,
 * IPv6) is rejected.
 * @param {unknown} value
 * @returns {string | null} the address, or null when it is not allowed
 */
export function validateTargetIp(value) {
  if (typeof value !== 'string' || !net.isIPv4(value)) {
    return null;
  }
  const [first, second] = value.split('.').map(Number);
  // 100.64.0.0/10 covers 100.64.0.0 - 100.127.255.255.
  if (first !== 100 || second < 64 || second > 127) {
    return null;
  }
  return value;
}

/**
 * Builds the forward URL from fixed parts and a validated address.
 * @param {unknown} targetIp
 * @returns {URL}
 */
export function buildTargetUrl(targetIp) {
  const ip = validateTargetIp(targetIp);
  if (!ip) {
    throw new Error('Invalid target address');
  }
  const url = new URL('http://localhost/');
  url.hostname = ip;
  url.port = String(TARGET_PORT);
  url.pathname = TARGET_PATH;
  return url;
}

/**
 * Verifies a relay token: HS256 only, must carry an expiry and a subject.
 * Throws when the token is not acceptable.
 * @param {unknown} token
 * @param {string} secret
 * @returns {{ userId: string, claims: object }}
 */
export function verifyRelayToken(token, secret) {
  if (typeof token !== 'string' || token.length === 0) {
    throw new Error('Missing token');
  }
  const claims = jwt.verify(token, secret, { algorithms: ['HS256'] });
  if (typeof claims !== 'object' || claims === null) {
    throw new Error('Token payload must be an object');
  }
  if (typeof claims.exp !== 'number') {
    throw new Error('Token must carry an expiry');
  }
  const userId = claims.sub || claims.userId;
  if (typeof userId !== 'string' || userId.length === 0) {
    throw new Error('Token must carry a subject');
  }
  return { userId, claims };
}
