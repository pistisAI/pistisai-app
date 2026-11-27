/**
 * Developer bypass token through the real middleware/auth.js and the real
 * AuthService. Only Postgres is replaced (an in-memory fake), so the bypass
 * decision, the token checks and the HTTP status codes are production code.
 *
 * The middleware keeps one AuthService per module instance, so each mode
 * reloads the module graph with the environment it needs.
 */

import { describe, it, beforeAll, afterAll, expect, jest } from "@jest/globals";
import express from "express";
import request from "supertest";

const DEV_TOKEN = "ci-dev-bypass-token-for-tests";
const ENV_KEYS = [
  "NODE_ENV",
  "DEV_BYPASS_TOKEN",
  "CF_ACCESS_TEAM_DOMAIN",
  "CF_ACCESS_AUD",
];

const queries = [];

function registerDatabaseFake() {
  jest.unstable_mockModule(
    "../../../services/api-backend/database/migrate-pg.js",
    () => ({
      DatabaseMigratorPG: class {
        constructor() {
          this.pool = {
            query: async (sql, params) => {
              queries.push({ sql, params });
              return { rows: [], rowCount: 0 };
            },
          };
        }
        async initialize() {}
      },
    }),
  );
}

async function loadApp(env) {
  for (const [key, value] of Object.entries(env)) {
    if (value === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = value;
    }
  }
  jest.resetModules();
  registerDatabaseFake();
  const { checkJwt, optionalAuth } =
    await import("../../../services/api-backend/middleware/auth.js");

  const app = express();
  app.use(express.json());
  app.get("/api/test-protected", checkJwt, (req, res) => {
    res.json({ message: "success", auth: req.auth });
  });
  app.get("/api/test-optional", optionalAuth, (req, res) => {
    res.json({ message: "success", auth: req.auth });
  });
  return app;
}

const saved = {};

beforeAll(() => {
  for (const key of ENV_KEYS) {
    saved[key] = process.env[key];
  }
});

afterAll(() => {
  for (const key of ENV_KEYS) {
    if (saved[key] === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = saved[key];
    }
  }
});

describe("Developer bypass in development with DEV_BYPASS_TOKEN set", () => {
  let app;

  beforeAll(async () => {
    app = await loadApp({
      NODE_ENV: "development",
      DEV_BYPASS_TOKEN: DEV_TOKEN,
      CF_ACCESS_TEAM_DOMAIN: undefined,
      CF_ACCESS_AUD: undefined,
    });
  });

  it("accepts the configured token on a protected route", async () => {
    const response = await request(app)
      .get("/api/test-protected")
      .set("Authorization", `Bearer ${DEV_TOKEN}`);

    expect(response.status).toBe(200);
    expect(response.body.auth.token).toBe(DEV_TOKEN);
    expect(response.body.auth.payload.email).toBe("dev@example.com");
    expect(response.body.auth.payload.name).toBe("Dev User");
    expect(response.body.auth.payload.nickname).toBe("dev-user");
  });

  it("populates auth under optionalAuth for the configured token", async () => {
    const response = await request(app)
      .get("/api/test-optional")
      .set("Authorization", `Bearer ${DEV_TOKEN}`);

    expect(response.status).toBe(200);
    expect(response.body.auth.payload.email).toBe("dev@example.com");
  });

  it("rejects any other token with 401", async () => {
    const response = await request(app)
      .get("/api/test-protected")
      .set("Authorization", "Bearer invalid_or_unsupported_token");

    expect(response.status).toBe(401);
    expect(response.body.code).toBe("TOKEN_INVALID");
    expect(response.body.auth).toBeUndefined();
  });

  it("rejects a token that only starts with the configured token with 401", async () => {
    const response = await request(app)
      .get("/api/test-protected")
      .set("Authorization", `Bearer ${DEV_TOKEN}x`);

    expect(response.status).toBe(401);
  });

  it("leaves optionalAuth anonymous for any other token", async () => {
    const response = await request(app)
      .get("/api/test-optional")
      .set("Authorization", "Bearer invalid_or_unsupported_token");

    expect(response.status).toBe(200);
    expect(response.body.auth).toBeNull();
  });
});

describe.each([
  ["production", "production"],
  ["test", "test"],
  ["unset", undefined],
])("Developer bypass when NODE_ENV is %s", (_label, nodeEnv) => {
  let app;

  beforeAll(async () => {
    app = await loadApp({
      NODE_ENV: nodeEnv,
      DEV_BYPASS_TOKEN: DEV_TOKEN,
      CF_ACCESS_TEAM_DOMAIN: undefined,
      CF_ACCESS_AUD: undefined,
    });
  });

  it("rejects the configured token with 401", async () => {
    const response = await request(app)
      .get("/api/test-protected")
      .set("Authorization", `Bearer ${DEV_TOKEN}`);

    expect(response.status).toBe(401);
    expect(response.body.code).toBe("TOKEN_INVALID");
  });

  it("does not attach the dev identity under optionalAuth", async () => {
    const response = await request(app)
      .get("/api/test-optional")
      .set("Authorization", `Bearer ${DEV_TOKEN}`);

    expect(response.status).toBe(200);
    expect(response.body.auth).toBeNull();
  });
});

describe("Developer bypass in development without DEV_BYPASS_TOKEN", () => {
  let app;

  beforeAll(async () => {
    app = await loadApp({
      NODE_ENV: "development",
      DEV_BYPASS_TOKEN: undefined,
      CF_ACCESS_TEAM_DOMAIN: undefined,
      CF_ACCESS_AUD: undefined,
    });
  });

  it("has no built-in fallback token", async () => {
    const response = await request(app)
      .get("/api/test-protected")
      .set("Authorization", `Bearer ${DEV_TOKEN}`);

    expect(response.status).toBe(401);
  });
});
