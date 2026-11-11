/**
 * Admin Routes for CORS Policy Management
 *
 * Provides endpoints to inspect and manage brand CORS policies.
 * Protected by admin authentication.
 *
 * Issue #385: CORS policy enforcement for whitelabel builds
 */

import express from 'express';
import { getAllBrandPolicies, getBrandCORSPolicy } from '../middleware/brand-cors-config.js';
import { authenticateJWT } from '../middleware/auth.js';
import { authorizeRBAC } from '../middleware/rbac.js';
import logger from '../logger.js';

const router = express.Router();

/**
 * GET /admin/cors-policies
 * List all registered brand CORS policies
 * Protected: admin-only
 */
router.get('/cors-policies', authenticateJWT, authorizeRBAC(['admin']), (req, res) => {
  try {
    const allPolicies = getAllBrandPolicies();

    res.json({
      status: 'success',
      totalBrands: Object.keys(allPolicies).length,
      policies: allPolicies,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Error fetching CORS policies', {
      error: error.message,
      stack: error.stack,
    });

    res.status(500).json({
      status: 'error',
      message: 'Failed to fetch CORS policies',
      error: error.message,
    });
  }
});

/**
 * GET /admin/cors-policies/:brandId
 * Get CORS policy for a specific brand
 * Protected: admin-only
 */
router.get('/cors-policies/:brandId', authenticateJWT, authorizeRBAC(['admin']), (req, res) => {
  try {
    const { brandId } = req.params;
    const policy = getBrandCORSPolicy(brandId);

    res.json({
      status: 'success',
      brandId,
      policy,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Error fetching CORS policy for brand', {
      brandId: req.params.brandId,
      error: error.message,
      stack: error.stack,
    });

    res.status(500).json({
      status: 'error',
      message: 'Failed to fetch CORS policy',
      error: error.message,
    });
  }
});

/**
 * POST /admin/cors-policies/validate
 * Validate if an origin is allowed for a brand
 * Protected: admin-only
 */
router.post('/cors-policies/validate', authenticateJWT, authorizeRBAC(['admin']), (req, res) => {
  try {
    const { brandId, origin } = req.body;

    if (!brandId || !origin) {
      return res.status(400).json({
        status: 'error',
        message: 'Missing required fields: brandId, origin',
      });
    }

    const policy = getBrandCORSPolicy(brandId);
    const isAllowed = (policy.origins || []).includes(origin);

    res.json({
      status: 'success',
      brandId,
      origin,
      isAllowed,
      message: isAllowed
        ? 'Origin is allowed for this brand'
        : 'Origin is NOT allowed for this brand',
      allowedOriginCount: (policy.origins || []).length,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Error validating origin for brand', {
      brandId: req.body.brandId,
      origin: req.body.origin,
      error: error.message,
      stack: error.stack,
    });

    res.status(500).json({
      status: 'error',
      message: 'Failed to validate origin',
      error: error.message,
    });
  }
});

export default router;
