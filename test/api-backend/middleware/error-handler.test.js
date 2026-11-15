/**
 * @jest-environment node
 *
 * Error-handler middleware scenarios for api-backend (#624).
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
    '/boom-400',
    asyncHandler(async () => {
      const err = new Error('bad request');
      err.statusCode = 400;
      throw err;
    }),
  );

  app.get(
    '/boom-status',
    asyncHandler(async () => {
      const err = new Error('not found');
      err.status = 404;
      throw err;
    }),
  );

  app.get(
    '/boom-code',
    asyncHandler(async () => {
      const err = new Error('rate limited');
      err.statusCode = 429;
      err.code = 'RATE_LIMITED';
      throw err;
    }),
  );

  app.get(
    '/invalid-status',
    asyncHandler(async () => {
      const err = new Error('weird status');
      err.statusCode = 999;
      throw err;
    }),
  );

  app.get(
    '/crash',
    asyncHandler(async () => {
      throw new Error('unexpected failure');
    }),
  );

  app.get(
    '/headers-sent',
    asyncHandler(async (_req, res, next) => {
      res.status(200).json({ partial: true });
      const err = new Error('after headers');
      err.statusCode = 500;
      next(err);
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

  test('500 errors return error, statusCode, and timestamp', async () => {
    const res = await request(app).get('/crash');
    expect(res.status).toBe(500);
    expect(res.body.error).toBe('Internal server error');
    expect(res.body.statusCode).toBe(500);
    expect(typeof res.body.timestamp).toBe('string');
    expect(Number.isNaN(Date.parse(res.body.timestamp))).toBe(false);
  });

  test('client errors from statusCode include error, statusCode, timestamp', async () => {
    const res = await request(app).get('/boom-400');
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('bad request');
    expect(res.body.statusCode).toBe(400);
    expect(typeof res.body.timestamp).toBe('string');
  });

  test('client errors from status property include error, statusCode, timestamp', async () => {
    const res = await request(app).get('/boom-status');
    expect(res.status).toBe(404);
    expect(res.body.error).toBe('not found');
    expect(res.body.statusCode).toBe(404);
    expect(typeof res.body.timestamp).toBe('string');
  });

  test('client errors may include code when present', async () => {
    const res = await request(app).get('/boom-code');
    expect(res.status).toBe(429);
    expect(res.body.error).toBe('rate limited');
    expect(res.body.statusCode).toBe(429);
    expect(res.body.code).toBe('RATE_LIMITED');
    expect(typeof res.body.timestamp).toBe('string');
  });

  test('invalid status codes fall back to 500 shape', async () => {
    const res = await request(app).get('/invalid-status');
    expect(res.status).toBe(500);
    expect(res.body.error).toBe('Internal server error');
    expect(res.body.statusCode).toBe(500);
    expect(typeof res.body.timestamp).toBe('string');
  });

  test('does not overwrite response when headers already sent', async () => {
    const res = await request(app).get('/headers-sent');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ partial: true });
  });

  test('asyncHandler forwards rejected promises to error middleware', async () => {
    const res = await request(app).get('/crash');
    expect(res.status).toBe(500);
    expect(res.body).toEqual(
      expect.objectContaining({
        error: 'Internal server error',
        statusCode: 500,
      }),
    );
  });
});
