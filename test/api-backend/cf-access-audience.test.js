/**
 * #806: Cloudflare Access JWTs must be bound to this application's audience.
 * With CF_ACCESS_AUD unset the check must fail closed, not pass every token.
 */
import { describe, it, expect, afterEach } from "@jest/globals";
import { AuthService } from "../../services/api-backend/auth/auth-service.js";

describe("assertAccessAudience (#806)", () => {
  afterEach(() => {
    delete process.env.CF_ACCESS_AUD;
  });

  it("rejects when CF_ACCESS_AUD is unset (fail closed)", () => {
    const auth = new AuthService({});
    auth.config.CF_ACCESS_AUD = "";
    expect(() => auth.assertAccessAudience({ aud: "anything" })).toThrow(
      "Cloudflare Access audience is not configured",
    );
  });

  it("accepts a token whose audience matches", () => {
    const auth = new AuthService({});
    auth.config.CF_ACCESS_AUD = "our-app-aud";
    expect(() =>
      auth.assertAccessAudience({ aud: "our-app-aud" }),
    ).not.toThrow();
  });

  it("rejects a token issued for another application", () => {
    const auth = new AuthService({});
    auth.config.CF_ACCESS_AUD = "our-app-aud";
    expect(() =>
      auth.assertAccessAudience({ aud: "some-other-app" }),
    ).toThrow("Cloudflare Access audience mismatch");
  });

  it("accepts a multi-audience token that includes ours", () => {
    const auth = new AuthService({});
    auth.config.CF_ACCESS_AUD = "our-app-aud";
    expect(() =>
      auth.assertAccessAudience({ aud: ["other", "our-app-aud"] }),
    ).not.toThrow();
  });
});
