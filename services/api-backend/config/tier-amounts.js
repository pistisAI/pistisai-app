/**
 * Subscription tier amounts come from the environment.
 * Unset variables contribute nothing, so prices are not stored in the repo.
 */
export function tierAmounts() {
  const read = (name) => {
    const raw = process.env[name];
    if (raw === undefined || raw === null || raw === '') {
      return 0;
    }
    const value = Number(raw);
    return Number.isFinite(value) ? value : 0;
  };

  return {
    free: 0,
    premium: read('PISTISAI_PRICE_PREMIUM'),
    enterprise: read('PISTISAI_PRICE_ENTERPRISE'),
  };
}
