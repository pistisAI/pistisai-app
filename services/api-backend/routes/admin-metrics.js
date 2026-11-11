/**
 * Admin Center Metrics Endpoint
 *
 * Exposes Prometheus metrics for the Admin Center API
 *
 * Requirements: Task 31.2, Requirement 12
 */

import express from 'express';
import rateLimit from 'express-rate-limit';
import logger from '../logger.js';
import { adminAuth } from '../middleware/admin-auth.js';
import {
  exportAdminMetricsAsText,
  initializeAdminMetrics,
} from '../middleware/admin-metrics.js';

const router = express.Router();
// Same limit as the global pipeline limiter, applied here as well so every
// route on this router is visibly rate limited.
router.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    standardHeaders: true,
    legacyHeaders: false,
  }),
);

// Initialize metrics on startup
initializeAdminMetrics();

/**
 * GET /metrics
 *
 * Export Prometheus metrics in text format
 *
 * Response: text/plain with Prometheus metrics
 */
router.get('/metrics', adminAuth(['view_system_metrics']), async (req, res) => {
  try {
    res.set('Content-Type', 'text/plain; version=0.0.4; charset=utf-8');
    const metrics = await exportAdminMetricsAsText();
    res.send(metrics);
  } catch (error) {
    logger.error('Error exporting metrics', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).send('Error exporting metrics');
  }
});

export default router;
