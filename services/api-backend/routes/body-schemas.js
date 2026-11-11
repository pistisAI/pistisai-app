/**
 * Request body schemas for the bridge, proxy metrics, proxy usage and proxy
 * provisioning routes (the admin routes have theirs in admin/body-schemas.js).
 *
 * They check the *shape* of the body: field types, lengths and ranges, so that
 * a wrong type is a 400 instead of reaching code that stores it or calls
 * string methods on it. Business checks stay in the handlers.
 */
import { z } from 'zod';
import { validateBody } from './admin/body-schemas.js';

export { validateBody };

const text = (max) => z.string().max(max);
const name = (max) => z.string().min(1).max(max);
const anyObject = z.record(z.string(), z.unknown());

// POST /bridge/register
export const bridgeRegisterBody = z.object({
  clientId: name(128),
  platform: name(64),
  version: name(64),
  capabilities: z.array(name(64)).max(50).optional(),
});

// POST /bridge/:id/provider-status
export const bridgeProviderStatusBody = z.object({
  providers: z.array(anyObject).max(100).optional(),
  timestamp: text(64).optional(),
});

// POST /bridge/:id/response. Header values may be a list (set-cookie).
export const bridgeResponseBody = z.object({
  requestId: name(128),
  status: z.number().int().min(100).max(599).optional(),
  headers: z
    .record(z.string(), z.union([z.string(), z.array(z.string())]))
    .optional(),
  body: z.unknown().optional(),
  error: text(4000).optional(),
});

// POST /metrics/:proxyId/record
export const proxyMetricsRecordBody = z.object({
  eventType: name(64),
  metrics: anyObject.optional(),
});

// POST /usage/:proxyId/record
export const proxyUsageRecordBody = z.object({
  eventType: name(64),
  eventData: anyObject.optional(),
});

// POST /usage/aggregate: ISO text or epoch milliseconds that make a real date.
const dateValue = z
  .union([z.string().min(1).max(64), z.number()])
  .refine((v) => !Number.isNaN(new Date(v).getTime()), 'Not a valid date');
export const proxyUsageAggregateBody = z.object({
  periodStart: dateValue,
  periodEnd: dateValue,
});

// POST proxy provision. `testMode` must be a real boolean: the text "false"
// is truthy and would switch on the simulated (no container) path.
export const proxyProvisionBody = z.object({
  testMode: z.boolean().optional(),
});
