import {
  describe,
  it,
  beforeAll,
  afterAll,
  expect,
  jest,
} from "@jest/globals";

const DEV_TOKEN = "ci-dev-bypass-token-for-tests";

// Mock express-oauth2-jwt-bearer and jwks-rsa to prevent ES module loading issues in Jest
jest.mock("express-oauth2-jwt-bearer", () => {
  return {
    auth: jest.fn().mockImplementation(() => {
      return (req, res, next) => next(new Error("Mocked Auth0 failure"));
    }),
  };
});
jest.mock("jwks-rsa", () => {
  const mockClient = jest.fn(() => ({
    getSigningKey: jest.fn(),
  }));
  mockClient.expressJwtSecret = jest.fn();
  return mockClient;
});

import express from "express";
import request from "supertest";

let checkJwt;
let optionalAuth;

// AuthService mock that mirrors env-gated isDevBypassToken behavior
jest.mock("../../../services/api-backend/auth/auth-service.js", () => {
  return {
    AuthService: jest.fn().mockImplementation(() => {
      const configured = process.env.DEV_BYPASS_TOKEN;
      const devBypassToken =
        process.env.NODE_ENV !== "production" &&
        typeof configured === "string" &&
        configured.length > 0
          ? configured
          : null;
      return {
        initialize: jest.fn().mockResolvedValue(true),
        syncSession: jest.fn().mockResolvedValue({ success: true }),
        validateToken: jest.fn().mockResolvedValue({ valid: true }),
        devBypassToken,
        isDevBypassToken(token) {
          return Boolean(devBypassToken) && token === devBypassToken;
        },
      };
    }),
  };
});

describe("Developer Mock Bypass Authentication", () => {
  let app;
  let originalNodeEnv;
  let originalDevBypass;

  beforeAll(async () => {
    originalNodeEnv = process.env.NODE_ENV;
    originalDevBypass = process.env.DEV_BYPASS_TOKEN;
    process.env.NODE_ENV = "development";
    process.env.DEV_BYPASS_TOKEN = DEV_TOKEN;

    const authModule =
      await import("../../../services/api-backend/middleware/auth.js");
    checkJwt = authModule.checkJwt;
    optionalAuth = authModule.optionalAuth;

    app = express();
    app.use(express.json());

    app.get("/api/test-protected", checkJwt, (req, res) => {
      res.json({
        message: "success",
        user: req.user,
        userId: req.userId,
        auth: req.auth,
      });
    });

    app.get("/api/test-optional", optionalAuth, (req, res) => {
      res.json({
        message: "success",
        user: req.user,
        userId: req.userId,
        auth: req.auth,
      });
    });
  });

  afterAll(() => {
    process.env.NODE_ENV = originalNodeEnv;
    if (originalDevBypass === undefined) {
      delete process.env.DEV_BYPASS_TOKEN;
    } else {
      process.env.DEV_BYPASS_TOKEN = originalDevBypass;
    }
  });

  it("should successfully bypass verification for configured DEV_BYPASS_TOKEN", async () => {
    const response = await request(app)
      .get("/api/test-protected")
      .set("Authorization", `Bearer ${DEV_TOKEN}`)
      .expect(200);

    expect(response.body.message).toBe("success");
    expect(response.body.auth).toBeDefined();
    expect(response.body.auth.token).toBe(DEV_TOKEN);
    expect(response.body.auth.payload.email).toBe("dev@pistisai.app");
    expect(response.body.auth.payload.name).toBe("Christopher (Dev)");
    expect(response.body.auth.payload.nickname).toBe("rightguy");
  });

  it("should successfully populate auth credentials under optionalAuth for DEV_BYPASS_TOKEN", async () => {
    const response = await request(app)
      .get("/api/test-optional")
      .set("Authorization", `Bearer ${DEV_TOKEN}`)
      .expect(200);

    expect(response.body.message).toBe("success");
    expect(response.body.auth).toBeDefined();
    expect(response.body.auth.payload.email).toBe("dev@pistisai.app");
  });

  it("should reject unrecognized tokens (delegating to express-jwt/express-oauth2-jwt-bearer)", async () => {
    const response = await request(app)
      .get("/api/test-protected")
      .set("Authorization", "Bearer invalid_or_unsupported_token");

    expect(response.status).not.toBe(200);
  });
});
