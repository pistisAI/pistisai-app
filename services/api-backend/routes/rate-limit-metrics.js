/**
 * @fileoverview Rate limit metrics routes
 * Provides endpoints for rate limit metrics and dashboards
 */

import express from 'express';
import { register } from 'prom-client';
import { TunnelLogger } from '../utils/logger.js';
import { rateLimitMetricsService } from '../services/rate-limit-metrics-service.js';
import { authenticateJWT } from '../middleware/auth.js';
import { requireAdmin } from '../middleware/rbac.js';

const router = express.Router();
const logger = new TunnelLogger('rate-limit-metrics-routes');

router.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    logger.error('Failed to generate metrics', {
      error: error.message,
    });
    res.status(500).json({
      error: 'Failed to generate metrics',
      message: error.message,
    });
  }
});

router.get('/rate-limit-metrics/summary', authenticateJWT, async (req, res) => {
  try {
    const summary = rateLimitMetricsService.getMetricsSummary();

    res.json({
      success: true,
      data: summary,
    });
  } catch (error) {
    logger.error('Failed to get metrics summary', {
      error: error.message,
      userId: req.userId,
    });
    res.status(500).json({
      error: 'Failed to get metrics summary',
      message: error.message,
    });
  }
});

router.get(
  '/rate-limit-metrics/top-violators',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const limit = Math.min(parseInt(req.query.limit) || 10, 100);
      const topViolators = rateLimitMetricsService.getTopViolators(limit);

      res.json({
        success: true,
        data: {
          timestamp: new Date().toISOString(),
          limit,
          count: topViolators.length,
          topViolators,
        },
      });
    } catch (error) {
      logger.error('Failed to get top violators', {
        error: error.message,
        userId: req.userId,
      });
      res.status(500).json({
        error: 'Failed to get top violators',
        message: error.message,
      });
    }
  },
);

router.get(
  '/rate-limit-metrics/top-ips',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const limit = Math.min(parseInt(req.query.limit) || 10, 100);
      const topIps = rateLimitMetricsService.getTopViolatingIps(limit);

      res.json({
        success: true,
        data: {
          timestamp: new Date().toISOString(),
          limit,
          count: topIps.length,
          topIps,
        },
      });
    } catch (error) {
      logger.error('Failed to get top violating IPs', {
        error: error.message,
        userId: req.userId,
      });
      res.status(500).json({
        error: 'Failed to get top violating IPs',
        message: error.message,
      });
    }
  },
);

router.get(
  '/rate-limit-metrics/dashboard-data',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const summary = rateLimitMetricsService.getMetricsSummary();
      const topViolators = rateLimitMetricsService.getTopViolators(10);
      const topIps = rateLimitMetricsService.getTopViolatingIps(10);

      res.json({
        success: true,
        data: {
          timestamp: new Date().toISOString(),
          summary: {
            totalViolators: summary.totalViolators,
            totalViolatingIps: summary.totalViolatingIps,
          },
          topViolators,
          topIps,
        },
      });
    } catch (error) {
      logger.error('Failed to get dashboard data', {
        error: error.message,
        userId: req.userId,
      });
      res.status(500).json({
        error: 'Failed to get dashboard data',
        message: error.message,
      });
    }
  },
);

export default router;
