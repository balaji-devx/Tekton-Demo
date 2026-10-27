/**
 * Release Console - Production-Grade Application Server
 * Built with native Node.js modules for lightweight, secure in-cluster execution.
 */

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const PUBLIC_DIR = path.resolve(__dirname, '..', 'public');

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml; charset=utf-8',
  '.ico': 'image/x-icon'
};

/**
 * Resolves static file path safely, mitigating directory traversal attacks.
 * @param {string} urlPath 
 * @returns {string|null} Resolved file path or null if invalid
 */
function resolveSafePath(urlPath) {
  let cleanPath = urlPath.split('?')[0];
  if (cleanPath === '/' || cleanPath === '') {
    cleanPath = '/index.html';
  }

  // Prevent directory traversal
  const resolvedPath = path.resolve(PUBLIC_DIR, '.' + cleanPath);
  if (!resolvedPath.startsWith(PUBLIC_DIR)) {
    return null;
  }

  return resolvedPath;
}

/**
 * Writes JSON response with standard security headers.
 * @param {http.ServerResponse} res 
 * @param {number} statusCode 
 * @param {object} data 
 */
function sendJson(res, statusCode, data) {
  const payload = JSON.stringify(data);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(payload),
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Cache-Control': 'no-store, no-cache, must-revalidate'
  });
  res.end(payload);
}

/**
 * Evaluates a release scenario for the UI's educational resilience lab.
 * This endpoint never invokes kubectl and never changes the live deployment.
 */
const RELEASE_LAB_SCENARIOS = Object.freeze({
  success: {
    outcome: 'ready',
    title: 'Quality gates passed',
    summary: 'The candidate is eligible to proceed to deployment. This simulation does not deploy it.',
    priorVersionPreserved: false,
    stages: [
      { name: 'Unit tests', status: 'passed', detail: 'Automated tests passed.' },
      { name: 'Build and publish image', status: 'passed', detail: 'Kaniko would publish the versioned image.' },
      { name: 'Kubernetes rollout', status: 'ready', detail: 'The candidate is ready for the deployment stage.' }
    ]
  },
  'test-failure': {
    outcome: 'blocked',
    title: 'Candidate blocked at the test gate',
    summary: 'The test Task fails, so the dependent image-build and deployment Tasks do not run. The currently deployed version remains in place.',
    priorVersionPreserved: true,
    stages: [
      { name: 'Unit tests', status: 'failed', detail: 'A regression was detected by the test suite.' },
      { name: 'Build and publish image', status: 'blocked', detail: 'Blocked because the test Task failed.' },
      { name: 'Kubernetes rollout', status: 'skipped', detail: 'No new image is deployed; the existing Deployment is untouched.' }
    ]
  },
  'rollout-failure': {
    outcome: 'recovered',
    title: 'Failed rollout — previous revision restored',
    summary: 'If a real rollout fails and a previous Deployment revision exists, the deploy Task attempts kubectl rollout undo and verifies the restored revision. The pipeline still reports failure.',
    priorVersionPreserved: true,
    stages: [
      { name: 'Unit tests', status: 'passed', detail: 'The candidate passed the test gate.' },
      { name: 'Build and publish image', status: 'passed', detail: 'The candidate image was published.' },
      { name: 'Kubernetes rollout', status: 'failed', detail: 'The candidate did not become ready before the rollout timeout.' },
      { name: 'Rollback', status: 'restored', detail: 'The prior Deployment revision is restored when rollback succeeds.' }
    ]
  }
});

function handleReleaseLabRequest(req, res) {
  const chunks = [];
  const maxBodyBytes = 8192;
  let bodyBytes = 0;
  let tooLarge = false;

  req.on('data', (chunk) => {
    bodyBytes += chunk.length;
    if (bodyBytes > maxBodyBytes) {
      tooLarge = true;
      return;
    }
    chunks.push(chunk);
  });

  req.on('end', () => {
    if (tooLarge) {
      return sendJson(res, 413, { error: 'Request body too large', code: 413 });
    }

    let payload;
    try {
      payload = JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
    } catch (_) {
      return sendJson(res, 400, { error: 'Invalid JSON body', code: 400 });
    }
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      return sendJson(res, 400, { error: 'JSON body must be an object', code: 400 });
    }

    const scenario = Object.hasOwn(RELEASE_LAB_SCENARIOS, payload.scenario)
      ? RELEASE_LAB_SCENARIOS[payload.scenario]
      : null;
    if (!scenario) {
      return sendJson(res, 400, {
        error: 'Unknown scenario. Use success, test-failure, or rollout-failure.',
        code: 400
      });
    }

    return sendJson(res, 200, {
      service: 'release-console',
      simulationOnly: true,
      liveClusterChanged: false,
      scenario: payload.scenario,
      currentVersion: process.env.APP_VERSION || 'dev-local',
      currentCommit: process.env.GIT_COMMIT || 'local-dev-commit',
      priorVersionPreserved: scenario.priorVersionPreserved,
      outcome: scenario.outcome,
      title: scenario.title,
      summary: scenario.summary,
      stages: scenario.stages
    });
  });
}

