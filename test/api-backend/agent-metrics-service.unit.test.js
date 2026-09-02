import { describe, expect, it } from "@jest/globals";

import { deriveMetrics } from "../../services/api-backend/services/agent-metrics-service.js";

describe("agent metrics service", () => {
  it("derives hourly metrics for message events", () => {
    const metrics = deriveMetrics("message:received", {});

    expect(metrics).toEqual([
      {
        name: "messages_per_hour",
        value: 1,
        window: "hourly",
      },
    ]);
  });

  it("records response time on reply events", () => {
    const metrics = deriveMetrics("reply", { duration_ms: 420 });

    expect(metrics).toEqual([
      {
        name: "avg_response_time",
        value: 420,
        window: "hourly",
      },
    ]);
  });
});
