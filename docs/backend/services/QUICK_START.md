# Payment Gateway Services - Quick Start Guide

## Setup

> **Verified against code:** there is no central services barrel module in this repo. `PaymentService`, `SubscriptionService`, and `RefundService` are default exports of `services/api-backend/services/payment-service.js:272`, `subscription-service.js:607`, and `refund-service.js:359`. The example env files are `.env.example` at the repository root and `config/docker-compose.env.example`; none exists under `services/api-backend`.

### 1. Install Dependencies

Dependencies are already installed. Verify with:

```bash
npm list stripe
```

### 2. Configure Environment Variables

The example file is at the repository root — there is no `.env.example` inside `services/api-backend`. From the repo root, copy it and add your Stripe keys:

```bash
cp .env.example .env
```

Edit `.env` and add your Stripe API keys from https://dashboard.stripe.com/apikeys

### 3. Validate Database Helpers

There is no `npm run db:migrate` in api-backend (`services/api-backend/package.json:7-25`); use the available helpers after
ensuring schema/SQL for payment tables is applied via your usual DB path:

```bash
cd services/api-backend
npm run db:validate
# npm run db:stats
# npm run db:test
```

## Basic Usage

### Initialize Services

```javascript
import { Pool } from 'pg';
import PaymentService from './services/payment-service.js';
import SubscriptionService from './services/subscription-service.js';
import RefundService from './services/refund-service.js';

// Create database connection
const db = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// Initialize services
const paymentService = new PaymentService(db);
const subscriptionService = new SubscriptionService(db);
const refundService = new RefundService(db);
```

### Process a Payment

```javascript
const result = await paymentService.processPayment({
  userId: 'user-uuid',
  amount: 29.99,
  currency: 'USD',
  paymentMethodId: 'pm_1234567890',
  metadata: {
    order_id: 'order-123',
  },
});

if (result.success) {
  console.log('Payment succeeded!');
  console.log('Transaction ID:', result.transaction.id);
} else {
  console.error('Payment failed:', result.error.message);
}
```

### Create a Subscription

```javascript
const result = await subscriptionService.createSubscription({
  userId: 'user-uuid',
  tier: 'premium',
  paymentMethodId: 'pm_1234567890',
  priceId: 'price_1234567890', // Get from Stripe Dashboard
  metadata: {
    source: 'admin_center',
  },
});

if (result.success) {
  console.log('Subscription created!');
  console.log('Subscription ID:', result.subscription.id);
}
```

### Process a Refund

```javascript
const result = await refundService.processRefund({
  transactionId: 'transaction-uuid',
  amount: 29.99, // or null for full refund
  reason: 'customer_request',
  reasonDetails: 'Customer was not satisfied',
  adminUserId: 'admin-uuid',
  adminRole: 'finance_admin',
  ipAddress: req.ip,
  userAgent: req.get('user-agent'),
});

if (result.success) {
  console.log('Refund processed!');
  console.log('Refund ID:', result.refund.id);
}
```

## Testing with Stripe Test Cards

Use these test cards in development:

```javascript
// Success
const testCard = {
  number: '4242424242424242',
  exp_month: 12,
  exp_year: 2025,
  cvc: '123',
};

// Declined
const declinedCard = {
  number: '4000000000000002',
  exp_month: 12,
  exp_year: 2025,
  cvc: '123',
};
```

## Error Handling

Always check the `success` field:

```javascript
const result = await paymentService.processPayment({...});

if (!result.success) {
  // Handle error
  const { code, message, statusCode } = result.error;

  switch (code) {
    case 'CARD_DECLINED':
      // Show user-friendly message
      break;
    case 'INVALID_REQUEST':
      // Log and show generic error
      break;
    default:
      // Show generic error
  }
}
```

## Common Error Codes

- `CARD_DECLINED` - Card was declined by issuer
- `INVALID_REQUEST` - Invalid parameters provided
- `PAYMENT_GATEWAY_ERROR` - Stripe API error
- `GATEWAY_CONNECTION_ERROR` - Network connectivity issue
- `RATE_LIMIT_EXCEEDED` - Too many requests
- `REFUND_ERROR` - Refund processing failed

## Webhook Handling

```javascript
import express from 'express';

const app = express();

app.post(
  '/api/webhooks/stripe',
  express.raw({ type: 'application/json' }),
  async (req, res) => {
    const sig = req.headers['stripe-signature'];

    try {
      // Verify webhook signature
      const event = stripe.webhooks.constructEvent(
        req.body,
        sig,
        process.env.STRIPE_WEBHOOK_SECRET
      );

      // Handle event
      await subscriptionService.handleWebhook(event);

      res.json({ received: true });
    } catch (err) {
      console.error('Webhook error:', err.message);
      res.status(400).send(`Webhook Error: ${err.message}`);
    }
  }
);
```

## Best Practices

1. **Always use try-catch blocks** when calling service methods
2. **Check the success field** before accessing result data
3. **Log all payment operations** for audit purposes
4. **Use test mode** for development and testing
5. **Verify webhook signatures** to prevent fraud
6. **Store minimal payment data** (only last 4 digits)
7. **Use environment variables** for all secrets
8. **Implement rate limiting** on payment endpoints
9. **Monitor payment metrics** in production
10. **Handle errors gracefully** with user-friendly messages

## Troubleshooting

### "Stripe API key not configured"

Make sure you've set the correct environment variable:

- Development: `STRIPE_SECRET_KEY_TEST`
- Production: `STRIPE_SECRET_KEY_PROD`

### "Transaction not found"

Ensure the transaction ID exists in the database and belongs to the correct user.

### "Can only refund succeeded transactions"

Check the transaction status. Only transactions with status `succeeded` can be refunded.

### Webhook not working

1. Verify webhook secret is correct
2. Check webhook signature verification
3. Ensure endpoint is publicly accessible
4. Check Stripe Dashboard for webhook delivery logs

## Next Steps

1. Implement API endpoints (Task 5)
2. Add authentication middleware
3. Implement rate limiting
4. Set up webhook endpoint
5. Configure monitoring and alerts

## Resources

- [Full Documentation](README.md)
- [Implementation Summary](../../archive/historical-reports/backend/services/IMPLEMENTATION_SUMMARY.md)
- [Stripe Documentation](https://stripe.com/docs)
- [Stripe Testing Guide](https://stripe.com/docs/testing)

## Support

For issues or questions:

1. Check the [README](README.md) for detailed documentation
2. Review Stripe documentation
3. Contact the development team
