/**
 * Release Console + DevOps Arena — Client Controller
 * Manages telemetry polling and the interactive DevOps quiz game.
 */

(function () {
  'use strict';

  // ─── Question Bank ────────────────────────────────────────────────────────
  const QUESTION_BANK = [
    // Docker — Beginner
    { id: 1, category: 'docker', difficulty: 'beginner', question: 'What is the default Docker network driver?', options: ['bridge', 'host', 'overlay', 'macvlan'], correct: 0, explanation: 'The default Docker network driver is "bridge". It creates a private internal network on the host so containers can communicate.' },
    { id: 2, category: 'docker', difficulty: 'beginner', question: 'Which Dockerfile instruction sets the base image?', options: ['RUN', 'FROM', 'COPY', 'CMD'], correct: 1, explanation: 'FROM initializes a new build stage and sets the base image for subsequent instructions.' },
    { id: 3, category: 'docker', difficulty: 'beginner', question: 'What command lists all running Docker containers?', options: ['docker images', 'docker ps', 'docker run', 'docker build'], correct: 1, explanation: '"docker ps" lists all currently running containers. Add -a flag to see stopped containers too.' },
    { id: 4, category: 'docker', difficulty: 'beginner', question: 'Which file tells Docker which files to exclude from the build context?', options: ['Dockerfile', '.gitignore', '.dockerignore', 'docker-compose.yml'], correct: 2, explanation: '.dockerignore excludes files and directories from being sent to the Docker daemon during build, reducing context size and build time.' },

    // Docker — Intermediate
    { id: 5, category: 'docker', difficulty: 'intermediate', question: 'What is the difference between CMD and ENTRYPOINT in a Dockerfile?', options: ['CMD cannot be overridden', 'ENTRYPOINT defines the executable, CMD provides default arguments', 'They are identical', 'CMD runs at build time'], correct: 1, explanation: 'ENTRYPOINT configures the container to run as an executable. CMD provides default arguments that can be overridden at runtime.' },
    { id: 6, category: 'docker', difficulty: 'intermediate', question: 'What does a multi-stage Docker build achieve?', options: ['Runs multiple containers simultaneously', 'Reduces final image size by discarding build dependencies', 'Deploys to multiple registries', 'Creates multiple networks'], correct: 1, explanation: 'Multi-stage builds use multiple FROM statements. Build tools and dependencies stay in earlier stages, keeping the final image lean.' },
    { id: 7, category: 'docker', difficulty: 'intermediate', question: 'Which command removes all stopped containers, unused networks, and dangling images?', options: ['docker clean', 'docker system prune', 'docker rm --all', 'docker gc'], correct: 1, explanation: '"docker system prune" removes all stopped containers, unused networks, dangling images, and optionally build cache.' },

    // Docker — Advanced
    { id: 8, category: 'docker', difficulty: 'advanced', question: 'In a Dockerfile, what does "COPY --from=builder" refer to?', options: ['Copying from the host machine', 'Copying from a previous build stage named "builder"', 'Copying from Docker Hub', 'Copying from a running container'], correct: 1, explanation: '--from=builder references a named build stage, enabling multi-stage builds where artifacts are selectively copied to the final image.' },
    { id: 9, category: 'docker', difficulty: 'advanced', question: 'What Linux kernel feature does Docker primarily use for process isolation?', options: ['SELinux', 'namespaces and cgroups', 'iptables', 'AppArmor'], correct: 1, explanation: 'Docker uses Linux namespaces for isolation (PID, network, mount, etc.) and cgroups for resource limiting (CPU, memory).' },
    { id: 10, category: 'docker', difficulty: 'advanced', question: 'What is Kaniko used for in a Kubernetes CI/CD pipeline?', options: ['Running unit tests', 'Building container images without a Docker daemon', 'Deploying Helm charts', 'Managing secrets'], correct: 1, explanation: 'Kaniko builds Docker images from a Dockerfile inside a container without requiring a privileged Docker daemon, making it secure for CI/CD in Kubernetes.' },

    // Kubernetes — Beginner
    { id: 11, category: 'kubernetes', difficulty: 'beginner', question: 'What is the smallest deployable unit in Kubernetes?', options: ['Container', 'Pod', 'Node', 'Deployment'], correct: 1, explanation: 'A Pod is the smallest deployable unit in Kubernetes. It can contain one or more containers that share network and storage.' },
    { id: 12, category: 'kubernetes', difficulty: 'beginner', question: 'What command applies a Kubernetes manifest file?', options: ['kubectl run', 'kubectl apply -f', 'kubectl create pod', 'kubectl deploy'], correct: 1, explanation: '"kubectl apply -f" applies a configuration from a YAML or JSON file to create or update resources declaratively.' },
    { id: 13, category: 'kubernetes', difficulty: 'beginner', question: 'What does a Kubernetes Service do?', options: ['Builds container images', 'Exposes pods to network traffic with a stable endpoint', 'Manages storage volumes', 'Scales nodes automatically'], correct: 1, explanation: 'A Service provides a stable network endpoint (IP and DNS) to access a set of Pods, even as Pods are created or destroyed.' },
    { id: 14, category: 'kubernetes', difficulty: 'beginner', question: 'What is Minikube?', options: ['A production Kubernetes cluster', 'A local single-node Kubernetes cluster for development', 'A Docker alternative', 'A cloud provider'], correct: 1, explanation: 'Minikube runs a single-node Kubernetes cluster locally for development and testing purposes.' },

    // Kubernetes — Intermediate
    { id: 15, category: 'kubernetes', difficulty: 'intermediate', question: 'What is a readiness probe used for?', options: ['Checking if a container should be restarted', 'Determining if a pod should receive traffic', 'Monitoring CPU usage', 'Logging container output'], correct: 1, explanation: 'Readiness probes determine if a Pod is ready to serve traffic. Failing probes remove the Pod from Service endpoints.' },
    { id: 16, category: 'kubernetes', difficulty: 'intermediate', question: 'What Kubernetes resource provides persistent storage to pods?', options: ['ConfigMap', 'Secret', 'PersistentVolumeClaim', 'Ingress'], correct: 2, explanation: 'A PersistentVolumeClaim (PVC) requests storage from a PersistentVolume, providing durable storage that survives pod restarts.' },
    { id: 17, category: 'kubernetes', difficulty: 'intermediate', question: 'What is the difference between a Deployment and a StatefulSet?', options: ['Deployments are newer', 'StatefulSets provide stable network identities and ordered deployment', 'Deployments support more replicas', 'There is no difference'], correct: 1, explanation: 'StatefulSets are for stateful applications needing stable pod names, ordered scaling, and persistent storage per pod.' },
    { id: 18, category: 'kubernetes', difficulty: 'intermediate', question: 'What does "kubectl rollout undo" do?', options: ['Deletes a deployment', 'Rolls back to the previous deployment revision', 'Pauses a rollout', 'Scales down replicas'], correct: 1, explanation: '"kubectl rollout undo" reverts a Deployment to its previous revision, restoring the prior pod template and configuration.' },

    // Kubernetes — Advanced
    { id: 19, category: 'kubernetes', difficulty: 'advanced', question: 'What happens when a liveness probe fails repeatedly?', options: ['Nothing, it is informational only', 'The Pod is removed from the Service', 'The kubelet restarts the container', 'The node is cordoned'], correct: 2, explanation: 'When a liveness probe fails beyond the failure threshold, the kubelet kills and restarts the container according to the pod restart policy.' },
    { id: 20, category: 'kubernetes', difficulty: 'advanced', question: 'What is the role of etcd in a Kubernetes cluster?', options: ['Container runtime', 'Distributed key-value store for cluster state', 'Network proxy', 'Log aggregator'], correct: 1, explanation: 'etcd is the consistent, distributed key-value store that Kubernetes uses to store all cluster configuration and state data.' },

    // Tekton — Beginner
    { id: 21, category: 'tekton', difficulty: 'beginner', question: 'What is a Tekton Task?', options: ['A running container', 'A reusable series of steps that run sequentially', 'A Kubernetes Service', 'A Docker image'], correct: 1, explanation: 'A Tekton Task defines a series of steps (containers) that execute sequentially to perform a specific CI/CD action.' },
    { id: 22, category: 'tekton', difficulty: 'beginner', question: 'What is a Tekton Pipeline?', options: ['A Docker network', 'An ordered collection of Tasks', 'A Kubernetes namespace', 'A Git webhook'], correct: 1, explanation: 'A Pipeline defines an ordered collection of Tasks that can run sequentially or in parallel to implement a CI/CD workflow.' },
    { id: 23, category: 'tekton', difficulty: 'beginner', question: 'What triggers the actual execution of a Tekton Pipeline?', options: ['kubectl apply pipeline.yaml', 'Creating a PipelineRun resource', 'Starting a Pod manually', 'Pushing to Git'], correct: 1, explanation: 'A PipelineRun creates a concrete execution of a Pipeline with specific parameter values and workspace bindings.' },

    // Tekton — Intermediate
    { id: 24, category: 'tekton', difficulty: 'intermediate', question: 'How do Tekton Tasks share files between steps?', options: ['Via environment variables', 'Through a shared workspace (PersistentVolumeClaim)', 'Using Docker volumes', 'Via network requests'], correct: 1, explanation: 'Workspaces backed by PVCs provide shared file storage that persists across steps and tasks within a PipelineRun.' },
    { id: 25, category: 'tekton', difficulty: 'intermediate', question: 'What happens when a Task fails in a Tekton Pipeline?', options: ['The Pipeline continues with the next Task', 'The PipelineRun is marked as Failed and subsequent Tasks are skipped', 'The Task is automatically retried', 'Nothing, failures are ignored'], correct: 1, explanation: 'By default, a Task failure causes the PipelineRun to fail immediately, and all dependent downstream Tasks are skipped.' },
    { id: 26, category: 'tekton', difficulty: 'intermediate', question: 'What is a Tekton Result?', options: ['A test report', 'A small piece of data produced by a Task that can be passed to subsequent Tasks', 'A logging endpoint', 'A metric dashboard'], correct: 1, explanation: 'Results allow Tasks to emit small string values (like a commit SHA) that can be consumed as parameters by later Tasks.' },

    // Tekton — Advanced
    { id: 27, category: 'tekton', difficulty: 'advanced', question: 'What RBAC resources does Tekton need to deploy to Kubernetes from within a Pipeline?', options: ['No special permissions needed', 'A ServiceAccount with a Role/ClusterRole binding granting deployment permissions', 'Root access to the node', 'Only a Docker Hub token'], correct: 1, explanation: 'Tekton runs as a ServiceAccount. To create/update Deployments, it needs a Role or ClusterRole with appropriate verbs bound via RoleBinding.' },
    { id: 28, category: 'tekton', difficulty: 'advanced', question: 'How does Tekton handle image registry authentication?', options: ['It uses Docker login on the host', 'Through Kubernetes Secrets annotated on the ServiceAccount', 'Via environment variables only', 'Authentication is not supported'], correct: 1, explanation: 'Tekton uses Kubernetes Secrets (type docker-registry) linked to the pipeline ServiceAccount for transparent registry authentication.' },

    // CI/CD — Beginner
    { id: 29, category: 'cicd', difficulty: 'beginner', question: 'What does CI stand for in CI/CD?', options: ['Container Integration', 'Continuous Integration', 'Code Inspection', 'Cloud Infrastructure'], correct: 1, explanation: 'Continuous Integration is the practice of frequently merging code changes into a shared repository and automatically testing them.' },
    { id: 30, category: 'cicd', difficulty: 'beginner', question: 'What is the purpose of a quality gate in a CI/CD pipeline?', options: ['To slow down deployment', 'To automatically block releases that fail predefined criteria', 'To manage database migrations', 'To send notifications'], correct: 1, explanation: 'Quality gates enforce standards by blocking pipeline progression when tests fail, vulnerabilities are found, or code quality degrades.' },
    { id: 31, category: 'cicd', difficulty: 'beginner', question: 'What does CD stand for?', options: ['Code Deployment', 'Continuous Delivery or Continuous Deployment', 'Container Distribution', 'Cloud Development'], correct: 1, explanation: 'CD can mean Continuous Delivery (automated release readiness) or Continuous Deployment (automated production release).' },

    // CI/CD — Intermediate
    { id: 32, category: 'cicd', difficulty: 'intermediate', question: 'What is a rolling deployment strategy?', options: ['Deploying to all servers at once', 'Gradually replacing old instances with new ones', 'Running two identical environments', 'Deploying only to staging'], correct: 1, explanation: 'Rolling deployments incrementally replace instances of the old version with the new version, ensuring zero-downtime updates.' },
    { id: 33, category: 'cicd', difficulty: 'intermediate', question: 'What is the purpose of running tests before building a container image?', options: ['To make the build faster', 'To fail fast and avoid wasting resources on a broken build', 'Tests must run before Docker is available', 'There is no benefit'], correct: 1, explanation: 'Running tests first ensures broken code never gets packaged into an image, saving compute time and preventing defective artifacts.' },
    { id: 34, category: 'cicd', difficulty: 'intermediate', question: 'What is artifact versioning in CI/CD?', options: ['Renaming files', 'Tagging build outputs with unique identifiers (version, commit SHA)', 'Compressing build output', 'Encrypting container images'], correct: 1, explanation: 'Artifact versioning tags each build output (images, packages) with identifiers like semantic versions or commit SHAs for traceability.' },

    // CI/CD — Advanced
    { id: 35, category: 'cicd', difficulty: 'advanced', question: 'What is the key difference between Continuous Delivery and Continuous Deployment?', options: ['They are the same thing', 'Delivery requires manual approval for production; Deployment is fully automated', 'Deployment only works with Docker', 'Delivery does not include testing'], correct: 1, explanation: 'Continuous Delivery automates up to a production-ready state with manual approval. Continuous Deployment automates the entire path to production.' },
    { id: 36, category: 'cicd', difficulty: 'advanced', question: 'Why is it important that CI/CD pipelines are idempotent?', options: ['To reduce costs', 'So running the same pipeline twice produces the same result without side effects', 'To speed up execution', 'It is not important'], correct: 1, explanation: 'Idempotent pipelines ensure reliability — re-running a pipeline does not create duplicates, corrupt state, or cause unintended side effects.' },

    // Git — Beginner
    { id: 37, category: 'git', difficulty: 'beginner', question: 'What does "git clone" do?', options: ['Creates a new branch', 'Copies a remote repository to your local machine', 'Deletes a repository', 'Merges two branches'], correct: 1, explanation: '"git clone" creates a local copy of a remote repository, including all branches, commits, and history.' },
    { id: 38, category: 'git', difficulty: 'beginner', question: 'What is a Git commit?', options: ['A branch name', 'A snapshot of changes saved to the repository history', 'A remote server', 'A merge conflict'], correct: 1, explanation: 'A commit is a snapshot of your staged changes saved to the repository with a unique SHA hash, author, and message.' },

    // Git — Intermediate
    { id: 39, category: 'git', difficulty: 'intermediate', question: 'What is the purpose of a Git webhook in CI/CD?', options: ['To protect branches', 'To automatically notify CI/CD systems when code is pushed', 'To encrypt repository data', 'To manage Git credentials'], correct: 1, explanation: 'Webhooks send HTTP POST payloads to CI/CD systems when events occur (push, PR), triggering automated pipelines.' },
    { id: 40, category: 'git', difficulty: 'intermediate', question: 'What is "git rebase" used for?', options: ['Deleting commits', 'Rewriting commit history by moving or combining commits onto a new base', 'Creating tags', 'Pushing to remote'], correct: 1, explanation: 'Rebase moves or combines commits onto a new base commit, creating a linear history without merge commits.' },

    // Git — Advanced
    { id: 41, category: 'git', difficulty: 'advanced', question: 'What does a commit SHA represent?', options: ['The author name', 'A SHA-1 hash uniquely identifying the commit content, tree, parent, and metadata', 'The branch name', 'The file size'], correct: 1, explanation: 'A commit SHA is a SHA-1 hash computed from the commit content, tree object, parent commit(s), author, and timestamp, ensuring integrity.' },
    { id: 42, category: 'git', difficulty: 'advanced', question: 'What is a Git sparse checkout?', options: ['A shallow clone', 'Checking out only a subset of files/directories from a repository', 'A type of merge strategy', 'An alias for git stash'], correct: 1, explanation: 'Sparse checkout allows working with only specific files or directories, reducing disk usage for large monorepos.' }
  ];

  const QUESTIONS_PER_GAME = 10;
  const TIME_PER_QUESTION = 30; // seconds
  const POINTS_BASE = 100;
  const POINTS_TIME_BONUS_MAX = 50;

  // ─── Session State ────────────────────────────────────────────────────────
  let sessionStats = { gamesPlayed: 0, bestScore: 0, totalCorrect: 0, totalAnswered: 0, currentStreak: 0 };
  let quizState = null; // { questions, currentIndex, score, answers[], startTime, questionStartTime, timerInterval }

  // ─── Telemetry DOM Elements ───────────────────────────────────────────────
  let currentTab = '/api/info';
  let cachedInfo = null;
  let cachedHealth = null;

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

  // ─── Arena DOM Elements ───────────────────────────────────────────────────
  const arenaRunningVersion = document.getElementById('arena-running-version');
  const arenaStatusBadge = document.getElementById('arena-status-badge');
  const arenaMainView = document.getElementById('arena-main-view');
  const arenaQuizView = document.getElementById('arena-quiz-view');
  const arenaResultsView = document.getElementById('arena-results-view');
  const arenaStartBtn = document.getElementById('arena-start-btn');
  const arenaRetryBtn = document.getElementById('arena-retry-btn');
  const arenaHomeBtn = document.getElementById('arena-home-btn');
  const arenaQuitBtn = document.getElementById('arena-quit-btn');
  const arenaNextBtn = document.getElementById('arena-next-btn');
  const arenaQCounter = document.getElementById('arena-q-counter');
  const arenaQCategory = document.getElementById('arena-q-category');
  const arenaQDifficulty = document.getElementById('arena-q-difficulty');
  const arenaTimerCircle = document.getElementById('arena-timer-circle');
  const arenaTimerText = document.getElementById('arena-timer-text');
  const arenaProgressFill = document.getElementById('arena-progress-fill');
  const arenaQuestionText = document.getElementById('arena-question-text');
  const arenaAnswersGrid = document.getElementById('arena-answers-grid');
  const arenaFeedbackBar = document.getElementById('arena-feedback-bar');
  const arenaFeedbackIcon = document.getElementById('arena-feedback-icon');
  const arenaFeedbackTitle = document.getElementById('arena-feedback-title');
  const arenaFeedbackExplanation = document.getElementById('arena-feedback-explanation');
  const arenaLiveScore = document.getElementById('arena-live-score');

  // Stats elements
  const statTotalPlayed = document.getElementById('stat-total-played');
  const statBestScore = document.getElementById('stat-best-score');
  const statAvgAccuracy = document.getElementById('stat-avg-accuracy');
  const statStreak = document.getElementById('stat-streak');

  // ─── Telemetry Functions (Preserved) ──────────────────────────────────────
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

      if (elVersion) elVersion.textContent = cachedInfo.version || 'Unknown';
      if (arenaRunningVersion) arenaRunningVersion.textContent = cachedInfo.version || 'Unknown';

      const commitSha = cachedInfo.commit || 'unknown';
      if (elCommit) {
        elCommit.textContent = commitSha.length > 7 ? commitSha.substring(0, 7) : commitSha;
        elCommit.title = commitSha;
      }

      if (elEnv) elEnv.textContent = cachedInfo.environment || 'Local';
      if (elRuntime) elRuntime.textContent = `Node.js ${cachedInfo.nodeVersion || 'v20'}`;

      if (cachedHealth.status === 'ok') {
        updateStatus('healthy', 'Pod Healthy (HTTP 200)');
        if (elTerminalStatus) elTerminalStatus.textContent = 'HTTP 200 OK';
      } else {
        updateStatus('error', 'Degraded Health');
        if (elTerminalStatus) elTerminalStatus.textContent = 'Degraded';
      }

      renderInspector();

    } catch (err) {
      console.error('[Release Console] Telemetry fetch failure:', err);
      updateStatus('error', 'Endpoint Unreachable');
      if (elTerminalStatus) elTerminalStatus.textContent = 'Connection Error';
      if (elTerminalContent) {
        elTerminalContent.textContent = `Error connecting to backend: ${err.message}\nMake sure the Node.js application server or Kubernetes service is reachable.`;
      }
      if (elLatency) elLatency.textContent = '--';
      if (arenaRunningVersion && (!arenaRunningVersion.textContent || arenaRunningVersion.textContent === '...')) {
        arenaRunningVersion.textContent = 'Unavailable';
      }
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

  btnRefresh.addEventListener('click', function () {
    fetchTelemetry();
  });

  // ─── Arena: Helpers ───────────────────────────────────────────────────────
  function showView(viewId) {
    [arenaMainView, arenaQuizView, arenaResultsView].forEach(function (v) {
      v.classList.add('arena-hidden');
    });
    document.getElementById(viewId).classList.remove('arena-hidden');
  }

  function getSelectedChip(groupId) {
    const group = document.getElementById(groupId);
    const active = group.querySelector('.arena-chip.active');
    return active ? (active.dataset.category || active.dataset.difficulty) : null;
  }

  function shuffleArray(arr) {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  function selectQuestions(category, difficulty) {
    let pool = QUESTION_BANK.slice();

    if (category && category !== 'all') {
      pool = pool.filter(function (q) { return q.category === category; });
    }
    if (difficulty && difficulty !== 'mixed') {
      pool = pool.filter(function (q) { return q.difficulty === difficulty; });
    }

    pool = shuffleArray(pool);
    return pool.slice(0, Math.min(QUESTIONS_PER_GAME, pool.length));
  }

  function updateSessionStatsDisplay() {
    if (statTotalPlayed) statTotalPlayed.textContent = sessionStats.gamesPlayed;
    if (statBestScore) statBestScore.textContent = sessionStats.bestScore;
    if (statAvgAccuracy) {
      const acc = sessionStats.totalAnswered > 0
        ? Math.round((sessionStats.totalCorrect / sessionStats.totalAnswered) * 100)
        : 0;
      statAvgAccuracy.textContent = acc + '%';
    }
    if (statStreak) statStreak.textContent = sessionStats.currentStreak;
  }

  // ─── Arena: Chip Selection ────────────────────────────────────────────────
  document.querySelectorAll('.arena-chip-group').forEach(function (group) {
    group.addEventListener('click', function (e) {
      const chip = e.target.closest('.arena-chip');
      if (!chip) return;

      group.querySelectorAll('.arena-chip').forEach(function (c) {
        c.classList.remove('active');
        c.setAttribute('aria-pressed', 'false');
      });
      chip.classList.add('active');
      chip.setAttribute('aria-pressed', 'true');
    });
  });

  // ─── Arena: Timer ─────────────────────────────────────────────────────────
  const TIMER_CIRCUMFERENCE = 2 * Math.PI * 20; // r=20

  function startTimer() {
    quizState.timeLeft = TIME_PER_QUESTION;
    quizState.questionStartTime = Date.now();
    arenaTimerText.textContent = TIME_PER_QUESTION;
    arenaTimerCircle.style.strokeDashoffset = '0';
    arenaTimerCircle.classList.remove('arena-timer-urgent');

    clearInterval(quizState.timerInterval);
    quizState.timerInterval = setInterval(function () {
      quizState.timeLeft--;
      if (quizState.timeLeft < 0) quizState.timeLeft = 0;

      arenaTimerText.textContent = quizState.timeLeft;
      const fraction = 1 - (quizState.timeLeft / TIME_PER_QUESTION);
      arenaTimerCircle.style.strokeDashoffset = (fraction * TIMER_CIRCUMFERENCE).toFixed(2);

      if (quizState.timeLeft <= 5) {
        arenaTimerCircle.classList.add('arena-timer-urgent');
      }

      if (quizState.timeLeft <= 0) {
        clearInterval(quizState.timerInterval);
        handleTimeout();
      }
    }, 1000);
  }

  function stopTimer() {
    if (quizState && quizState.timerInterval) {
      clearInterval(quizState.timerInterval);
    }
  }

  // ─── Arena: Render Question ───────────────────────────────────────────────
  function renderQuestion() {
    const q = quizState.questions[quizState.currentIndex];
    const total = quizState.questions.length;

    arenaQCounter.textContent = `Question ${quizState.currentIndex + 1} / ${total}`;
    arenaQCategory.textContent = q.category.charAt(0).toUpperCase() + q.category.slice(1);
    arenaQDifficulty.textContent = q.difficulty.charAt(0).toUpperCase() + q.difficulty.slice(1);
    arenaQDifficulty.dataset.level = q.difficulty;
    arenaProgressFill.style.width = ((quizState.currentIndex + 1) / total * 100) + '%';
    arenaQuestionText.textContent = q.question;
    arenaLiveScore.textContent = quizState.score;

    // Shuffle option order for display
    const optionIndices = q.options.map(function (_, i) { return i; });
    const shuffledIndices = shuffleArray(optionIndices);

    arenaAnswersGrid.innerHTML = '';
    const labels = ['A', 'B', 'C', 'D'];
    shuffledIndices.forEach(function (origIdx, displayIdx) {
      const btn = document.createElement('button');
      btn.className = 'arena-answer-btn';
      btn.type = 'button';
      btn.dataset.index = origIdx;
      btn.innerHTML = '<span class="arena-answer-label">' + labels[displayIdx] + '</span><span class="arena-answer-text">' + q.options[origIdx] + '</span>';
      btn.addEventListener('click', function () { handleAnswer(origIdx); });
      arenaAnswersGrid.appendChild(btn);
    });

    arenaFeedbackBar.classList.add('arena-hidden');
    arenaNextBtn.classList.add('arena-hidden');

    startTimer();
  }

  // ─── Arena: Handle Answer ─────────────────────────────────────────────────
  function handleAnswer(selectedIndex) {
    stopTimer();

    const q = quizState.questions[quizState.currentIndex];
    const timeTaken = Math.round((Date.now() - quizState.questionStartTime) / 1000);
    const isCorrect = selectedIndex === q.correct;

    // Disable all answer buttons
    const btns = arenaAnswersGrid.querySelectorAll('.arena-answer-btn');
    btns.forEach(function (btn) {
      btn.disabled = true;
      const idx = parseInt(btn.dataset.index, 10);
      if (idx === q.correct) {
        btn.classList.add('arena-answer-correct');
      } else if (idx === selectedIndex && !isCorrect) {
        btn.classList.add('arena-answer-wrong');
      }
    });

    // Score calculation
    let points = 0;
    if (isCorrect) {
      const timeBonus = Math.round(POINTS_TIME_BONUS_MAX * (quizState.timeLeft / TIME_PER_QUESTION));
      points = POINTS_BASE + timeBonus;
      quizState.score += points;
      sessionStats.currentStreak++;
    } else {
      sessionStats.currentStreak = 0;
    }

    // Record answer
    quizState.answers.push({
      questionId: q.id,
      question: q.question,
      selected: selectedIndex,
      correct: q.correct,
      isCorrect: isCorrect,
      points: points,
      timeTaken: timeTaken,
      explanation: q.explanation,
      options: q.options
    });

    // Show feedback
    arenaFeedbackBar.classList.remove('arena-hidden');
    arenaFeedbackBar.className = 'arena-feedback-bar ' + (isCorrect ? 'arena-feedback-correct' : 'arena-feedback-wrong');
    arenaFeedbackIcon.innerHTML = isCorrect
      ? '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>'
      : '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>';
    arenaFeedbackTitle.textContent = isCorrect ? `Correct! +${points} pts` : 'Incorrect';
    arenaFeedbackExplanation.textContent = q.explanation;

    arenaLiveScore.textContent = quizState.score;
    arenaNextBtn.classList.remove('arena-hidden');

    updateSessionStatsDisplay();
  }

  function handleTimeout() {
    const q = quizState.questions[quizState.currentIndex];

    const btns = arenaAnswersGrid.querySelectorAll('.arena-answer-btn');
    btns.forEach(function (btn) {
      btn.disabled = true;
      const idx = parseInt(btn.dataset.index, 10);
      if (idx === q.correct) {
        btn.classList.add('arena-answer-correct');
      }
    });

    sessionStats.currentStreak = 0;

    quizState.answers.push({
      questionId: q.id,
      question: q.question,
      selected: -1,
      correct: q.correct,
      isCorrect: false,
      points: 0,
      timeTaken: TIME_PER_QUESTION,
      explanation: q.explanation,
      options: q.options
    });

    arenaFeedbackBar.classList.remove('arena-hidden');
    arenaFeedbackBar.className = 'arena-feedback-bar arena-feedback-timeout';
    arenaFeedbackIcon.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>';
    arenaFeedbackTitle.textContent = 'Time\'s up!';
    arenaFeedbackExplanation.textContent = q.explanation;

    arenaNextBtn.classList.remove('arena-hidden');
    updateSessionStatsDisplay();
  }

  // ─── Arena: Next Question / Results ───────────────────────────────────────
  function goNext() {
    quizState.currentIndex++;
    if (quizState.currentIndex >= quizState.questions.length) {
      showResults();
    } else {
      renderQuestion();
    }
  }

  function showResults() {
    stopTimer();
    showView('arena-results-view');

    const total = quizState.questions.length;
    const correct = quizState.answers.filter(function (a) { return a.isCorrect; }).length;
    const accuracy = total > 0 ? Math.round((correct / total) * 100) : 0;
    const totalTime = quizState.answers.reduce(function (s, a) { return s + a.timeTaken; }, 0);
    const avgTime = total > 0 ? Math.round(totalTime / total) : 0;

    // Update session stats
    sessionStats.gamesPlayed++;
    sessionStats.totalCorrect += correct;
    sessionStats.totalAnswered += total;
    if (quizState.score > sessionStats.bestScore) {
      sessionStats.bestScore = quizState.score;
    }

    // Grade
    let grade, title;
    if (accuracy >= 90) { grade = 'A+'; title = 'Outstanding!'; }
    else if (accuracy >= 80) { grade = 'A'; title = 'Excellent!'; }
    else if (accuracy >= 70) { grade = 'B'; title = 'Great Job!'; }
    else if (accuracy >= 60) { grade = 'C'; title = 'Good Effort!'; }
    else if (accuracy >= 50) { grade = 'D'; title = 'Keep Practicing!'; }
    else { grade = 'F'; title = 'Study More!'; }

    const resultsGrade = document.getElementById('arena-results-grade');
    const resultsTitle = document.getElementById('arena-results-title');
    const resultsSubtitle = document.getElementById('arena-results-subtitle');
    const resultScore = document.getElementById('result-score');
    const resultCorrect = document.getElementById('result-correct');
    const resultAccuracy = document.getElementById('result-accuracy');
    const resultTime = document.getElementById('result-time');
    const reviewList = document.getElementById('arena-review-list');

    const heroEl = document.getElementById('arena-results-hero');
    heroEl.className = 'arena-results-hero';
    if (accuracy >= 80) heroEl.classList.add('arena-hero-excellent');
    else if (accuracy >= 50) heroEl.classList.add('arena-hero-good');
    else heroEl.classList.add('arena-hero-poor');

    resultsGrade.textContent = grade;
    resultsTitle.textContent = title;
    resultsSubtitle.textContent = `You scored ${correct}/${total}`;
    resultScore.textContent = quizState.score;
    resultCorrect.textContent = `${correct}/${total}`;
    resultAccuracy.textContent = accuracy + '%';
    resultTime.textContent = avgTime + 's';

    // Build review list
    reviewList.innerHTML = '';
    quizState.answers.forEach(function (answer, i) {
      const li = document.createElement('li');
      li.className = 'arena-review-item ' + (answer.isCorrect ? 'arena-review-correct' : 'arena-review-wrong');

      const statusIcon = answer.isCorrect
        ? '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>'
        : '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>';

      let answerDetail = '';
      if (answer.selected === -1) {
        answerDetail = '<span class="arena-review-answer">Timed out</span>';
      } else if (!answer.isCorrect) {
        answerDetail = '<span class="arena-review-answer">Your answer: ' + answer.options[answer.selected] + '</span>';
      }

      li.innerHTML =
        '<div class="arena-review-status">' + statusIcon + '</div>' +
        '<div class="arena-review-content">' +
          '<strong class="arena-review-q">' + (i + 1) + '. ' + answer.question + '</strong>' +
          answerDetail +
          '<span class="arena-review-correct-answer">Correct: ' + answer.options[answer.correct] + '</span>' +
          '<p class="arena-review-explanation">' + answer.explanation + '</p>' +
          '<span class="arena-review-meta">+' + answer.points + ' pts &middot; ' + answer.timeTaken + 's</span>' +
        '</div>';
      reviewList.appendChild(li);
    });

    updateSessionStatsDisplay();
  }

  // ─── Arena: Start Quiz ────────────────────────────────────────────────────
  function startQuiz() {
    const category = getSelectedChip('arena-category-group');
    const difficulty = getSelectedChip('arena-difficulty-group');
    const questions = selectQuestions(category, difficulty);

    if (questions.length === 0) {
      arenaStatusBadge.textContent = 'NO QUESTIONS';
      arenaStatusBadge.className = 'arena-badge arena-badge-warn';
      setTimeout(function () {
        arenaStatusBadge.textContent = 'READY';
        arenaStatusBadge.className = 'arena-badge arena-badge-live';
      }, 2000);
      return;
    }

    quizState = {
      questions: questions,
      currentIndex: 0,
      score: 0,
      answers: [],
      startTime: Date.now(),
      questionStartTime: Date.now(),
      timerInterval: null,
      timeLeft: TIME_PER_QUESTION
    };

    arenaStatusBadge.textContent = 'IN PROGRESS';
    arenaStatusBadge.className = 'arena-badge arena-badge-active';

    showView('arena-quiz-view');
    renderQuestion();
  }

  function quitQuiz() {
    stopTimer();
    arenaStatusBadge.textContent = 'READY';
    arenaStatusBadge.className = 'arena-badge arena-badge-live';
    showView('arena-main-view');
    updateSessionStatsDisplay();
  }

  // ─── Arena: Event Listeners ───────────────────────────────────────────────
  arenaStartBtn.addEventListener('click', startQuiz);
  arenaRetryBtn.addEventListener('click', startQuiz);
  arenaHomeBtn.addEventListener('click', function () {
    arenaStatusBadge.textContent = 'READY';
    arenaStatusBadge.className = 'arena-badge arena-badge-live';
    showView('arena-main-view');
    updateSessionStatsDisplay();
  });
  arenaQuitBtn.addEventListener('click', quitQuiz);
  arenaNextBtn.addEventListener('click', goNext);

  // ─── Boot ─────────────────────────────────────────────────────────────────
  fetchTelemetry();
  setInterval(fetchTelemetry, 15000);
  updateSessionStatsDisplay();
})();
