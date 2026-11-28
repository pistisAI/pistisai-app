'use strict';

const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const net = require('node:net');
const path = require('node:path');
const { describe, it } = require('node:test');

const handlersPath = path.join(__dirname, 'handlers.js');
const PORT = '39991';

function portIsOpen(port) {
  return new Promise((resolve) => {
    const socket = net.connect({ port: Number(port), host: '127.0.0.1' });
    socket.once('connect', () => {
      socket.end();
      resolve(true);
    });
    socket.once('error', () => resolve(false));
  });
}

describe('quarantined legacy Auth0 backend', () => {
  it('refuses to load as a module', () => {
    assert.throws(() => {
      require(handlersPath);
    }, /quarantined/);
  });

  it('exits non-zero when started and does not listen', async () => {
    const result = spawnSync(process.execPath, [handlersPath], {
      encoding: 'utf8',
      timeout: 5000,
      env: {
        ...process.env,
        PORT,
        NODE_ENV: 'production',
        AUTH0_DOMAIN: 'test.example.auth0.com',
        AUTH0_AUDIENCE: 'https://api.example.com',
        DEV_BYPASS_TOKEN: 'must-not-authenticate',
      },
    });

    assert.strictEqual(result.status, 1);
    assert.equal(result.signal, null);
    assert.match(result.stderr, /quarantined/);
    assert.match(result.stderr, /Cloudflare Access/);
    assert.match(result.stderr, /services\/api-backend/);
    assert.doesNotMatch(result.stderr + result.stdout, /listening/i);
    assert.equal(await portIsOpen(PORT), false);
  });

  it('still refuses to load when Auth0 env vars are unset', () => {
    const result = spawnSync(
      process.execPath,
      ['-e', `require(${JSON.stringify(handlersPath)})`],
      { encoding: 'utf8', timeout: 5000, env: { PATH: process.env.PATH } },
    );

    assert.notStrictEqual(result.status, 0);
    assert.match(result.stderr, /quarantined/);
    assert.match(result.stderr, /services\/api-backend/);
  });
});
