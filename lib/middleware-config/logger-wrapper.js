/**
 * Logger Wrapper - Provides backward compatibility for middleware importing logger
 *
 * All middleware files import: import logger from './logger-wrapper.js'
 * Services must call setLoggerInstance() once during initialization
 */

import { getLoggerInstance } from './logger.js';

// Create logger object that delegates to the injected logger
const logger = {
  get error() {
    return getLoggerInstance().error;
  },
  get info() {
    return getLoggerInstance().info;
  },
  get warn() {
    return getLoggerInstance().warn;
  },
  get debug() {
    return getLoggerInstance().debug;
  },
};

export default logger;
