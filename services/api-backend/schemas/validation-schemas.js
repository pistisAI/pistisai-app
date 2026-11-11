/**
 * Centralized Zod Schemas for Input Validation
 * Addresses security audit findings from #619
 *
 * Serves as template for PR implementation.
 * Place in: services/api-backend/schemas/validation-schemas.js
 *
 * @fileoverview Validation schemas for critical endpoints
 * @version 1.0.0
 */

import { z } from 'zod';

// ============================================================================
// COMMON PATTERNS
// ============================================================================

export const UUIDSchema = z.string().uuid('Invalid UUID format');

export const EmailSchema = z
  .string()
  .email('Invalid email format')
  .max(255, 'Email too long');

export const SlugSchema = z
  .string()
  .regex(/^[a-z0-9_-]+$/, 'Invalid slug format (alphanumeric, hyphens, underscores only)')
  .max(100);

export const RoleSchema = z.enum(['admin', 'moderator', 'user'], {
  errorMap: () => ({ message: 'Role must be one of: admin, moderator, user' }),
});

// ============================================================================
// DNS MANAGEMENT (routes/admin/dns.js)
// ============================================================================

export const CreateDnsRecordSchema = z.object({
  recordType: z.enum(['A', 'MX', 'TXT', 'CNAME', 'SRV', 'NS', 'AAAA'], {
    errorMap: () => ({ message: 'Invalid DNS record type' }),
  }),
  name: z
    .string()
    .regex(/^[a-z0-9._-]+$/i, 'Invalid DNS name (alphanumeric, dots, hyphens only)')
    .max(255),
  value: z.string().max(255, 'DNS record value too long'),
  ttl: z
    .number()
    .int('TTL must be an integer')
    .min(300, 'TTL minimum is 300 seconds')
    .max(86400, 'TTL maximum is 86400 seconds'),
  priority: z
    .number()
    .int()
    .min(0)
    .max(100)
    .optional(),
});

export const UpdateDnsRecordSchema = z.object({
  value: z.string().max(255),
  ttl: z.number().int().min(300).max(86400),
  priority: z.number().int().min(0).max(100).optional(),
});

export const CheckDnsSchema = z.object({
  domain: z
    .string()
    .regex(/^[a-z0-9.-]+$/i, 'Invalid domain format')
    .max(255)
    .optional(),
  recordTypes: z
    .array(z.enum(['A', 'MX', 'TXT', 'CNAME', 'SPF', 'DMARC', 'NS']))
    .optional()
    .default(['MX', 'SPF', 'DMARC']),
});

// ============================================================================
// ADMIN MANAGEMENT (routes/admin/admins.js, routes/admin/users.js)
// ============================================================================

export const CreateAdminSchema = z.object({
  email: EmailSchema,
  role: RoleSchema,
  firstName: z.string().max(100).optional(),
  lastName: z.string().max(100).optional(),
});

export const UpdateAdminSchema = z.object({
  email: EmailSchema.optional(),
  role: RoleSchema.optional(),
  firstName: z.string().max(100).optional(),
  lastName: z.string().max(100).optional(),
}).refine(
  (obj) => Object.keys(obj).length > 0,
  { message: 'At least one field is required' },
);

export const UserNoteSchema = z.object({
  note: z.string().min(1).max(1000),
  targetUserId: UUIDSchema.optional(),
});

// ============================================================================
// BULK OPERATIONS (routes/admin/bulk-operations.js)
// ============================================================================

export const BulkOperationSchema = z.object({
  operationType: z.enum(['suspend', 'activate', 'delete', 'downgrade'], {
    errorMap: () => ({ message: 'Invalid operation type' }),
  }),
  userIds: z
    .array(UUIDSchema)
    .min(1, 'At least one user ID is required')
    .max(1000, 'Maximum 1000 users per operation'),
  operationData: z.record(z.string(), z.any()).optional(),
  reason: z.string().max(500).optional(),
});

// ============================================================================
// PROXY INFRASTRUCTURE (routes/proxy-scaling.js, routes/proxy.js)
// ============================================================================

export const ProxyScalingSchema = z.object({
  newReplicaCount: z
    .number()
    .int('Replica count must be an integer')
    .min(1, 'Minimum 1 replica')
    .max(10, 'Maximum 10 replicas'),
  reason: z.string().max(500),
  triggeredBy: UUIDSchema,
});

export const ProxyConfigSchema = z.object({
  testMode: z.boolean().optional().default(false),
  timeout: z.number().int().min(1000).max(120000).optional(),
});

// ============================================================================
// WEBHOOK CONFIGURATION (middleware/webhook-rate-limiter.js)
// ============================================================================

export const WebhookRateLimitSchema = z.object({
  webhook_id: UUIDSchema,
  user_id: UUIDSchema,
  rate_limit_config: z.object({
    requests_per_minute: z
      .number()
      .int('Requests per minute must be an integer')
      .min(1, 'Minimum 1 request per minute')
      .max(10000, 'Maximum 10000 requests per minute'),
    burst_size: z.number().int().min(1).max(100).optional(),
  }),
});

// ============================================================================
// CLOUD CONNECTOR (routes/cloud-connector.js)
// ============================================================================

export const CloudConnectorScopeSchema = z.object({
  scope: z.enum(['read', 'write', 'admin'], {
    errorMap: () => ({ message: 'Scope must be one of: read, write, admin' }),
  }),
  target_device_id: UUIDSchema,
  runtime_available: z.boolean().optional(),
  metadata: z.record(z.string(), z.any()).optional(),
});

