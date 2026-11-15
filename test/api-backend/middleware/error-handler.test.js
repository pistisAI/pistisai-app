/**
 * @jest-environment node
 */

import express from 'express';
import request from 'supertest';
import {
  asyncHandler,
  errorHandlerMiddleware,
} from '../../../services/api-backend/middleware/error-handler.js';

function buildApp() {
  const app = express();
  app.get(
    '/ok',
    asyncHandler(async (_req, res) => {
      res.status(200).json({ ok: true });
    }),
  );
  app.get(
    '/boom',
    asyncHandler(async () => {
      const err = new Error('boom');
      err.statusCode = 400;
      throw err;
    }),
  );
  app.get(
    '/crash',
    asyncHandler(async () => {
      throw new Error('unexpected');
    }),
  );
  app.use(errorHandlerMiddleware);
  return app;
}

describe('error-handler middleware', () => {
  const app = buildApp();

  test('asyncHandler passes successful responses', async () => {
    const res = await request(app).get('/ok');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });
  });

  test('client errors include error, statusCode, timestamp', async () => {
    const res = await request(app).get('/boom');
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('boom');
    expect(res.body.statusCode).toBe(400);
    expect(typeof res.body.timestamp).toBe('string');
  });

  test('500 errors include error, statusCode, timestamp', async () => {
    const res = await request(app).get('/crash');
    expect(res.status).toBe(500);
    expect(res.body.error).toBe('Internal server error');
    expect(res.body.statusCode).toBe(500);
    expect(typeof res.body.timestamp).toBe('string');
  });
});
