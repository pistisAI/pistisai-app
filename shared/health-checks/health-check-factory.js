/**
 * Health Check Factory
 * Provides standardized health check endpoints for all services
 * Implements Kubernetes-style health checks: liveness (/health) and readiness (/ready)
 */

export class HealthCheckFactory {
  constructor(logger = null) {
    this.logger = logger;
    this.startTime = Date.now();
    this.dependencies = {
      database: null,
      cache: null,
      services: [],
      customChecks: [],
    };
    this.isReady = false;
    this.readyCallbacks = [];
  }

  /**
   * Mark the service as ready
   */
  markReady() {
    this.isReady = true;
    this.readyCallbacks.forEach((callback) => callback());
  }

  /**
   * Mark the service as not ready
   */
  markNotReady(reason = 'Unknown') {
    this.isReady = false;
    this.log('warn', `Service marked as not ready: ${reason}`);
  }

  /**
   * Register a custom readiness check
   * @param {string} name - Check name
   * @param {Function} checkFn - Async function that returns { status, message, details? }
   */
  registerReadinessCheck(name, checkFn) {
    this.dependencies.customChecks.push({
      name,
      checkFn,
      type: 'readiness',
    });
  }

  /**
   * Register a liveness check
   * @param {string} name - Check name
   * @param {Function} checkFn - Async function that returns { status, message, details? }
   */
  registerLivenessCheck(name, checkFn) {
    this.dependencies.customChecks.push({
      name,
      checkFn,
      type: 'liveness',
    });
  }

  /**
   * Register database dependency
   */
  registerDatabase(dbInstance) {
    this.dependencies.database = dbInstance;
  }

  /**
   * Register cache dependency
   */
  registerCache(cacheInstance) {
    this.dependencies.cache = cacheInstance;
  }

  /**
   * Check if service is alive (liveness probe)
   * A service is alive if it's still running and not in a broken state
   */
  async checkLiveness() {
    const checks = {};
    const timestamp = new Date().toISOString();

    try {
      // Check custom liveness checks
      const livenessChecks = this.dependencies.customChecks.filter(
        (c) => c.type === 'liveness'
      );

      for (const check of livenessChecks) {
        try {
          checks[check.name] = await check.checkFn();
        } catch (error) {
          this.log('error', `Liveness check failed for ${check.name}:`, error);
          checks[check.name] = {
            status: 'unhealthy',
            message: `Check failed: ${error.message}`,
          };
        }
      }

      // Check uptime - a service that's been restarted recently might be recovering
      const uptime = process.uptime();

      // Determine overall liveness status
      const statuses = Object.values(checks).map((c) => c.status);
      const overallStatus = statuses.includes('unhealthy')
        ? 'unhealthy'
        : statuses.includes('degraded')
          ? 'degraded'
          : 'healthy';

      return {
        status: overallStatus,
        timestamp,
        uptime,
        checks,
      };
    } catch (error) {
      this.log('error', 'Failed to check liveness:', error);
      return {
        status: 'unhealthy',
        timestamp,
        error: error.message,
      };
    }
  }

  /**
   * Check if service is ready (readiness probe)
   * A service is ready if dependencies are initialized and it can handle requests
   */
  async checkReadiness() {
    const checks = {};
    const timestamp = new Date().toISOString();

    try {
      // Quick check: is the service explicitly marked as ready?
      if (!this.isReady) {
        return {
          status: 'not_ready',
          timestamp,
          message: 'Service initialization in progress',
          checks: {},
        };
      }

      // Check database
      if (this.dependencies.database) {
        checks.database = await this.checkDatabaseReadiness();
      }

      // Check cache
      if (this.dependencies.cache) {
        checks.cache = await this.checkCacheReadiness();
      }

      // Check custom readiness checks
      const readinessChecks = this.dependencies.customChecks.filter(
        (c) => c.type === 'readiness'
      );

      for (const check of readinessChecks) {
        try {
          checks[check.name] = await check.checkFn();
        } catch (error) {
          this.log('error', `Readiness check failed for ${check.name}:`, error);
          checks[check.name] = {
            status: 'not_ready',
            message: `Check failed: ${error.message}`,
          };
        }
      }

      // Determine overall readiness status
      const statuses = Object.values(checks)
        .filter((c) => c.status)
        .map((c) => c.status);

      const overallStatus =
        statuses.includes('not_ready') || statuses.length === 0
          ? 'not_ready'
          : statuses.includes('degraded')
            ? 'degraded'
            : 'ready';

      return {
        status: overallStatus,
        timestamp,
        checks,
      };
    } catch (error) {
      this.log('error', 'Failed to check readiness:', error);
      return {
        status: 'not_ready',
        timestamp,
        error: error.message,
      };
    }
  }

