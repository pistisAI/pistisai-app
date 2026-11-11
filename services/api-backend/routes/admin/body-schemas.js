/**
 * Request body schemas for admin routes that read `req.body`.
 *
 * The handlers keep their own business checks (allowed tiers, allowed roles,
 * "reason is required"). These schemas only make sure the body has the right
 * *shape* first, so a wrong type is a 400 and never reaches code that calls
 * `.toLowerCase()` or `.trim()` on something that is not a string.
 */
import { z } from 'zod';
import { validateSchema } from '../../middleware/schema-validation.js';

const text = (max) => z.string().max(max);

export const changeTierBody = z.object({
  subscriptionTier: text(32).min(1),
  reason: text(1000).optional(),
});

export const suspendBody = z.object({
  reason: text(1000),
});

export const reactivateBody = z.object({
  note: text(1000).optional(),
});

export const addAdminBody = z.object({
  email: z.string().email().max(254),
  role: text(64).min(1),
});

const uuid = z.string().uuid();

// Bulk operations: the service checks the operation type and the data for each
// type; this makes sure the *ids* are what the later database calls expect.
export const bulkCreateBody = z.object({
  operationType: z.enum(['tier_update', 'suspend', 'reactivate', 'delete']),
  userIds: z.array(uuid).min(1).max(1000),
  operationData: z.record(z.string(), z.unknown()),
});

// Refunds: the handler keeps its own messages for a missing or unknown reason
// and transaction id, so those stay plain strings here. The amount is checked
// strictly: parseFloat('12abc') is 12, and a refund must not be 12 by accident.
export const refundBody = z.object({
  transactionId: z.string().max(64),
  reason: z.string().max(64),
  amount: z
    .union([
      z.number().positive().finite(),
      z.string().regex(/^\d+(\.\d{1,2})?$/),
    ])
    .nullable()
    .optional(),
  reasonDetails: text(2000).optional(),
});

// Subscriptions. `immediate` must be a real boolean: the text "false" is truthy,
// and would cancel the subscription on the spot.
export const changeSubscriptionBody = z.object({
  tier: z.string().max(32),
  priceId: z.string().max(128),
  prorationBehavior: z
    .enum(['create_prorations', 'none', 'always_invoice'])
    .optional(),
});

export const cancelSubscriptionBody = z.object({
  immediate: z.boolean().optional(),
  reason: z.string().min(1).max(1000),
});

/**
 * Express 5 leaves `req.body` undefined when no body was sent, and
 * validateSchema skips a missing body. Default it to `{}` so the schema
 * decides (a missing required field is then a 400, not a TypeError).
 */
export const validateBody = (schema) => [
  (req, _res, next) => {
    if (req.body === undefined || req.body === null) {
      req.body = {};
    }
    next();
  },
  validateSchema({ body: schema }),
];
