/**
 * Logging & Metrics Middleware Module
 *
 * Unified request logging, metrics collection, and audit logging
 */

// Request Logging
export {
  createRequestLoggingMiddleware,
  requestLoggingMiddleware,
} from './request-logging.js';

// Metrics Collection
export {
  createMetricsCollectionMiddleware,
  metricsCollectionMiddleware,
} from './metrics-collection.js';

// Admin Metrics
export {
  adminMetricsRegistry,
  adminApiRequestsTotal,
  adminApiResponseTimeMs,
  adminPaymentAttemptsTotal,
  adminPaymentSuccessRate,
  adminPaymentFailureRate,
  adminRefundAttemptsTotal,
  adminRefundProcessingTimeMs,
  adminSubscriptionOperationsTotal,
  adminDatabaseQueriesTotal,
  adminDatabaseQueryTimeMs,
  adminStripeApiCallsTotal,
  adminStripeApiResponseTimeMs,
  adminStripeApiErrorsTotal,
  adminActionsTotal,
  adminActiveSessionsGauge,
  adminAuthAttemptsTotal,
  adminApiErrorsTotal,
  adminErrorRate,
  adminSlowRequestsTotal,
  adminDbPoolIdleConnections,
  adminDbPoolSize,
  adminDbPoolWaitingRequests,
  adminMetricsMiddleware,
  getAdminMetricsRegistry,
  initializeAdminMetrics,
  trackAdminAction,
  trackAuthAttempt,
  trackDatabaseQuery,
  trackStripeApiCall,
  trackStripeApiError,
  updateDbPoolMetrics,
  updateErrorRate,
  updatePaymentRates,
  exportAdminMetricsAsText,
} from './admin-metrics.js';
