import { describe, expect, it, beforeEach, afterEach } from "@jest/globals";

import {
  getStripePriceCatalog,
  getStripePriceIdForTier,
} from "../../services/api-backend/services/stripe-price-catalog.js";

describe("stripe price catalog", () => {
  const originalEnv = { ...process.env };

  beforeEach(() => {
    process.env = { ...originalEnv };
    delete process.env.STRIPE_PRICE_FREE;
    delete process.env.STRIPE_PRICE_PREMIUM;
    delete process.env.STRIPE_PRICE_ENTERPRISE;
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it("returns configured tier price IDs from environment variables", () => {
    process.env.STRIPE_PRICE_PREMIUM = "price_premium_test";
    process.env.STRIPE_PRICE_ENTERPRISE = "price_enterprise_test";

    expect(getStripePriceCatalog()).toEqual({
      premium: "price_premium_test",
      enterprise: "price_enterprise_test",
    });
    expect(getStripePriceIdForTier("premium")).toBe("price_premium_test");
  });
});
