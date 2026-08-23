/**
 * Cloud Connector Routes
 *
 * Device registry and presence endpoints for the per-user cloud connector.
 * All endpoints require JWT authentication and are scoped to the
 * authenticated user's devices only.
 */

import express from 'express';
import { z } from 'zod';
import { authenticateJWT } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import { CloudConnectorService } from '../services/cloud-connector-service.js';
import logger from '../logger.js';

const router = express.Router();
let cloudConnectorService = null;

export async function initializeCloudConnectorService() {
  cloudConnectorService = new CloudConnectorService();
  await cloudConnectorService.initialize();
  if (!cloudConnectorService._sweeperInterval) {
    const SWEEP_INTERVAL_MS = 5 * 60 * 1000;
    cloudConnectorService._sweeperInterval = setInterval(() => {
      cloudConnectorService
        .markStaleDevicesOffline()
        .then((count) => {
          if (count > 0) {
            logger.info(
              `[CloudConnectorRoutes] Marked ${count} stale device(s) offline`,
            );
          }
        })
        .catch((err) =>
          logger.warn(
            `[CloudConnectorRoutes] Stale-device sweep failed: ${err.message}`,
          ),
        );
    }, SWEEP_INTERVAL_MS);
    cloudConnectorService._sweeperInterval.unref();
  }
  logger.info('[CloudConnectorRoutes] Cloud connector service initialized');
}

const deviceRegistrationSchema = z.object({
  device_id: z.string().min(8).max(64),
  device_name: z.string().max(200).optional(),
  platform: z.string().max(50).optional(),
  app_version: z.string().max(50).optional(),
  runtime_location: z
    .enum([
      'local',
      'private_device',
      'tailscale_device',
      'manual_url',
      'pistisai_hosted',
    ])
    .default('local'),
  capabilities: z.record(z.unknown()).default({}),
});

const heartbeatSchema = z.object({
  device_id: z.string().min(8).max(64),
  runtime_available: z.boolean().default(false),
  metadata: z.record(z.unknown()).default({}),
});

router.use(authenticateJWT);

function requireService(res) {
  if (!cloudConnectorService) {
    res.status(503).json({
      error: 'Service unavailable',
      code: 'SERVICE_UNAVAILABLE',
      message: 'Cloud connector service is not initialized',
    });
    return false;
  }
  return true;
}

async function resolveUserId(req, res) {
  const userId = await cloudConnectorService.resolveUserUuid(req.user.sub);
  if (!userId) {
    res.status(404).json({
      error: 'User not found',
      code: 'USER_NOT_FOUND',
      message: 'No user record for authenticated identity',
    });
    return null;
  }
  return userId;
}

router.post(
  '/devices',
  validateSchema({ body: deviceRegistrationSchema }),
  async (req, res) => {
    if (!requireService(res)) {
return;
}
    try {
      const userId = await resolveUserId(req, res);
      if (!userId) {
return;
}
      const b = req.body;
      const device = await cloudConnectorService.registerDevice(userId, {
        deviceId: b.device_id,
        deviceName: b.device_name,
        platform: b.platform,
        appVersion: b.app_version,
        runtimeLocation: b.runtime_location,
        capabilities: b.capabilities,
      });
      res.status(201).json({ success: true, data: device });
    } catch (error) {
      logger.error('[CloudConnectorRoutes] Device registration failed', {
        error: error.message,
      });
      const status = error.code === 'VALIDATION_ERROR' ? 400 : 500;
      res.status(status).json({
        error: 'Device registration failed',
        code: error.code || 'REGISTRATION_FAILED',
      });
    }
  },
);

router.get('/devices', async (req, res) => {
  if (!requireService(res)) {
return;
}
  try {
    const userId = await resolveUserId(req, res);
    if (!userId) {
return;
}
    const devices = await cloudConnectorService.listDevices(userId);
    res.json({ success: true, data: devices });
  } catch (error) {
    logger.error('[CloudConnectorRoutes] List devices failed', {
      error: error.message,
    });
    res.status(500).json({
      error: 'Failed to list devices',
      code: 'LIST_FAILED',
    });
  }
});

router.post(
  '/devices/heartbeat',
  validateSchema({ body: heartbeatSchema }),
  async (req, res) => {
    if (!requireService(res)) {
return;
}
    try {
      const userId = await resolveUserId(req, res);
      if (!userId) {
return;
}
      const result = await cloudConnectorService.heartbeat(
        userId,
        req.body.device_id,
        req.body.runtime_available,
        req.body.metadata,
      );
      res.json({ success: true, data: result });
    } catch (error) {
      logger.error('[CloudConnectorRoutes] Heartbeat failed', {
        error: error.message,
      });
      const status = error.code === 'DEVICE_NOT_FOUND' ? 404 : 500;
      res.status(status).json({
        error: 'Heartbeat failed',
        code: error.code || 'HEARTBEAT_FAILED',
      });
    }
  },
);

router.delete('/devices/:deviceId', async (req, res) => {
  if (!requireService(res)) {
return;
}
  try {
    const userId = await resolveUserId(req, res);
    if (!userId) {
return;
}
    const result = await cloudConnectorService.revokeDevice(
      userId,
      req.params.deviceId,
    );
    res.json({ success: true, data: result });
  } catch (error) {
    logger.error('[CloudConnectorRoutes] Revoke failed', {
      error: error.message,
    });
    const status = error.code === 'DEVICE_NOT_FOUND' ? 404 : 500;
    res.status(status).json({
      error: 'Revoke failed',
      code: error.code || 'REVOKE_FAILED',
    });
  }
});

export default router;
