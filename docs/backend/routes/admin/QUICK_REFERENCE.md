# Admin API Quick Reference

Quick reference guide for Pistisai Admin Center API endpoints.

## Base URL

```
Production: https://api.example.com/api/admin
Development: http://localhost:8080/api/admin
```

> **Verified against code:** the backend default port is `8080` (`services/api-backend/server.js:183`), so the local base URL uses 8080, not 3001. `registerRoutes` adds the `/api` prefix and mounts the admin routes (`services/api-backend/server.js:265-266`, `:305`).

## Authentication

All endpoints require JWT Bearer token:

```bash
Authorization: Bearer <jwt_token>
```

## Admin Roles & Permissions

### Roles

- **Super Admin**: All permissions (\*)
- **Support Admin**: view_users, edit_users, suspend_users, view_sessions, terminate_sessions, view_payments, view_audit_logs
- **Finance Admin**: view_users, view_payments, process_refunds, view_subscriptions, edit_subscriptions, view_reports, export_reports, view_audit_logs

### Permission Mapping

| Permission         | Super Admin | Support Admin | Finance Admin |
| ------------------ | ----------- | ------------- | ------------- |
| view_users         | ✅          | ✅            | ✅            |
| edit_users         | ✅          | ✅            | ❌            |
| suspend_users      | ✅          | ✅            | ❌            |
| view_sessions      | ✅          | ✅            | ❌            |
| terminate_sessions | ✅          | ✅            | ❌            |
| view_payments      | ✅          | ✅            | ✅            |
| process_refunds    | ✅          | ❌            | ✅            |
| view_subscriptions | ✅          | ❌            | ✅            |
| edit_subscriptions | ✅          | ❌            | ✅            |
| view_reports       | ✅          | ❌            | ✅            |
| export_reports     | ✅          | ❌            | ✅            |
| view_audit_logs    | ✅          | ✅            | ✅            |
| export_audit_logs  | ✅          | ❌            | ❌            |

---

## User Management

### List Users

```bash
GET /api/admin/users?page=1&limit=50&search=john&tier=premium&status=active
```

**Permission:** `view_users`

### Get User Details

```bash
GET /api/admin/users/:userId
```

**Permission:** `view_users`

### Update Subscription

```bash
PATCH /api/admin/users/:userId
Content-Type: application/json

{
  "subscriptionTier": "premium",
  "reason": "Customer request"
}
```

**Permission:** `edit_users`

### Suspend User

```bash
POST /api/admin/users/:userId/suspend
Content-Type: application/json

{
  "reason": "Terms of service violation"
}
```

**Permission:** `suspend_users`

### Reactivate User

```bash
POST /api/admin/users/:userId/reactivate
Content-Type: application/json

{
  "note": "Issue resolved"
}
```

**Permission:** `suspend_users`

---

## Subscription Management

### List Subscriptions

```bash
GET /api/admin/subscriptions?tier=premium&includeUpcoming=true
```

### Get Subscription Details

```bash
GET /api/admin/subscriptions/{id}
```

### Update Subscription Tier

```bash
PATCH /api/admin/subscriptions/{id}
Body: {"tier": "enterprise", "priceId": "price_xxx"}
```

### Cancel Subscription

```bash
POST /api/admin/subscriptions/{id}/cancel
Body: {"immediate": false, "reason": "Customer request"}
```

## Payment Management

### List Transactions

```bash
GET /api/admin/payments/transactions?page=1&limit=100&status=succeeded&sortBy=amount&sortOrder=desc
```

**Permission:** `view_payments`

**Filters:**

- `userId` - Filter by user ID (UUID)
- `status` - pending, succeeded, failed, refunded, partially_refunded, disputed
- `startDate` - ISO 8601 date
- `endDate` - ISO 8601 date
- `minAmount` - Decimal
- `maxAmount` - Decimal
- `sortBy` - created_at, amount, status
- `sortOrder` - asc, desc

### Get Transaction Details

```bash
GET /api/admin/payments/transactions/:transactionId
```

**Permission:** `view_payments`

### Process Refund

```bash
POST /api/admin/payments/refunds
Content-Type: application/json

{
  "transactionId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 29.99,
  "reason": "customer_request",
  "reasonDetails": "Customer requested refund"
}
```

**Permission:** `process_refunds`

**Refund Reasons:**

- `customer_request` - Customer requested refund
- `billing_error` - Billing error occurred
- `service_issue` - Service quality issue
- `duplicate` - Duplicate charge
- `fraudulent` - Fraudulent transaction
- `other` - Other reason

### Get Payment Methods

```bash
GET /api/admin/payments/methods/:userId
```

**Permission:** `view_payments`

---

## Common Response Format

### Success Response

```json
{
  "success": true,
  "data": { ... },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

### Error Response

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": "Additional details"
}
```

---

## Common Error Codes

