/**
 * Tailscale Join Service
 *
 * Provisions the per-user cloud connector's Tailscale join flow
 * (docs/architecture/SECURE_DEVICE_MESH.md):
 * - generates a short-lived, single-use join token scoped to one user
 * - emits a container run configuration for the isolated connector
 * - the connector joins ONLY that user's tailnet as a tagged service device
 *
 * The actual tailnet admission is performed by the Tailscale auth key the
 * operator supplies (TS_AUTH_KEY with tags:pistisai-connector ACL tag).
 * This service never sees or stores tailnet admin credentials.
 */

import crypto from 'crypto';
import logger from '../logger.js';

const JOIN_TOKEN_TTL_MINUTES = 15;

export class TailscaleJoinService {
  constructor() {
    // userId -> { token, expiresAt, used }
    this.pendingJoins = new Map();
    this._sweeper = setInterval(() => this._sweep(), 60 * 1000);
    this._sweeper.unref();
  }

  /**
   * Create a single-use join token for a user's connector.
   */
  createJoinToken(userId) {
    const token = crypto.randomBytes(24).toString('hex');
    const expiresAt = Date.now() + JOIN_TOKEN_TTL_MINUTES * 60 * 1000;
    this.pendingJoins.set(userId, { token, expiresAt, used: false });
    logger.info('[TailscaleJoin] Join token issued', {
      userId,
      ttlMinutes: JOIN_TOKEN_TTL_MINUTES,
    });
    return { token, expiresAt: new Date(expiresAt).toISOString() };
  }

  /**
   * Redeem a join token: single-use, TTL-bound. Returns the connector
   * container spec on success.
   */
  redeemJoinToken(userId, token) {
    const entry = this.pendingJoins.get(userId);
    if (!entry || entry.used || entry.token !== token) {
      return { ok: false, reason: 'INVALID_JOIN_TOKEN' };
    }
    if (Date.now() > entry.expiresAt) {
      this.pendingJoins.delete(userId);
      return { ok: false, reason: 'JOIN_TOKEN_EXPIRED' };
    }
    entry.used = true;
    this.pendingJoins.delete(userId);
    return { ok: true, spec: this.buildConnectorSpec(userId) };
  }

  /**
   * Container spec for the user's isolated connector. One container per
   * user; joins only their tailnet; tagged as a service device.
   */
  buildConnectorSpec(userId) {
    const containerName = `pistisai-connector-${String(userId)
      .slice(0, 12)
      .replace(/[^a-z0-9-]/gi, '')}`;
    return {
      containerName,
      image: 'pistisai/cloud-connector:latest',
      tailscale: {
        hostname: containerName,
        tags: ['tag:pistisai-connector'],
        // Auth key comes from operator env at deploy time — never persisted.
        authKeyEnv: 'TS_AUTH_KEY',
        acceptRoutes: false,
        ssh: false,
      },
      constraints: {
        scope: 'single_user',
        noTailnetScan: true,
        desktopActionsRequireLocalPermission: true,
      },
    };
  }

  _sweep() {
    const now = Date.now();
    for (const [userId, entry] of this.pendingJoins) {
      if (now > entry.expiresAt) {
        this.pendingJoins.delete(userId);
      }
    }
  }

  destroy() {
    clearInterval(this._sweeper);
  }
}

export default TailscaleJoinService;
