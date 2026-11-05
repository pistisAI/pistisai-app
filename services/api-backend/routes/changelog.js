/**
 * Changelog Routes
 *
 * Provides API endpoints for accessing changelog and release notes
 *
 * Requirements: 12.10
 */

import express from 'express';
import ChangelogService from '../services/changelog-service.js';

const router = express.Router();
const changelogService = new ChangelogService();

router.get('/', (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 10, 100);
    const offset = Math.max(parseInt(req.query.offset) || 0, 0);

    if (limit < 1 || limit > 100) {
      return res.status(400).json({
        error: 'Invalid limit parameter. Must be between 1 and 100.',
      });
    }

    if (offset < 0) {
      return res.status(400).json({
        error: 'Invalid offset parameter. Must be >= 0.',
      });
    }

    const result = changelogService.getAllVersions(limit, offset);

    // Format entries
    result.versions = result.versions.map((entry) =>
      changelogService.formatChangelogEntry(entry),
    );

    res.json(result);
  } catch (error) {
    res.status(500).json({
      error: 'Failed to retrieve changelog',
      message: error.message,
    });
  }
});

router.get('/latest', (req, res) => {
  try {
    const latest = changelogService.getLatestVersion();

    if (!latest) {
      return res.status(404).json({
        error: 'No changelog entries found',
      });
    }

    res.json(changelogService.formatChangelogEntry(latest));
  } catch (error) {
    res.status(500).json({
      error: 'Failed to retrieve latest version',
      message: error.message,
    });
  }
});

router.get('/:version', (req, res) => {
  try {
    const { version } = req.params;

    // Validate version format
    if (!version.match(/^\d+\.\d+\.\d+/)) {
      return res.status(400).json({
        error:
          'Invalid version format. Expected semantic versioning (e.g., 2.0.0)',
      });
    }

    const releaseNotes = changelogService.getReleaseNotes(version);

    if (!releaseNotes) {
      return res.status(404).json({
        error: `Release notes not found for version ${version}`,
      });
    }

    res.json(releaseNotes);
  } catch (error) {
    res.status(500).json({
      error: 'Failed to retrieve release notes',
      message: error.message,
    });
  }
});

router.get('/stats', (req, res) => {
  try {
    const stats = changelogService.getChangelogStats();
    res.json(stats);
  } catch (error) {
    res.status(500).json({
      error: 'Failed to retrieve changelog statistics',
      message: error.message,
    });
  }
});

export default router;
