/**
 * Contract tests for agent-runtime / support-provider discovery probes.
 *
 * The Flutter `ProviderDiscoveryService` issues these HTTP checks against
 * Hermes (agent runtime), Ollama, and LM Studio. OpenClaw Gateway remains a
 * supported runtime via configuration / gateway control, but is not part of
 * the auto-scan list today (Hermes is the primary discovery path).
 *
 * @jest-environment node
 */

import http from 'http';

function listen(handler) {
  return new Promise((resolve, reject) => {
    const server = http.createServer(handler);
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      resolve({ server, port, baseUrl: `http://127.0.0.1:${port}` });
    });
    server.on('error', reject);
  });
}

async function get(url) {
  const res = await fetch(url);
  const text = await res.text();
  let json = null;
  try {
    json = JSON.parse(text);
  } catch {
    // ignore
  }
  return { status: res.status, text, json };
}

describe('runtime discovery probe contract', () => {
  /** @type {import('http').Server[]} */
  const servers = [];

  afterAll(async () => {
    await Promise.all(
      servers.map(
        (server) =>
          new Promise((resolve) => {
            server.close(() => resolve());
          }),
      ),
    );
  });

  test('Hermes /health probe succeeds on a mock agent API', async () => {
    const { server, baseUrl } = await listen((req, res) => {
      if (req.url === '/health') {
        res.writeHead(200, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok', version: 'test' }));
        return;
      }
      res.writeHead(404);
      res.end();
    });
    servers.push(server);

    const result = await get(`${baseUrl}/health`);
    expect(result.status).toBe(200);
    expect(result.json?.status).toBe('ok');
  });

  test('Ollama /api/tags probe succeeds on a mock support provider', async () => {
    const { server, baseUrl } = await listen((req, res) => {
      if (req.url === '/api/tags') {
        res.writeHead(200, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ models: [{ name: 'llama-test' }] }));
        return;
      }
      res.writeHead(404);
      res.end();
    });
    servers.push(server);

    const result = await get(`${baseUrl}/api/tags`);
    expect(result.status).toBe(200);
    expect(result.json?.models?.[0]?.name).toBe('llama-test');
  });

  test('OpenAI-compatible /v1/models probe (LM Studio / OpenClaw-style)', async () => {
    const { server, baseUrl } = await listen((req, res) => {
      if (req.url === '/v1/models') {
        res.writeHead(200, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ data: [{ id: 'local-model' }] }));
        return;
      }
      res.writeHead(404);
      res.end();
    });
    servers.push(server);

    const result = await get(`${baseUrl}/v1/models`);
    expect(result.status).toBe(200);
    expect(result.json?.data?.[0]?.id).toBe('local-model');
  });

  test('graceful degradation when nothing is listening', async () => {
    await expect(
      fetch('http://127.0.0.1:9/health', { signal: AbortSignal.timeout(500) }),
    ).rejects.toThrow();
  });
});
