import express from 'express';
import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import { z } from 'zod';
import path from 'path';
import { promises as fs } from 'fs';
import logger from '../logger.js';
import { validateSchema } from '../middleware/schema-validation.js';

/**
 * Client log intake for the web app (lib/services/log_buffer_service.dart).
 *
 * The endpoint is unauthenticated, so everything about it is bounded:
 * body size, batch size, field lengths, request rate per IP and the size of
 * the file on disk (rotated to `<file>.1`, one rotated file kept).
 */

export const CLIENT_LOG_LIMITS = Object.freeze({
  bodyLimit: 256 * 1024,
  maxEntries: 100,
  maxMessageLength: 2000,
  maxUrlLength: 512,
  maxUserAgentLength: 512,
  maxLevelLength: 16,
  maxSourceLength: 64,
  maxSessionIdLength: 128,
  maxFileBytes: 10 * 1024 * 1024,
});

const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const RATE_LIMIT_MAX = Number(process.env.CLIENT_LOG_RATE_LIMIT_MAX) || 30;

const router = express.Router();
let logDir = process.env.CLIENT_LOG_DIR || '/tmp/logs';
const logFileName = process.env.CLIENT_LOG_FILE || 'client-web.log';
let logFilePath = path.join(logDir, logFileName);

/** Test hook: point the route at another directory. */
export function setClientLogDirForTesting(dir) {
  logDir = dir;
  logFilePath = path.join(logDir, logFileName);
  return logFilePath;
}

const logEntrySchema = z.object({
  timestamp: z.string().datetime().optional(),
  level: z.string().max(64).optional(),
  // Objects are accepted for compatibility and stringified, then capped.
  message: z.unknown(),
  url: z.string().max(4096).nullable().optional(),
  userAgent: z.string().max(4096).nullable().optional(),
});

const clientLogsBodySchema = z.object({
  entries: z.array(logEntrySchema).min(1).max(CLIENT_LOG_LIMITS.maxEntries),
  source: z.string().max(256).optional(),
  sessionId: z.string().max(256).nullable().optional(),
});

function cap(value, max) {
  if (typeof value !== 'string') {
    return value;
  }
  return value.length > max ? value.slice(0, max) : value;
}

function messageToString(message) {
  if (typeof message === 'string') {
    return message;
  }
  if (message === undefined || message === null) {
    return '';
  }
  try {
    return JSON.stringify(message) ?? String(message);
  } catch {
    return String(message);
  }
}

/** Drop the query string and fragment: they can carry tokens or personal data. */
export function stripUrlQuery(url) {
  if (typeof url !== 'string' || url.length === 0) {
    return null;
  }
  const cut = url.search(/[?#]/);
  const base = cut === -1 ? url : url.slice(0, cut);
  return cap(base, CLIENT_LOG_LIMITS.maxUrlLength);
}

export function sanitizeClientLogEntry(
  entry,
  { source, sessionId, fallbackUserAgent },
) {
  return {
    timestamp: entry?.timestamp || new Date().toISOString(),
    level: cap(entry?.level || 'INFO', CLIENT_LOG_LIMITS.maxLevelLength),
    message: cap(
      messageToString(entry?.message),
      CLIENT_LOG_LIMITS.maxMessageLength,
    ),
    url: stripUrlQuery(entry?.url),
    userAgent: cap(
      entry?.userAgent || fallbackUserAgent || null,
      CLIENT_LOG_LIMITS.maxUserAgentLength,
    ),
    source: cap(source, CLIENT_LOG_LIMITS.maxSourceLength),
    sessionId: cap(sessionId, CLIENT_LOG_LIMITS.maxSessionIdLength),
  };
}

async function ensureLogDirectory() {
  try {
    await fs.mkdir(logDir, { recursive: true });
    await fs.access(logDir, fs.constants.W_OK);
  } catch (error) {
    if (logDir !== '/tmp/logs') {
      logger.warn(
        `[ClientLogs] Failed to access configured log directory ${logDir}, falling back to /tmp/logs`,
        { error: error.message },
      );
      logDir = '/tmp/logs';
      logFilePath = path.join(logDir, logFileName);
      await fs.mkdir(logDir, { recursive: true });
    } else {
      throw error;
    }
  }
}

/**
 * Rotate the log file to `<file>.1` (replacing any older rotated file) when
 * appending `incomingBytes` would push it over the size cap.
 */
export async function rotateIfNeeded(
  filePath,
  incomingBytes,
  maxBytes = CLIENT_LOG_LIMITS.maxFileBytes,
) {
  let size;
  try {
    size = (await fs.stat(filePath)).size;
  } catch (error) {
    if (error.code === 'ENOENT') {
      return false;
    }
    throw error;
  }
  if (size + incomingBytes <= maxBytes) {
    return false;
  }
  await fs.rename(filePath, `${filePath}.1`);
  return true;
}

const clientLogsRateLimiter = rateLimit({
  windowMs: RATE_LIMIT_WINDOW_MS,
  max: RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => `client-logs:${ipKeyGenerator(req.ip || '')}`,
  handler: (req, res) => {
    logger.warn('[ClientLogs] Rate limit exceeded');
    res.status(429).json({
      error: 'Too many client log requests, please try again later.',
      code: 'CLIENT_LOGS_RATE_LIMITED',
    });
  },
});

// The global parser skips this route (middleware/pipeline.js), so this
// route-scoped parser is the one that enforces the body limit.
const parseBody = express.json({ limit: CLIENT_LOG_LIMITS.bodyLimit });

// Belt and braces for any mount path the global parser did not skip.
function rejectOversized(req, res, next) {
  const length = Number(req.get('content-length'));
  if (Number.isFinite(length) && length > CLIENT_LOG_LIMITS.bodyLimit) {
    return res
      .status(413)
      .json({ error: 'Payload too large', code: 'PAYLOAD_TOO_LARGE' });
  }
  return next();
}

function handleBodyError(error, req, res, next) {
  if (error?.type === 'entity.too.large') {
    return res
      .status(413)
      .json({ error: 'Payload too large', code: 'PAYLOAD_TOO_LARGE' });
  }
  if (error?.type === 'entity.parse.failed') {
    return res
      .status(400)
      .json({ error: 'Invalid JSON', code: 'INVALID_JSON' });
  }
  return next(error);
}

function requireBody(req, res, next) {
  if (!req.body || typeof req.body !== 'object') {
    return res
      .status(400)
      .json({ error: 'Validation failed', code: 'INVALID_FIELDS' });
  }
  return next();
}

router.post(
  '/',
  clientLogsRateLimiter,
  rejectOversized,
  parseBody,
  handleBodyError,
  requireBody,
  validateSchema({ body: clientLogsBodySchema }),
  async (req, res) => {
    try {
      const { entries, source = 'web-client', sessionId = null } = req.body;
      const fallbackUserAgent = req.get('user-agent') || null;

      const sanitized = entries.map((entry) =>
        sanitizeClientLogEntry(entry, { source, sessionId, fallbackUserAgent }),
      );

      await ensureLogDirectory();
      const payload =
        sanitized.map((entry) => JSON.stringify(entry)).join('\n') + '\n';
      await rotateIfNeeded(logFilePath, Buffer.byteLength(payload, 'utf8'));
      await fs.appendFile(logFilePath, payload, 'utf8');

      res.json({ success: true, count: sanitized.length });
    } catch (error) {
      logger.error('[ClientLogs] Failed to persist log entries', {
        error: error?.message,
      });
      res.status(500).json({ error: 'Failed to persist logs' });
    }
  },
);

export default router;
