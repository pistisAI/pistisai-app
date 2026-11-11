# Distributed Request Tracing Implementation

**Status:** ✅ Complete  
**PR:** #405  
**Date:** 2026-11-11

## Overview

Implemented W3C Trace Context (https://www.w3.org/TR/trace-context/) for distributed tracing across PistisAI backend services. All requests now carry trace IDs in structured logs and are integrated with Sentry for centralized observability.

## What Was Implemented

### 1. Trace Context Middleware (`middleware/trace-context.js`)

- **Generates** new W3C traceparent headers when none provided
- **Extracts** existing trace IDs from incoming `traceparent` headers
- **Validates** W3C Trace Context format: `00-trace-id(32-hex)-span-id(16-hex)-flags(2-hex)`
- **Attaches** trace context to request object: `req.traceId`, `req.traceContext`
- **Returns** W3C format in response headers and legacy `X-Trace-ID` header for backward compatibility

### 2. Request Logging Integration (`middleware/request-logging.js`)

- **Includes** `traceId`, `traceSpanId`, and `traceFlags` in all request logs
- **Preserves** existing `correlationId` for backward compatibility
- **Logs on request start** with trace context
- **Logs on request completion** with trace context and duration

### 3. Sentry Integration (`middleware/sentry-trace-context.js`)

- **Attaches** trace ID to Sentry scope: `scope.setTag('traceId', traceId)`
- **Tags** Sentry errors with trace span and flags
- **Enables** correlation between Sentry error reports and structured logs
- **Sets** transaction name for Sentry performance monitoring

### 4. Middleware Pipeline Integration (`middleware/pipeline.js`)

Added trace context middleware in correct order:
1. CORS (preflight handling)
2. Helmet (security headers)
3. **Trace Context** (NEW: extracts/generates trace IDs)
4. **Sentry Trace Context** (NEW: attaches to Sentry)
5. Request Logging (includes trace in logs)
6. ... rest of pipeline

## W3C Trace Context Format

```
Request header (incoming):
  traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
  tracestate: congo=t61rcWxrMzE

Response header (outgoing):
  traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
  X-Trace-ID: 0af7651916cd43dd8448eb211c80319c  (legacy)
```

**Format breakdown:**
- `version` = `00` (W3C version 1.0)
- `trace-id` = 32 hex characters (128 bits, must be != 0)
- `span-id` = 16 hex characters (64 bits, must be != 0)
- `flags` = 2 hex characters:
  - `01` = sampled (trace is recorded)
  - `00` = not sampled

## Structured Log Example

Before:
```json
{
  "correlationId": "req-8fc811f8-b9db-406f-b4d9-b7a1decd2cd8",
  "method": "GET",
  "path": "/api/v1/users",
  "statusCode": 200,
  "duration": 42,
  "message": "Request completed"
}
```

After:
```json
{
  "correlationId": "req-8fc811f8-b9db-406f-b4d9-b7a1decd2cd8",
  "traceId": "001eeb3a0a9c4899893ddcc0a34f000d",
  "traceSpanId": "48dbf1f6e2f06258",
  "traceFlags": "01",
  "method": "GET",
  "path": "/api/v1/users",
  "statusCode": 200,
  "duration": 42,
  "message": "Request completed"
}
```

## Testing

### Test Coverage
- ✅ Trace ID generation (creates valid W3C format)
- ✅ Trace ID extraction (parses incoming traceparent headers)
- ✅ Invalid header handling (generates new ID on parse failure)
- ✅ Response headers (includes traceparent and X-Trace-ID)
- ✅ Trace context consistency (same ID across req/res cycle)
- ✅ Unique trace IDs per request
- ✅ Integration with request logging (trace fields in logs)

**Test file:** `test/api-backend/trace-context.test.js`  
**Coverage:** 76.19% of trace-context.js (key functions covered)

Run tests:
```bash
npm test test/api-backend/trace-context.test.js
```

## Service-to-Service Propagation (Future)

When api-backend calls streaming-proxy or other services, propagate trace context:

```javascript
// In api-backend when making outbound requests
const traceparent = `00-${req.traceId}-${newSpanId}-${req.traceContext.flags}`;
const options = {
  headers: {
    traceparent,
    tracestate: req.tracestate,
  },
};
// Make HTTP call with headers
```

The downstream service (streaming-proxy, tailscale-relay) will extract and log the same trace ID, enabling end-to-end tracing.

## Integration with Observability Stack

### Sentry
- Errors automatically tagged with `traceId`
- Performance transactions include trace ID
- Allows filtering Sentry issues by trace ID
- Sentry dashboards can correlate errors with logs

### Structured Logs (ELK, Datadog, CloudWatch)
- All JSON logs include `traceId` field
- Log ingestion pipelines can index by trace ID
- Correlation queries: `traceId:001eeb3a0a9c4899893ddcc0a34f000d`

### Metrics (Prometheus)
- Trace IDs available in request duration metrics
- Can slice metrics by trace ID for debugging

## Backward Compatibility

- **Correlation ID preserved:** Existing `correlationId` field remains in logs
- **Legacy header:** `X-Trace-ID` header returned alongside W3C `traceparent`
- **Fallback:** If incoming request has no `traceparent`, a new one is generated
- **No breaking changes:** All existing logging and Sentry integration continues to work

## Known Limitations

1. **Single-service tracing:** Currently works within api-backend. Multi-service tracing requires downstream services (streaming-proxy, tailscale-relay) to also implement trace context extraction.

2. **Sampling:** Sentry's `tracesSampleRate` (currently 0.1 in production, 1.0 in dev) controls which traces are recorded. Adjust in `server.js` if needed.

3. **Async context:** Trace context is attached to Express `req` object, which works for synchronous code. For long-lived async operations (worker threads, scheduled jobs), consider using Node.js `AsyncLocalStorage` for continuation.

## Files Changed

- ✅ `middleware/trace-context.js` (NEW)
- ✅ `middleware/sentry-trace-context.js` (NEW)
- ✅ `middleware/request-logging.js` (UPDATED)
- ✅ `middleware/pipeline.js` (UPDATED)
- ✅ `test/api-backend/trace-context.test.js` (NEW)

## Next Steps

1. **Streaming Proxy:** Implement trace context middleware in `services/streaming-proxy/src/server.ts`
2. **Tailscale Relay:** Implement trace context middleware in `services/tailscale-relay/src/server.js`
3. **Observability Configuration:** Configure ELK/Datadog to parse and index `traceId` field from logs
4. **Runbooks:** Document how to debug requests using trace IDs in production

## Verification Evidence

### Test Results
```
PASS ../../test/api-backend/trace-context.test.js
  Trace Context Middleware
    Trace ID Generation
      ✓ should generate a trace ID when none is provided
      ✓ should generate a valid W3C traceparent header
      ✓ should include trace context in request object
    Trace ID Extraction
      ✓ should extract trace ID from incoming traceparent header
      ✓ should handle invalid traceparent headers gracefully
      ✓ should preserve tracestate header
    Response Headers
      ✓ should include W3C traceparent in response headers
      ✓ should include legacy X-Trace-ID header
      ✓ should not include tracestate if not provided
    Integration with Request Logging
      ✓ should include trace context in logged requests
    Trace ID Consistency
      ✓ should maintain the same trace ID across req/res cycle
      ✓ should generate unique trace IDs for separate requests
    Error Handling
      ✓ should recover from errors in trace context generation
```

### Log Evidence
Structured logs now include trace context:
```json
{
  "traceId": "001eeb3a0a9c4899893ddcc0a34f000d",
  "traceSpanId": "48dbf1f6e2f06258",
  "traceFlags": "01",
  "correlationId": "req-8fc811f8-b9db-406f-b4d9-b7a1decd2cd8",
  "message": "Request completed",
  ...
}
```

## References

- **W3C Trace Context:** https://www.w3.org/TR/trace-context/
- **OpenTelemetry Spec:** https://opentelemetry.io/docs/concepts/signals/traces/
- **Sentry Tracing:** https://docs.sentry.io/product/tracing/
