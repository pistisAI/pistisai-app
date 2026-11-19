/**
 * Authorization for the streaming-proxy /stats endpoint.
 * Fail closed: missing PROXY_STATS_TOKEN or mismatched bearer → deny.
 */
import crypto from 'crypto';

/**
 * @param {Record<string, string|string[]|undefined>} headers
 * @param {string|undefined} [expectedToken]
 * @returns {boolean}
 */
export function isProxyStatsAuthorized(
  headers,
  expectedToken = process.env.PROXY_STATS_TOKEN,
) {
  if (typeof expectedToken !== 'string' || expectedToken.length === 0) {
    return false;
  }

  const authHeader = headers?.authorization || headers?.Authorization || '';
  const headerValue = Array.isArray(authHeader) ? authHeader[0] : authHeader;
  if (typeof headerValue !== 'string' || !headerValue.startsWith('Bearer ')) {
    return false;
  }

  const provided = headerValue.slice('Bearer '.length);
  if (provided.length !== expectedToken.length) {
    return false;
  }

  return crypto.timingSafeEqual(
    Buffer.from(provided, 'utf8'),
    Buffer.from(expectedToken, 'utf8'),
  );
}
