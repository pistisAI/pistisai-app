/**
 * Unified Structured JSON Logger for PistisAI Backend Services
 *
 * Provides consistent JSON logging across all backend services with:
 * - Structured log entries (JSON format)
 * - Log level management
 * - Correlation IDs for distributed tracing
 * - Service-specific context
 * - Performance-optimized output
 */

/**
 * Log levels in order of severity
 */
export const LogLevel = {
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
 * Get current log level from environment or default
 */
function getCurrentLogLevel() {
  const envLevel = process.env.LOG_LEVEL || 'INFO';
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
function createLogEntry(level, message, metadata = {}, service, component) {
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    service,
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

  // Add request ID if present
  if (metadata.requestId) {
    entry.requestId = metadata.requestId;
  }

  // Add duration if present (for performance logging)
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
  const reservedKeys = ['component', 'correlationId', 'userId', 'requestId', 'duration', 'error'];
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
 * Format log entry for output
 */
function formatLogEntry(entry) {
  // Always output JSON for structured logging
  return JSON.stringify(entry);
}

/**
 * Core logger implementation
 */
class StructuredLogger {
  constructor(service, component = null) {
    this.service = service;
    this.component = component;
  }

  /**
   * Log at ERROR level
   */
  error(message, metadata = {}) {
    if (!shouldLog(LogLevel.ERROR)) return;
    const entry = createLogEntry(LogLevel.ERROR, message, metadata, this.service, this.component);
    console.error(formatLogEntry(entry));
  }

  /**
   * Log at WARN level
   */
  warn(message, metadata = {}) {
    if (!shouldLog(LogLevel.WARN)) return;
    const entry = createLogEntry(LogLevel.WARN, message, metadata, this.service, this.component);
    console.warn(formatLogEntry(entry));
  }

  /**
   * Log at INFO level
   */
  info(message, metadata = {}) {
    if (!shouldLog(LogLevel.INFO)) return;
    const entry = createLogEntry(LogLevel.INFO, message, metadata, this.service, this.component);
    console.info(formatLogEntry(entry));
  }

  /**
   * Log at DEBUG level
   */
  debug(message, metadata = {}) {
    if (!shouldLog(LogLevel.DEBUG)) return;
    const entry = createLogEntry(LogLevel.DEBUG, message, metadata, this.service, this.component);
    console.debug(formatLogEntry(entry));
  }

  /**
   * Log at TRACE level
   */
  trace(message, metadata = {}) {
    if (!shouldLog(LogLevel.TRACE)) return;
    const entry = createLogEntry(LogLevel.TRACE, message, metadata, this.service, this.component);
    console.debug(formatLogEntry(entry));
  }

  /**
   * Create a child logger with additional context
   */
  child(component, metadata = {}) {
    const childLogger = new StructuredLogger(this.service, component);
    if (metadata && Object.keys(metadata).length > 0) {
      // Store context for use in child logger methods
      childLogger._defaultMetadata = metadata;
    }
    return childLogger;
  }

  /**
   * Log HTTP request details
   */
  logRequest(method, url, statusCode, duration, metadata = {}) {
    const level = statusCode >= 400 ? LogLevel.WARN : LogLevel.INFO;
    const message = `HTTP ${method} ${url}`;
    this[level.toLowerCase()](message, {
      method,
      url,
      statusCode,
      duration,
      ...metadata,
    });
  }

  /**
   * Log database query
   */
  logQuery(query, duration, metadata = {}) {
    const level = duration > 1000 ? LogLevel.WARN : LogLevel.DEBUG;
    const message = `Database query executed`;
    this[level.toLowerCase()](message, {
      query: query.substring(0, 200), // Truncate for safety
      duration,
      ...metadata,
    });
  }
}

/**
 * Create a logger for a specific service
 */
export function createLogger(service, component = null) {
  return new StructuredLogger(service, component);
}

/**
 * Create loggers for common services
 */
export const loggers = {
  apiBackend: createLogger('api-backend'),
  streamingProxy: createLogger('streaming-proxy'),
  tailscaleRelay: createLogger('tailscale-relay'),
  auth: createLogger('auth-service'),
};

export default { createLogger, loggers, LogLevel };
