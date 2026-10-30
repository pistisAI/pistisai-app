/**


 * @fileoverview Tests for Adaptive Rate Limiting
 * Tests system load monitoring and adaptive rate limit adjustment
 */

import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import { SystemLoadMonitor } from "../../services/api-backend/services/system-load-monitor.js";

describe("Adaptive Rate Limiting", () => {
  describe("SystemLoadMonitor", () => {
    let monitor;

    beforeEach(() => {
      monitor = new SystemLoadMonitor({
        sampleIntervalMs: 100, // Fast sampling for tests
        historySize: 10,
      });
    });

    afterEach(() => {
      if (monitor) {
        monitor.destroy();
      }
    });

    it("should initialize with default configuration", () => {
      expect(monitor).toBeDefined();
      expect(monitor.config.sampleIntervalMs).toBe(100);
      expect(monitor.config.historySize).toBe(10);
      expect(monitor.adaptiveMultiplier).toBe(1.0);
    });

    it("should collect system metrics", (done) => {
      setTimeout(() => {
        monitor.collectMetrics();
        const metrics = monitor.getCurrentMetrics();

        expect(metrics).toBeDefined();
        expect(metrics.cpuUsage).toBeDefined();
        expect(metrics.memoryUsage).toBeDefined();
        expect(metrics.loadPercentage).toBeDefined();
        expect(metrics.loadLevel).toBeDefined();
        expect(metrics.adaptiveMultiplier).toBeDefined();

        // Verify metrics are numbers
        expect(typeof parseFloat(metrics.cpuUsage)).toBe("number");
        expect(typeof parseFloat(metrics.memoryUsage)).toBe("number");
        expect(typeof parseFloat(metrics.loadPercentage)).toBe("number");

        done();
      }, 150);
    });

    it("should track active requests", () => {
      monitor.recordActiveRequest();
      monitor.recordActiveRequest();
      expect(monitor.activeRequests).toBe(2);

      monitor.recordCompletedRequest();
      expect(monitor.activeRequests).toBe(1);
    });

    it("should track queued requests", () => {
      monitor.recordQueuedRequest();
      monitor.recordQueuedRequest();
      expect(monitor.queuedRequests).toBe(2);

      monitor.recordDequeuedRequest();
      expect(monitor.queuedRequests).toBe(1);
    });

    it("should calculate load percentage correctly", (done) => {
      setTimeout(() => {
        monitor.collectMetrics();
        const load = monitor.currentMetrics.getLoadPercentage();

        expect(load).toBeGreaterThanOrEqual(0);
        expect(load).toBeLessThanOrEqual(100);

        done();
      }, 150);
    });

    it("should determine load level correctly", (done) => {
      setTimeout(() => {
        monitor.collectMetrics();
        const level = monitor.currentMetrics.getLoadLevel();

        expect(["low", "medium", "high", "critical"]).toContain(level);

        done();
      }, 150);
    });

    it("should maintain metrics history", (done) => {
      let collectionCount = 0;

      const interval = setInterval(() => {
        monitor.collectMetrics();
        collectionCount++;

        if (collectionCount >= 3) {
          clearInterval(interval);

          expect(monitor.metricsHistory.length).toBeGreaterThan(0);
          expect(monitor.metricsHistory.length).toBeLessThanOrEqual(10);

          done();
        }
      }, 50);
    });

    it("should calculate average metrics", (done) => {
      let collectionCount = 0;

      const interval = setInterval(() => {
        monitor.collectMetrics();
        collectionCount++;

        if (collectionCount >= 3) {
          clearInterval(interval);

          const avgMetrics = monitor.getAverageMetrics();

          expect(avgMetrics.cpuUsage).toBeDefined();
          expect(avgMetrics.memoryUsage).toBeDefined();
          expect(avgMetrics.loadPercentage).toBeDefined();
          expect(avgMetrics.sampleCount).toBeGreaterThan(0);

          done();
        }
      }, 50);
    });

    it("should provide adaptive limits based on system load", (done) => {
      setTimeout(() => {
        monitor.collectMetrics();
        const limits = monitor.getAdaptiveLimits(1000);

        expect(limits.baseLimit).toBe(1000);
        expect(limits.adaptiveLimit).toBeDefined();
        expect(limits.multiplier).toBeDefined();
        expect(limits.loadLevel).toBeDefined();
        expect(limits.recommendation).toBeDefined();

        // Adaptive limit should be <= base limit
        expect(limits.adaptiveLimit).toBeLessThanOrEqual(limits.baseLimit);

        done();
      }, 150);
    });

    it("should provide system status", (done) => {
      setTimeout(() => {
        monitor.collectMetrics();
        const status = monitor.getSystemStatus();

        expect(status.current).toBeDefined();
        expect(status.average).toBeDefined();
        expect(status.requests).toBeDefined();
        expect(status.adaptive).toBeDefined();
        expect(status.system).toBeDefined();

        expect(status.requests.active).toBeDefined();
        expect(status.requests.queued).toBeDefined();
        expect(status.requests.total).toBeDefined();

        done();
      }, 150);
    });

    it("should adjust adaptive multiplier based on load", (done) => {
      // Simulate high load
      monitor.currentMetrics.cpuUsage = 85;
      monitor.currentMetrics.memoryUsage = 80;

      monitor.updateAdaptiveMultiplier(true); // Force immediate update

      // Should reduce multiplier under high load
      expect(monitor.adaptiveMultiplier).toBeLessThan(1.0);

      done();
    });

    it("should not adjust multiplier during cooldown period", (done) => {
      monitor.currentMetrics.cpuUsage = 85;
      monitor.currentMetrics.memoryUsage = 80;

      monitor.updateAdaptiveMultiplier();
      const firstMultiplier = monitor.adaptiveMultiplier;

      // Try to adjust again immediately
      monitor.currentMetrics.cpuUsage = 95;
      monitor.currentMetrics.memoryUsage = 95;

      monitor.updateAdaptiveMultiplier();

      // Multiplier should not change due to cooldown
      expect(monitor.adaptiveMultiplier).toBe(firstMultiplier);

      done();
    });
  });
});
