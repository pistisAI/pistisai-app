import express from 'express';
import http from 'http';
import { pathToFileURL } from 'node:url';
import { WebSocketServer } from 'ws';
import fetch from 'node-fetch';
import {
  buildTargetUrl,
  checkJwtSecret,
  validateTargetIp,
  verifyRelayToken,
} from './relay-checks.js';

const FORWARD_ERROR = 'Failed to forward to target device';

/**
 * Creates the relay HTTP server (not yet listening).
 * @param {{ jwtSecret: string, fetchImpl?: typeof fetch, logger?: Console }} options
 */
export function createRelayServer({ jwtSecret, fetchImpl = fetch, logger = console }) {
  const secretError = checkJwtSecret(jwtSecret);
  if (secretError) {
    throw new Error(secretError);
  }

  const app = express();
  const server = http.createServer(app);

  app.get('/health', (req, res) => {
    res.send({ status: 'healthy', timestamp: new Date().toISOString() });
  });

  // WebSocket server for Tailscale connections
  const wss = new WebSocketServer({
    server,
    path: '/tailscale/ws'
  });

  wss.on('connection', (ws, req) => {
    const url = new URL(req.url, 'http://relay.invalid');
    const token = url.searchParams.get('token');
    const rawTarget = url.searchParams.get('targetIp');

    if (!token || !rawTarget) {
      ws.close(1008, 'Missing token or targetIp');
      return;
    }

    let userId;
    try {
      ({ userId } = verifyRelayToken(token, jwtSecret));
    } catch (error) {
      logger.error('Tailscale Relay: Auth failed', error.message);
      ws.close(1008, 'Authentication failed');
      return;
    }

    const targetIp = validateTargetIp(rawTarget);
    if (!targetIp) {
      logger.error(`Tailscale Relay: Rejected target for user ${userId}`);
      ws.close(1008, 'Invalid targetIp');
      return;
    }
    const targetUrl = buildTargetUrl(targetIp);
    logger.log(`Tailscale Relay: Connection for user ${userId} to ${targetIp}`);

    ws.on('message', async (message) => {
      try {
        // Forward request to Ollama on the Tailscale device (fixed port/path).
        const response = await fetchImpl(targetUrl.href, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: message,
          redirect: 'error'
        });

        const data = Buffer.from(await response.arrayBuffer());
        ws.send(data);
      } catch (error) {
        logger.error(`Tailscale Relay: Forward error to ${targetIp}`, error.message);
        ws.send(JSON.stringify({ error: FORWARD_ERROR }));
      }
    });
  });

  return server;
}

function isMainModule() {
  return Boolean(process.argv[1]) && import.meta.url === pathToFileURL(process.argv[1]).href;
}

if (isMainModule()) {
  const jwtSecret = process.env.JWT_SECRET;
  const secretError = checkJwtSecret(jwtSecret);
  if (secretError) {
    console.error(`Tailscale Relay: ${secretError}. Refusing to start.`);
    process.exit(1);
  }
  const PORT = process.env.PORT || 3002;
  createRelayServer({ jwtSecret }).listen(PORT, () => {
    console.log(`Tailscale Relay listening on port ${PORT}`);
  });
}
