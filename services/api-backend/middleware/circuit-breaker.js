/**
 * Circuit Breaker Pattern Middleware
 *
 * Implements the circuit breaker pattern to prevent cascading failures when
 * external services are unavailable. The circuit breaker monitors requests
 * to external services and opens the circuit (fails fast) after a threshold
 * of failures is reached.
 *
 * States:
 * - CLOSED: Normal operation, requests pass through
 * - OPEN: Too many failures, requests fail immediately
 * - HALF_OPEN: Testing if service recovered, limited requests allowed
 *
 * @fileoverview Circuit breaker middleware for external service resilience
 * @version 1.0.0
 */

import logger from '../logger.js';

/**
 * Circuit breaker states
 */
export const CIRCUIT_STATES = {
  CLOSED: 'CLOSED',
  OPEN: 'OPEN',
  HALF_OPEN: 'HALF_OPEN',
};

/**
 * Circuit Breaker class
 *
 * Manages the state and behavior of a single circuit breaker instance.
 */
export class CircuitBreaker {
  /**
   * Create a new circuit breaker
   * @param {Object} options - Configuration options
   * @param {string} options.name - Name of the circuit breaker
   * @param {number} options.failureThreshold - Failures before opening (default: 5)
   * @param {number} options.successThreshold - Successes before closing (default: 2)
   * @param {number} options.timeout - Time before half-open attempt (ms, default: 30000)
   * @param {Function} options.fallback - Fallback function when circuit is open
   */
  constructor(options = {}) {
    this.name = options.name || 'default';
    this.failureThreshold = options.failureThreshold || 5;
    this.successThreshold = options.successThreshold || 2;
    this.timeout = options.timeout || 30000;
    this.fallback = options.fallback;

    this.state = CIRCUIT_STATES.CLOSED;
    this.failureCount = 0;
    this.successCount = 0;
    this.lastFailureTime = null;
    this.nextAttemptTime = null;
  }

  /**
   * Record a successful request
   */
  recordSuccess() {
    this.failureCount = 0;

    if (this.state === CIRCUIT_STATES.HALF_OPEN) {
      this.successCount++;

      if (this.successCount >= this.successThreshold) {
        this.state = CIRCUIT_STATES.CLOSED;
        this.successCount = 0;
        logger.info(`Circuit breaker "${this.name}" closed after successful recovery`, {
          circuitName: this.name,
          state: this.state,
        });
      }
    }
  }

  /**
   * Record a failed request
   */
  recordFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();

    if (this.state === CIRCUIT_STATES.CLOSED && this.failureCount >= this.failureThreshold) {
      this.state = CIRCUIT_STATES.OPEN;
      this.nextAttemptTime = Date.now() + this.timeout;

      logger.warn(`Circuit breaker "${this.name}" opened after ${this.failureCount} failures`, {
        circuitName: this.name,
        state: this.state,
        failureCount: this.failureCount,
        nextAttemptTime: new Date(this.nextAttemptTime).toISOString(),
      });
    } else if (this.state === CIRCUIT_STATES.HALF_OPEN) {
      this.state = CIRCUIT_STATES.OPEN;
      this.successCount = 0;
      this.nextAttemptTime = Date.now() + this.timeout;

      logger.warn(
        `Circuit breaker "${this.name}" reopened during recovery attempt`,
        {
          circuitName: this.name,
          state: this.state,
          nextAttemptTime: new Date(this.nextAttemptTime).toISOString(),
        },
      );
    }
  }

  /**
   * Check if the circuit breaker can allow a request
   * @returns {boolean} - True if request should proceed, false if it should be rejected
   */
  canProceed() {
    if (this.state === CIRCUIT_STATES.CLOSED) {
      return true;
    }

    if (this.state === CIRCUIT_STATES.OPEN) {
      // Check if it's time to attempt recovery
      if (Date.now() >= this.nextAttemptTime) {
        this.state = CIRCUIT_STATES.HALF_OPEN;
        this.successCount = 0;

        logger.info(`Circuit breaker "${this.name}" entering half-open state`, {
          circuitName: this.name,
          state: this.state,
        });

        return true;
      }

      return false;
    }

    // HALF_OPEN: allow the request
    return true;
  }

  /**
   * Get the current state of the circuit breaker
   * @returns {Object} - Current state metrics
   */
  getState() {
    return {
      name: this.name,
      state: this.state,
      failureCount: this.failureCount,
      successCount: this.successCount,
      lastFailureTime: this.lastFailureTime,
      nextAttemptTime: this.nextAttemptTime,
    };
  }

  /**
   * Reset the circuit breaker (for testing)
   */
  reset() {
    this.state = CIRCUIT_STATES.CLOSED;
    this.failureCount = 0;
    this.successCount = 0;
    this.lastFailureTime = null;
    this.nextAttemptTime = null;
  }
}

/**
 * Circuit Breaker Manager
 *
 * Manages multiple circuit breakers for different external services.
 */
