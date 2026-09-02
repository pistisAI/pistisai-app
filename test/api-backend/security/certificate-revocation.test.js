import { describe, expect, it } from "@jest/globals";

import { ConnectionSecurityManager } from "../../../services/api-backend/middleware/connection-security.js";

function validCertificate(overrides = {}) {
  return {
    valid_from: "Jan  1 00:00:00 2020 GMT",
    valid_to: "Jan  1 00:00:00 2100 GMT",
    issuer: { CN: "PistisAI CA" },
    subject: { CN: "PistisAI client" },
    serialNumber: "01AB",
    fingerprint: "AA:BB:CC:DD",
    ...overrides,
  };
}

describe("ConnectionSecurityManager certificate revocation", () => {
  it("rejects a certificate whose serial number is on the revocation list", () => {
    const manager = new ConnectionSecurityManager({
      certificateRevocationCheck: true,
      revokedCertificateSerials: ["01:ab"],
    });

    const result = manager.validateClientCertificate(
      validCertificate(),
      "127.0.0.1",
      "test-correlation",
    );

    expect(result).toEqual({
      valid: false,
      reason: "Certificate has been revoked",
      errorCode: "CLIENT_CERT_REVOKED",
    });
  });

  it("rejects a certificate whose fingerprint is on the revocation list", () => {
    const manager = new ConnectionSecurityManager({
      certificateRevocationCheck: true,
      revokedCertificateFingerprints: ["aabbccdd"],
    });

    expect(manager.isCertificateRevoked(validCertificate())).toBe(true);
  });

  it("accepts a certificate absent from the configured revocation lists", () => {
    const manager = new ConnectionSecurityManager({
      certificateRevocationCheck: true,
      revokedCertificateSerials: ["99FF"],
      revokedCertificateFingerprints: ["11223344"],
    });

    expect(manager.isCertificateRevoked(validCertificate())).toBe(false);
  });
});
