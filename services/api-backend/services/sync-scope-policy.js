/**
 * Sync Scope Policy
 *
 * Enforces the sync rules from docs/architecture/SECURE_DEVICE_MESH.md:
 * - Global/syncable: secure channel history, active agent runtime metadata,
 *   device presence, user-approved avatar/companion state, non-sensitive prefs.
 * - Device-scoped: screen/camera capture, clipboard, shell commands, file
 *   operations, window/app control, local secrets.
 *
 * Device-scoped operations must always carry an explicit target device and are
 * never synced through the cloud connector; local app permissions remain the
 * final authorization layer.
 */

// Categories the cloud connector may sync globally for the user.
export const SYNCABLE_SCOPES = Object.freeze([
  'channel_history',
  'runtime_metadata',
  'device_presence',
  'companion_state',
  'preferences',
]);

// Categories that stay on the originating device and require explicit
// device targeting — the connector only relays them when permitted by
// local app policy, never stores or broadcasts them.
export const DEVICE_SCOPED = Object.freeze([
  'screen_capture',
  'camera_capture',
  'clipboard',
  'shell_commands',
  'file_operations',
  'window_control',
  'local_secrets',
]);

const DEVICE_SCOPE_SET = new Set(DEVICE_SCOPED);

/**
 * Classify an operation scope.
 * @param {string} scope
 * @returns {{syncable: boolean, requiresTargetDevice: boolean}}
 */
export function classifyScope(scope) {
  if (DEVICE_SCOPE_SET.has(scope)) {
    return { syncable: false, requiresTargetDevice: true };
  }
  if (SYNCABLE_SCOPES.includes(scope)) {
    return { syncable: true, requiresTargetDevice: false };
  }
  // Unknown scopes default to device-scoped (fail closed).
  return { syncable: false, requiresTargetDevice: true };
}

/**
 * Validate a relay request for a device-scoped operation.
 * Throws when the target device is missing or does not belong to the user.
 * @param {CloudConnectorService} service
 * @param {string} userId
 * @param {{scope: string, targetDeviceId?: string}} request
 * @returns {Promise<{allowed: boolean, reason?: string}>}
 */
export async function authorizeRelay(service, userId, request) {
  const classification = classifyScope(request.scope);
  if (!classification.requiresTargetDevice) {
    return { allowed: true };
  }
  if (!request.targetDeviceId) {
    return {
      allowed: false,
      reason: 'MISSING_TARGET_DEVICE',
    };
  }
  const device = await service._getUserDevice(userId, request.targetDeviceId);
  if (!device) {
    return {
      allowed: false,
      reason: 'TARGET_DEVICE_NOT_FOUND',
    };
  }
  if (device.status !== 'online') {
    return {
      allowed: false,
      reason: 'TARGET_DEVICE_OFFLINE',
    };
  }
  // Local app permission is enforced on the device itself; the connector
  // only verifies targeting + reachability here.
  return { allowed: true };
}

export default { SYNCABLE_SCOPES, DEVICE_SCOPED, classifyScope, authorizeRelay };
