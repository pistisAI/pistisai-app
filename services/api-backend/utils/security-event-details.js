/**
 * Prepare a security_events.details document before it is stored.
 *
 * The table has no user_id column, so the user id stays in details and hard
 * delete finds the row from it. Email addresses are masked and tokens are
 * removed so the JSON never holds them in the clear. IP and user agent stay:
 * hard delete clears the whole document, along with the ip_address column,
 * once the row can be tied to the user.
 */
import { maskEmail, redactSensitiveText } from './mask-email.js';

const EMAIL_KEYS = new Set(['email', 'recipientEmail', 'userEmail']);

function sanitizeDetailValue(value) {
  if (typeof value === 'string') {
    return redactSensitiveText(value);
  }
  if (Array.isArray(value)) {
    return value.map((item) => sanitizeDetailValue(item));
  }
  if (value && typeof value === 'object') {
    const nested = {};
    for (const [key, inner] of Object.entries(value)) {
      nested[key] = EMAIL_KEYS.has(key)
        ? maskEmail(inner)
        : sanitizeDetailValue(inner);
    }
    return nested;
  }
  return value;
}

/**
 * @param {unknown} details
 * @returns {Record<string, unknown>}
 */
export function sanitizeSecurityEventDetails(details) {
  if (!details || typeof details !== 'object' || Array.isArray(details)) {
    return {};
  }
  const safe = {};
  for (const [key, value] of Object.entries(details)) {
    safe[key] = EMAIL_KEYS.has(key)
      ? maskEmail(value)
      : sanitizeDetailValue(value);
  }
  return safe;
}
