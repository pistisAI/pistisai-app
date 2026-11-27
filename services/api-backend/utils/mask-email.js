/**
 * Mask an email address before it goes into a log line.
 *
 * Keeps the first character of the local part and the domain so an operator
 * can still tell entries apart, e.g. `alice@example.com` -> `a***@example.com`.
 * Anything that does not look like an address is fully masked.
 *
 * @param {unknown} email
 * @returns {string|null|undefined} masked address, or the input when it is null/undefined
 */
export function maskEmail(email) {
  if (email === null || email === undefined) {
    return email;
  }
  if (typeof email !== 'string') {
    return '***';
  }
  const trimmed = email.trim();
  const at = trimmed.lastIndexOf('@');
  if (at <= 0 || at === trimmed.length - 1) {
    return '***';
  }
  const local = trimmed.slice(0, at);
  const domain = trimmed.slice(at + 1);
  return `${local[0]}***@${domain}`;
}

const EMAIL_IN_TEXT = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
// JWT compact form: header.payload.signature, header always starts with eyJ.
const JWT_IN_TEXT =
  /eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{8,}/g;
const BEARER_IN_TEXT = /\bBearer\s+\S+/gi;

/**
 * Mask every email address embedded in a free-text log or details string.
 * Non-strings are returned unchanged.
 *
 * @param {unknown} value
 * @returns {unknown}
 */
export function redactEmailsInText(value) {
  if (typeof value !== 'string') {
    return value;
  }
  return value.replace(EMAIL_IN_TEXT, (address) => maskEmail(address));
}

/**
 * Replace JWTs and Bearer tokens in a free-text string with `[redacted]`.
 *
 * @param {unknown} value
 * @returns {unknown}
 */
export function redactTokensInText(value) {
  if (typeof value !== 'string') {
    return value;
  }
  return value
    .replace(JWT_IN_TEXT, '[redacted]')
    .replace(BEARER_IN_TEXT, 'Bearer [redacted]');
}

/**
 * Mask emails and redact tokens in one string. Used for log messages and
 * security-event detail values that are not a single email field.
 *
 * @param {unknown} value
 * @returns {unknown}
 */
export function redactSensitiveText(value) {
  return redactEmailsInText(redactTokensInText(value));
}

export default maskEmail;
