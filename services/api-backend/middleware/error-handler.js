/**
 * Centralized Express error handling for api-backend.
 *
 * Provides:
 * - asyncHandler: wrap async route handlers so rejections reach this middleware
 * - errorHandlerMiddleware: consistent JSON error body
 *   { error, statusCode, timestamp } (plus message/code when useful)
 *
 * Mount after all routes. Prefer leaving existing per-route catch blocks that
 * already return client-facing shapes; use this for unhandled/propagated errors.
 */

import logger from '../logger.js';

/**
 * Wrap an async Express handler so rejected promises call next(err).
 * @param {(req: import('express').Request, res: import('express').Response, next: import('express').NextFunction) => Promise<unknown>} fn
 * @returns {import('express').RequestHandler}
 */
export function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

/**
 * Final error middleware. Must be registered after all routes.
 * @type {import('express').ErrorRequestHandler}
 */
export function errorHandlerMiddleware(error, req, res, _next) {
  const statusCode =
    typeof error?.statusCode === 'number'
      ? error.statusCode
      : typeof error?.status === 'number'
        ? error.status
        : 500;

  const safeStatus =
    statusCode >= 400 && statusCode < 600 ? statusCode : 500;

  logger.error('Unhandled error:', {
    error: error?.message,
    statusCode: safeStatus,
    path: req?.path,
    method: req?.method,
    stack: error?.stack,
  });

  if (res.headersSent) {
    return;
  }

  const body = {
    error:
      safeStatus >= 500
        ? 'Internal server error'
        : error?.message || 'Request failed',
    statusCode: safeStatus,
    timestamp: new Date().toISOString(),
  };

  // Keep message for clients that already read it (compat with prior shape).
  if (safeStatus >= 500) {
    body.message =
      process.env.NODE_ENV === 'development'
        ? error?.message || 'Something went wrong'
        : 'Something went wrong';
  } else if (error?.code) {
    body.code = error.code;
  }

  res.status(safeStatus).json(body);
}

export default {
  asyncHandler,
  errorHandlerMiddleware,
};
