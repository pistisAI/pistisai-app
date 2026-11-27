import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { once } from 'node:events';
import jwt from 'jsonwebtoken';
import WebSocket from 'ws';
import { createRelayServer } from '../src/server.js';

const SECRET = 'test-only-relay-secret-0123456789abcdef';
const quietLogger = { log() {}, error() {} };

let target;
let targetHits = 0;
let targetPort;

before(async () => {
  // Stand-in for any service reachable from the relay host.
  target = http.createServer((req, res) => {
    targetHits += 1;
    res.end('reached');
  });
  target.listen(0, '127.0.0.1');
  await once(target, 'listening');
  targetPort = target.address().port;
});

after(() => {
  target.close();
});

async function startRelay(fetchImpl) {
  const relay = createRelayServer({ jwtSecret: SECRET, logger: quietLogger, fetchImpl });
  relay.listen(0, '127.0.0.1');
  await once(relay, 'listening');
  return relay;
}

function token(payload = { sub: 'user-1' }, options = { expiresIn: 60 }) {
  return jwt.sign(payload, SECRET, { algorithm: 'HS256', ...options });
}

function connect(relay, params) {
  const qs = new URLSearchParams(params).toString();
  return new WebSocket(`ws://127.0.0.1:${relay.address().port}/tailscale/ws?${qs}`);
}

async function closeCode(ws) {
  ws.on('open', () => ws.send('{}'));
  ws.on('message', () => ws.close());
  const [code] = await once(ws, 'close');
  return code;
}

test('a targetIp that is not a tailnet address is refused and nothing is forwarded', async () => {
  const relay = await startRelay(undefined);
  try {
    const crafted = [
      `127.0.0.1:${targetPort}/probe?`,
      `127.0.0.1:${targetPort}`,
      '127.0.0.1',
      'localhost',
    ];
    for (const targetIp of crafted) {
      const code = await closeCode(connect(relay, { token: token(), targetIp }));
      assert.equal(code, 1008, `expected ${targetIp} to be refused`);
    }
    assert.equal(targetHits, 0);
  } finally {
    relay.close();
  }
});

test('a token without exp is refused', async () => {
  const relay = await startRelay(async () => {
    throw new Error('must not forward');
  });
  try {
    const noExp = token({ sub: 'user-1' }, {});
    const code = await closeCode(connect(relay, { token: noExp, targetIp: '100.64.0.10' }));
    assert.equal(code, 1008);
  } finally {
    relay.close();
  }
});

test('a tailnet target is forwarded to the fixed port and path', async () => {
  const calls = [];
  const relay = await startRelay(async (url) => {
    calls.push(url);
    return new Response('ok-from-device');
  });
  try {
    const ws = connect(relay, { token: token(), targetIp: '100.100.1.2' });
    await once(ws, 'open');
    ws.send('{"model":"m"}');
    const [data] = await once(ws, 'message');
    assert.equal(data.toString(), 'ok-from-device');
    assert.deepEqual(calls, ['http://100.100.1.2:11434/api/generate']);
    ws.close();
  } finally {
    relay.close();
  }
});

test('forward errors reach the client without internal details', async () => {
  const relay = await startRelay(async () => {
    throw new Error('connect ECONNREFUSED internal-detail');
  });
  try {
    const ws = connect(relay, { token: token(), targetIp: '100.100.1.2' });
    await once(ws, 'open');
    ws.send('{}');
    const [data] = await once(ws, 'message');
    assert.deepEqual(JSON.parse(data.toString()), { error: 'Failed to forward to target device' });
    ws.close();
  } finally {
    relay.close();
  }
});
