/**
 * Behavior tests for request validation middleware.
 */

import { describe, it, expect, jest, beforeEach } from '@jest/globals';
import {
  createRequestValidationMiddleware,
  requestValidationMiddleware,
} from '../../../services/api-backend/middleware/request-validation.js';

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

function mockReq({ method = 'POST', headers = {}, user = null } = {}) {
  return {
    method,
    path: '/api/test',
    correlationId: 'corr-1',
    user,
    get(name) {
      const key = Object.keys(headers).find(
        (k) => k.toLowerCase() === name.toLowerCase(),
      );
      return key ? headers[key] : undefined;
    },
  };
}

describe('request-validation middleware', () => {
  let next;
  let middleware;

  beforeEach(() => {
    next = jest.fn();
    middleware = createRequestValidationMiddleware();
  });

  it('skips validation for GET, HEAD, and OPTIONS', () => {
    for (const method of ['GET', 'HEAD', 'OPTIONS']) {
      next.mockClear();
      const res = mockRes();
      middleware(mockReq({ method }), res, next);
      expect(next).toHaveBeenCalledTimes(1);
      expect(res.statusCode).toBeNull();
    }
  });

  it('rejects POST without Content-Type', () => {
    const res = mockRes();
    middleware(mockReq({ method: 'POST', headers: {} }), res, next);
    expect(res.statusCode).toBe(400);
    expect(res.body.code).toBe('MISSING_CONTENT_TYPE');
    expect(next).not.toHaveBeenCalled();
  });

  it('allows DELETE without Content-Type', () => {
    const res = mockRes();
    middleware(mockReq({ method: 'DELETE', headers: {} }), res, next);
    expect(next).toHaveBeenCalledTimes(1);
    expect(res.statusCode).toBeNull();
  });

  it('rejects unsupported media types', () => {
    const res = mockRes();
    middleware(
      mockReq({
        method: 'POST',
        headers: { 'Content-Type': 'text/plain' },
      }),
      res,
      next,
    );
    expect(res.statusCode).toBe(415);
    expect(res.body.code).toBe('UNSUPPORTED_MEDIA_TYPE');
    expect(next).not.toHaveBeenCalled();
  });

  it('accepts application/json Content-Type', () => {
    const res = mockRes();
    middleware(
      mockReq({
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
      }),
      res,
      next,
    );
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('accepts multipart and form-urlencoded Content-Types', () => {
    for (const contentType of [
      'multipart/form-data; boundary=abc',
      'application/x-www-form-urlencoded',
    ]) {
      next.mockClear();
      const res = mockRes();
      middleware(
        mockReq({ method: 'POST', headers: { 'Content-Type': contentType } }),
        res,
        next,
      );
      expect(next).toHaveBeenCalledTimes(1);
    }
  });

  it('rejects bodies larger than 10MB', () => {
    const res = mockRes();
    middleware(
      mockReq({
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': String(11 * 1024 * 1024),
        },
      }),
      res,
      next,
    );
    expect(res.statusCode).toBe(413);
    expect(res.body.code).toBe('PAYLOAD_TOO_LARGE');
    expect(next).not.toHaveBeenCalled();
  });

  it('rejects Authorization headers that are not Bearer', () => {
    const res = mockRes();
    middleware(
      mockReq({
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Basic abc123',
        },
      }),
      res,
      next,
    );
    expect(res.statusCode).toBe(400);
    expect(res.body.code).toBe('INVALID_AUTH_HEADER');
    expect(next).not.toHaveBeenCalled();
  });

  it('allows Bearer Authorization headers', () => {
    const res = mockRes();
    middleware(
      mockReq({
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer token-value',
        },
      }),
      res,
      next,
    );
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('exports a default middleware instance', () => {
    const res = mockRes();
    requestValidationMiddleware(mockReq({ method: 'GET' }), res, next);
    expect(next).toHaveBeenCalledTimes(1);
  });
});
