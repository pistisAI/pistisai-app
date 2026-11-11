/**
 * Structured JSON Logger for Tailscale Relay Service
 *
 * Provides consistent structured logging across the tailscale-relay service.
 */

/**
 * Log levels
 */
const LogLevel = {
  ERROR: 'ERROR',
  WARN: 'WARN',
  INFO: 'INFO',
  DEBUG: 'DEBUG',
  TRACE: 'TRACE',
};

const LOG_LEVEL_HIERARCHY = {
  [LogLevel.ERROR]: 0,
  [LogLevel.WARN]: 1,
  [LogLevel.INFO]: 2,
  [LogLevel.DEBUG]: 3,
  [LogLevel.TRACE]: 4,
};

/**
 * Get current log level from environment or default to INFO
 */
function getCurrentLogLevel() {
  const envLevel = (process.env.LOG_LEVEL || 'INFO').toUpperCase();
  return LogLevel[envLevel] || LogLevel.INFO;
}

/**
 * Check if a message should be logged based on current level
 */
function shouldLog(level) {
  const currentLevel = getCurrentLogLevel();
  return LOG_LEVEL_HIERARCHY[level] <= LOG_LEVEL_HIERARCHY[currentLevel];
}

/**
 * Create a structured log entry
 */
function createLogEntry(level, message, metadata = {}, component) {
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    service: 'tailscale-relay',
    component: component || metadata.component,
    message,
    pid: process.pid,
    version: process.env.npm_package_version || '1.0.0',
  };

  // Add correlation ID if present
  if (metadata.correlationId) {
    entry.correlationId = metadata.correlationId;
  }

  // Add user ID if present
  if (metadata.userId) {
    entry.userId = metadata.userId;
  }

  // Add connection ID if present
  if (metadata.connectionId) {
    entry.connectionId = metadata.connectionId;
  }

  // Add duration if present
  if (metadata.duration !== undefined) {
    entry.duration = metadata.duration;
  }

  // Add error details if present
  if (metadata.error instanceof Error) {
    entry.error = {
      message: metadata.error.message,
      stack: metadata.error.stack,
      code: metadata.error.code,
    };
  } else if (metadata.error) {
    entry.error = metadata.error;
  }

  // Add custom metadata (exclude reserved keys)
  const reservedKeys = ['component', 'correlationId', 'userId', 'connectionId', 'duration', 'error'];
  const customMeta = Object.keys(metadata).reduce((acc, key) => {
    if (!reservedKeys.includes(key)) {
      acc[key] = metadata[key];
    }
    return acc;
  }, {});

  if (Object.keys(customMeta).length > 0) {
    entry.metadata = customMeta;
  }

  return entry;
}

/**
 * Format log entry as JSON
 */
function formatLogEntry(entry) {
  return JSON.stringify(entry);
}

/**
 * Logger implementation for Tailscale Relay
 */
class TailscaleRelayLogger {
  constructor(component = 'relay') {
    this.component = component;
  }

  /**
   * Log at ERROR level
   */
  error(message, metadata = {}) {
    if (!shouldLog(LogLevel.ERROR)) return;
    const entry = createLogEntry(LogLevel.ERROR, message, metadata, this.component);
    console.error(formatLogEntry(entry));
  }

  /**
   * Log at WARN level
   */
  warn(message, metadata = {}) {
    if (!shouldLog(LogLevel.WARN)) return;
    const entry = createLogEntry(LogLevel.WARN, message, metadata, this.component);
    console.warn(formatLogEntry(entry));
  }

  /**
   * Log at INFO level
   */
  info(message, metadata = {}) {
    if (!shouldLog(LogLevel.INFO)) return;
    const entry = createLogEntry(LogLevel.INFO, message, metadata, this.component);
    console.info(formatLogEntry(entry));
  }

  /**
   * Log at DEBUG level
   */
  debug(message, metadata = {}) {
    if (!shouldLog(LogLevel.DEBUG)) return;
    const entry = createLogEntry(LogLevel.DEBUG, message, metadata, this.component);
    console.debug(formatLogEntry(entry));
  }

  /**
   * Log at TRACE level
   */
  trace(message, metadata = {}) {
    if (!shouldLog(LogLevel.TRACE)) return;
    const entry = createLogEntry(LogLevel.TRACE, message, metadata, this.component);
    console.debug(formatLogEntry(entry));
  }

  /**
   * Create a child logger with specific component
   */
  child(component) {
    return new TailscaleRelayLogger(component);
  }

  /**
   * Log WebSocket connection event
   */
  logConnection(userId, targetIp, metadata = {}) {
    this.info('WebSocket connection established', {
      userId,
      targetIp,
      ...metadata,
    });
  }

  /**
   * Log WebSocket error
   */
  logError(userId, error, metadata = {}) {
    this.error(`WebSocket error for user ${userId}`, {
      userId,
      error,
      ...metadata,
    });
  }
}

// Create default logger instance
const logger = new TailscaleRelayLogger();

export default logger;
export { TailscaleRelayLogger, LogLevel };
