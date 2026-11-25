import logger from '../logger.js';

let dbMigrator;

export function setDbMigrator(migrator) {
  dbMigrator = migrator;
}

/**
 * Public database health check.
 *
 * The route has no authentication, so it returns only a status word and a
 * timestamp. Per-table validation results and error messages go to the
 * server log, not to the caller.
 */
export const dbHealthHandler = async (req, res) => {
  try {
    if (!dbMigrator) {
      return res.status(503).json({
        status: 'error',
        timestamp: new Date().toISOString(),
      });
    }

    const validation = await dbMigrator.validateSchema();

    if (!validation.allValid) {
      logger.warn('Database schema validation reported invalid tables', {
        results: validation.results,
      });
    }

    res.json({
      status: validation.allValid ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Database health check failed:', error);
    res.status(503).json({
      status: 'error',
      timestamp: new Date().toISOString(),
    });
  }
};

export default dbHealthHandler;
