/**
 * Release Console - Automated Unit & Integration Tests
 * Validates HTTP contract, health endpoints, static delivery, quiz arena, and failure safety.
 * Uses native Node.js test runner (node:test).
 */

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createServer } = require('../src/index.js');

describe('Release Console - Server Test Suite', () => {
  let server;
  let baseUrl;

  // Set explicit test environment variables
  process.env.APP_VERSION = 'v1.0.0-test';
  process.env.GIT_COMMIT = 'abcdef1234567890';
  process.env.DEPLOY_ENV = 'unit-test-env';

  before((_, done) => {
    server = createServer();
    // Bind to ephemeral port 0 to prevent port collisions
    server.listen(0, '127.0.0.1', () => {
      const port = server.address().port;
      baseUrl = `http://127.0.0.1:${port}`;
      done();
    });
  });

  after((_, done) => {
    if (server) {
      server.close(done);
    } else {
      done();
    }
  });

  /**
   * Helper function to perform HTTP request and parse response.
   */
  function makeRequest(path, options = {}) {
    return new Promise((resolve, reject) => {
      const url = new URL(path, baseUrl);
      const req = http.request(url, options, (res) => {
        let body = '';
        res.setEncoding('utf8');
        res.on('data', (chunk) => { body += chunk; });
        res.on('end', () => {
          let json = null;
          try {
            json = JSON.parse(body);
          } catch (_) {}
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body,
            json
          });
        });
      });

      req.on('error', reject);
      if (options.body) {
        req.write(options.body);
      }
      req.end();
    });
  }

  // Requirement 1 & 2: Health endpoint returns HTTP 200 and valid JSON
  test('Requirement 1 & 2: GET /healthz returns HTTP 200 and valid JSON', async () => {
    const res = await makeRequest('/healthz');
    assert.equal(res.statusCode, 200, 'Health endpoint should return status code 200');
    assert.match(res.headers['content-type'], /application\/json/, 'Content-Type must be JSON');
    assert.ok(res.json !== null, 'Response body must be parseable JSON');
  });

  // Requirement 3: Health endpoint reports healthy state
  test('Requirement 3: GET /healthz reports status ok', async () => {
    const res = await makeRequest('/healthz');
    assert.equal(res.json.status, 'ok', 'Health status should equal "ok"');
    assert.equal(res.json.service, 'release-console', 'Service name must be release-console');
  });

  // Requirement 4: Application version and commit reflect environment variables
  test('Requirement 4: GET /healthz returns correct version and Git commit SHA', async () => {
    const res = await makeRequest('/healthz');
    assert.equal(res.json.version, 'v1.0.0-test', 'Version must match process.env.APP_VERSION');
    assert.equal(res.json.commit, 'abcdef1234567890', 'Commit must match process.env.GIT_COMMIT');
  });

  // Requirement 5: GET /api/info contains expected runtime fields
  test('Requirement 5: GET /api/info returns complete runtime telemetry metadata', async () => {
    const res = await makeRequest('/api/info');
    assert.equal(res.statusCode, 200, 'Info endpoint should return status code 200');
    assert.ok(res.json !== null, 'Info payload must be JSON');
    assert.equal(res.json.service, 'release-console');
    assert.equal(res.json.version, 'v1.0.0-test');
    assert.equal(res.json.commit, 'abcdef1234567890');
    assert.equal(res.json.environment, 'unit-test-env');
    assert.equal(res.json.health, 'healthy');
    assert.ok(typeof res.json.nodeVersion === 'string', 'nodeVersion must be a string');
    assert.ok(typeof res.json.uptimeSeconds === 'number', 'uptimeSeconds must be a number');
    assert.ok(typeof res.json.timestamp === 'string', 'timestamp must be a valid ISO string');
  });

  // Requirement 6: Root route serves HTML application shell
  test('Requirement 6: GET / returns HTML application page', async () => {
    const res = await makeRequest('/');
    assert.equal(res.statusCode, 200, 'Root route must return HTTP 200');
    assert.match(res.headers['content-type'], /text\/html/, 'Content-Type must be text/html');
    assert.match(res.body, /<title>Release Console/, 'Page must contain Release Console title');
    assert.match(res.body, /id="val-version"/, 'Page must contain version placeholder element');
  });

  // Requirement 7: Unknown route returns clean HTTP 404
  test('Requirement 7: GET /non-existent-endpoint returns HTTP 404', async () => {
    const res = await makeRequest('/non-existent-endpoint');
    assert.equal(res.statusCode, 404, 'Unknown route must return 404');
    assert.equal(res.json.code, 404);
    assert.equal(res.json.error, 'Resource Not Found');
  });

  // Requirement 8: Unsupported HTTP method returns 405 without server crash
  test('Requirement 8: POST /healthz returns 405 Method Not Allowed without crashing', async () => {
    const res = await makeRequest('/healthz', { method: 'POST', body: 'invalid-payload' });
    assert.equal(res.statusCode, 405, 'POST method should return 405 Method Not Allowed');
    assert.equal(res.json.code, 405);
    assert.equal(res.headers['allow'], 'GET, HEAD');
  });

  test('Release lab: test failure blocks image and deployment stages', async () => {
    const res = await makeRequest('/api/release-lab/evaluate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ scenario: 'test-failure' })
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json.simulationOnly, true);
    assert.equal(res.json.liveClusterChanged, false);
    assert.equal(res.json.currentVersion, 'v1.0.0-test');
    assert.equal(res.json.outcome, 'blocked');
    assert.equal(res.json.priorVersionPreserved, true);
    assert.deepEqual(res.json.stages.map((stage) => stage.status), ['failed', 'blocked', 'skipped']);
  });

  test('Release lab: healthy candidate is marked ready, not actually deployed', async () => {
    const res = await makeRequest('/api/release-lab/evaluate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ scenario: 'success' })
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json.outcome, 'ready');
    assert.equal(res.json.liveClusterChanged, false);
  });

  test('Release lab: unknown scenarios are rejected', async () => {
    const res = await makeRequest('/api/release-lab/evaluate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ scenario: 'delete-everything' })
    });
    assert.equal(res.statusCode, 400);
  });

  test('Release lab: rollout failure simulates rollback recovery', async () => {
    const res = await makeRequest('/api/release-lab/evaluate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ scenario: 'rollout-failure' })
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json.outcome, 'recovered');
    assert.equal(res.json.priorVersionPreserved, true);
    assert.deepEqual(res.json.stages.map((stage) => stage.status), ['passed', 'passed', 'failed', 'restored']);
    assert.ok(res.json.stages.every((stage) => stage.name && stage.status && stage.detail));
  });

  test('Release lab: all valid scenarios return consistent JSON structure', async () => {
    const scenarios = ['success', 'test-failure', 'rollout-failure'];
    for (const scenario of scenarios) {
      const res = await makeRequest('/api/release-lab/evaluate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ scenario })
      });
      assert.equal(res.statusCode, 200);
      assert.ok(typeof res.json.outcome === 'string');
      assert.ok(typeof res.json.title === 'string');
      assert.ok(typeof res.json.summary === 'string');
      assert.equal(res.json.currentVersion, 'v1.0.0-test');
      assert.ok(Array.isArray(res.json.stages));
      for (const stage of res.json.stages) {
        assert.ok(stage.name, 'Stage must have a name');
        assert.ok(stage.status, 'Stage must have a status');
        assert.ok(stage.detail, 'Stage must have a detail');
      }
    }
  });

  test('Release lab: endpoint accepts POST only', async () => {
    const res = await makeRequest('/api/release-lab/evaluate');
    assert.equal(res.statusCode, 405);
    assert.equal(res.headers.allow, 'POST');
  });

  // DevOps Arena quiz tests
  test('DevOps Arena: POST /api/quiz/questions returns quiz questions', async () => {
    const res = await makeRequest('/api/quiz/questions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ category: 'all', difficulty: 'mixed' })
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.json.service, 'release-console');
    assert.equal(res.json.feature, 'devops-arena');
    assert.ok(Array.isArray(res.json.questions), 'Response must contain a questions array');
    assert.ok(res.json.questions.length > 0, 'Must return at least one question');
    assert.ok(typeof res.json.count === 'number', 'Must include count');
  });

  test('DevOps Arena: questions have required fields', async () => {
    const res = await makeRequest('/api/quiz/questions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ category: 'all', difficulty: 'mixed' })
    });
    assert.equal(res.statusCode, 200);
    for (const q of res.json.questions) {
      assert.ok(typeof q.id === 'number', 'Question must have numeric id');
      assert.ok(typeof q.category === 'string', 'Question must have category');
      assert.ok(typeof q.difficulty === 'string', 'Question must have difficulty');
      assert.ok(typeof q.question === 'string', 'Question must have question text');
      assert.ok(Array.isArray(q.options), 'Question must have options array');
      assert.ok(q.options.length >= 2, 'Question must have at least 2 options');
      assert.ok(typeof q.correct === 'number', 'Question must have correct answer index');
      assert.ok(typeof q.explanation === 'string', 'Question must have explanation');
    }
  });

  test('DevOps Arena: filtering by category works', async () => {
    const res = await makeRequest('/api/quiz/questions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ category: 'docker', difficulty: 'mixed' })
    });
    assert.equal(res.statusCode, 200);
    for (const q of res.json.questions) {
      assert.equal(q.category, 'docker', 'All questions must be docker category');
    }
  });

  test('DevOps Arena: quiz endpoint accepts POST only', async () => {
    const res = await makeRequest('/api/quiz/questions');
    assert.equal(res.statusCode, 405);
    assert.equal(res.headers.allow, 'POST');
  });

  test('Static asset cache headers: CSS and JS served with no-cache, must-revalidate', async () => {
    const cssRes = await makeRequest('/styles.css?v=devops-arena-1');
    assert.equal(cssRes.statusCode, 200);
    assert.match(cssRes.headers['content-type'], /text\/css/);
    assert.equal(cssRes.headers['cache-control'], 'no-cache, must-revalidate');

    const jsRes = await makeRequest('/app.js?v=devops-arena-1');
    assert.equal(jsRes.statusCode, 200);
    assert.match(jsRes.headers['content-type'], /application\/javascript/);
    assert.equal(jsRes.headers['cache-control'], 'no-cache, must-revalidate');
  });

  // Directory traversal attack protection
  test('Security Check: Path traversal attempt (../../etc/passwd) is blocked', async () => {
    const res = await makeRequest('/../../etc/passwd');
    assert.ok([403, 404].includes(res.statusCode), 'Path traversal must be rejected with 403 or 404');
  });

  // Controlled fault injection for the live CI/CD demo. Disabled by default.
  if (process.env.DEMO_FORCE_TEST_FAILURE === 'true') {
    test('DEMO FAULT INJECTION: candidate regression must fail the quality gate', () => {
      assert.fail('Intentional demonstration failure: Tekton must block image build and deployment.');
    });
  }
});
