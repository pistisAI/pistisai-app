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
