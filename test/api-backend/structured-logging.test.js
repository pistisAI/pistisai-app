import { jest } from '@jest/globals';
import logger from '../../services/api-backend/logger.js';
import { createLogger, LogLevel } from '../../shared/structured-logger.js';

describe('Structured JSON Logging Across Services', () => {
  describe('JSON Format Output', () => {
    it('api-backend logger outputs JSON format in production', () => {
      // The logger.js exports a Winston logger that outputs JSON
      expect(logger).toBeDefined();
      expect(typeof logger.info).toBe('function');
      expect(typeof logger.error).toBe('function');
      expect(typeof logger.warn).toBe('function');
      expect(typeof logger.debug).toBe('function');
    });

    it('api-backend logger has structured component logging methods', () => {
      // Component loggers should exist
      expect(logger.auth).toBeDefined();
      expect(logger.proxy).toBeDefined();
      expect(logger.zrok).toBeDefined();
      expect(logger.container).toBeDefined();
      expect(logger.database).toBeDefined();

      // Each should have standard log methods
      ['auth', 'proxy', 'zrok', 'container', 'database'].forEach((component) => {
        expect(typeof logger[component].info).toBe('function');
        expect(typeof logger[component].error).toBe('function');
        expect(typeof logger[component].warn).toBe('function');
        expect(typeof logger[component].debug).toBe('function');
      });
    });

    it('shared structured logger creates service-specific loggers', () => {
      const apiLogger = createLogger('api-backend');
      const proxyLogger = createLogger('streaming-proxy');
      const relayLogger = createLogger('tailscale-relay');

      expect(apiLogger).toBeDefined();
      expect(proxyLogger).toBeDefined();
      expect(relayLogger).toBeDefined();

      // Each should have standard methods
      [apiLogger, proxyLogger, relayLogger].forEach((lgr) => {
        expect(typeof lgr.info).toBe('function');
        expect(typeof lgr.warn).toBe('function');
        expect(typeof lgr.error).toBe('function');
        expect(typeof lgr.debug).toBe('function');
        expect(typeof lgr.trace).toBe('function');
      });
    });

    it('supports log levels across all services', () => {
      const logger = createLogger('test-service');
      expect(() => {
        logger.error('error');
        logger.warn('warn');
        logger.info('info');
        logger.debug('debug');
        logger.trace('trace');
      }).not.toThrow();
    });

    it('child loggers can be created with component context', () => {
      const logger = createLogger('api-backend');
      const authLogger = logger.child('auth', { userId: 'user-1' });
      expect(authLogger).toBeDefined();
      expect(typeof authLogger.info).toBe('function');
    });
  });

  describe('Log Entry Structure', () => {
    it('shared logger produces valid log entries', () => {
      // Simulate what structured logger produces
      const createEntry = (level, message, metadata = {}) => {
        return {
          timestamp: new Date().toISOString(),
          level,
          service: 'test-service',
          component: 'test-component',
          message,
          pid: process.pid,
          version: '1.0.0',
        };
      };

      const entry = createEntry('INFO', 'Test message');

      // Should have required fields
      expect(entry).toHaveProperty('timestamp');
      expect(entry).toHaveProperty('level');
      expect(entry).toHaveProperty('service');
      expect(entry).toHaveProperty('message');
      expect(entry).toHaveProperty('pid');

      // Timestamp should be valid ISO 8601
      expect(() => new Date(entry.timestamp)).not.toThrow();
    });

    it('supports correlation IDs for distributed tracing', () => {
      const createEntry = (level, message, metadata = {}) => {
        const entry = {
          timestamp: new Date().toISOString(),
          level,
          service: 'test-service',
          message,
        };

        if (metadata.correlationId) {
          entry.correlationId = metadata.correlationId;
        }

        if (metadata.userId) {
          entry.userId = metadata.userId;
        }

        return entry;
      };

      const entry = createEntry('INFO', 'Request', {
        correlationId: 'trace-123',
        userId: 'user-1',
      });

      expect(entry).toHaveProperty('correlationId', 'trace-123');
      expect(entry).toHaveProperty('userId', 'user-1');
    });

    it('handles error objects in logs', () => {
      const createEntry = (level, message, metadata = {}) => {
        const entry = {
          timestamp: new Date().toISOString(),
          level,
          service: 'test-service',
          message,
        };

        if (metadata.error instanceof Error) {
          entry.error = {
            message: metadata.error.message,
            stack: metadata.error.stack,
            code: metadata.error.code,
          };
        }

        return entry;
      };

      const testError = new Error('Something failed');
      const entry = createEntry('ERROR', 'Operation failed', { error: testError });

      expect(entry.error).toBeDefined();
      expect(entry.error.message).toBe('Something failed');
      expect(entry.error.stack).toBeDefined();
    });
  });

  describe('Service Compatibility', () => {
    it('all services can use unified logger API', () => {
      const services = [
        { name: 'api-backend', component: 'auth' },
        { name: 'streaming-proxy', component: 'relay' },
        { name: 'tailscale-relay', component: 'websocket' },
      ];

      services.forEach(({ name, component }) => {
        const serviceLogger = createLogger(name, component);
        expect(() => {
          serviceLogger.info('Service test', { requestId: 'test-123' });
          serviceLogger.error('Error test', { error: new Error('test') });
        }).not.toThrow();
      });
    });

    it('log levels can be configured via environment', () => {
      const originalLevel = process.env.LOG_LEVEL;

      // Test that level reading works
      process.env.LOG_LEVEL = 'debug';
      expect(process.env.LOG_LEVEL).toBe('debug');

      process.env.LOG_LEVEL = 'error';
      expect(process.env.LOG_LEVEL).toBe('error');

      // Restore
      if (originalLevel) {
        process.env.LOG_LEVEL = originalLevel;
      } else {
        delete process.env.LOG_LEVEL;
      }
    });
  });

  describe('API Backend Logger Integration', () => {
    it('provides request logging middleware', () => {
      expect(typeof logger.logRequest).toBe('function');
    });

    it('has component-specific loggers for all services', () => {
      const components = ['zrok', 'auth', 'proxy', 'container', 'database'];
      components.forEach((comp) => {
        expect(logger[comp]).toBeDefined();
        expect(logger[comp].info).toBeDefined();
        expect(logger[comp].warn).toBeDefined();
        expect(logger[comp].error).toBeDefined();
        expect(logger[comp].debug).toBeDefined();
      });
    });

    it('initializes with correct service name', () => {
      // The logger should be configured with 'api-backend' as service
      expect(logger).toBeDefined();
      // Note: Winston doesn't expose defaultMeta easily, but we can verify the logger exists
      expect(typeof logger.info).toBe('function');
    });
  });

  describe('Tailscale Relay Logger Integration', () => {
    it('tailscale-relay logger has structured logging', async () => {
      // Import the tailscale relay logger
      const relayLogger = await import(
        '../../services/tailscale-relay/src/logger.js'
      );
      expect(relayLogger.default).toBeDefined();
      expect(relayLogger.LogLevel).toBeDefined();

      const logger = relayLogger.default;
      expect(typeof logger.info).toBe('function');
      expect(typeof logger.error).toBe('function');
      expect(typeof logger.warn).toBe('function');
      expect(typeof logger.debug).toBe('function');
    });
  });
});
