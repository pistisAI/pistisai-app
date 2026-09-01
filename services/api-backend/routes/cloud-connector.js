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
import {
  classifyScope,
  authorizeRelay,
  SYNCABLE_SCOPES,
} from '../services/sync-scope-policy.js';
import { TailscaleJoinService } from '../services/tailscale-join-service.js';
import logger from '../logger.js';

const router = express.Router();
let cloudConnectorService = null;
const tailscaleJoinService = new TailscaleJoinService();

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

const relayRequestSchema = z.object({
  scope: z.string().min(1).max(50),
  target_device_id: z.string().min(8).max(64).optional(),
  payload: z.record(z.unknown()).default({}),
});

router.post(
  '/relay',
  validateSchema({ body: relayRequestSchema }),
  async (req, res) => {
    if (!requireService(res)) {
return;
}
    try {
      const userId = await resolveUserId(req, res);
      if (!userId) {
return;
      }
      const classification = classifyScope(req.body.scope);
      if (classification.syncable) {
        // Syncable scope — connector may coordinate it globally.
        return res.json({
          success: true,
          data: {
            scope: req.body.scope,
            syncable: true,
            requiresTargetDevice: false,
          },
        });
      }
      // Device-scoped — require explicit targeting and reachability.
      const decision = await authorizeRelay(cloudConnectorService, userId, {
        scope: req.body.scope,
        targetDeviceId: req.body.target_device_id,
      });
      if (!decision.allowed) {
        const status =
          decision.reason === 'MISSING_TARGET_DEVICE' ||
          decision.reason === 'TARGET_DEVICE_NOT_FOUND'
            ? 404
            : 409;
        return res.status(status).json({
          error: 'Relay not authorized',
          code: decision.reason,
        });
      }
      res.json({
        success: true,
        data: {
          scope: req.body.scope,
          syncable: false,
          requiresTargetDevice: true,
          targetDeviceId: req.body.target_device_id,
        },
      });
    } catch (error) {
      logger.error('[CloudConnectorRoutes] Relay check failed', {
        error: error.message,
      });
      res.status(500).json({
        error: 'Relay check failed',
        code: 'RELAY_FAILED',
      });
    }
  },
);

router.get('/sync-scopes', async (req, res) => {
  res.json({ success: true, data: { syncable: SYNCABLE_SCOPES } });
});

const joinTokenSchema = z.object({}).default({});
const joinRedeemSchema = z.object({
  token: z.string().min(16).max(128),
});

// Issue a single-use Tailscale join token for the user's connector.
router.post('/tailscale/join-token', validateSchema({ body: joinTokenSchema }), async (req, res) => {
  if (!requireService(res)) {
    return;
  }
  try {
    const userId = await resolveUserId(req, res);
    if (!userId) {
return;
    }
    const { token, expiresAt } = tailscaleJoinService.createJoinToken(userId);
    res.status(201).json({
      success: true,
      data: { token, expiresAt, ttlMinutes: 15 },
    });
  } catch (error) {
    logger.error('[CloudConnectorRoutes] Join token issue failed', {
      error: error.message,
    });
    res.status(500).json({
      error: 'Join token issue failed',
      code: 'JOIN_TOKEN_FAILED',
    });
  }
});

// Redeem a join token → connector container spec for this user's tailnet.
router.post('/tailscale/join', validateSchema({ body: joinRedeemSchema }), async (req, res) => {
  if (!requireService(res)) {
    return;
  }
  try {
    const userId = await resolveUserId(req, res);
    if (!userId) {
return;
    }
    const result = tailscaleJoinService.redeemJoinToken(userId, req.body.token);
    if (!result.ok) {
      const status = result.reason === 'JOIN_TOKEN_EXPIRED' ? 410 : 403;
      return res.status(status).json({
        error: 'Join rejected',
        code: result.reason,
      });
    }
    res.json({ success: true, data: result.spec });
  } catch (error) {
    logger.error('[CloudConnectorRoutes] Join redeem failed', {
      error: error.message,
    });
    res.status(500).json({
      error: 'Join redeem failed',
      code: 'JOIN_REDEEM_FAILED',
    });
  }
});

export default router;
