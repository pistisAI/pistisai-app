/**
 * Schema validation middleware — Express 5 query getter compatibility (#846).
 */

import { describe, it, expect, jest } from '@jest/globals';
import { z } from 'zod';
import { validateSchema } from '../../../services/api-backend/middleware/schema-validation.js';

function mockRes() {
  return {
    statusCode: null,
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

/** Simulate Express 5: req.query is a getter, not assignable. */
function express5Req(rawQuery) {
  const req = {
    path: '/test',
    method: 'GET',
    body: {},
    params: {},
    user: { sub: 'user-1' },
  };
  Object.defineProperty(req, 'query', {
    configurable: true,
    enumerable: true,
    get() {
      return rawQuery;
    },
  });
  return req;
}

describe('validateSchema query handling (#846)', () => {
  it('does not assign to req.query and stores parsed values on req.validatedQuery', async () => {
    const middleware = validateSchema({
      query: z.object({
        limit: z.coerce.number().int().default(50),
      }),
    });
    const req = express5Req({ limit: '10' });
    const res = mockRes();
    const next = jest.fn();

    await middleware(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
    expect(next.mock.calls[0][0]).toBeUndefined();
    expect(res.statusCode).toBeNull();
    expect(req.validatedQuery).toEqual({ limit: 10 });
    // Getter still returns the original raw query object
    expect(req.query).toEqual({ limit: '10' });
  });
});
