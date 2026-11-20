/**
 * Ensures config-mutating HTTP routes cannot be wired without admin auth.
 * server.ts is not imported (it starts a listener); we assert the route table.
 */

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from '@jest/globals';

const serverSource = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), 'server.ts'),
  'utf8'
);

function middlewareListFor(method: 'put' | 'post', path: string): string {
  const escapedPath = path.replace(/\//g, '\\/');
  const pattern = new RegExp(
    `app\\.${method}\\(\\s*['"]${escapedPath}['"]\\s*,([^)]*)\\)`,
    'm'
  );
  const match = serverSource.match(pattern);
  if (!match) {
    throw new Error(`Route ${method.toUpperCase()} ${path} not found in server.ts`);
  }
  return match[1];
}

describe('config write routes require admin auth', () => {
  it.each([
    ['put', '/api/tunnel/config/log-level'],
    ['put', '/api/tunnel/config'],
    ['post', '/api/tunnel/config/reset'],
  ] as const)('%s %s registers requireAdminAuth', (method, path) => {
    expect(middlewareListFor(method, path)).toMatch(/requireAdminAuth/);
  });
});
