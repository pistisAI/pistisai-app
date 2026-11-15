/**
 * N+1 query batching regression tests (#621)
 *
 * Asserts that previously per-row query loops issue a bounded number of
 * SQL statements independent of collection size.
 */

import { jest, describe, it, expect, beforeEach } from '@jest/globals';

jest.unstable_mockModule('../../services/api-backend/logger.js', () => ({
  default: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  },
}));

const { TunnelService } =
  await import('../../services/api-backend/services/tunnel-service.js');
const { ProxyWebhookService } =
  await import('../../services/api-backend/services/proxy-webhook-service.js');
const { TunnelWebhookService } =
  await import('../../services/api-backend/services/tunnel-webhook-service.js');
const { insertMessagesBatched } =
  await import('../../services/api-backend/database/sql-batch.js');

function makeCountingClient(handlers = {}) {
  const calls = [];
  const client = {
    query: jest.fn(async (sql, params = []) => {
      calls.push({ sql, params });
      for (const [match, result] of Object.entries(handlers)) {
        if (sql.includes(match)) {
          return typeof result === 'function' ? result(sql, params) : result;
        }
      }
      return { rows: [], rowCount: 0 };
    }),
    release: jest.fn(),
  };
  return { client, calls };
}

describe('N+1 batching (#621)', () => {
  describe('TunnelService.listTunnels', () => {
    let service;

    beforeEach(() => {
      service = new TunnelService();
    });

    it('loads endpoints for N tunnels with one query (not N)', async () => {
      const tunnels = [1, 2, 3, 4, 5].map((n) => ({
        id: `tunnel-${n}`,
        user_id: 'user-1',
        name: `T${n}`,
        config: '{}',
        metrics: '{}',
        created_at: new Date().toISOString(),
      }));

      const endpointRows = tunnels.flatMap((t, i) => [
        {
          id: `ep-${i}-a`,
          tunnel_id: t.id,
          url: `http://localhost:${8000 + i}`,
          priority: 2,
          weight: 1,
        },
        {
          id: `ep-${i}-b`,
          tunnel_id: t.id,
          url: `http://localhost:${9000 + i}`,
          priority: 1,
          weight: 1,
        },
      ]);

      const { client, calls } = makeCountingClient({
        COUNT: { rows: [{ count: String(tunnels.length) }] },
        'FROM tunnels': { rows: tunnels },
        tunnel_endpoints: { rows: endpointRows },
      });
      service.pool = client;

      const result = await service.listTunnels('user-1', { limit: 50, offset: 0 });

      expect(result.tunnels).toHaveLength(5);
      expect(result.tunnels[0].endpoints).toHaveLength(2);
      expect(result.tunnels[0].endpoints[0].priority).toBeGreaterThanOrEqual(
        result.tunnels[0].endpoints[1].priority,
      );

      const endpointQueries = calls.filter((c) =>
        c.sql.includes('tunnel_endpoints'),
      );
      expect(endpointQueries).toHaveLength(1);
      expect(endpointQueries[0].sql).toMatch(/ANY\s*\(/i);
      expect(endpointQueries[0].params[0]).toEqual(tunnels.map((t) => t.id));

      // count + tunnels + batched endpoints
      expect(calls).toHaveLength(3);
    });

    it('skips endpoint query when there are no tunnels', async () => {
      const { client, calls } = makeCountingClient({
        COUNT: { rows: [{ count: '0' }] },
        'FROM tunnels': { rows: [] },
      });
      service.pool = client;

      const result = await service.listTunnels('user-1');

      expect(result.tunnels).toEqual([]);
      expect(calls.filter((c) => c.sql.includes('tunnel_endpoints'))).toHaveLength(
        0,
      );
      expect(calls).toHaveLength(2);
    });
  });

  describe('ProxyWebhookService.triggerWebhookEvent', () => {
    it('inserts webhook events in a single multi-row INSERT', async () => {
      const webhooks = [1, 2, 3, 4].map((n) => ({
        id: `wh-${n}`,
        user_id: 'user-1',
        is_active: true,
      }));

      const { client, calls } = makeCountingClient({
        'FROM proxy_webhooks': { rows: webhooks },
        'INSERT INTO proxy_webhook_events': { rows: [], rowCount: webhooks.length },
      });

      const service = new ProxyWebhookService();
      service.pool = {
        connect: jest.fn(async () => client),
      };
      service.queueWebhookDelivery = jest.fn(async () => {});

      await service.triggerWebhookEvent('proxy-1', 'user-1', 'status_change', {
        status: 'up',
      });

      const inserts = calls.filter((c) =>
        c.sql.includes('INSERT INTO proxy_webhook_events'),
      );
      expect(inserts).toHaveLength(1);
      expect(inserts[0].sql.match(/\$\d+/g).length).toBe(webhooks.length * 5);
      expect(service.queueWebhookDelivery).toHaveBeenCalledTimes(webhooks.length);
    });

    it('issues no event INSERT when no webhooks match', async () => {
      const { client, calls } = makeCountingClient({
        'FROM proxy_webhooks': { rows: [] },
      });

      const service = new ProxyWebhookService();
      service.pool = {
        connect: jest.fn(async () => client),
      };
      service.queueWebhookDelivery = jest.fn(async () => {});

      await service.triggerWebhookEvent('proxy-1', 'user-1', 'status_change', {});

      expect(
        calls.filter((c) => c.sql.includes('INSERT INTO proxy_webhook_events')),
      ).toHaveLength(0);
    });
  });

  describe('TunnelWebhookService.triggerWebhookEvent', () => {
    it('inserts webhook events in a single multi-row INSERT', async () => {
      const webhooks = [1, 2, 3].map((n) => ({
        id: `twh-${n}`,
        user_id: 'user-1',
        is_active: true,
      }));

      const { client, calls } = makeCountingClient({
        'FROM tunnel_webhooks': { rows: webhooks },
        'INSERT INTO tunnel_webhook_events': {
          rows: [],
          rowCount: webhooks.length,
        },
      });

      const service = new TunnelWebhookService();
      service.pool = {
        connect: jest.fn(async () => client),
      };
      service.queueWebhookDelivery = jest.fn(async () => {});

      await service.triggerWebhookEvent('tunnel-1', 'user-1', 'status_change', {
        status: 'down',
      });

      const inserts = calls.filter((c) =>
        c.sql.includes('INSERT INTO tunnel_webhook_events'),
      );
      expect(inserts).toHaveLength(1);
      expect(inserts[0].sql.match(/\$\d+/g).length).toBe(webhooks.length * 5);
    });
  });

  describe('insertMessagesBatched', () => {
    it('inserts N messages with one query', async () => {
      const { client, calls } = makeCountingClient({
        'INSERT INTO messages': { rows: [], rowCount: 3 },
      });

      const messages = [
        { role: 'user', content: 'hi', model: 'm', status: 'sent' },
        { role: 'assistant', content: 'hello', model: 'm', status: 'sent' },
        { role: 'user', content: 'thanks', model: 'm', status: 'sent' },
      ];

      await insertMessagesBatched(client, 'conv-1', messages, 'm');

      expect(calls).toHaveLength(1);
      expect(calls[0].sql).toMatch(/INSERT INTO messages/i);
      expect(calls[0].sql.match(/\$\d+/g).length).toBe(messages.length * 8);
      expect(calls[0].params).toHaveLength(messages.length * 8);
    });

    it('no-ops for empty message list', async () => {
      const { client, calls } = makeCountingClient();
      await insertMessagesBatched(client, 'conv-1', [], 'm');
      expect(calls).toHaveLength(0);
    });
  });
});
