import { jest } from "@jest/globals";
import express from "express";
import request from "supertest";

const asUser = (req, _res, next) => {
  req.user = { sub: "user-1" };
  next();
};
const log = { info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() };

jest.unstable_mockModule("../../services/api-backend/logger.js", () => ({
  default: log,
}));
jest.unstable_mockModule(
  "../../services/api-backend/middleware/auth.js",
  () => ({ authenticateJWT: asUser }),
);

const { default: router, initializeTunnelUsageRoutes } = await import(
  "../../services/api-backend/routes/tunnel-usage.js"
);

const recordUsageEvent = jest.fn().mockResolvedValue({ id: "e1" });
initializeTunnelUsageRoutes({ recordUsageEvent });

const app = express();
app.use(express.json());
app.use("/", router);

const url = "/tunnels/123e4567-e89b-42d3-a456-426614174000/usage/events";

describe("POST /tunnels/:id/usage/events body", () => {
  beforeEach(() => recordUsageEvent.mockClear());

  it("accepts a valid event", async () => {
    const res = await request(app)
      .post(url)
      .send({ eventType: "data_transfer", dataBytes: 1024 });
    expect(res.status).toBe(201);
    expect(recordUsageEvent).toHaveBeenCalledTimes(1);
  });

  it.each([
    ["dataBytes as text", { eventType: "error", dataBytes: "abc" }],
    ["negative dataBytes", { eventType: "error", dataBytes: -5 }],
    ["fractional dataBytes", { eventType: "error", dataBytes: 1.5 }],
    ["oversized errorMessage", { eventType: "error", errorMessage: "x".repeat(2001) }],
    ["unknown eventType", { eventType: "nope" }],
    ["missing eventType", {}],
  ])("rejects %s before the service is called", async (_label, body) => {
    const res = await request(app).post(url).send(body);
    expect(res.status).toBe(400);
    expect(recordUsageEvent).not.toHaveBeenCalled();
  });
});
