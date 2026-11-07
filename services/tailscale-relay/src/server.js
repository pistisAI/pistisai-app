import express from 'express';
import http from 'node:http';
import { WebSocketServer } from 'ws';
import fetch from 'node-fetch';
import {
  accessSettings,
  authorizeTunnelRequest,
} from './cloudflare-access-jwt.js';

let cachedKeys = null;
let cachedAt = 0;

export async function fetchJwks(jwksUrl, fetcher = fetch) {
  const response = await fetcher(jwksUrl);
  if (!response.ok) {
    throw new Error(`JWKS fetch failed (${response.status})`);
  }
  const body = await response.json();
  if (!body || !Array.isArray(body.keys)) {
    throw new Error('JWKS document has no keys');
  }
  return body.keys;
}

async function keysFor(settings, keysProvider) {
  if (keysProvider) return keysProvider();
  const fresh = Date.now() - cachedAt < 10 * 60 * 1000;
  if (cachedKeys && fresh) return cachedKeys;
  cachedKeys = await fetchJwks(settings.jwksUrl);
  cachedAt = Date.now();
  return cachedKeys;
}

export function createRelayServer({
  customerNetwork = process.env.PISTISAI_TUNNEL_AUTH === 'customer',
  keysProvider = null,
  settings = accessSettings(),
  listen = false,
  port = Number(process.env.PORT || 3002),
} = {}) {
  const app = express();
  const server = http.createServer(app);

  async function decide(headers, query) {
    if (customerNetwork) {
      return authorizeTunnelRequest({
        headers,
        query,
        customerNetwork: true,
      });
    }
    const keys = await keysFor(settings, keysProvider);
    return authorizeTunnelRequest({
      headers,
      query,
      customerNetwork: false,
      keys,
      audience: settings.audience,
      issuer: settings.issuer,
    });
  }

  app.get('/health', (_req, res) => {
    res.send({
      status: 'healthy',
      auth: customerNetwork ? 'customer' : 'cloudflare-access',
      timestamp: new Date().toISOString(),
    });
  });

  app.get('/tunnel/whoami', async (req, res) => {
    try {
      const decision = await decide(req.headers, req.query);
      if (!decision.ok) {
        res.status(401).json({ error: decision.error, code: decision.code });
        return;
      }
      res.json({ email: decision.email, mode: decision.mode });
    } catch (error) {
      res.status(401).json({ error: 'Authentication failed' });
    }
  });

  const wss = new WebSocketServer({ server, path: '/tailscale/ws' });

  wss.on('connection', async (ws, req) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const query = Object.fromEntries(url.searchParams.entries());
    let decision;
    try {
      decision = await decide(req.headers, query);
    } catch {
      ws.close(1008, 'Authentication failed');
      return;
    }
    if (!decision.ok) {
      ws.close(1008, 'Authentication failed');
      return;
    }
    const targetIp = query.targetIp;
    if (!targetIp) {
      ws.close(1008, 'Missing targetIp');
      return;
    }
    console.log(
      `Tailscale Relay: ${decision.mode} session ${decision.email || 'customer-network'} to ${targetIp}`,
    );
    ws.on('message', async (message) => {
      try {
        const response = await fetch(`http://${targetIp}:11434/api/generate`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: message,
        });
        const data = await response.buffer();
        ws.send(data);
      } catch (error) {
        console.error(
          `Tailscale Relay: Forward error to ${targetIp}`,
          error.message,
        );
        ws.send(
          JSON.stringify({
            error: 'Failed to forward to target device',
            details: error.message,
          }),
        );
      }
    });
  });

  if (listen) {
    server.listen(port, () => {
      console.log(`Tailscale Relay listening on port ${port}`);
    });
  }

  return { app, server, wss, customerNetwork };
}

const isDirectRun = process.argv[1] &&
  process.argv[1].endsWith('server.js');
if (isDirectRun) {
  createRelayServer({ listen: true });
}
