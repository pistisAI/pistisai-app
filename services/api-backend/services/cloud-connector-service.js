/**
 * Cloud Connector Service
 *
 * Per-user cloud connector foundation: device registry and presence tracking
 * for the Tailscale-first secure device mesh. One isolated connector per user;
 * this service stores only that user's device/sync metadata.
 *
 * See docs/architecture/SECURE_DEVICE_MESH.md
 */

import logger from '../logger.js';
import { initializePool } from '../database/db-pool.js';

const VALID_RUNTIME_LOCATIONS = new Set([
  'local',
  'private_device',
  'tailscale_device',
  'manual_url',
  'pistisai_hosted',
]);

export class CloudConnectorService {
  constructor() {
    this.pool = null;
  }

  async initialize() {
    try {
      this.pool = await initializePool();
      logger.info('[CloudConnectorService] Service initialized');
    } catch (error) {
      logger.error('[CloudConnectorService] Failed to initialize', {
        error: error.message,
      });
      throw error;
    }
  }

  _assertPool() {
    if (!this.pool) {
      throw Object.assign(new Error('Service not initialized'), {
        code: 'SERVICE_NOT_INITIALIZED',
      });
    }
  }

  async resolveUserUuid(authSub) {
    this._assertPool();
    const result = await this.pool.query(
      'SELECT id FROM users WHERE auth0_sub = $1 OR id::text = $1 LIMIT 1',
      [authSub],
    );
    return result.rows[0]?.id || null;
  }

  async registerDevice(userId, device) {
    this._assertPool();
    if (!VALID_RUNTIME_LOCATIONS.has(device.runtimeLocation)) {
      throw Object.assign(
        new Error(`Invalid runtime location: ${device.runtimeLocation}`),
        { code: 'VALIDATION_ERROR' },
      );
    }
    const query = `
      INSERT INTO cloud_devices (
        user_id, device_id, device_name, platform, app_version,
        runtime_location, capabilities, status
      ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, 'online')
      ON CONFLICT (device_id) DO UPDATE SET
        user_id = EXCLUDED.user_id,
        device_name = EXCLUDED.device_name,
        platform = EXCLUDED.platform,
        app_version = EXCLUDED.app_version,
        runtime_location = EXCLUDED.runtime_location,
        capabilities = EXCLUDED.capabilities,
        status = 'online',
        updated_at = NOW()
      RETURNING *`;
    const result = await this.pool.query(query, [
      userId,
      device.deviceId,
      device.deviceName || null,
      device.platform || null,
      device.appVersion || null,
      device.runtimeLocation || 'local',
      JSON.stringify(device.capabilities || {}),
    ]);
    await this._upsertPresence(result.rows[0].id, true);
    return result.rows[0];
  }

  async heartbeat(userId, deviceId, runtimeAvailable = false, metadata = {}) {
    this._assertPool();
    const device = await this._getUserDevice(userId, deviceId);
    if (!device) {
      throw Object.assign(new Error('Device not registered'), {
        code: 'DEVICE_NOT_FOUND',
      });
    }
    await this.pool.query(
      "UPDATE cloud_devices SET status = 'online', updated_at = NOW() WHERE id = $1",
      [device.id],
    );
    const presence = await this._upsertPresence(
      device.id,
      runtimeAvailable,
      metadata,
    );
    return { deviceId, lastSeen: presence.last_seen };
  }

  async listDevices(userId) {
    this._assertPool();
    const result = await this.pool.query(
      `SELECT d.*, p.last_seen, p.runtime_available
       FROM cloud_devices d
       LEFT JOIN cloud_presence p ON p.device_uuid = d.id
       WHERE d.user_id = $1 AND d.status != 'revoked'
       ORDER BY d.updated_at DESC`,
      [userId],
    );
    return result.rows;
  }

  async revokeDevice(userId, deviceId) {
    this._assertPool();
    const device = await this._getUserDevice(userId, deviceId);
    if (!device) {
      throw Object.assign(new Error('Device not found'), {
        code: 'DEVICE_NOT_FOUND',
      });
    }
    await this.pool.query(
      "UPDATE cloud_devices SET status = 'revoked', updated_at = NOW() WHERE id = $1",
      [device.id],
    );
    await this.pool.query('DELETE FROM cloud_presence WHERE device_uuid = $1', [
      device.id,
    ]);
    return { deviceId, revoked: true };
  }

  async _getUserDevice(userId, deviceId) {
    const result = await this.pool.query(
      'SELECT * FROM cloud_devices WHERE user_id = $1 AND device_id = $2 AND status != \'revoked\'',
      [userId, deviceId],
    );
    return result.rows[0] || null;
  }

  async _upsertPresence(deviceUuid, runtimeAvailable, metadata = {}) {
    const result = await this.pool.query(
      `INSERT INTO cloud_presence (device_uuid, last_seen, runtime_available, metadata)
       VALUES ($1, NOW(), $2, $3::jsonb)
       ON CONFLICT (device_uuid) DO UPDATE SET
         last_seen = NOW(),
         runtime_available = EXCLUDED.runtime_available,
         metadata = EXCLUDED.metadata
       RETURNING last_seen`,
      [deviceUuid, runtimeAvailable, JSON.stringify(metadata)],
    );
    return result.rows[0];
  }

  async markStaleDevicesOffline(staleAfterMinutes = 10) {
    this._assertPool();
    const result = await this.pool.query(
      `UPDATE cloud_devices SET status = 'offline', updated_at = NOW()
       WHERE status = 'online'
         AND id IN (
           SELECT device_uuid FROM cloud_presence
           WHERE last_seen < NOW() - ($1 || ' minutes')::interval
         )`,
      [String(staleAfterMinutes)],
    );
    return result.rowCount;
  }
}

export default CloudConnectorService;