// ============================================================================
// SUBSCRIPTIONS (routes/admin/subscriptions.js, routes/admin/users.js)
// ============================================================================

export const ChangeSubscriptionTierSchema = z.object({
  subscriptionTier: z.enum(['free', 'pro', 'enterprise'], {
    errorMap: () => ({ message: 'Invalid subscription tier' }),
  }),
  reason: z.string().max(500),
  effective_date: z.string().datetime().optional(),
  immediate: z.boolean().optional().default(false),
});

// ============================================================================
// AUTH (routes/auth.js)
// ============================================================================

export const AuthTokenSchema = z.object({
  token: z
    .string()
    .regex(
      /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/,
      'Invalid JWT token format',
    ),
  expiresIn: z.number().int().positive().optional(),
});

// ============================================================================
// BRIDGE POLLING (routes/bridge-polling-routes.js)
// ============================================================================

export const BridgeStateUpdateSchema = z.object({
  clientId: UUIDSchema,
  platform: z.string().max(50),
  version: z.string().regex(/^\d+\.\d+\.\d+$/, 'Invalid semantic version'),
  capabilities: z.array(z.string().max(50)).optional(),
});

export const BridgeProviderUpdateSchema = z.object({
  providers: z.array(z.string()).optional(),
  timestamp: z.string().datetime().optional(),
});

export const BridgeResponseSchema = z.object({
  requestId: z.string().uuid(),
  status: z.enum(['success', 'error', 'pending', 'timeout'], {
    errorMap: () => ({ message: 'Invalid status' }),
  }),
  headers: z
    .record(z.string(), z.union([z.string(), z.array(z.string())]))
    .optional(),
  body: z.any().optional(),
  error: z
    .object({
      code: z.string().max(100),
      message: z.string().max(500),
    })
    .optional(),
});

// ============================================================================
// METRICS & MONITORING (routes/proxy-metrics.js, routes/proxy-usage.js)
// ============================================================================

export const ProxyMetricsSchema = z.object({
  eventType: z.enum(['request', 'response', 'error', 'throttle'], {
    errorMap: () => ({ message: 'Invalid event type' }),
  }),
  metrics: z.object({
    latency_ms: z.number().min(0).optional(),
    bytes_in: z.number().int().min(0).optional(),
    bytes_out: z.number().int().min(0).optional(),
    status_code: z.number().int().min(100).max(599).optional(),
  }),
});

export const ProxyUsageSchema = z.object({
  eventType: z.enum(['request', 'response', 'error']).optional(),
  eventData: z.record(z.string(), z.any()).optional(),
  periodStart: z.string().datetime().optional(),
  periodEnd: z.string().datetime().optional(),
});

// ============================================================================
// PAYMENTS (routes/admin/payments.js)
// ============================================================================

export const RefundSchema = z.object({
  transactionId: z.string().max(255),
  amount: z.number().positive().optional(),
  reason: z.string().max(500),
  reasonDetails: z.string().max(2000).optional(),
});

// ============================================================================
// EMAIL CONFIGURATION (routes/admin/email.js)
// ============================================================================

export const EmailConfigSchema = z.object({
  provider: z.enum(['sendgrid', 'mailgun', 'ses'], {
    errorMap: () => ({ message: 'Invalid email provider' }),
  }),
  apiKey: z.string().max(500),
  senderEmail: EmailSchema,
  senderName: z.string().max(255).optional(),
});

export const SendTestEmailSchema = z.object({
  recipientEmail: EmailSchema,
  templateName: z.string().max(255).optional(),
});

// ============================================================================
// INFRASTRUCTURE TUNNEL (routes/infrastructure-tunnel.js)
// ============================================================================

export const TunnelConfigSchema = z.object({
  urls: z
    .array(z.string().url('Invalid URL format'))
    .min(1, 'At least one URL required'),
});

// ============================================================================
// AGENT EVENTS (routes/agent-events.js)
// ============================================================================

export const AgentEventSchema = z.object({
  agent_id: UUIDSchema.optional(),
  eventType: z.string().max(100).optional(),
  eventData: z.record(z.string(), z.any()).optional(),
});

// ============================================================================
// DEFAULT EXPORT
// ============================================================================

export default {
  // Common
  UUIDSchema,
  EmailSchema,
  SlugSchema,
  RoleSchema,
  // DNS
  CreateDnsRecordSchema,
  UpdateDnsRecordSchema,
  CheckDnsSchema,
  // Admin
  CreateAdminSchema,
  UpdateAdminSchema,
  UserNoteSchema,
  // Bulk
  BulkOperationSchema,
  // Infrastructure
  ProxyScalingSchema,
  ProxyConfigSchema,
  WebhookRateLimitSchema,
  CloudConnectorScopeSchema,
  // Subscriptions
  ChangeSubscriptionTierSchema,
  // Auth
  AuthTokenSchema,
  // Bridge
  BridgeStateUpdateSchema,
  BridgeProviderUpdateSchema,
  BridgeResponseSchema,
  // Metrics
  ProxyMetricsSchema,
  ProxyUsageSchema,
  // Payments
  RefundSchema,
  // Email
  EmailConfigSchema,
  SendTestEmailSchema,
  // Infrastructure
  TunnelConfigSchema,
  // Agent
  AgentEventSchema,
};
