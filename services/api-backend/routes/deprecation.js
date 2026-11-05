/**
 * API Deprecation Routes
 *
 * Provides endpoints for deprecation information and migration guides.
 * Allows clients to discover deprecated endpoints and access migration documentation.
 *
 * Requirements: 12.5
 */

import express from 'express';
import {
  getDeprecationStatusReport,
  getAllDeprecatedEndpoints,
  getAllSunsetEndpoints,
  getMigrationGuide,
  getDeprecationInfo,
  MIGRATION_GUIDES,
} from '../services/deprecation-service.js';

const router = express.Router();

router.get('/status', (req, res) => {
  try {
    const report = getDeprecationStatusReport();
    res.json(report);
  } catch {
    res.status(500).json({
      error: {
        code: 'DEPRECATION_STATUS_ERROR',
        message: 'Failed to retrieve deprecation status',
        statusCode: 500,
      },
    });
  }
});

router.get('/deprecated', (req, res) => {
  try {
    const endpoints = getAllDeprecatedEndpoints();
    res.json({
      endpoints,
      count: endpoints.length,
    });
  } catch {
    res.status(500).json({
      error: {
        code: 'DEPRECATED_LIST_ERROR',
        message: 'Failed to retrieve deprecated endpoints',
        statusCode: 500,
      },
    });
  }
});

router.get('/sunset', (req, res) => {
  try {
    const endpoints = getAllSunsetEndpoints();
    res.json({
      endpoints,
      count: endpoints.length,
    });
  } catch {
    res.status(500).json({
      error: {
        code: 'SUNSET_LIST_ERROR',
        message: 'Failed to retrieve sunset endpoints',
        statusCode: 500,
      },
    });
  }
});

router.get('/migration-guide/:guideId', (req, res) => {
  try {
    const { guideId } = req.params;
    const guide = MIGRATION_GUIDES[guideId];

    if (!guide) {
      return res.status(404).json({
        error: {
          code: 'MIGRATION_GUIDE_NOT_FOUND',
          message: `Migration guide '${guideId}' not found`,
          statusCode: 404,
          suggestion: 'Check the guide ID and try again',
        },
      });
    }

    res.json(guide);
  } catch {
    res.status(500).json({
      error: {
        code: 'MIGRATION_GUIDE_ERROR',
        message: 'Failed to retrieve migration guide',
        statusCode: 500,
      },
    });
  }
});

router.get('/endpoint-info', (req, res) => {
  try {
    const { path } = req.query;

    if (!path) {
      return res.status(400).json({
        error: {
          code: 'MISSING_PATH_PARAMETER',
          message: 'path query parameter is required',
          statusCode: 400,
          suggestion: 'Provide the endpoint path as a query parameter',
        },
      });
    }

    const info = getDeprecationInfo(path);

    if (!info) {
      return res.status(404).json({
        error: {
          code: 'ENDPOINT_NOT_DEPRECATED',
          message: `Endpoint '${path}' is not deprecated`,
          statusCode: 404,
        },
      });
    }

    res.json({
      path,
      ...info,
      migrationGuide: getMigrationGuide(path),
    });
  } catch {
    res.status(500).json({
      error: {
        code: 'ENDPOINT_INFO_ERROR',
        message: 'Failed to retrieve endpoint information',
        statusCode: 500,
      },
    });
  }
});

export default router;
