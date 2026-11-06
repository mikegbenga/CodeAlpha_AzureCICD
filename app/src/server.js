'use strict';

/**
 * CodeAlpha DevOps — Task 1
 * Minimal, dependency-free Node.js web app deployed to Azure App Service
 * (Web App for Containers) through an Azure Pipelines CI/CD pipeline.
 */

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');

const PORT = Number(process.env.PORT || process.env.WEBSITES_PORT || 3000);
const APP_VERSION = process.env.APP_VERSION || 'dev';
const BUILD_ID = process.env.BUILD_ID || 'local';
const ENVIRONMENT = process.env.APP_ENVIRONMENT || 'development';
const STARTED_AT = new Date();
const PUBLIC_DIR = path.join(__dirname, '..', 'public');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.json': 'application/json; charset=utf-8',
};

const SECURITY_HEADERS = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Content-Security-Policy': "default-src 'self'; style-src 'self'; script-src 'self'",
};

let requestCount = 0;

function info() {
  return {
    app: 'codealpha-azure-cicd',
    version: APP_VERSION,
    buildId: BUILD_ID,
    environment: ENVIRONMENT,
    hostname: os.hostname(),
    node: process.version,
    startedAt: STARTED_AT.toISOString(),
    uptimeSeconds: Math.round(process.uptime()),
    requestsServed: requestCount,
  };
}

function sendJson(res, status, body) {
  res.writeHead(status, { ...SECURITY_HEADERS, 'Content-Type': MIME['.json'], 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(body));
}

function serveStatic(req, res, urlPath) {
  const rel = urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, '');
  const filePath = path.normalize(path.join(PUBLIC_DIR, rel));
  if (!filePath.startsWith(PUBLIC_DIR)) return sendJson(res, 400, { error: 'bad path' });

  fs.readFile(filePath, (err, data) => {
    if (err) return sendJson(res, 404, { error: 'not found', path: urlPath });
    res.writeHead(200, {
      ...SECURITY_HEADERS,
      'Content-Type': MIME[path.extname(filePath)] || 'application/octet-stream',
      'Cache-Control': 'public, max-age=300',
    });
    res.end(data);
  });
}

function handler(req, res) {
  requestCount += 1;
  const started = process.hrtime.bigint();
  const urlPath = new URL(req.url, 'http://localhost').pathname;

  res.on('finish', () => {
    const ms = Number(process.hrtime.bigint() - started) / 1e6;
    // Structured log line -> App Service console logs -> Log Analytics
    console.log(JSON.stringify({
      t: new Date().toISOString(), method: req.method, path: urlPath,
      status: res.statusCode, ms: Number(ms.toFixed(2)),
    }));
  });

  if (req.method !== 'GET' && req.method !== 'HEAD') {
    return sendJson(res, 405, { error: 'method not allowed' });
  }

  switch (urlPath) {
    case '/health':
      return sendJson(res, 200, { status: 'healthy', version: APP_VERSION, uptimeSeconds: Math.round(process.uptime()) });
    case '/api/info':
      return sendJson(res, 200, info());
    default:
      return serveStatic(req, res, urlPath);
  }
}

function createServer() {
  return http.createServer(handler);
}

if (require.main === module) {
  const server = createServer();
  server.listen(PORT, () => console.log(`codealpha-azure-cicd v${APP_VERSION} listening on :${PORT}`));

  const shutdown = (signal) => {
    console.log(`${signal} received, shutting down gracefully`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10000).unref();
  };
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

module.exports = { createServer, info };