export class CircuitBreakerManager {
  constructor() {
    this.breakers = new Map();
  }

  /**
   * Get or create a circuit breaker for a service
   * @param {string} serviceName - Name of the external service
   * @param {Object} options - Circuit breaker options
   * @returns {CircuitBreaker} - The circuit breaker instance
   */
  getBreaker(serviceName, options = {}) {
    if (!this.breakers.has(serviceName)) {
      const breaker = new CircuitBreaker({
        name: serviceName,
        ...options,
      });
      this.breakers.set(serviceName, breaker);
    }

    return this.breakers.get(serviceName);
  }

  /**
   * Get all circuit breakers and their states
   * @returns {Array} - Array of circuit breaker states
   */
  getAllStates() {
    return Array.from(this.breakers.values()).map((breaker) => breaker.getState());
  }

  /**
   * Reset all circuit breakers (for testing)
   */
  resetAll() {
    for (const breaker of this.breakers.values()) {
      breaker.reset();
    }
  }
}

// Global circuit breaker manager
export const circuitBreakerManager = new CircuitBreakerManager();

/**
 * Create circuit breaker middleware
 *
 * @param {Object} options - Middleware configuration
 * @param {Object} options.breakers - Mapping of service names to breaker configs
 * @param {Function} options.isExternalServiceCall - Function to identify external service calls
 * @param {Function} options.getFallbackResponse - Function to generate fallback responses
 * @returns {Function} - Express middleware
 */
export function createCircuitBreakerMiddleware(options = {}) {
  const { breakers = {}, isExternalServiceCall, getFallbackResponse } = options;

  // Initialize circuit breakers
  for (const [serviceName, config] of Object.entries(breakers)) {
    circuitBreakerManager.getBreaker(serviceName, config);
  }

  return async (req, res, next) => {
    // Attach circuit breaker manager to request for route handlers to use
    req.circuitBreakerManager = circuitBreakerManager;

    // Call the function to identify external service calls and determine which breaker to use
    const serviceName = isExternalServiceCall?.(req);

    if (!serviceName) {
      // Not an external service call, proceed normally
      return next();
    }

    const breaker = circuitBreakerManager.getBreaker(serviceName);

    // Check if we can proceed
    if (!breaker.canProceed()) {
      logger.warn(`Circuit breaker for "${serviceName}" is open, returning fallback response`, {
        serviceName,
        state: breaker.state,
      });

      const fallbackResponse = getFallbackResponse?.(req, serviceName);

      if (fallbackResponse) {
        return res.status(fallbackResponse.status).json(fallbackResponse.body);
      }

      return res.status(503).json({
        error: 'Service Unavailable',
        message: `External service "${serviceName}" is currently unavailable. Please try again later.`,
      });
    }

    // Attach breaker to request for handlers to update state
    req.currentCircuitBreaker = breaker;
    req.currentServiceName = serviceName;

    next();
  };
}

/**
 * Middleware to handle circuit breaker state updates
 *
 * Should be used in error handling middleware to record failures
 */
export function circuitBreakerErrorHandler(err, req, res, next) {
  if (req.currentCircuitBreaker) {
    req.currentCircuitBreaker.recordFailure();
  }

  // Continue with error handling
  next(err);
}

/**
 * Helper to record success for external service calls
 *
 * Can be called from route handlers or other middleware
 */
export function recordCircuitBreakerSuccess(req) {
  if (req.currentCircuitBreaker) {
    req.currentCircuitBreaker.recordSuccess();
  }
}

/**
 * Helper to record failure for external service calls
 */
export function recordCircuitBreakerFailure(req) {
  if (req.currentCircuitBreaker) {
    req.currentCircuitBreaker.recordFailure();
  }
}

/**
 * Create a wrapped axios client with circuit breaker support
 *
 * @param {Object} axiosInstance - Axios instance to wrap
 * @param {string} serviceName - Name of the external service
 * @param {Object} breakerConfig - Circuit breaker configuration
 * @returns {Object} - Wrapped axios instance
 */
export function createCircuitBreakerAxios(axiosInstance, serviceName, breakerConfig = {}) {
  const breaker = circuitBreakerManager.getBreaker(serviceName, breakerConfig);

  const originalRequest = axiosInstance.request;

  axiosInstance.request = async function (config) {
    if (!breaker.canProceed()) {
      logger.error(
        `Circuit breaker for "${serviceName}" is ${breaker.state}, failing fast`,
        {
          serviceName,
          state: breaker.state,
        },
      );

      const error = new Error(`Circuit breaker for service "${serviceName}" is ${breaker.state}`);
      error.code = 'CIRCUIT_BREAKER_OPEN';
      error.status = 503;
      throw error;
    }

    try {
      const response = await originalRequest.call(this, config);
      breaker.recordSuccess();
      return response;
    } catch (error) {
      breaker.recordFailure();
      throw error;
    }
  };

  return axiosInstance;
}

export default circuitBreakerManager;
