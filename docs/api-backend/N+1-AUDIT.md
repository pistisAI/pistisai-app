# api-backend N+1 query audit (#621)

Review of database access patterns under `services/api-backend/` for loops that issue one SQL statement per iteration.

## Refactored in this change

| Location | Pattern | Fix |
| --- | --- | --- |
| `services/tunnel-service.js` `listTunnels` | Per-tunnel `SELECT` on `tunnel_endpoints` | One `WHERE tunnel_id = ANY($1)` + in-memory group |
| `services/proxy-webhook-service.js` `triggerWebhookEvent` | Per-webhook `INSERT` into `proxy_webhook_events` | Single multi-row `INSERT` |
| `services/tunnel-webhook-service.js` `triggerWebhookEvent` | Per-webhook `INSERT` into `tunnel_webhook_events` | Single multi-row `INSERT` |
| `routes/conversations.js` create/update | Per-message `INSERT` into `messages` | `insertMessagesBatched` in `database/sql-batch.js` |

Regression coverage: `test/api-backend/n-plus-one-batching.unit.test.js` (asserts query count stays O(1) in collection size).

## Suspects identified, left unchanged

| Location | Why left | Notes |
| --- | --- | --- |
| `services/tunnel-service.js` `createTunnel` / `updateTunnel` | Lower frequency; needs `RETURNING` mapping | Multi-row `INSERT` is safe when endpoints share one tunnel |
| `services/tunnel-health-service.js` `performHealthCheck` | HTTP probe must stay per endpoint | DB `UPDATE`s can be batched with `unnest` after probes |
| `services/bulk-operations-service.js` | Per-user `BEGIN`/`COMMIT` for partial success | Batching would change failure semantics |
| `scripts/test-database.js` / migrate scripts | Offline tooling | Not a runtime path |

## Already batched (good examples)

- `routes/conversations.js` list: message counts via `WHERE conversation_id = ANY($1) GROUP BY`
- `routes/admin/payments.js`: `WHERE id = ANY($1)` for refunds lookup
