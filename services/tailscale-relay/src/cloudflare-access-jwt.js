import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';

/**
 * Public Cloudflare Access settings for the pistisai.app tunnel.
 * Env vars override these. Nothing here is a secret.
 *
 * Desktop tunnel and sync talk to api.pistisai.app, so that app's AUD is
 * the audience the relay and API verify. app.pistisai.app is the web host
 * and is not the tunnel audience.
 */
export const cloudflareAccessDefaults = {
  teamDomain: 'pistisai.cloudflareaccess.com',
  issuer: 'https://pistisai.cloudflareaccess.com',
  jwksUrl: 'https://pistisai.cloudflareaccess.com/cdn-cgi/access/certs',
  tunnelHost: 'api.pistisai.app',
  audience:
    'c0134585f8067b43908572f93046917aedfb9b8d111f3ed716e3fc204e8fe7d3',
  appHost: 'app.pistisai.app',
  appAudience:
    'b1f78e752af5c24fccb62238333da87fca981436711244f31ba6d612b92bc9fd',
};

export function accessSettings(env = process.env) {
  const issuer = env.CF_ACCESS_ISSUER || cloudflareAccessDefaults.issuer;
  return {
    teamDomain:
      env.CF_ACCESS_TEAM_DOMAIN || cloudflareAccessDefaults.teamDomain,
    issuer,
    jwksUrl: env.CF_ACCESS_JWKS_URL || cloudflareAccessDefaults.jwksUrl,
    audience: env.CF_ACCESS_AUD || cloudflareAccessDefaults.audience,
    tunnelHost:
      env.CF_ACCESS_TUNNEL_HOST || cloudflareAccessDefaults.tunnelHost,
  };
}

export function loginUrl(settings = accessSettings(), redirectUrl) {
  const base = `https://${settings.teamDomain}/cdn-cgi/access/login/${settings.audience}`;
  if (!redirectUrl) return base;
  const url = new URL(base);
  url.searchParams.set('redirect_url', redirectUrl);
  return url.toString();
}

/**
 * Token from Cf-Access-Jwt-Assertion, cf-access-token, or the
 * CF_Authorization cookie.
 */
export function extractAccessToken(headers = {}, query = {}) {
  const lower = {};
  for (const [key, value] of Object.entries(headers)) {
    if (typeof value === 'string') lower[key.toLowerCase()] = value;
  }
  if (lower['cf-access-jwt-assertion']) return lower['cf-access-jwt-assertion'];
  if (lower['cf-access-token']) return lower['cf-access-token'];
  const cookie = lower.cookie || '';
  const match = cookie.match(/(?:^|;\s*)CF_Authorization=([^;]+)/);
  if (match) return decodeURIComponent(match[1]);
  const authorization = lower.authorization || '';
  if (authorization.startsWith('Bearer ')) return authorization.slice(7);
  if (typeof query.token === 'string' && query.token.length > 0) {
    return query.token;
  }
  return null;
}

function failure(code, message) {
  const error = new Error(message);
  error.code = code;
  return error;
}

/**
 * Verify a Cloudflare Access user JWT against a local or fetched JWKS.
 * Checks signature, aud, iss, and exp. Email comes from the token.
 */
export function verifyAccessJwt(
  token,
  { keys, audience, issuer, now = () => Date.now() },
) {
  if (typeof token !== 'string' || token.length === 0) {
    throw failure('invalid', 'Missing token');
  }
  const decoded = jwt.decode(token, { complete: true });
  if (!decoded || !decoded.header) {
    throw failure('invalid', 'Invalid token structure');
  }
  const kid = decoded.header.kid;
  const jwk = (keys || []).find((key) => !kid || key.kid === kid);
  if (!jwk) {
    throw failure('bad_signature', 'No matching signing key');
  }
  let publicKey;
  try {
    publicKey = crypto.createPublicKey({ key: jwk, format: 'jwk' });
  } catch {
    throw failure('bad_signature', 'Bad signature');
  }
  let payload;
  try {
    payload = jwt.verify(token, publicKey, {
      algorithms: ['RS256'],
      audience,
      issuer,
      clockTimestamp: Math.floor(now() / 1000),
    });
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw failure('expired', 'Token expired');
    }
    const message = String(error.message || '');
    if (message.includes('audience')) {
      throw failure('wrong_aud', 'Wrong audience');
    }
    if (message.includes('issuer')) {
      throw failure('wrong_iss', 'Wrong issuer');
    }
    throw failure('bad_signature', 'Bad signature');
  }
  const email =
    typeof payload.email === 'string' && payload.email.length > 0
      ? payload.email
      : null;
  if (!email) {
    throw failure('invalid', 'Token missing email');
  }
  return { email, sub: payload.sub, payload };
}

/**
 * Free-tier pistisai.app tunnel auth, or a customer-operated relay that
 * never contacts Cloudflare.
 */
export function authorizeTunnelRequest({
  headers,
  query,
  customerNetwork = false,
  keys,
  audience,
  issuer,
  now,
}) {
  if (customerNetwork) {
    return { ok: true, mode: 'customer', email: null };
  }
  const token = extractAccessToken(headers, query);
  if (!token) {
    return { ok: false, error: 'Missing token', code: 'missing' };
  }
  try {
    const verified = verifyAccessJwt(token, { keys, audience, issuer, now });
    return {
      ok: true,
      mode: 'access',
      email: verified.email,
      sub: verified.sub,
    };
  } catch (error) {
    return { ok: false, error: error.message, code: error.code || 'invalid' };
  }
}
