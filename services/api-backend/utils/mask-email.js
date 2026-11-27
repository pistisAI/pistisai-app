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

export default maskEmail;