  /**
   * Check database readiness
   */
  async checkDatabaseReadiness() {
    try {
      if (!this.dependencies.database) {
        return { status: 'unknown', message: 'Database not registered' };
      }

      // Try pool query first, then db.get
      if (this.dependencies.database.pool) {
        await this.dependencies.database.pool.query('SELECT 1');
      } else if (this.dependencies.database.db) {
        await this.dependencies.database.db.get('SELECT 1');
      } else if (this.dependencies.database.isConnected) {
        // For custom implementations
        if (!this.dependencies.database.isConnected()) {
          return {
            status: 'not_ready',
            message: 'Database not connected',
          };
        }
      } else {
        return {
          status: 'unknown',
          message: 'Database connection not initialized',
        };
      }

      return {
        status: 'ready',
        message: 'Database is ready',
      };
    } catch (error) {
      this.log('error', 'Database readiness check failed:', error);
      return {
        status: 'not_ready',
        message: 'Database readiness check failed',
        error: error.message,
      };
    }
  }

  /**
   * Check cache readiness
   */
  async checkCacheReadiness() {
    try {
      if (!this.dependencies.cache) {
        return { status: 'unknown', message: 'Cache not registered' };
      }

      if (typeof this.dependencies.cache.ping === 'function') {
        await this.dependencies.cache.ping();
        return { status: 'ready', message: 'Cache is ready' };
      }

      return {
        status: 'unknown',
        message: 'Cache readiness check not available',
      };
    } catch (error) {
      this.log('error', 'Cache readiness check failed:', error);
      return {
        status: 'not_ready',
        message: 'Cache readiness check failed',
        error: error.message,
      };
    }
  }

  /**
   * Get complete health status (combined liveness + readiness + metadata)
   */
  async getHealthStatus(serviceName = 'unknown-service') {
    const [liveness, readiness] = await Promise.all([
      this.checkLiveness(),
      this.checkReadiness(),
    ]);

    return {
      service: serviceName,
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      liveness,
      readiness,
      // Overall status: unhealthy if either liveness or readiness is unhealthy
      status:
        liveness.status === 'unhealthy' || readiness.status === 'not_ready'
          ? 'unhealthy'
          : readiness.status === 'degraded' || liveness.status === 'degraded'
            ? 'degraded'
            : 'healthy',
    };
  }

  /**
   * Create Express middleware for liveness probe
   * GET /health
   */
  createLivenessMiddleware() {
    return async (req, res) => {
      try {
        const liveness = await this.checkLiveness();

        const statusCode =
          liveness.status === 'unhealthy' ? 503 : liveness.status === 'degraded' ? 200 : 200;

        res.status(statusCode).json(liveness);
      } catch (error) {
        this.log('error', 'Liveness endpoint error:', error);
        res.status(503).json({
          status: 'unhealthy',
          timestamp: new Date().toISOString(),
          error: error.message,
        });
      }
    };
  }

  /**
   * Create Express middleware for readiness probe
   * GET /ready
   */
  createReadinessMiddleware() {
    return async (req, res) => {
      try {
        const readiness = await this.checkReadiness();

        // Readiness: return 200 if ready, 503 if not ready
        const statusCode =
          readiness.status === 'ready' || readiness.status === 'degraded' ? 200 : 503;

        res.status(statusCode).json(readiness);
      } catch (error) {
        this.log('error', 'Readiness endpoint error:', error);
        res.status(503).json({
          status: 'not_ready',
          timestamp: new Date().toISOString(),
          error: error.message,
        });
      }
    };
  }

  /**
   * Create a simple health check for minimal services
   * Returns basic status and uptime
   */
  createSimpleHealthMiddleware(serviceName = 'service') {
    return (req, res) => {
      res.status(200).json({
        status: 'healthy',
        service: serviceName,
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
      });
    };
  }

  /**
   * Internal logging helper
   */
  log(level, message, ...args) {
    if (this.logger && typeof this.logger[level] === 'function') {
      this.logger[level](message, ...args);
    } else if (level === 'error') {
      console.error(message, ...args);
    } else if (level === 'warn') {
      console.warn(message, ...args);
    } else {
      console.log(message, ...args);
    }
  }
}

export default HealthCheckFactory;
