/**
 * Release Console - Client Telemetry Controller
 * Queries live in-cluster pod endpoints via fetch().
 */

(function () {
  'use strict';

  let currentTab = '/api/info';
  let cachedInfo = null;
  let cachedHealth = null;

  // DOM Elements
  const elVersion = document.getElementById('val-version');
  const elCommit = document.getElementById('val-commit');
  const elEnv = document.getElementById('val-env');
  const elRuntime = document.getElementById('val-runtime');
  const elHeaderDot = document.getElementById('header-status-dot');
  const elHeaderStatus = document.getElementById('header-status-text');
  const elTerminalContent = document.getElementById('terminal-content');
  const elTerminalStatus = document.getElementById('terminal-http-status');
  const elTerminalTime = document.getElementById('terminal-timestamp');
  const elLatency = document.getElementById('val-latency');
  const btnRefresh = document.getElementById('btn-refresh');
  const tabInfo = document.getElementById('tab-info');
  const tabHealth = document.getElementById('tab-health');
  const labScenarioButtons = Array.from(document.querySelectorAll('[data-scenario]'));
  const labOutcomePanel = document.getElementById('lab-outcome-panel');
  const labOutcomeTitle = document.getElementById('lab-outcome-title');
  const labOutcomeSummary = document.getElementById('lab-outcome-summary');
  const labCurrentVersion = document.getElementById('lab-current-version');
  const labStageResults = document.getElementById('lab-stage-results');
  const labEvidence = document.getElementById('lab-evidence');

  function updateStatus(state, label) {
    elHeaderDot.className = 'status-dot';
    if (state === 'healthy') {
      elHeaderDot.classList.add('healthy');
    } else if (state === 'error') {
      elHeaderDot.classList.add('error');
    }
    elHeaderStatus.textContent = label;
  }

  function renderInspector() {
    const isInfo = currentTab === '/api/info';
    const data = isInfo ? cachedInfo : cachedHealth;

    if (!data) {
      elTerminalContent.textContent = 'Awaiting data...';
      return;
    }

    elTerminalContent.textContent = JSON.stringify(data, null, 2);
    elTerminalTime.textContent = new Date().toLocaleTimeString();
  }

  async function fetchTelemetry() {
    const startTime = performance.now();
    updateStatus('pending', 'Polling pod...');

    try {
      const [infoRes, healthRes] = await Promise.all([
        fetch('/api/info', { cache: 'no-store' }),
        fetch('/healthz', { cache: 'no-store' })
      ]);

      const latencyMs = Math.round(performance.now() - startTime);
      elLatency.textContent = latencyMs;

      if (!infoRes.ok || !healthRes.ok) {
        throw new Error(`HTTP Error: info(${infoRes.status}), health(${healthRes.status})`);
      }

      cachedInfo = await infoRes.json();
      cachedHealth = await healthRes.json();

      // Render primary telemetry
      elVersion.textContent = cachedInfo.version || 'Unknown';
      labCurrentVersion.textContent = cachedInfo.version || 'Unknown';
      
      const commitSha = cachedInfo.commit || 'unknown';
      elCommit.textContent = commitSha.length > 7 ? commitSha.substring(0, 7) : commitSha;
      elCommit.title = commitSha;

      elEnv.textContent = cachedInfo.environment || 'Local';
      elRuntime.textContent = `Node.js ${cachedInfo.nodeVersion || 'v20'}`;

      // Update status indicators
      if (cachedHealth.status === 'ok') {
        updateStatus('healthy', 'Pod Healthy (HTTP 200)');
        elTerminalStatus.textContent = 'HTTP 200 OK';
      } else {
        updateStatus('error', 'Degraded Health');
        elTerminalStatus.textContent = 'Degraded';
      }

      renderInspector();

    } catch (err) {
      console.error('[Release Console] Telemetry fetch failure:', err);
      updateStatus('error', 'Endpoint Unreachable');
      elTerminalStatus.textContent = 'Connection Error';
      elTerminalContent.textContent = `Error connecting to backend: ${err.message}\nMake sure the Node.js application server or Kubernetes service is reachable.`;
      elLatency.textContent = '--';
    }
  }

  // Tab switching
  tabInfo.addEventListener('click', function () {
    currentTab = '/api/info';
    tabInfo.classList.add('active');
    tabInfo.setAttribute('aria-selected', 'true');
    tabHealth.classList.remove('active');
    tabHealth.setAttribute('aria-selected', 'false');
    renderInspector();
  });

  tabHealth.addEventListener('click', function () {
    currentTab = '/healthz';
    tabHealth.classList.add('active');
    tabHealth.setAttribute('aria-selected', 'true');
    tabInfo.classList.remove('active');
    tabInfo.setAttribute('aria-selected', 'false');
    renderInspector();
  });

  // Refresh trigger
  btnRefresh.addEventListener('click', function () {
    fetchTelemetry();
  });

  function renderLabResult(result) {
    labOutcomePanel.dataset.outcome = result.outcome;
    labOutcomeTitle.textContent = result.title;
    labOutcomeSummary.textContent = result.summary;
    labCurrentVersion.textContent = result.currentVersion || 'Unknown';
    labStageResults.replaceChildren();

    result.stages.forEach(function (stage) {
      const item = document.createElement('li');
      item.className = 'lab-stage-item';

      const status = document.createElement('span');
      status.className = `lab-stage-status status-${stage.status}`;
      status.textContent = stage.status.replace(/-/g, ' ').toUpperCase();

      const content = document.createElement('div');
      content.className = 'lab-stage-copy';
      const title = document.createElement('strong');
      title.textContent = stage.name;
      const detail = document.createElement('p');
      detail.textContent = stage.detail;
      content.append(title, detail);
      item.append(status, content);
      labStageResults.append(item);
    });

    labEvidence.textContent = JSON.stringify(result, null, 2);
  }

  async function evaluateReleaseScenario(button) {
    labScenarioButtons.forEach(function (candidate) { candidate.disabled = true; });
    labOutcomeTitle.textContent = 'Evaluating scenario...';
    labOutcomeSummary.textContent = 'The local evaluator is calculating the expected pipeline outcome.';
    labOutcomePanel.dataset.outcome = 'pending';

    try {
      const response = await fetch('/api/release-lab/evaluate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ scenario: button.dataset.scenario }),
        cache: 'no-store'
      });
      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.error || `HTTP ${response.status}`);
      }
      renderLabResult(result);
    } catch (error) {
      labOutcomePanel.dataset.outcome = 'error';
      labOutcomeTitle.textContent = 'Scenario evaluator unavailable';
      labOutcomeSummary.textContent = error.message;
      labStageResults.replaceChildren();
      labEvidence.textContent = String(error.message);
    } finally {
      labScenarioButtons.forEach(function (candidate) { candidate.disabled = false; });
    }
  }

  labScenarioButtons.forEach(function (button) {
    button.addEventListener('click', function () { evaluateReleaseScenario(button); });
  });

  // Initial fetch and 15-second polling interval
  fetchTelemetry();
  setInterval(fetchTelemetry, 15000);
})();
