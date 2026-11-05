/**
 * @fileoverview Prometheus metrics endpoint routes
 * Provides /metrics endpoint for Prometheus scraping
 */

import express from 'express';
import { metricsService } from '../services/metrics-service.js';
import { TunnelLogger } from '../utils/logger.js';

const router = express.Router();
const logger = new TunnelLogger('prometheus-metrics-routes');

router.get('/metrics', async (req, res) => {
  try {
    const metrics = await metricsService.getMetrics();
    const contentType = metricsService.getContentType();

    res.set('Content-Type', contentType);
    res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.set('Pragma', 'no-cache');
    res.set('Expires', '0');

    res.send(metrics);

    logger.debug('Prometheus metrics endpoint accessed', {
      metricsSize: metrics.length,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Failed to generate Prometheus metrics', {
      error: error.message,
      stack: error.stack,
    });

    res.status(500).json({
      error: 'Failed to generate metrics',
      message: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

router.get('/health/metrics', async (req, res) => {
  try {
    // Try to get metrics to verify collection is working
    const metrics = await metricsService.getMetrics();

    if (!metrics || metrics.length === 0) {
      return res.status(503).json({
        status: 'unhealthy',
        message: 'Metrics collection is not working',
        timestamp: new Date().toISOString(),
      });
    }

    res.json({
      status: 'healthy',
      message: 'Metrics collection is working',
      metricsSize: metrics.length,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Metrics health check failed', {
      error: error.message,
    });

    res.status(503).json({
      status: 'unhealthy',
      message: 'Metrics health check failed',
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

export default router;
