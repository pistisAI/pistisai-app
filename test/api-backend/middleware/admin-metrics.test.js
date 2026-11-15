/**
 * Behavior tests for admin Prometheus metrics helpers and middleware.
 */

import { describe, it, expect, jest } from '@jest/globals';
import {
  initializeAdminMetrics,
  exportAdminMetricsAsText,
  getAdminMetricsRegistry,
  adminMetricsMiddleware,
  updatePaymentRates,
  updateErrorRate,
  trackDatabaseQuery,
  trackStripeApiCall,
  trackStripeApiError,
  trackAdminAction,
  trackAuthAttempt,
  updateDbPoolMetrics,
} from '../../../services/api-backend/middleware/admin-metrics.js';

describe('admin-metrics middleware helpers', () => {
  it('initializes metrics and exports prometheus text', async () => {
    initializeAdminMetrics();
    const text = await exportAdminMetricsAsText();
    expect(typeof text).toBe('string');
    expect(text).toMatch(/admin_api_requests_total|admin_payment/);
    expect(getAdminMetricsRegistry()).toBeTruthy();
  });

  it('adminMetricsMiddleware records request metrics on finish', async () => {
    const req = { method: 'GET', path: '/admin/users', route: { path: '/users' } };
    const listeners = {};
    const res = {
      statusCode: 200,
      on(event, fn) {
        listeners[event] = fn;
      },
    };
    const next = jest.fn();
    adminMetricsMiddleware(req, res, next);
    expect(next).toHaveBeenCalledTimes(1);
    listeners.finish();
    const text = await exportAdminMetricsAsText();
    expect(text).toMatch(/admin_api_requests_total/);
  });

  it('tracks error responses as validation/server errors', async () => {
    const req = { method: 'POST', path: '/admin/pay' };
    const listeners = {};
    const res = {
      statusCode: 500,
      on(event, fn) {
        listeners[event] = fn;
      },
    };
    adminMetricsMiddleware(req, res, jest.fn());
    listeners.finish();
    const text = await exportAdminMetricsAsText();
    expect(text).toMatch(/admin_api_errors_total/);
  });

  it('updates payment and error rate gauges', () => {
    updatePaymentRates(8, 2);
    updateErrorRate(1, 10);
    updatePaymentRates(0, 0); // no-op when total is 0
    updateErrorRate(1, 0); // no-op when total is 0
  });

  it('tracks database, stripe, admin, and auth events', async () => {
    trackDatabaseQuery('select', 'users', 12);
    trackStripeApiCall('payment', 'success', 250);
    trackStripeApiError('network');
    trackAdminAction('user_suspend', 'superadmin');
    trackAuthAttempt('failed', 'invalid_token');
    updateDbPoolMetrics(10, 4, 1);
    const text = await exportAdminMetricsAsText();
    expect(text).toMatch(/admin_database_queries_total/);
    expect(text).toMatch(/admin_stripe_api_calls_total/);
    expect(text).toMatch(/admin_actions_total/);
    expect(text).toMatch(/admin_auth_attempts_total/);
    expect(text).toMatch(/admin_db_pool_size/);
  });
});
