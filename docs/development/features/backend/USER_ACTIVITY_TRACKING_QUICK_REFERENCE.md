# User Activity Tracking - Quick Reference

## Files Created (verified against code)

> **Verified against code (2026-11-24):** the service and route are at `services/api-backend/services/user-activity-service.js` and `services/api-backend/routes/user-activity.js` (not root-level `services/`/`routes/`). The router registers `/activity` (:53), `/metrics` (:153), `/activity/summary` (:236) but is mounted by `services/api-backend/server.js:359` at `/user-activity` (and `/api/user-activity`) — **not** `/api/users` — so the live endpoints are `/api/user-activity/activity`, `/api/user-activity/metrics`, `/api/user-activity/activity/summary` (corrected below). `services/api-backend/middleware/activity-logging.js` **does not exist**. The migration is `services/api-backend/database/migrations/003-user-activity-tracking.sql`, applied at startup (`server.js:563-578`); **there is no `npm run migrate` script** in `services/api-backend/package.json`.

1. **Database Migration**
   - `services/api-backend/database/migrations/003-user-activity-tracking.sql` - Creates tables and indexes

2. **Service**
   - `services/api-backend/services/user-activity-service.js` - Core activity tracking logic

3. **Middleware**
   - `services/api-backend/middleware/activity-logging.js` — **MISSING** (planned)

4. **Routes**
   - `services/api-backend/routes/user-activity.js` - User-facing activity endpoints

5. **Tests**
   - `test/api-backend/user-activity-unit.test.js` - Unit tests (passing)
   - `test/api-backend/user-activity.test.js` - Integration tests (requires DB)

6. **Documentation**
   - `docs/archive/historical-reports/development/features/backend/USER_ACTIVITY_TRACKING_IMPLEMENTATION.md` - Full implementation guide (archived; the old root-level path no longer exists)
   - `USER_ACTIVITY_TRACKING_QUICK_REFERENCE.md` - This file

## Key Functions

### Service Functions

```javascript
// Log activity
logUserActivity({
  userId, action, resourceType, resourceId,
  ipAddress, userAgent, details, severity
})

// Update metrics
updateUserUsageMetrics(userId)

// Get activity logs
getUserActivityLogs(userId, { limit, offset, action, resourceType, startDate, endDate })

// Get usage metrics
getUserUsageMetrics(userId)

// Get activity summary
getUserActivitySummary(userId, { period, startDate, endDate })

// Admin functions
getAllUserActivityLogs(options)
getAllUserActivityLogsCount(options)
```

### API Endpoints

```
GET  /api/user-activity/activity          - Get user's activity logs
GET  /api/user-activity/metrics           - Get user's usage metrics
GET  /api/user-activity/activity/summary  - Get user's activity summary
```

## Activity Actions

```javascript
// Profile
PROFILE_VIEW, PROFILE_UPDATE, PROFILE_DELETE, AVATAR_UPLOAD, PREFERENCES_UPDATE

// Tunnel
TUNNEL_CREATE, TUNNEL_START, TUNNEL_STOP, TUNNEL_DELETE, TUNNEL_UPDATE, TUNNEL_STATUS_CHECK

// API Keys
API_KEY_CREATE, API_KEY_DELETE, API_KEY_ROTATE

// Sessions
SESSION_CREATE, SESSION_DESTROY, SESSION_REFRESH

// Admin
ADMIN_USER_VIEW, ADMIN_USER_UPDATE, ADMIN_USER_DELETE, ADMIN_TIER_CHANGE
```

## Integration Steps

1. **Apply Database Migration**

   The migration `services/api-backend/database/migrations/003-user-activity-tracking.sql` is applied automatically at backend startup (`services/api-backend/server.js:563-578` → `dbMigrator.migrate()`; runner `services/api-backend/database/migrate-pg.js`). **There is no `npm run migrate` script** in `services/api-backend/package.json` — use the startup path or `db:validate` / `db:stats` / `db:test`.

2. **Add Middleware to Server** (planned — the middleware file does not exist)

   ```javascript
   // PLANNED: services/api-backend/middleware/activity-logging.js is MISSING.
   import { activityLoggingMiddleware } from '../../services/api-backend/middleware/activity-logging.js';
   app.use(authenticateJWT);
   app.use(activityLoggingMiddleware);
   ```

3. **Add Routes to Server**

   ```javascript
   import userActivityRoutes from '../../services/api-backend/routes/user-activity.js';
   // Actual mount is /user-activity (server.js:359), which also registers /api/user-activity;
   // the /api/users mount below is planned, not current.
   app.use('/api/users', userActivityRoutes);
   ```

4. **Use in Route Handlers** (Optional)

   ```javascript
   await res.logActivity({
     action: ACTIVITY_ACTIONS.PROFILE_UPDATE,
     details: { fields: ['email', 'name'] }
   });
   ```

## Database Tables

### user_activity_logs

- Stores individual activity events
- Indexed by: user_id, action, created_at

### user_usage_metrics

- Aggregates usage per user
- Unique constraint on user_id

### user_activity_summary

- Stores period-based summaries
- Unique constraint on (user_id, period, period_start)

## Testing

```bash
# Run unit tests (no DB required)
npm test -- test/api-backend/user-activity-unit.test.js

# Run integration tests (requires DB)
npm test -- test/api-backend/user-activity.test.js
```

## Requirements Validation

✅ **Requirement 3.4**: Track user activity and usage metrics

- Implemented via `logUserActivity()` and `updateUserUsageMetrics()`
- Automatic middleware logging for all requests
- Usage metrics aggregation

✅ **Requirement 3.10**: Provide user activity audit logs

- Implemented via `getUserActivityLogs()` and `getAllUserActivityLogs()`
- API endpoints for retrieving activity logs
- Admin access to system-wide logs

## Performance Notes

- Activity logging is asynchronous (non-blocking)
- Database indexes optimize query performance
- Metrics updates are incremental
- Pagination support for large datasets
- Graceful error handling (logging failures don't break requests)

## Security Notes

- All user endpoints require JWT authentication
- Admin endpoints require admin role
- IP addresses and user agents captured for audit
- Users can only view their own activity
- Admins can view all activity
