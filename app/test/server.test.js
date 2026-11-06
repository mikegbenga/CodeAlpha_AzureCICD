'use strict';

const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('../src/server');

let server;
let base;

before(async () => {
  server = createServer();
  await new Promise((resolve) => server.listen(0, resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((resolve) => server.close(resolve)));

test('GET /health returns healthy', async () => {
  const res = await fetch(`${base}/health`);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.status, 'healthy');
});

test('GET /api/info returns build metadata', async () => {
  const res = await fetch(`${base}/api/info`);
  assert.equal(res.status, 200);
  const body = await res.json();
  for (const key of ['version', 'buildId', 'environment', 'hostname', 'uptimeSeconds']) {
    assert.ok(key in body, `missing ${key}`);
  }
});

test('GET / serves the landing page with security headers', async () => {
  const res = await fetch(`${base}/`);
  assert.equal(res.status, 200);
  assert.match(res.headers.get('content-type'), /text\/html/);
  assert.equal(res.headers.get('x-content-type-options'), 'nosniff');
  assert.match(await res.text(), /Azure Pipelines/);
});

test('unknown path returns 404', async () => {
  const res = await fetch(`${base}/does-not-exist`);
  assert.equal(res.status, 404);
});

test('path traversal is blocked', async () => {
  const res = await fetch(`${base}/..%2f..%2fpackage.json`);
  assert.notEqual(res.status, 200);
});

test('non-GET methods are rejected', async () => {
  const res = await fetch(`${base}/health`, { method: 'POST' });
  assert.equal(res.status, 405);
});
