#!/usr/bin/env node
/**
 * Scan backtick-quoted repo paths in docs/ and report paths that no longer exist.
 *
 * This reproduces the scan behind issue #813: only repo-relative code paths
 * (a leading directory that exists at the repo root, a known code-file
 * extension, no shell/URL characters) are checked. Doc-to-doc paths under
 * `docs/` are excluded; archived reports are excluded unless `--all` is given,
 * because `docs/archive/historical-reports/` is explicitly historical.
 *
 * Usage: node scripts/validate-doc-paths.js [--all]
 */
import fs from 'fs';
import path from 'path';
import process from 'process';
import { fileURLToPath } from 'url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const includeArchived = process.argv.includes('--all');

const codeExts = new Set(`.js .jsx .ts .tsx .mjs .cjs .json .dart .py .sh .yml .yaml .md
  .html .css .scss .sql .java .kt .swift .rb .go .rs .cs .php .vue .svelte .toml
  .lock .env .properties .gradle .xml .plist .xcconfig .tf .proto .prisma .graphql
  .conf .ini .cfg .txt .jks .keystore .pem .crt .svg .png .jpg .gif .webp`
  .trim().split(/\s+/));

const repoTop = new Set(fs.readdirSync(repoRoot));
const safePath = /^[A-Za-z0-9_.+\-/]+$/;

function looksLikeCodePath(value) {
  if (!value.includes('/') || !safePath.test(value)) return false;
  const top = value.split('/')[0];
  if (top === 'docs' || !repoTop.has(top)) return false;
  const last = value.split('/').pop();
  if (!last.includes('.')) return false;
  return codeExts.has('.' + last.split('.').pop());
}

function walk(dir) {
  const files = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === 'node_modules' || entry.name === '.git') continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      const rel = path.relative(repoRoot, full).split(path.sep).join('/');
      if (!includeArchived && rel.startsWith('docs/archive')) continue;
      files.push(...walk(full));
    } else if (entry.isFile() && entry.name.endsWith('.md')) {
      files.push(full);
    }
  }
  return files;
}

const missing = new Map();
let refs = 0;
let unique = new Set();
for (const file of walk(path.join(repoRoot, 'docs'))) {
  const relFile = path.relative(repoRoot, file).split(path.sep).join('/');
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  lines.forEach((line, index) => {
    for (const match of line.matchAll(/`([^`\n]+)`/g)) {
      const value = match[1];
      if (!looksLikeCodePath(value)) continue;
      refs++;
      unique.add(value);
      if (!fs.existsSync(path.join(repoRoot, value))) {
        if (!missing.has(value)) missing.set(value, []);
        missing.get(value).push(`${relFile}:${index + 1}`);
      }
    }
  });
}

console.log(`Scanned ${refs} code-path references (${unique.size} unique) in docs/${includeArchived ? ' (including archive)' : ' (excluding archive)'}.`);
if (missing.size === 0) {
  console.log('OK: 0 missing code paths.');
  process.exit(0);
}
console.log(`FAIL: ${missing.size} missing code paths:`);
for (const [value, locations] of [...missing].sort()) {
  console.log(`- ${value}\n    ${locations.join(', ')}`);
}
process.exit(1);
