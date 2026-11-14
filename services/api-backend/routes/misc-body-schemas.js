/**
 * Request body schemas for DNS, email, token-expiry, cache purge, proxy
 * scaling, tunnel sharing and sub-agent routes. Same idea as
 * admin/body-schemas.js: check the *shape* (types, lengths, ranges) so a wrong
 * type is a 400 and never reaches `.trim()`, a comparison that quietly passes
 * for a string, or a purge-everything default. Business checks stay in the
 * handlers.
 */
import { z } from 'zod';
import { validateBody } from './admin/body-schemas.js';

export { validateBody };

const text = (max) => z.string().max(max);
const name = (max) => z.string().min(1).max(max);

// --- DNS (admin) -----------------------------------------------------------
// `ttl` is checked as a whole number here; its 60..86400 range stays in the
// handler. Before, the text "abc" passed that range check (NaN < 60 is false).
const dnsTtl = z.number().int();
const dnsPriority = z.number().int().min(0).max(65535);

export const dnsCreateBody = z.object({
  recordType: name(16),
  name: name(255),
  value: name(2048),
  ttl: dnsTtl.optional(),
  priority: dnsPriority.nullable().optional(),
});

export const dnsUpdateBody = z.object({
  value: name(2048).nullable().optional(),
  ttl: dnsTtl.nullable().optional(),
  priority: dnsPriority.nullable().optional(),
});

// The domain is used to build DNS records, so it must look like a host name.
const hostname = z
  .string()
  .max(253)
  .regex(/^(?=.{1,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/i);

export const dnsSetupGoogleBody = z.object({
  domain: hostname.optional(),
  recordTypes: z
    .array(z.enum(['mx', 'spf', 'dmarc']))
    .max(3)
    .optional(),
});

// --- Email (admin) ---------------------------------------------------------
export const emailOauthCallbackBody = z.object({
  code: name(2048),
  state: name(256),
});

export const emailTestBody = z.object({
  recipientEmail: z.string().max(254),
  subject: text(200).optional(),
});

export const emailTemplateBody = z.object({
  name: text(200),
  subject: text(500),
  html_body: text(200000),
  text_body: text(200000).nullable().optional(),
  description: text(1000).nullable().optional(),
  variables: z.array(name(100)).max(100).optional(),
});

// --- Others ---------------------------------------------------------------
export const tokenExpiryBody = z.object({
  token: text(8192).optional(),
});

// Leaving `urls` out purges the whole zone cache (existing behaviour). A value
// that is present must be a real list: before, "" or 0 or false also meant
// "purge everything". 30 is Cloudflare's limit per call.
export const cachePurgeBody = z.object({
  urls: z
    .array(
      z
        .string()
        .url()
        .max(2048)
        .refine((u) => /^https?:\/\//i.test(u), 'Must be an http(s) address'),
    )
    .min(1)
    .max(30)
    .nullable()
    .optional(),
});

export const proxyScalingExecuteBody = z.object({
  newReplicaCount: z.number().int().min(1).max(1000),
  reason: text(500).optional(),
  triggeredBy: text(64).optional(),
});

export const tunnelSharePermissionBody = z.object({
  permission: name(32),
});

export const subagentMetadataBody = z.object({
  label: text(200).nullable().optional(),
  task: text(4000).nullable().optional(),
});

// --- Tunnel usage events ---------------------------------------------------
// Before, only `eventType` was checked: `dataBytes: "abc"` or a 1 MB
// `errorMessage` went straight to the usage service.
export const usageEventBody = z.object({
  eventType: z.enum([
    'connection_start',
    'connection_end',
    'data_transfer',
    'error',
  ]),
  connectionId: text(128).optional(),
  dataBytes: z.number().int().min(0).optional(),
  durationSeconds: z.number().min(0).optional(),
  errorMessage: text(2000).optional(),
  ipAddress: text(64).optional(),
});
