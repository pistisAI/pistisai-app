/**
 * Stripe price catalog loaded from environment variables.
 *
 * Configure per-tier Stripe price IDs:
 * - STRIPE_PRICE_FREE
 * - STRIPE_PRICE_PREMIUM
 * - STRIPE_PRICE_ENTERPRISE
 */

const TIER_ENV_KEYS = {
  free: 'STRIPE_PRICE_FREE',
  premium: 'STRIPE_PRICE_PREMIUM',
  enterprise: 'STRIPE_PRICE_ENTERPRISE',
};

/**
 * @returns {Record<string, string>} tier -> Stripe price ID
 */
export function getStripePriceCatalog() {
  const catalog = {};

  for (const [tier, envKey] of Object.entries(TIER_ENV_KEYS)) {
    const priceId = process.env[envKey];
    if (priceId) {
      catalog[tier] = priceId;
    }
  }

  return catalog;
}

/**
 * @param {string} tier
 * @returns {string|null}
 */
export function getStripePriceIdForTier(tier) {
  const normalized = String(tier || '').toLowerCase();
  return getStripePriceCatalog()[normalized] || null;
}

/**
 * @returns {boolean}
 */
export function isStripePriceCatalogConfigured() {
  return Object.keys(getStripePriceCatalog()).length > 0;
}