/**
 * Handles incoming HTTP requests for Release Console.
 * @param {http.IncomingMessage} req 
 * @param {http.ServerResponse} res 
 */
function requestHandler(req, res) {
  try {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
    const pathname = url.pathname;

    // Interactive what-if evaluator; deliberately separate from live cluster control.
    if (pathname === '/api/release-lab/evaluate') {
      if (req.method !== 'POST') {
        res.writeHead(405, {
          'Content-Type': 'application/json; charset=utf-8',
          'Allow': 'POST',
          'X-Content-Type-Options': 'nosniff'
        });
        return res.end(JSON.stringify({ error: 'Method Not Allowed', code: 405 }));
      }
      return handleReleaseLabRequest(req, res);
    }

    // Ordinary application routes are read-only and accept GET/HEAD only.
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.writeHead(405, { 'Content-Type': 'application/json; charset=utf-8', 'Allow': 'GET, HEAD' });
      return res.end(JSON.stringify({ error: 'Method Not Allowed', code: 405 }));
    }

    // Health check endpoint for Kubernetes liveness & readiness probes
    if (pathname === '/healthz') {
      return sendJson(res, 200, {
        status: 'ok',
        service: 'release-console',
        version: process.env.APP_VERSION || 'dev-local',
        commit: process.env.GIT_COMMIT || 'local-dev-commit'
      });
    }

    // Live runtime metadata endpoint for Release Console UI
    if (pathname === '/api/info') {
      return sendJson(res, 200, {
        service: 'release-console',
        version: process.env.APP_VERSION || 'dev-local',
        commit: process.env.GIT_COMMIT || 'local-dev-commit',
        environment: process.env.DEPLOY_ENV || 'local-development',
        nodeVersion: process.version,
        health: 'healthy',
        uptimeSeconds: Math.floor(process.uptime()),
        timestamp: new Date().toISOString()
      });
    }

    // Static asset serving with traversal protection
    const filePath = resolveSafePath(pathname);
    if (!filePath) {
      return sendJson(res, 403, { error: 'Forbidden', code: 403 });
    }

    fs.stat(filePath, (err, stats) => {
      if (err || !stats.isFile()) {
        return sendJson(res, 404, { error: 'Resource Not Found', code: 404 });
      }

      const ext = path.extname(filePath).toLowerCase();
      const contentType = MIME_TYPES[ext] || 'application/octet-stream';

      res.writeHead(200, {
        'Content-Type': contentType,
        'Content-Length': stats.size,
        'X-Content-Type-Options': 'nosniff',
        'Cache-Control': ext === '.html' ? 'no-cache' : 'public, max-age=3600'
      });

      if (req.method === 'HEAD') {
        return res.end();
      }

      const stream = fs.createReadStream(filePath);
      stream.on('error', () => {
        if (!res.headersSent) {
          sendJson(res, 500, { error: 'Internal Server Error', code: 500 });
        }
      });
      stream.pipe(res);
    });

  } catch (err) {
    // Return sanitized error without exposing internal stack traces
    if (!res.headersSent) {
      sendJson(res, 500, { error: 'Internal Server Error', code: 500 });
    }
  }
}

/**
 * Creates an HTTP server instance for testing or execution.
 * @returns {http.Server}
 */
function createServer() {
  return http.createServer(requestHandler);
}

/**
 * Starts the application server on the specified host and port.
 * @param {number} port 
 * @param {string} host 
 * @returns {http.Server}
 */
function startServer(port = 3000, host = '0.0.0.0') {
  const server = createServer();
  server.listen(port, host, () => {
    const actualPort = server.address().port;
    console.log(`[Release Console] Server listening on ${host}:${actualPort}`);
    console.log(`[Release Console] Environment: ${process.env.DEPLOY_ENV || 'local-development'}`);
    console.log(`[Release Console] Version: ${process.env.APP_VERSION || 'dev-local'}`);
    console.log(`[Release Console] Git Commit: ${process.env.GIT_COMMIT || 'local-dev-commit'}`);
  });
  return server;
}

// Auto-start when executed directly
if (require.main === module) {
  const port = parseInt(process.env.PORT, 10) || 3000;
  startServer(port, '0.0.0.0');
}

module.exports = {
  createServer,
  startServer,
  requestHandler,
  resolveSafePath
};
