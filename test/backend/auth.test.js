import { describe, it, expect } from "@jest/globals";

describe("Quarantined legacy Auth0 backend", () => {
  it("refuses to load and is not an active auth service", async () => {
    await expect(import("../../backend/auth/handlers.js")).rejects.toThrow(
      /quarantined/,
    );
  });
});
