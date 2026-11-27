/**
 * Behavior tests for the database health route handler.
 */

import { describe, it, expect, beforeEach } from '@jest/globals';
import {
  dbHealthHandler,
  setDbMigrator,
} from '../../services/api-backend/routes/db-health.js';

function mockRes() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

describe('db-health route', () => {
  beforeEach(() => {
    setDbMigrator(undefined);
  });

  it('returns 503 when migrator is not initialized', async () => {
    const res = mockRes();
    await dbHealthHandler({}, res);
    expect(res.statusCode).toBe(503);
    expect(res.body.status).toBe('error');
    expect(Object.keys(res.body).sort()).toEqual(['status', 'timestamp']);
  });

  it('returns healthy when schema validation passes', async () => {
    setDbMigrator({
      validateSchema: async () => ({
        allValid: true,
        results: { users: true },
      }),
    });
    const res = mockRes();
    await dbHealthHandler({}, res);
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(Object.keys(res.body).sort()).toEqual(['status', 'timestamp']);
  });

  it('returns degraded when schema validation fails checks', async () => {
    setDbMigrator({
      validateSchema: async () => ({
        allValid: false,
        results: { users: false },
      }),
    });
    const res = mockRes();
    await dbHealthHandler({}, res);
    expect(res.body.status).toBe('degraded');
    expect(res.body.schema_validation).toBeUndefined();
  });

  it('returns 503 when validation throws', async () => {
    setDbMigrator({
      validateSchema: async () => {
        throw new Error('connection refused');
      },
    });
    const res = mockRes();
    await dbHealthHandler({}, res);
    expect(res.statusCode).toBe(503);
    expect(res.body.status).toBe('error');
    expect(JSON.stringify(res.body)).not.toContain('connection refused');
  });
});
