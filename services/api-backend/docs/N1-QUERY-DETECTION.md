# N+1 Query Detection & Remediation Guide

## Overview

N+1 query problems occur when a single operation (typically a loop) triggers N additional queries instead of batching them. This causes significant performance degradation with scale.

**Example of N+1 (BAD):**
```javascript
// 1 query to fetch users
const usersResult = await pool.query('SELECT * FROM users');

// N queries (one per user) - THIS IS THE PROBLEM
for (const user of usersResult.rows) {
  const orders = await pool.query('SELECT * FROM orders WHERE user_id = $1', [user.id]);
  user.orders = orders.rows;
}
```

**Example of batched solution (GOOD):**
```javascript
const usersResult = await pool.query('SELECT * FROM users');
const userIds = usersResult.rows.map(u => u.id);

// Single query with IN clause
const allOrders = await pool.query(
  'SELECT * FROM orders WHERE user_id = ANY($1)',
  [userIds]
);

// Map results to users
const ordersByUserId = new Map();
for (const order of allOrders.rows) {
  if (!ordersByUserId.has(order.user_id)) {
    ordersByUserId.set(order.user_id, []);
  }
  ordersByUserId.get(order.user_id).push(order);
}

for (const user of usersResult.rows) {
  user.orders = ordersByUserId.get(user.id) || [];
}
```

## Current State

**Detection Results (2026-11-10):**
- Total files scanned: 116
- Total SQL queries: 473
- Potential N+1 issues: 10 (all HIGH severity)
- Affected files: 5

### Identified Issues

| File | Pattern | Count | Status | Issue |
|------|---------|-------|--------|-------|
| `routes/admin/payments.js` | Loop Query | 2 | Tracked | #621 |
| `routes/conversations.js` | Loop Query | 2 | Tracked | #621 |
| `services/bulk-operations-service.js` | Loop Query | 2 | Tracked | #621 |
| `services/proxy-webhook-service.js` | Loop Query | 2 | Tracked | #621 |
| `services/tunnel-webhook-service.js` | Loop Query | 2 | Tracked | #621 |

## Detector Setup

### Running Locally

```bash
cd services/api-backend

# Scan for N+1 issues
npm run scan:n1

# Output: n1-detection-report.json with detailed findings
```

### Running in CI

The detector is integrated into the Cloud Build pipeline as a gating step:

1. **Detection Phase** (`ci-n1-gate.sh`): Scans codebase
2. **Test Phase** (`npm run test:n1`): Validates against baseline
3. **Failure Criteria**: Any NEW N+1 issues → build fails

## Remediation Patterns

### Pattern 1: Loop with Individual Queries

**Before (N+1):**
```javascript
for (const item of items) {
  const result = await pool.query('SELECT * FROM related WHERE id = $1', [item.id]);
  item.related = result.rows[0];
}
```

**After (Batched):**
```javascript
const ids = items.map(i => i.id);
const relatedResult = await pool.query(
  'SELECT * FROM related WHERE id = ANY($1)',
  [ids]
);
const relatedMap = new Map(relatedResult.rows.map(r => [r.id, r]));
for (const item of items) {
  item.related = relatedMap.get(item.id);
}
```

### Pattern 2: Array.map with Async Query

**Before (N+1):**
```javascript
const details = items.map(async (item) => {
  const result = await pool.query('SELECT COUNT(*) FROM orders WHERE user_id = $1', [item.id]);
  return { ...item, orderCount: result.rows[0].count };
});
```

**After (Batched):**
```javascript
const ids = items.map(i => i.id);
const countsResult = await pool.query(`
  SELECT user_id, COUNT(*) as order_count FROM orders 
  WHERE user_id = ANY($1) 
  GROUP BY user_id
`, [ids]);
const countMap = new Map(countsResult.rows.map(r => [r.user_id, r.order_count]));
const details = items.map(item => ({
  ...item,
  orderCount: countMap.get(item.id) || 0
}));
```

### Pattern 3: Using Promise.all()

**Before (Sequential):**
```javascript
const user = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
const orders = await pool.query('SELECT * FROM orders WHERE user_id = $1', [userId]);
const payments = await pool.query('SELECT * FROM payments WHERE user_id = $1', [userId]);
```

**After (Concurrent):**
```javascript
const [userRes, ordersRes, paymentsRes] = await Promise.all([
  pool.query('SELECT * FROM users WHERE id = $1', [userId]),
  pool.query('SELECT * FROM orders WHERE user_id = $1', [userId]),
  pool.query('SELECT * FROM payments WHERE user_id = $1', [userId]),
]);
```

## Code Review Checklist

When reviewing PRs, check for:

- [ ] Loops containing `.query()` or `.query()` calls
- [ ] `.map()` without `Promise.all()`
- [ ] Sequential `await` statements for related queries
- [ ] Use of IN clauses or JOINs where appropriate

## Testing

### Local Test Run

```bash
npm run test:n1
```

Expected output:
```
PASS n1-query-detection.test.js
  N+1 Query Detection (CI Gate)
    ✓ should not exceed known N+1 issue threshold
    ✓ should identify existing N+1 issues
    ✓ statistics should show query coverage
    ✓ should document remediation steps
```

### Baseline Updates

When fixing N+1 issues:
1. Fix the code
2. Re-run detector: `npm run scan:n1`
3. Update `KNOWN_N1_ISSUES` in `test/api-backend/n1-query-detection.test.js`
4. Commit both files

## Performance Impact

**Estimated Improvements (from typical fixes):**
- Loop reduction: **50-90%** query count reduction
- Response time: **2-10x** faster for list endpoints
- Database load: **50%+ reduction** during high traffic

**Example:** The `admin/payments` loop issue processes ~100 payment methods:
- Current: 101 queries (1 + 100 forEach)
- Fixed: 2 queries (1 + 1 batched)
- Time improvement: ~5 seconds → ~500ms

## References

- PostgreSQL `ANY()` operator: https://www.postgresql.org/docs/current/functions-comparison.html
- PostgreSQL `IN` clause: https://www.postgresql.org/docs/current/sql-syntax.html
- Node.js `Promise.all()`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/all
- Database query patterns: https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html
