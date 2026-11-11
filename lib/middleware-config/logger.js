/**
 * Logger Adapter for Middleware Config
 *
 * Services must inject their logger instance before using middleware.
 * This prevents circular dependencies and allows each service to use its own logger.
 */

let _loggerInstance = null;

/**
 * Set the logger instance to be used by all middleware
 * Call this once during service initialization before setting up middleware
 *
 * @param {Object} logger - Logger instance with error(), info(), warn(), debug() methods
 */
export function setLoggerInstance(logger) {
  _loggerInstance = logger;
}

/**
 * Get the current logger instance
 * @returns {Object} Logger instance, or console if not set
 */
export function getLoggerInstance() {
  if (!_loggerInstance) {
    console.warn(
      '[middleware-config] Logger not initialized. Call setLoggerInstance() first. Using console as fallback.'
    );
    return {
      error: (msg, ctx) => console.error('[ERROR]', msg, ctx),
      info: (msg, ctx) => console.info('[INFO]', msg, ctx),
      warn: (msg, ctx) => console.warn('[WARN]', msg, ctx),
      debug: (msg, ctx) => console.debug('[DEBUG]', msg, ctx),
    };
  }
  return _loggerInstance;
}

// Default export for easy usage
export default {
  setLoggerInstance,
  getLoggerInstance,
};
