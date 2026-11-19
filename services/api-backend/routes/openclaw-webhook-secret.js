/**
 * Dedicated OpenClaw webhook secret only — never fall back to JWT_SECRET.
 * @param {NodeJS.ProcessEnv} [env]
 * @returns {string|null}
 */
export function resolveOpenClawWebhookSecret(env = process.env) {
  const secret = env.OPENCLAW_WEBHOOK_SECRET;
  return typeof secret === 'string' && secret.length > 0 ? secret : null;
}