| Code                       | HTTP Status | Description                                       |
| -------------------------- | ----------- | ------------------------------------------------- |
| NO_TOKEN                   | 401         | No JWT token provided                             |
| INVALID_TOKEN              | 401         | Invalid or expired JWT token                      |
| USER_NOT_FOUND             | 403         | User not found in database                        |
| ADMIN_ACCESS_REQUIRED      | 403         | User does not have admin role                     |
| INSUFFICIENT_PERMISSIONS   | 403         | User lacks required permissions                   |
| INVALID_USER_ID            | 400         | Invalid user ID format                            |
| INVALID_TIER               | 400         | Invalid subscription tier                         |
| TIER_UNCHANGED             | 400         | User already has this tier                        |
| REASON_REQUIRED            | 400         | Reason field is required                          |
| ALREADY_SUSPENDED          | 400         | User is already suspended                         |
| NOT_SUSPENDED              | 400         | User is not suspended                             |
| INVALID_STATUS             | 400         | Invalid transaction status                        |
| INVALID_TRANSACTION_ID     | 400         | Invalid transaction ID format                     |
| TRANSACTION_NOT_FOUND      | 404         | Transaction not found                             |
| INVALID_REASON             | 400         | Invalid refund reason                             |
| INVALID_AMOUNT             | 400         | Invalid refund amount                             |
| INVALID_TRANSACTION_STATUS | 400         | Cannot refund transaction with current status     |
| AMOUNT_EXCEEDS_REMAINING   | 400         | Refund amount exceeds remaining refundable amount |

---

## Rate Limiting

- **100 requests per minute** per admin user
- **Burst allowance**: 20 requests
- **Response headers** include rate limit information

---

## Testing with cURL

### Get JWT Token (Auth0)

```bash
# Login via Auth0 and extract token from callback
# Token format: eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Set Token Variable

```bash
export JWT_TOKEN="your_jwt_token_here"
```

### Test User List

```bash
curl -X GET "http://localhost:8080/api/admin/users?page=1&limit=10" \
  -H "Authorization: Bearer $JWT_TOKEN"
```

### Test Transaction List

```bash
curl -X GET "http://localhost:8080/api/admin/payments/transactions?page=1&limit=10" \
  -H "Authorization: Bearer $JWT_TOKEN"
```

### Test Refund Processing

```bash
curl -X POST "http://localhost:8080/api/admin/payments/refunds" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "transactionId": "550e8400-e29b-41d4-a716-446655440000",
    "amount": 29.99,
    "reason": "customer_request",
    "reasonDetails": "Test refund"
  }'
```

---

## Database Setup

> **Verified against code:** `services/api-backend/database/migrations/run-migration.js` does not exist in this repo. Migrations are applied at backend startup by `DatabaseMigratorPG` (`services/api-backend/database/migrate-pg.js:14`, instantiated at `services/api-backend/server.js:563` with `migrate()` called at `:578`) from the SQL files in `services/api-backend/database/migrations/`.

### Apply Migration

Migrations (for example `services/api-backend/database/migrations/001_admin_center_schema.sql`) run automatically when the backend starts; there is no `run-migration.js up` CLI.

### Apply Seed Data (Development)

```bash
node services/api-backend/database/seeds/run-seed.js apply 001
```

This matches the usage documented at `services/api-backend/database/seeds/run-seed.js:6-8`.

### Check Migration Status

Applied migrations are recorded in the `schema_migrations` table (`services/api-backend/database/migrate-pg.js:59-80`, `:397-402`). There is no `run-migration.js status` command; `services/api-backend/package.json:16-17` defines `db:validate` and `db:stats` helpers.

---

## Environment Variables

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=Pistisai
DB_USER=postgres
DB_PASSWORD=yourpassword
DB_SSL=false
DB_POOL_MAX=50
DB_POOL_IDLE=600000
DB_POOL_CONNECT_TIMEOUT=30000

# Stripe
STRIPE_SECRET_KEY_TEST=sk_test_...
STRIPE_PUBLISHABLE_KEY_TEST=pk_test_...
STRIPE_SECRET_KEY_PROD=sk_live_...
STRIPE_PUBLISHABLE_KEY_PROD=pk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Environment
NODE_ENV=development
```

---

## Useful Queries

### Check Admin Roles

```sql
SELECT u.email, ar.role, ar.is_active
FROM admin_roles ar
JOIN users u ON ar.user_id = u.id
WHERE ar.is_active = true;
```

### Check Recent Transactions

```sql
SELECT
  pt.id,
  u.email,
  pt.amount,
  pt.status,
  pt.created_at
FROM payment_transactions pt
JOIN users u ON pt.user_id = u.id
ORDER BY pt.created_at DESC
LIMIT 10;
```

### Check Audit Logs

```sql
SELECT
  aal.action,
  admin_u.email as admin_email,
  affected_u.email as affected_email,
  aal.created_at
FROM admin_audit_logs aal
JOIN users admin_u ON aal.admin_user_id = admin_u.id
LEFT JOIN users affected_u ON aal.affected_user_id = affected_u.id
ORDER BY aal.created_at DESC
LIMIT 10;
```

---

## Documentation Links

> **Verified against code:** the paths below are files that actually exist in this repo. The former `services/api-backend/.../*.md` links and `.kiro/specs/admin-center/*` links do not exist here.

- **Full API Reference**: `docs/api/ADMIN_API.md`
- **Payment API Reference**: `docs/backend/routes/admin/PAYMENTS_API.md`
- **Implementation Summary**: `docs/archive/historical-reports/backend/routes/admin/IMPLEMENTATION_SUMMARY.md`
- **Route Registration**: `services/api-backend/routes/admin.js` (no `README.md` exists under `services/api-backend/routes/admin/`)
- **Database Quickstart**: `docs/backend/database/QUICKSTART.md`
- **Admin Center design/requirements/tasks specs**: not present in this repo (`.kiro/` does not exist); historical/aspirational references only.

---

## Support

For questions or issues:

- GitHub Issues: https://github.com/pistisAI/pistisai-app/issues
- Email: ops@example.com
