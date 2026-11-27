/**
 * Raw request body capture for routes that verify a signature over the exact
 * bytes the sender signed (#895). Used as the `verify` callback of the global
 * `express.json()` parser, so the parsed `req.body` is unchanged for every
 * route while only the listed webhook paths keep a copy of the raw bytes.
 */

/** Paths (without the `/api` prefix) whose raw body must be kept. */
const RAW_BODY_PATHS = ['/agent/events'];

function normalizePath(url) {
  const path = String(url || '')
    .split('?')[0]
    .replace(/\/+$/, '');
  return path.startsWith('/api/') ? path.slice('/api'.length) : path;
}

/**
 * @param {import('express').Request} req
 * @returns {boolean}
 */
export function needsRawBody(req) {
  return RAW_BODY_PATHS.includes(normalizePath(req.originalUrl || req.url));
}

/**
 * Paths (without the `/api` prefix) whose router parses its own body with a
 * tighter limit, so the global 10 MB parser must skip them.
 */
const SELF_PARSED_BODY_PATHS = ['/client-logs'];

/**
 * @param {import('express').Request} req
 * @returns {boolean}
 */
export function hasOwnBodyParser(req) {
  return SELF_PARSED_BODY_PATHS.includes(
    normalizePath(req.originalUrl || req.url),
  );
}

/**
 * `verify` callback for `express.json()`: stores the raw bytes on
 * `req.rawBody` for the webhook paths above.
 * @param {import('express').Request} req
 * @param {import('express').Response} _res
 * @param {Buffer} buf
 */
export function captureRawBody(req, _res, buf) {
  if (needsRawBody(req)) {
    req.rawBody = Buffer.from(buf);
  }
}
