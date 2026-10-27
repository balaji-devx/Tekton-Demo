# Project Codebase Dump: Tekton-Demo

> Auto-generated from `E:\SEM 3\DEVOPS\Tekton-Demo`

> Total Files: **24**

---

## Table of Contents

| # | File Path | Language | Lines | Size (Bytes) |
|---|-----------|----------|-------|--------------|
| 1 | [.dockerignore](#dockerignore) | `dockerfile` | 27 | 322 |
| 2 | [.gitignore](#gitignore) | `gitignore` | 28 | 321 |
| 3 | [Dockerfile](#dockerfile) | `dockerfile` | 38 | 1,009 |
| 4 | [README.md](#readmemd) | `markdown` | 551 | 28,817 |
| 5 | [k8s/deployment.yaml](#k8sdeploymentyaml) | `yaml` | 65 | 1,661 |
| 6 | [k8s/service.yaml](#k8sserviceyaml) | `yaml` | 17 | 295 |
| 7 | [package-lock.json](#packagelockjson) | `json` | 16 | 272 |
| 8 | [package.json](#packagejson) | `json` | 23 | 502 |
| 9 | [public/app.js](#publicappjs) | `javascript` | 224 | 8,702 |
| 10 | [public/index.html](#publicindexhtml) | `html` | 250 | 12,685 |
| 11 | [public/styles.css](#publicstylescss) | `css` | 741 | 15,147 |
| 12 | [run.txt](#runtxt) | `text` | 88 | 2,928 |
| 13 | [scripts/check-prerequisites.ps1](#scriptscheckprerequisitesps1) | `powershell` | 130 | 5,501 |
| 14 | [scripts/run-pipeline.ps1](#scriptsrunpipelineps1) | `powershell` | 145 | 6,504 |
| 15 | [scripts/setup-registry-secret.ps1](#scriptssetupregistrysecretps1) | `powershell` | 130 | 5,266 |
| 16 | [scripts/validate-project.ps1](#scriptsvalidateprojectps1) | `powershell` | 153 | 5,262 |
| 17 | [scripts/verify-deployment.ps1](#scriptsverifydeploymentps1) | `powershell` | 163 | 7,668 |
| 18 | [src/index.js](#srcindexjs) | `javascript` | 291 | 10,614 |
| 19 | [tekton/pipeline.yaml](#tektonpipelineyaml) | `yaml` | 98 | 3,193 |
| 20 | [tekton/pipelinerun-template.yaml](#tektonpipelineruntemplateyaml) | `yaml` | 35 | 812 |
| 21 | [tekton/pvc.yaml](#tektonpvcyaml) | `yaml` | 15 | 282 |
| 22 | [tekton/rbac.yaml](#tektonrbacyaml) | `yaml` | 42 | 1,138 |
| 23 | [tekton/tasks.yaml](#tektontasksyaml) | `yaml` | 245 | 9,513 |
| 24 | [test/app.test.js](#testapptestjs) | `javascript` | 233 | 10,186 |

---

## 1. `.dockerignore`

**Path:** `.dockerignore`  
**Language:** `dockerfile`

```dockerfile
# Git
.git
.gitignore

# Dependencies & Build artifacts
node_modules
npm-debug.log*

# Test files & configurations
test/
coverage/

# Kubernetes & Tekton manifests (not needed inside app container)
k8s/
tekton/
scripts/

# Documentation
README.md
docs/

# System and editor files
.DS_Store
Thumbs.db
.vscode/
.idea/
*.swp

```

---

## 2. `.gitignore`

**Path:** `.gitignore`  
**Language:** `gitignore`

```gitignore
# Node dependencies
node_modules/
package-lock.json.backup

# Testing & Coverage
coverage/
.nyc_output/

# Logs
logs/
*.log
npm-debug.log*

# Environment and Credentials (never commit secrets)
.env
.env.*
dockerhub-auth.json
*.key
*.token

# OS and Editor
.DS_Store
Thumbs.db
.vscode/
.idea/
*.swp
*.patch
powershell.cmd

```

---

## 3. `Dockerfile`

**Path:** `Dockerfile`  
**Language:** `dockerfile`

```dockerfile
# Build stage & production container for Release Console
FROM node:20-alpine

# Set dedicated working directory
WORKDIR /app

# Ensure non-root ownership of app directory
RUN chown -R node:node /app

# Accept build arguments for release versioning
ARG APP_VERSION=dev-local
ARG GIT_COMMIT=local-dev-commit

# Set production environment variables
ENV NODE_ENV=production \
    PORT=3000 \
    DEPLOY_ENV=minikube-local \
    APP_VERSION=${APP_VERSION} \
    GIT_COMMIT=${GIT_COMMIT}

# Copy package manifests first for efficient layer caching
COPY --chown=node:node package.json package-lock.json ./

# Install production dependencies reproducibly
RUN npm ci --only=production --ignore-scripts && npm cache clean --force

# Copy application source code and public assets
COPY --chown=node:node src/ ./src/
COPY --chown=node:node public/ ./public/

# Switch to non-root user for security compliance
USER node

# Expose internal application port
EXPOSE 3000

# Container entry point
CMD ["node", "src/index.js"]

```

---

## 4. `README.md`

**Path:** `README.md`  
**Language:** `markdown`

````markdown
# Design and Implementation of a Non-Cloud CI/CD Pipeline Using Tekton, Docker and Kubernetes

## 1. Project Title and Objective

**Title:** Design and Implementation of a Non-Cloud CI/CD Pipeline Using Tekton, Docker and Kubernetes  
**Project Application:** Release Console  
**Domain:** DevOps, Cloud-Native Engineering, Container Orchestration  

The primary objective of this project is to design, implement, and demonstrate a local Kubernetes-native Continuous Integration and Continuous Deployment (CI/CD) pipeline running on **Minikube** without relying on managed cloud compute infrastructure (e.g., AWS, GCP, Azure). GitHub and Docker Hub remain external hosted services. The current pipeline is started manually; GitHub push webhooks are not configured.

Using **Tekton Pipelines**, **Docker**, and **Kubernetes**, this project automates the entire software delivery lifecycle:
1. Cloning source code from a public Git repository after a manually triggered PipelineRun (GitHub push webhooks are not configured in this implementation).
2. Executing automated unit test suites within containerised quality gates.
3. Building a container image in-cluster using the daemonless **Kaniko** container builder.
4. Publishing the versioned image to **Docker Hub**.
5. Performing an automated rolling deployment to the local Kubernetes cluster.
6. Validating operational health and telemetry through a live application: **Release Console**.

---

## 2. The Problem Being Addressed

Modern DevOps coursework and enterprise systems frequently rely on proprietary managed cloud services (such as AWS CodePipeline, GitHub Actions hosted runners, or Google Cloud Build). While powerful, these approaches introduce critical challenges:
- **Cloud Dependency & Cost:** Substantial ongoing recurring costs for cloud compute, managed Kubernetes clusters (EKS/GKE), and external network ingress/egress.
- **Opacity of In-Cluster Execution:** Developers treat CI/CD as an external "black box" without understanding Kubernetes-native primitives, controllers, or Custom Resource Definitions (CRDs).
- **Resource Constraints on Local Machines:** Running heavy enterprise toolchains (Jenkins, GitLab CI, heavy databases) on developer laptops with ~8 GB RAM frequently results in system thrashing and crashes.

**Solution:** This project demonstrates that a fully standard, Kubernetes-native CI/CD architecture can be executed locally on a single developer workstation using open standards (Tekton, OCI containers, native Node.js), keeping memory utilization under 3 GB while providing enterprise-grade gating, versioning, and zero-downtime rolling updates.

---

## 3. Explanation of CI, CD and the Role of Tekton

| Concept | Definition & Project Implementation |
| :--- | :--- |
| **Continuous Integration (CI)** | The automated practice of validating software changes as soon as they are committed. In this project, Tekton checks out source code into an ephemeral workspace, triggers clean dependency installation (`npm ci`), and runs `node:test` unit tests. If any test fails, CI halts immediately. |
| **Continuous Deployment (CD)** | The automated mechanism by which tested code is packaged into an immutable container artifact, published to a registry, and rolled out to Kubernetes. Tekton invokes Kaniko to build the OCI container, tags it semantically (`v1`, `v2`), pushes it to Docker Hub, and applies rolling updates to the cluster. |
| **Tekton Pipelines** | A Cloud Native Computing Foundation (CNCF) open-source framework for creating cloud-native CI/CD systems on top of Kubernetes. Unlike traditional CI servers that run as external VMs, Tekton runs natively as Kubernetes Custom Resource Definitions (CRDs). Each Task executes in its own isolated Kubernetes Pod, utilizing Kubernetes scheduling, RBAC, and storage primitives. |

---

## 4. System Architecture

The following diagram illustrates the architecture and separation of concerns:

```
[ Developer Workstation ]
        │
        ▼ (git push)
[ GitHub Repository ] (External Source Control)
        │
        │ (Cloned via alpine/git)
        ▼
╔═══════════════════════════════════════════════════════════════════╗
║            LOCAL KUBERNETES CLUSTER (Minikube on Docker)          ║
║                                                                   ║
║  ┌─────────────────────────────────────────────────────────────┐  ║
║  │                  Tekton Pipeline Engine                     │  ║
║  │                                                             │  ║
║  │  [Task 1: clone-source] ───► Captures Git Commit SHA        │  ║
║  │            │                                                │  ║
║  │            ▼                                                │  ║
║  │  [Task 2: test-application] ──► Automated Quality Gate      │  ║
║  │            │                    (Blocks pipeline on error)  │  ║
║  │            ▼                                                │  ║
║  │  [Task 3: build-and-push]   ──► Kaniko In-Cluster Build     │  ║
║  │            │                    (Uses dockerhub-auth secret)│  ║
║  │            ▼                                                │  ║
║  │  [Task 4: deploy-app]       ──► Rollout & Status Verify     │  ║
║  └─────────────────────────────────────────────────────────────┘  ║
║            │                                                      ║
║            │ Shared Workspace PVC (release-console-pvc)           ║
║            ▼                                                      ║
║  ┌─────────────────────────────────────────────────────────────┐  ║
║  │                Application Runtime                          │  ║
║  │                                                             │  ║
║  │   Deployment: release-console (1 Pod, Port 3000)            │  ║
║  │   Service: release-console-service (NodePort 30080)         │  ║
║  │   Health Probe: /healthz | Telemetry: /api/info             │  ║
║  └─────────────────────────────────────────────────────────────┘  ║
╚═══════════════════════════════════════════════════════════════════╝
        ▲                                │
        │ (Kubernetes Secret Auth)       │ (Docker Image Push)
        │                                ▼
[ Docker Hub Container Registry ] (External OCI Registry)
```

---

## 5. Complete Workflow Step-by-Step

```
1. Developer edits code & pushes to GitHub
         │
         ▼
2. Launch PipelineRun (`run-pipeline.ps1`)
         │
         ▼
3. Task: clone-source
   └── Clones repo into shared PVC Workspace
   └── Emits commit SHA as result
         │
         ▼
4. Task: test-application
   └── Runs `npm ci` and `node --test test/app.test.js`
   └── [Gate]: If tests FAIL ──► PIPELINE HALTS (No build or deployment)
   └── If tests PASS ──────────► Proceed to build
         │
         ▼
5. Task: build-and-push-image
   └── Kaniko executor builds Dockerfile inside Pod
   └── Injects APP_VERSION and GIT_COMMIT build arguments
   └── Authenticates via `dockerhub-auth` Secret
   └── Pushes `username/release-console:<tag>` to Docker Hub
         │
         ▼
6. Task: deploy-application
   └── Updates Kubernetes Deployment manifest with new image tag
   └── Applies Deployment and NodePort Service
   └── Executes `kubectl rollout status` (waits for pod readiness)
         │
         ▼
7. Verification & Health Monitoring
   └── Developer runs `verify-deployment.ps1`
   └── Browser visits `http://<minikube-ip>:30080`
   └── Release Console UI displays live running version, commit SHA, and health state
```

---

## 6. Technology Stack and Responsibilities

| Technology | Version | Role in Architecture |
| :--- | :--- | :--- |
| **Node.js** | 20.x (Alpine) | Application runtime and HTTP server built exclusively with native modules (`node:http`, `node:fs`, `node:path`). |
| **Node Test Runner** | Native `node:test` | Automated unit testing framework executed during the CI quality gate without external npm dependencies. |
| **HTML5 / CSS3 / JS** | Vanilla standards | Frontend for **Release Console** using an intentional dark aesthetic without heavy frontend frameworks. |
| **Git & GitHub** | Git 2.50+ | Distributed version control and remote source repository for Tekton clones. |
| **Docker Engine** | 29.6+ | Container runtime backing Minikube through the `desktop-linux` context. |
| **Docker Hub** | OCI Registry | Remote public container registry storing versioned application images. |
| **Minikube** | 1.39+ | Local Kubernetes cluster running on Windows 10 with Docker driver. |
| **Kubernetes (kubectl)** | v1.36+ / v1.37+ | Container orchestrator managing Deployment, Service, PVC, RBAC, and Secrets. |
| **Tekton Pipelines** | v1 API | Kubernetes-native CI/CD controller and CRDs executing pipeline workflows. |
| **Kaniko** | `v1.28.6` (martizih) | Maintained in-cluster container builder compiling Dockerfiles daemonless without host socket mounts. |
| **PowerShell** | 5.1+ / 7.x | Automation scripts for prerequisite checks, secret setup, and deployment validation. |

---

## 7. Project Structure

```
release-console-tekton/
│
├── src/
│   └── index.js                   # Application server (native HTTP, static files, health API)
│
├── public/
│   ├── index.html                 # Semantic HTML5 UI for Release Console
│   ├── styles.css                 # Dark, restrained stylesheet (strictly no pills or fake charts)
│   └── app.js                     # Client-side telemetry polling and terminal inspector
│
├── test/
│   └── app.test.js                # 8 comprehensive automated unit tests using node:test
│
├── k8s/
│   ├── deployment.yaml            # Kubernetes Deployment (1 replica, probes, securityContext)
│   └── service.yaml               # Kubernetes NodePort Service (Port 3000 -> NodePort 30080)
│
├── tekton/
│   ├── pvc.yaml                   # PersistentVolumeClaim (500Mi) for shared pipeline workspace
│   ├── rbac.yaml                  # Least-privilege ServiceAccount, Role, and RoleBinding
│   ├── tasks.yaml                 # 4 Tekton Tasks (clone, test, build/push, deploy)
│   ├── pipeline.yaml              # Sequential Pipeline linking tasks with quality gates
│   └── pipelinerun-template.yaml  # PipelineRun invocation template
│
├── scripts/
│   ├── check-prerequisites.ps1    # Non-destructive environment and tool audit
│   ├── setup-registry-secret.ps1  # Secure Docker Hub credentials configuration
│   ├── validate-project.ps1       # Local syntax validation and unit test execution
│   ├── run-pipeline.ps1           # PipelineRun generator and execution trigger
│   └── verify-deployment.ps1      # Post-deployment rollout and live HTTP verification
│
├── package.json                   # Project manifest (test & start scripts)
├── package-lock.json              # Deterministic dependency lockfile
├── Dockerfile                     # Multi-stage production container build (non-root)
├── .dockerignore                  # Build context exclusions
├── .gitignore                     # Git tracking exclusions
└── README.md                      # Comprehensive project documentation
```

---

## 8. Prerequisites

To execute this project, your Windows workstation must have:
- **Windows 10/11 Pro or Enterprise** (Build 22H2 recommended).
- **Physical Memory:** Minimum 8 GB RAM (Minikube uses 3 GB).
- **Docker Desktop:** Running and configured with the `desktop-linux` context.
- **Git for Windows:** Installed and accessible via PowerShell.
- **Minikube & kubectl:** Installed and in your system `%PATH%`.
- **A Docker Hub Account:** Free personal account at [hub.docker.com](https://hub.docker.com/).
- **A GitHub Account:** For hosting your repository fork/copy publicly.

---

## 9. Environment-Specific Information (Windows, Docker Desktop, Minikube)

Your existing environment parameters:
- **Cluster driver:** Docker (`minikube start --driver=docker`)
- **Resource Allocation:** 2 CPUs, 3072 MB RAM, 20 GB disk
- **Active kubectl context:** `minikube`
- **Kubernetes Node status:** Ready
- **Tekton Pipelines controller, webhook & events controller:** Verified as Running in `tekton-pipelines` namespace.

> [!IMPORTANT]
> The scripts and manifests in this project are strictly designed to run within your existing cluster without resetting Minikube or reinstalling Tekton.

---

## 10. Docker Hub Repository Preparation

1. Log into your account at [hub.docker.com](https://hub.docker.com/).
2. Click **Create Repository**.
3. Set the Repository Name to: `release-console`.
4. Set the Visibility to **Public**.
   - *Why Public?* Keeping the demonstration repository public allows Minikube's kubelet to pull the newly built image cleanly on any node without needing cluster-wide image pull credentials.
5. Generate a **Personal Access Token (PAT)**:
   - Navigate to **Account Settings** -> **Security** -> **New Access Token**.
   - Token Description: `tekton-local-pipeline`.
   - Access Permissions: **Read & Write**.
   - Copy the generated token for use in the setup script.

---

## 11. GitHub Repository Setup and Push Commands

Because Tekton's `clone-source` task clones from source control, create a public GitHub repository for your project:

1. Create a new public repository on GitHub named `Tekton-Demo` (or `release-console`).
2. Run the following commands in Windows PowerShell from the project root:

```powershell
# Navigate to the workspace root
cd "e:\SEM 3\DEVOPS\Tekton-Demo"

# Initialize local git repository (if not already initialized)
git init -b main

# Stage all files
git add .

# Create the initial commit
git commit -m "feat: initial commit of Release Console and Tekton CI/CD pipeline"

# Add your GitHub repository remote (replace with your actual username/repo)
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/Tekton-Demo.git

# Push main branch to GitHub
git push -u origin main
```

When you make modifications to the application later (such as during version updates or failure testing), commit and push them with:
```powershell
git add .
git commit -m "chore: release update v2"
git push origin main
```

---

## 12. Registry Secret Setup

Run the provided secure PowerShell script to configure your credentials inside Kubernetes:

```powershell
.\scripts\setup-registry-secret.ps1
```

**How it works:**
- It prompts for your Docker Hub username.
- It prompts for your Docker Hub Access Token securely (`Read-Host -AsSecureString`), ensuring the token is never displayed or echoed.
- It creates a standard Docker authentication JSON payload in memory.
- It applies a Kubernetes Secret named `dockerhub-auth` in namespace `default` containing both `config.json` (used by Kaniko) and `.dockerconfigjson` (standard Kubernetes).
- It removes any temporary files immediately upon completion.

---

## 13. Deep Dive: Tekton Tasks, Pipeline, Workspaces, and Kaniko

### PersistentVolumeClaim Workspace (`tekton/pvc.yaml`)
A single `500Mi` volume (`release-console-pvc`) is provisioned using Minikube's `standard` StorageClass. This shared volume persists across sequential Tasks in a PipelineRun, allowing `clone-source` to write the files that `test-application`, `build-and-push-image`, and `deploy-application` subsequently access.

### Tekton Tasks (`tekton/tasks.yaml`)
1. **`clone-source`**:
   - Runs `alpine/git:v2.45.2`.
   - Clones the target GitHub repository into `$(workspaces.source.path)/release-console`.
   - Runs `git rev-parse HEAD` and writes the resulting commit SHA to `$(results.commit.path)`.
2. **`test-application`**:
   - Runs `node:20-alpine`.
   - Navigates into the workspace and executes `npm ci` followed by `npm test`.
   - Emits structured execution logs. Halts with exit code 1 if any test fails.
3. **`build-and-push-image` (Kaniko)**:
   - Runs `martizih/kaniko:v1.28.6` (maintained community fork by mzihlmann/osscontainertools).
   - Drop-in continuation of Kaniko supporting up-to-date dependencies and vulnerability patches for daemonless in-cluster builds without requiring Docker daemon privileges.
   - Mounts the `dockerhub-auth` secret at `/kaniko/.docker` to read credentials.
   - Compiles the Dockerfile using the shared workspace context and pushes `docker.io/<username>/release-console:<tag>` to Docker Hub.
4. **`deploy-application`**:
   - Runs `alpine/k8s:1.37.0` (Kubernetes v1.37 compatible toolbox containing `sh`, `sed`, and `kubectl`).
   - Templates `k8s/deployment.yaml` with the exact image tag and Git commit SHA.
   - Applies the Deployment and Service manifests.
   - Executes `kubectl rollout status deployment/release-console --timeout=120s` to block until the new pod is healthy.

### Pipeline Sequencing (`tekton/pipeline.yaml`)
The pipeline enforces sequential execution using `runAfter`:
- `run-tests` specifies `runAfter: [fetch-source]`
- `build-push` specifies `runAfter: [run-tests]`
- `deploy` specifies `runAfter: [build-push]`

---

## 14. How the Dockerfile Builds the Container

The application's `Dockerfile` follows enterprise containerisation best practices:
- **Base Image:** `node:20-alpine` (ultra-lightweight footprint, ~50 MB).
- **Layer Caching:** Copies `package.json` and `package-lock.json` first, executing `npm ci --only=production` before copying source code.
- **Build Arguments:** Accepts `APP_VERSION` and `GIT_COMMIT` dynamically from Kaniko, setting them as runtime environment variables.
- **Security:** Switches to the unprivileged built-in `node` user (`USER node`, UID 1000) to prevent container escape vulnerabilities.
- **Port:** Exposes internal HTTP port 3000.

---

## 15. Kubernetes Deployment and NodePort Service

- **Deployment (`k8s/deployment.yaml`):**
  - Replicas: 1
  - Resource Requests: 50m CPU, 64Mi Memory (extremely lightweight for laptop).
  - Resource Limits: 200m CPU, 128Mi Memory.
  - Health Probes: HTTP probes on `/healthz` for both liveness (period 10s) and readiness (period 5s).
  - Security Context: `runAsNonRoot: true`, `runAsUser: 1000`.
- **Service (`k8s/service.yaml`):**
  - Type: `NodePort`
  - Targets container port 3000.
  - Exposes fixed **NodePort 30080** on the Minikube cluster IP.

---

## 16. How to Launch the Complete Pipeline

Run the automated orchestrator script:

```powershell
.\scripts\run-pipeline.ps1 `
  -RepoUrl "https://github.com/YOUR_GITHUB_USERNAME/Tekton-Demo.git" `
  -DockerHubUsername "YOUR_DOCKERHUB_USERNAME" `
  -ImageTag "v1"
```

The script will:
1. Verify the current kubectl context is `minikube`.
2. Ensure the `dockerhub-auth` secret exists.
3. Declaratively apply `tekton/pvc.yaml`, `tekton/rbac.yaml`, `tekton/tasks.yaml`, and `tekton/pipeline.yaml`.
4. Generate a timestamped PipelineRun manifest (e.g. `release-console-run-v1-20261025-183000`).
5. Submit the PipelineRun to Kubernetes.

---

## 17. How to Monitor TaskRuns and PipelineRuns

Inspect the status of your running pipeline:

```powershell
# 1. Check all PipelineRuns and their overall status:
kubectl get pipelinerun

# 2. Check the individual TaskRuns created by the PipelineRun:
kubectl get taskruns -l tekton.dev/pipelineRun=YOUR_PIPELINERUN_NAME

# 3. Locate the active Task Pods:
kubectl get pods -l tekton.dev/pipelineRun=YOUR_PIPELINERUN_NAME

# 4. Stream live logs from a specific Task Pod:
kubectl logs -f <pod-name> --all-containers
```

---

## 18. How to Inspect Test Logs

To inspect the automated test output during or after a run:
1. Identify the pod running the `test-application` Task:
   ```powershell
   kubectl get pods -l tekton.dev/task=test-application
   ```
2. View the container log:
   ```powershell
   kubectl logs <test-task-pod-name> -c step-run-unit-tests
   ```
You will see the output of `node:test` showing all 8 tests passing with execution timings.

---

## 19. How to Verify the Deployed Application

Once the deployment completes, verify the running application:

```powershell
.\scripts\verify-deployment.ps1 -ExpectedTag "v1"
```

The script displays:
- Rollout completion confirmation.
- Active Pod details.
- Active container image reference (`.../release-console:v1`).
- Direct HTTP probe of `/healthz` (status 200).
- Direct HTTP probe of `/api/info` (showing live version and commit SHA).

### Accessing the Web Application UI
Open the application in your web browser:
```
http://<MINIKUBE_IP>:30080
```
*(Run `minikube ip` to obtain your cluster IP, typically `192.168.49.2`).*

> [!TIP]
> **Windows Port Forwarding Fallback:** If your Windows host firewall restricts access to the Minikube IP, open a separate terminal and run:
> ```powershell
> kubectl port-forward svc/release-console-service 3000:3000
> ```
> Then open `http://localhost:3000` in your browser.

---

## 20. How to Demonstrate Failure Gating (College Demo)

This demonstration proves to evaluators that tests genuinely guard against bad releases:

### Step 1: Run Successful Release (`v1`)
Run the pipeline with the clean code and tag `v1`. Confirm that all 4 tasks pass, and `verify-deployment.ps1` shows version `v1` running.

### Step 2: Trigger a Controlled Failing Test
The patch adds a `-DemoFailTests` switch that sets `DEMO_FORCE_TEST_FAILURE=true` only inside the test Task. The normal test suite remains unchanged when the flag is off. This injects one explicit, deliberate failure so the quality gate can be demonstrated without committing broken application code.

### Step 3: Run Pipeline with a failure-demo tag
```powershell
.\scripts\run-pipeline.ps1 `
  -RepoUrl "https://github.com/YOUR_GITHUB_USERNAME/Tekton-Demo.git" `
  -DockerHubUsername "YOUR_DOCKERHUB_USERNAME" `
  -ImageTag "v2-fail-demo" `
  -DemoFailTests
```

### Step 5: Observe Quality Gate Halting
- Task `fetch-source` succeeds.
- Task `run-tests` **FAILS**.
- Task `build-and-push-image` is **SKIPPED / NEVER EXECUTED**.
- Task `deploy-application` is **SKIPPED / NEVER EXECUTED**.
- Check the running deployment:
  ```powershell
  kubectl get deployment release-console -o jsonpath='{.spec.template.spec.containers[0].image}'
  ```
  The active image remains `v1`! The production environment was completely protected from the defective build.

### Step 6: Restore the Test
Revert the change in `test/app.test.js`:
```powershell
git checkout -- test/app.test.js
git commit -am "fix: restore passing unit test"
git push origin main
```
Run `run-pipeline.ps1` with `-ImageTag "v2"`, and observe full green deployment to `v2`.

---

## 21. Troubleshooting Guide

| Issue / Error | Probable Cause | Corrective Action |
| :--- | :--- | :--- |
| `dockerhub-auth secret not found` | Secret setup script was not run. | Run `.\scripts\setup-registry-secret.ps1` and supply your Docker Hub PAT. |
| Kaniko fails with `unauthorized: authentication required` | Invalid Docker Hub token or username mismatch. | Regenerate a Docker Hub PAT with Read & Write permissions and re-run `setup-registry-secret.ps1`. |
| `minikube ip` connection timed out | Windows Hyper-V / VirtualBox host network routing. | Run `kubectl port-forward svc/release-console-service 3000:3000` and use `http://localhost:3000`. |
| PipelineRun stuck in `Pending` | Insufficient cluster CPU/RAM or PVC pending. | Check pod events: `kubectl describe pod -l tekton.dev/pipelineRun=<name>`. Ensure Minikube has 3072 MB memory allocated. |
| `git clone` fails in Task 1 | Repository URL is private or typed incorrectly. | Verify repository visibility is Public on GitHub. |

---

## 22. Safe Cleanup of Project Resources

To clean up resources created specifically for this project without affecting your core Minikube or Tekton installation:

```powershell
# Remove application deployment and service
kubectl delete -f k8s/deployment.yaml --ignore-not-found
kubectl delete -f k8s/service.yaml --ignore-not-found

# Remove PipelineRuns and TaskRuns
kubectl delete pipelineruns --all
kubectl delete taskruns --all

# Remove Tekton definitions
kubectl delete -f tekton/pipeline.yaml --ignore-not-found
kubectl delete -f tekton/tasks.yaml --ignore-not-found
kubectl delete -f tekton/rbac.yaml --ignore-not-found
kubectl delete -f tekton/pvc.yaml --ignore-not-found

# Remove registry secret
kubectl delete secret dockerhub-auth --ignore-not-found
```

---

## 23. Limitations and Future Improvements

- **Local Triggering:** Currently initiated via `run-pipeline.ps1`. In a cloud enterprise setup, **Tekton Triggers** (`EventListener` and `TriggerBinding`) combined with a public webhook receiver (or ngrok tunnel) would trigger runs automatically on `git push`.
- **Ephemeral Storage:** Sequential runs reuse the PVC. In heavy multi-branch enterprise setups, dynamic VolumeClaimTemplates provision dedicated volumes per run.
- **Image Scanning:** Future iterations can introduce a vulnerability scanning Task (such as Trivy or Grype) between the build and deployment phases.

---

## 24. Interactive Release Resilience Lab and Controlled Failure Demo

The Release Console UI now includes a **Release Resilience Lab** with three clearly labelled what-if scenarios: a healthy candidate, a test failure, and a rollout failure. The evaluator endpoint (`POST /api/release-lab/evaluate`) is a simulation only; it does not run `kubectl` or change the live cluster. The running version shown in the lab is read from the application environment.

For a real pipeline failure-gate demonstration, first commit and push this patch so the pipeline can clone the new files, then run:

```powershell
.\scripts\run-pipeline.ps1 `
  -RepoUrl "https://github.com/balaji-devx/Tekton-Demo.git" `
  -DockerHubUsername "ba1aj1" `
  -ImageTag "v2-fail-demo" `
  -DemoFailTests
```

The test Task fails intentionally, so the image-building and deployment Tasks are not executed. The already-running Deployment remains unchanged. Capture its current image before and after the failure with:

```powershell
kubectl get deployment release-console -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Then run a normal release with a **new, unused image tag**, for example `v3`, by omitting `-DemoFailTests`. If a real Deployment rollout fails after the image is built, `deploy-application` attempts `kubectl rollout undo` when a previous Deployment revision exists. The PipelineRun remains failed even if rollback succeeds, making the failure visible rather than reporting a false success.

The rollout-undo path requires the pipeline ServiceAccount's least-privilege Role to read ReplicaSets and patch the Deployment. A first-ever deployment has no previous revision to restore.

---

## 25. Official Technical References

- [Tekton Pipelines Documentation](https://tekton.dev/docs/pipelines/)
- [Kubernetes Documentation: Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Minikube Official Handbook](https://minikube.sigs.k8s.io/docs/)
- [Kaniko Container Engine (GitHub Archive & Reference)](https://github.com/GoogleContainerTools/kaniko)
- [Node.js Native Test Runner (node:test)](https://nodejs.org/api/test.html)

````

---

## 5. `k8s/deployment.yaml`

**Path:** `k8s/deployment.yaml`  
**Language:** `yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: release-console
  namespace: default
  labels:
    app: release-console
    tier: presentation
spec:
  replicas: 1
  selector:
    matchLabels:
      app: release-console
  template:
    metadata:
      labels:
        app: release-console
        tier: presentation
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: release-console
          image: DOCKERHUB_USERNAME/release-console:v1
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
              name: http
          env:
            - name: PORT
              value: "3000"
            - name: DEPLOY_ENV
              value: "minikube-local"
            - name: APP_VERSION
              value: "v1"
            - name: GIT_COMMIT
              value: "commit-sha-placeholder"
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "200m"
              memory: "128Mi"
          livenessProbe:
            httpGet:
              path: /healthz
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /healthz
              port: 3000
            initialDelaySeconds: 3
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false

```

---

## 6. `k8s/service.yaml`

**Path:** `k8s/service.yaml`  
**Language:** `yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: release-console-service
  namespace: default
  labels:
    app: release-console
spec:
  type: NodePort
  selector:
    app: release-console
  ports:
    - name: http
      port: 3000
      targetPort: 3000
      nodePort: 30080
      protocol: TCP

```

---

## 7. `package-lock.json`

**Path:** `package-lock.json`  
**Language:** `json`

```json
{
  "name": "release-console",
  "version": "1.0.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "release-console",
      "version": "1.0.0",
      "license": "MIT",
      "engines": {
        "node": ">=20.0.0"
      }
    }
  }
}

```

---

## 8. `package.json`

**Path:** `package.json`  
**Language:** `json`

```json
{
  "name": "release-console",
  "version": "1.0.0",
  "description": "Production-grade release console web application deployed via Tekton CI/CD on Kubernetes",
  "main": "src/index.js",
  "type": "commonjs",
  "scripts": {
    "start": "node src/index.js",
    "test": "node --test test/app.test.js"
  },
  "keywords": [
    "tekton",
    "kubernetes",
    "docker",
    "cicd",
    "devops"
  ],
  "author": "DevOps Engineering Team",
  "license": "MIT",
  "engines": {
    "node": ">=20.0.0"
  }
}

```

---

## 9. `public/app.js`

**Path:** `public/app.js`  
**Language:** `javascript`

```javascript
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
      if (elVersion) {
        elVersion.textContent = cachedInfo.version || 'Unknown';
      }
      if (labCurrentVersion) {
        labCurrentVersion.textContent = cachedInfo.version || 'Unknown';
      }
      
      const commitSha = cachedInfo.commit || 'unknown';
      if (elCommit) {
        elCommit.textContent = commitSha.length > 7 ? commitSha.substring(0, 7) : commitSha;
        elCommit.title = commitSha;
      }

      if (elEnv) elEnv.textContent = cachedInfo.environment || 'Local';
      if (elRuntime) elRuntime.textContent = `Node.js ${cachedInfo.nodeVersion || 'v20'}`;

      // Update status indicators
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
      if (labCurrentVersion && (labCurrentVersion.textContent === 'Loading...' || !labCurrentVersion.textContent)) {
        labCurrentVersion.textContent = 'Unavailable';
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

  // Refresh trigger
  btnRefresh.addEventListener('click', function () {
    fetchTelemetry();
  });

  function renderLabResult(result) {
    if (labOutcomePanel) labOutcomePanel.dataset.outcome = result.outcome;
    if (labOutcomeTitle) labOutcomeTitle.textContent = result.title;
    if (labOutcomeSummary) labOutcomeSummary.textContent = result.summary;
    if (labCurrentVersion) {
      labCurrentVersion.textContent = result.currentVersion || cachedInfo?.version || 'Unknown';
    }
    if (labStageResults) {
      labStageResults.replaceChildren();

      if (Array.isArray(result.stages)) {
        result.stages.forEach(function (stage) {
          const item = document.createElement('li');
          item.className = 'lab-stage-item';

          const status = document.createElement('span');
          status.className = `lab-stage-status status-${stage.status}`;
          status.textContent = (stage.status || 'unknown').replace(/-/g, ' ').toUpperCase();

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
      }
    }

    if (labEvidence) {
      labEvidence.textContent = JSON.stringify(result, null, 2);
    }
  }

  async function evaluateReleaseScenario(button) {
    labScenarioButtons.forEach(function (candidate) {
      candidate.disabled = true;
      candidate.setAttribute('aria-busy', 'true');
    });
    if (labOutcomeTitle) labOutcomeTitle.textContent = 'Evaluating scenario...';
    if (labOutcomeSummary) labOutcomeSummary.textContent = 'The local evaluator is calculating the expected pipeline outcome.';
    if (labOutcomePanel) labOutcomePanel.dataset.outcome = 'pending';

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
      if (labOutcomePanel) labOutcomePanel.dataset.outcome = 'error';
      if (labOutcomeTitle) labOutcomeTitle.textContent = 'Scenario evaluator unavailable';
      if (labOutcomeSummary) labOutcomeSummary.textContent = error.message;
      if (labStageResults) labStageResults.replaceChildren();
      if (labEvidence) labEvidence.textContent = String(error.message);
    } finally {
      labScenarioButtons.forEach(function (candidate) {
        candidate.disabled = false;
        candidate.removeAttribute('aria-busy');
      });
      if (button) button.focus();
    }
  }

  labScenarioButtons.forEach(function (button) {
    button.addEventListener('click', function () { evaluateReleaseScenario(button); });
  });

  // Initial fetch and 15-second polling interval
  fetchTelemetry();
  setInterval(fetchTelemetry, 15000);
})();

```

---

## 10. `public/index.html`

**Path:** `public/index.html`  
**Language:** `html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="Release Console - Production telemetry and deployment verification for local Kubernetes CI/CD pipeline using Tekton and Docker.">
  <title>Release Console — Local Kubernetes CI/CD</title>
  <link rel="stylesheet" href="styles.css?v=resilience-lab-2">
</head>
<body>
  <div class="shell">
    <header class="app-header">
      <div class="header-inner">
        <div class="brand">
          <div class="brand-mark">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <path d="M22 12h-4l-3 9L9 3l-3 9H2" />
            </svg>
          </div>
          <div>
            <h1 class="brand-title">Release Console V2</h1>
            <p class="brand-subtitle">Local Kubernetes CI/CD Pipeline Telemetry</p>
          </div>
        </div>

        <div class="header-actions">
          <button id="btn-refresh" class="btn btn-secondary" type="button" aria-label="Refresh telemetry data">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <path d="M3 12a9 9 0 0 1 15-6.7L21 8" />
              <path d="M21 3v5h-5" />
              <path d="M21 12a9 9 0 0 1-15 6.7L3 16" />
              <path d="M3 21v-5h5" />
            </svg>
            <span>Refresh Telemetry</span>
          </button>
        </div>
      </div>
    </header>

    <main class="content-container">
      <!-- System Architecture & Context Summary -->
      <section class="overview-section" aria-labelledby="overview-heading">
        <div class="overview-card">
          <div class="overview-header">
            <h2 id="overview-heading" class="section-title">Deployment Overview</h2>
            <div class="status-summary" id="status-summary">
              <span class="status-dot" id="header-status-dot" aria-hidden="true"></span>
              <span class="status-label" id="header-status-text">Connecting to pod...</span>
            </div>
          </div>
          <p class="overview-copy">
            This application is released through a non-cloud CI/CD pipeline on a local Minikube Kubernetes cluster. After a PipelineRun is manually triggered, Tekton clones and tests the source, Kaniko builds and publishes the image, and the deployment Task updates Kubernetes.
          </p>
        </div>
      </section>

      <!-- Primary Telemetry Grid -->
      <section class="telemetry-section" aria-labelledby="telemetry-heading">
        <h2 id="telemetry-heading" class="visually-hidden">Live Application Telemetry</h2>

        <div class="grid grid-primary">
          <div class="data-panel">
            <span class="panel-caption">Application Release</span>
            <div class="panel-value-row">
              <span class="panel-value" id="val-version">Loading...</span>
            </div>
            <span class="panel-foot">Injected during build</span>
          </div>

          <div class="data-panel">
            <span class="panel-caption">Git Commit SHA</span>
            <div class="panel-value-row">
              <code class="code-value" id="val-commit">Loading...</code>
            </div>
            <span class="panel-foot">Source repository checkout</span>
          </div>

          <div class="data-panel">
            <span class="panel-caption">Execution Environment</span>
            <div class="panel-value-row">
              <span class="panel-value" id="val-env">Loading...</span>
            </div>
            <span class="panel-foot">Local Kubernetes / Minikube</span>
          </div>

          <div class="data-panel">
            <span class="panel-caption">Runtime Platform</span>
            <div class="panel-value-row">
              <span class="panel-value" id="val-runtime">Loading...</span>
            </div>
            <span class="panel-foot">Alpine Node.js 20 base</span>
          </div>
        </div>
      </section>

      <!-- Interactive what-if scenarios: these evaluate policy and never mutate Minikube. -->
      <section class="lab-section" aria-labelledby="lab-heading">
        <div class="lab-heading-row">
          <div>
            <h2 class="section-title" id="lab-heading">Release Resilience Lab</h2>
            <p class="lab-subtitle">Explore how the pipeline should behave when a release passes or fails.</p>
          </div>
          <span class="lab-mode-label">WHAT-IF SIMULATION</span>
        </div>

        <div class="lab-scenarios" role="group" aria-label="Select release scenario">
          <button class="lab-scenario-btn" type="button" data-scenario="success">Healthy Candidate</button>
          <button class="lab-scenario-btn" type="button" data-scenario="test-failure">Test Failure</button>
          <button class="lab-scenario-btn" type="button" data-scenario="rollout-failure">Rollout Failure</button>
        </div>

        <div class="lab-result-grid">
          <section class="lab-result-card lab-outcome-panel" id="lab-outcome-panel" data-outcome="idle" aria-live="polite">
            <p class="lab-card-eyebrow">Expected pipeline decision</p>
            <h3 id="lab-outcome-title">Choose a scenario</h3>
            <p id="lab-outcome-summary" class="lab-outcome-summary">Run a what-if scenario to see the quality gate, deployment decision, and release protection behavior.</p>
            <div class="lab-current-release">Currently running version <strong id="lab-current-version">Loading...</strong></div>
            <p class="lab-simulation-note">This lab is a simulation only. It does not create a PipelineRun or change the live Kubernetes Deployment.</p>
          </section>

          <section class="lab-result-card" aria-labelledby="lab-stages-heading">
            <div class="lab-card-header">
              <h3 id="lab-stages-heading">Stage-by-stage evidence</h3>
              <span class="lab-card-eyebrow">EXPECTED RESULT</span>
            </div>
            <ol id="lab-stage-results" class="lab-stage-results">
              <li class="lab-stage-placeholder">Select one of the scenarios to inspect its expected stages.</li>
            </ol>
          </section>
        </div>
        <details class="lab-response-details">
          <summary>View evaluator response</summary>
          <pre id="lab-evidence" class="lab-evidence">No scenario evaluated yet.</pre>
        </details>
      </section>

      <!-- Two-column Section: Pipeline Workflow & Raw Telemetry Inspector -->
      <section class="details-section" aria-labelledby="details-heading">
        <h2 id="details-heading" class="visually-hidden">Pipeline Architecture and Live Verification</h2>

        <div class="grid grid-split">
          <!-- Pipeline Stages Column -->
          <div class="panel-block">
            <div class="panel-block-header">
              <h3 class="panel-block-title">Tekton Pipeline Stages</h3>
              <span class="panel-block-sub">Sequential execution workflow</span>
            </div>

            <ol class="stage-list">
              <li class="stage-item">
                <div class="stage-index">1</div>
                <div class="stage-details">
                  <div class="stage-title">Clone Source</div>
                  <div class="stage-desc">Retrieves the repository from GitHub into a shared PersistentVolume Workspace and outputs the verified commit SHA.</div>
                  <div class="stage-tech">Task: clone-source &bull; alpine/git</div>
                </div>
              </li>

              <li class="stage-item">
                <div class="stage-index">2</div>
                <div class="stage-details">
                  <div class="stage-title">Install &amp; Test Quality Gate</div>
                  <div class="stage-desc">Executes clean npm ci and unit tests with node:test. Failure halts the pipeline immediately before building.</div>
                  <div class="stage-tech">Task: test-application &bull; node:20-alpine</div>
                </div>
              </li>

              <li class="stage-item">
                <div class="stage-index">3</div>
                <div class="stage-details">
                  <div class="stage-title">In-Cluster Image Build</div>
                  <div class="stage-desc">Builds the production Docker image inside the Kubernetes pod using Kaniko and pushes versioned tags to Docker Hub.</div>
                  <div class="stage-tech">Task: build-and-push-image &bull; Kaniko Executor</div>
                </div>
              </li>

              <li class="stage-item">
                <div class="stage-index">4</div>
                <div class="stage-details">
                  <div class="stage-title">Rolling Kubernetes Deployment</div>
                  <div class="stage-desc">Updates deployment manifests with the verified container image, monitors rollout status, and confirms endpoint readiness.</div>
                  <div class="stage-tech">Task: deploy-application &bull; kubectl 1.37</div>
                </div>
              </li>
            </ol>
          </div>

          <!-- Raw Diagnostic Inspector Column -->
          <div class="panel-block">
            <div class="panel-block-header">
              <h3 class="panel-block-title">Live Endpoint Inspector</h3>
              <span class="panel-block-sub">Direct HTTP probe response</span>
            </div>

            <div class="inspector-controls">
              <div class="endpoint-tabs" role="tablist" aria-label="Select diagnostic endpoint">
                <button class="tab-btn active" id="tab-info" role="tab" aria-selected="true" type="button">GET /api/info</button>
                <button class="tab-btn" id="tab-health" role="tab" aria-selected="false" type="button">GET /healthz</button>
              </div>
              <div class="latency-counter" id="telemetry-latency">
                Latency: <span id="val-latency">--</span> ms
              </div>
            </div>

            <div class="terminal-view">
              <div class="terminal-meta">
                <span class="terminal-status" id="terminal-http-status">HTTP 200 OK</span>
                <span class="terminal-time" id="terminal-timestamp">--:--:--</span>
              </div>
              <pre class="terminal-output" id="terminal-content">Awaiting backend response...</pre>
            </div>

            <div class="inspector-notes">
              Health check requests are probed periodically by the Kubernetes kubelet via HTTP probes and displayed here directly from the server.
            </div>
          </div>
        </div>
      </section>

      <!-- College Presentation Architecture Context -->
      <section class="footer-context" aria-labelledby="context-heading">
        <h2 id="context-heading" class="visually-hidden">System Context</h2>
        <div class="context-grid">
          <div class="context-item">
            <div class="context-title">Local Execution</div>
            <div class="context-body">All build and deploy operations execute entirely within the local Minikube cluster on Windows 10 without requiring cloud compute resources.</div>
          </div>
          <div class="context-item">
            <div class="context-title">External Registries</div>
            <div class="context-body">GitHub serves as external VCS and Docker Hub serves as the external OCI container registry, authenticated through Kubernetes Secrets.</div>
          </div>
          <div class="context-item">
            <div class="context-title">Automated Gating</div>
            <div class="context-body">PipelineRun sequential dependencies guarantee that any failing unit test halts container builds, preventing defective deployments.</div>
          </div>
        </div>
      </section>
    </main>

    <footer class="app-footer">
      <div class="footer-inner">
        <span>Design and Implementation of a Non-Cloud CI/CD Pipeline Using Tekton, Docker and Kubernetes</span>
        <span>Node.js &bull; Docker &bull; Minikube &bull; Tekton</span>
      </div>
    </footer>
  </div>

  <script src="app.js?v=resilience-lab-2"></script>
</body>
</html>

```

---

## 11. `public/styles.css`

**Path:** `public/styles.css`  
**Language:** `css`

```css
/* Release Console - Professional Dark Design System */

:root {
  --bg-main: #121416;
  --bg-secondary: #191D20;
  --bg-elevated: #22272A;
  --bg-terminal: #0E1012;
  
  --text-primary: #E9ECE7;
  --text-secondary: #A1AAA5;
  --text-muted: #727C78;
  
  --accent: #C3E96A;
  --accent-muted: #8AA844;
  --border-muted: #2A3033;
  --border-subtle: #1F2427;
  
  --status-healthy: #8EDB7D;
  --status-error: #E57373;
  --status-pending: #E0C266;

  --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  --font-mono: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, Courier, monospace;

  --radius-sm: 3px;
  --radius-md: 4px;
  --radius-lg: 6px;

  --transition-fast: 150ms ease;
}

*, *::before, *::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  background-color: var(--bg-main);
  color: var(--text-primary);
  font-family: var(--font-sans);
  font-size: 14px;
  line-height: 1.5;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

.visually-hidden {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.shell {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}

/* Header */
.app-header {
  background-color: var(--bg-secondary);
  border-bottom: 1px solid var(--border-subtle);
}

.header-inner {
  max-width: 1240px;
  margin: 0 auto;
  padding: 16px 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.brand {
  display: flex;
  align-items: center;
  gap: 14px;
}

.brand-mark {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  background-color: var(--bg-elevated);
  color: var(--accent);
  border-radius: var(--radius-md);
}

.brand-title {
  font-size: 18px;
  font-weight: 600;
  letter-spacing: -0.01em;
  color: var(--text-primary);
}

.brand-subtitle {
  font-size: 12px;
  color: var(--text-secondary);
}

/* Restrained Button */
.btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 14px;
  font-family: var(--font-sans);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  border-radius: var(--radius-md);
  transition: background-color var(--transition-fast), color var(--transition-fast), border-color var(--transition-fast);
}

.btn-secondary {
  background-color: var(--bg-elevated);
  color: var(--text-primary);
  border: 1px solid var(--border-muted);
}

.btn-secondary:hover {
  background-color: #2B3236;
  border-color: #3D464A;
}

.btn-secondary:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}

/* Main Layout */
.content-container {
  max-width: 1240px;
  width: 100%;
  margin: 0 auto;
  padding: 28px 24px 40px;
  display: flex;
  flex-direction: column;
  gap: 24px;
  flex: 1;
}

/* Overview Section */
.overview-card {
  background-color: var(--bg-secondary);
  border-radius: var(--radius-lg);
  padding: 22px 24px;
}

.overview-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.section-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
}

.status-summary {
  display: flex;
  align-items: center;
  gap: 8px;
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background-color: var(--status-pending);
  display: inline-block;
  transition: background-color var(--transition-fast);
}

.status-dot.healthy {
  background-color: var(--status-healthy);
}

.status-dot.error {
  background-color: var(--status-error);
}

.status-label {
  font-size: 13px;
  color: var(--text-secondary);
}

.overview-copy {
  color: var(--text-secondary);
  font-size: 14px;
  line-height: 1.6;
  max-width: 980px;
}

/* Telemetry Grid */
.grid {
  display: grid;
  gap: 16px;
}

.grid-primary {
  grid-template-columns: repeat(4, 1fr);
}

.data-panel {
  background-color: var(--bg-secondary);
  border-radius: var(--radius-lg);
  padding: 20px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  min-height: 110px;
}

.panel-caption {
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--text-muted);
}

.panel-value-row {
  margin: 10px 0 6px;
}

.panel-value {
  font-size: 22px;
  font-weight: 600;
  color: var(--text-primary);
  letter-spacing: -0.01em;
}

.code-value {
  font-family: var(--font-mono);
  font-size: 16px;
  color: var(--accent);
  background-color: var(--bg-elevated);
  padding: 2px 6px;
  border-radius: var(--radius-sm);
  display: inline-block;
}

.panel-foot {
  font-size: 12px;
  color: var(--text-secondary);
}

/* Split Section */
.grid-split {
  grid-template-columns: 1fr 1fr;
}

.panel-block {
  background-color: var(--bg-secondary);
  border-radius: var(--radius-lg);
  padding: 24px;
  display: flex;
  flex-direction: column;
}

.panel-block-header {
  margin-bottom: 20px;
}

.panel-block-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
}

.panel-block-sub {
  font-size: 12px;
  color: var(--text-muted);
  display: block;
  margin-top: 2px;
}

/* Stage List */
.stage-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.stage-item {
  display: flex;
  align-items: flex-start;
  gap: 14px;
}

.stage-index {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  background-color: var(--bg-elevated);
  color: var(--text-primary);
  font-family: var(--font-mono);
  font-size: 12px;
  font-weight: 600;
  border-radius: var(--radius-sm);
  flex-shrink: 0;
  margin-top: 2px;
}

.stage-details {
  flex: 1;
}

.stage-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 2px;
}

.stage-desc {
  font-size: 13px;
  color: var(--text-secondary);
  line-height: 1.4;
  margin-bottom: 4px;
}

.stage-tech {
  font-size: 11px;
  font-family: var(--font-mono);
  color: var(--text-muted);
}

/* Inspector */
.inspector-controls {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.endpoint-tabs {
  display: flex;
  gap: 4px;
  background-color: var(--bg-elevated);
  padding: 3px;
  border-radius: var(--radius-md);
}

.tab-btn {
  background: transparent;
  border: none;
  color: var(--text-secondary);
  font-family: var(--font-mono);
  font-size: 12px;
  padding: 5px 10px;
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: background-color var(--transition-fast), color var(--transition-fast);
}

.tab-btn.active {
  background-color: var(--bg-secondary);
  color: var(--accent);
  font-weight: 500;
}

.tab-btn:hover:not(.active) {
  color: var(--text-primary);
}

.latency-counter {
  font-size: 12px;
  font-family: var(--font-mono);
  color: var(--text-muted);
}

.terminal-view {
  background-color: var(--bg-terminal);
  border-radius: var(--radius-md);
  padding: 14px 16px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  flex: 1;
  min-height: 200px;
}

.terminal-meta {
  display: flex;
  justify-content: space-between;
  font-size: 11px;
  font-family: var(--font-mono);
  color: var(--text-muted);
  border-bottom: 1px solid var(--border-subtle);
  padding-bottom: 8px;
}

.terminal-output {
  font-family: var(--font-mono);
  font-size: 12px;
  line-height: 1.6;
  color: var(--text-primary);
  white-space: pre-wrap;
  word-break: break-all;
  overflow-y: auto;
  max-height: 240px;
}

.inspector-notes {
  margin-top: 12px;
  font-size: 12px;
  color: var(--text-muted);
  line-height: 1.4;
}

/* Footer Context */
.context-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
}

.context-item {
  background-color: var(--bg-secondary);
  border-radius: var(--radius-lg);
  padding: 18px 20px;
}

.context-title {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 6px;
}

.context-body {
  font-size: 13px;
  color: var(--text-secondary);
  line-height: 1.5;
}

/* App Footer */
.app-footer {
  background-color: var(--bg-secondary);
  border-top: 1px solid var(--border-subtle);
  margin-top: auto;
}

.footer-inner {
  max-width: 1240px;
  margin: 0 auto;
  padding: 16px 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 12px;
  color: var(--text-muted);
}

/* Responsive adjustments */
@media (max-width: 1024px) {
  .grid-primary {
    grid-template-columns: repeat(2, 1fr);
  }
  .grid-split {
    grid-template-columns: 1fr;
  }
  .context-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .header-inner {
    flex-direction: column;
    align-items: flex-start;
    gap: 14px;
  }
  .grid-primary {
    grid-template-columns: 1fr;
  }
  .footer-inner {
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }
}


/* Release Resilience Lab */
.lab-section {
  background: var(--bg-secondary);
  border: 1px solid var(--border-muted);
  border-radius: var(--radius-lg);
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.lab-heading-row,
.lab-card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.lab-subtitle {
  margin-top: 5px;
  color: var(--text-secondary);
  font-size: 13px;
}

.lab-mode-label,
.lab-card-eyebrow {
  color: var(--text-muted);
  font-family: var(--font-mono);
  font-size: 10px;
  letter-spacing: 0.07em;
  text-transform: uppercase;
}

.lab-mode-label {
  border: 1px solid var(--border-muted);
  background-color: var(--bg-elevated);
  color: var(--accent);
  border-radius: var(--radius-sm);
  padding: 5px 10px;
  font-weight: 600;
  white-space: nowrap;
}

.lab-scenarios {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.lab-scenario-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  border: 1px solid var(--border-muted);
  background: var(--bg-elevated);
  color: var(--text-primary);
  border-radius: var(--radius-md);
  padding: 9px 16px;
  font-family: var(--font-sans);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color var(--transition-fast), border-color var(--transition-fast), color var(--transition-fast);
}

.lab-scenario-btn:hover:not(:disabled) {
  background-color: #2B3236;
  border-color: #3D464A;
}

.lab-scenario-btn:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
  border-color: var(--accent);
}

.lab-scenario-btn:disabled {
  cursor: not-allowed;
  opacity: 0.55;
  background-color: var(--bg-elevated);
  border-color: var(--border-subtle);
}

.lab-result-grid {
  display: grid;
  grid-template-columns: minmax(0, 0.95fr) minmax(0, 1.05fr);
  gap: 16px;
}

.lab-result-card {
  min-width: 0;
  border: 1px solid var(--border-muted);
  border-radius: var(--radius-md);
  background: var(--bg-main);
  padding: 20px;
}

.lab-outcome-panel {
  border-left: 3px solid var(--border-muted);
}

.lab-outcome-panel[data-outcome="ready"] { border-left-color: var(--status-healthy); }
.lab-outcome-panel[data-outcome="blocked"] { border-left-color: var(--status-error); }
.lab-outcome-panel[data-outcome="recovered"] { border-left-color: var(--accent); }
.lab-outcome-panel[data-outcome="pending"] { border-left-color: var(--status-pending); }
.lab-outcome-panel[data-outcome="error"] { border-left-color: var(--status-error); }

.lab-result-card h3 {
  margin: 8px 0 10px;
  font-size: 16px;
  font-weight: 600;
}

.lab-outcome-summary,
.lab-stage-copy p,
.lab-simulation-note {
  color: var(--text-secondary);
  font-size: 13px;
  line-height: 1.55;
}

.lab-current-release {
  margin-top: 18px;
  padding-top: 14px;
  border-top: 1px solid var(--border-subtle);
  color: var(--text-muted);
  font-size: 13px;
}

.lab-current-release strong {
  color: var(--accent);
  font-family: var(--font-mono);
  font-size: 13px;
  font-weight: 600;
  background-color: var(--bg-elevated);
  padding: 2px 7px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--border-muted);
  display: inline-block;
}

.lab-simulation-note {
  margin-top: 14px;
  font-size: 11px;
}

.lab-stage-results {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 14px;
  margin-top: 16px;
}

.lab-stage-item {
  display: grid;
  grid-template-columns: 94px minmax(0, 1fr);
  gap: 12px;
  align-items: start;
}

.lab-stage-status {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 4px 8px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--border-muted);
  color: var(--text-secondary);
  font-family: var(--font-mono);
  font-size: 10px;
  font-weight: 600;
  line-height: 1.3;
  letter-spacing: 0.05em;
  text-align: center;
  overflow-wrap: anywhere;
}

.lab-stage-status.status-passed,
.lab-stage-status.status-ready,
.lab-stage-status.status-restored {
  color: var(--status-healthy);
  border-color: rgba(142, 219, 125, 0.35);
  background-color: rgba(142, 219, 125, 0.08);
}

.lab-stage-status.status-failed {
  color: var(--status-error);
  border-color: rgba(229, 115, 115, 0.35);
  background-color: rgba(229, 115, 115, 0.08);
}

.lab-stage-status.status-blocked,
.lab-stage-status.status-skipped {
  color: var(--status-pending);
  border-color: rgba(224, 194, 102, 0.35);
  background-color: rgba(224, 194, 102, 0.08);
}

.lab-stage-copy strong {
  display: block;
  margin-bottom: 3px;
  font-size: 13px;
  font-weight: 600;
}

.lab-stage-copy p { font-size: 12px; }
.lab-stage-placeholder { color: var(--text-muted); font-size: 13px; }

.lab-response-details {
  border-top: 1px solid var(--border-subtle);
  padding-top: 12px;
  color: var(--text-secondary);
  font-size: 12px;
}

.lab-response-details summary { cursor: pointer; }
.lab-evidence {
  margin-top: 10px;
  padding: 14px;
  background: var(--bg-terminal);
  color: var(--text-primary);
  font: 11px/1.5 var(--font-mono);
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  max-height: 260px;
  overflow: auto;
}

@media (max-width: 900px) {
  .lab-result-grid { grid-template-columns: 1fr; }
}

@media (max-width: 640px) {
  .lab-section { padding: 16px; }
  .lab-heading-row { flex-direction: column; }
  .lab-mode-label { align-self: flex-start; }
  .lab-stage-item { grid-template-columns: 80px minmax(0, 1fr); gap: 8px; }
}

```

---

## 12. `run.txt`

**Path:** `run.txt`  
**Language:** `text`

```text
cd "E:\SEM 3\DEVOPS\Tekton-Demo"

minikube start
kubectl config use-context minikube

kubectl wait --for=condition=Ready node/minikube --timeout=120s

kubectl get pods -n tekton-pipelines
kubectl rollout status deployment/release-console --timeout=180s
kubectl get pods,services


kubectl port-forward svc/release-console-service 3000:3000 -n default

kubectl get pipelineruns
kubectl get taskruns

$ErrorActionPreference = "Stop"

Write-Host "`nConfiguring release v2..." -ForegroundColor Cyan

$templatePath = ".\tekton\pipelinerun-template.yaml"
$template = Get-Content $templatePath -Raw

$template = $template -replace '(?m)(name:\simage-tag\s\r?\n\svalue:\s)v[0-9]+', '${1}v2'
$template = $template -replace '(?m)(name:\sapp-version\s\r?\n\svalue:\s)v[0-9]+', '${1}v2'

Set-Content -Path $templatePath -Value $template -NoNewline

Write-Host "`nChecking v2 configuration..." -ForegroundColor Yellow
Select-String -Path $templatePath -Pattern 'image-tag|app-version|value: v2' -Context 0,2

git add .\tekton\pipelinerun-template.yaml

git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "`nNo new template changes to commit." -ForegroundColor Yellow
}
else {
    git commit -m "Configure release v2"
    if ($LASTEXITCODE -ne 0) {
        throw "Git commit failed."
    }
}

Write-Host "`nPushing v2 configuration to GitHub..." -ForegroundColor Cyan

git push origin main
if ($LASTEXITCODE -ne 0) {
    throw "Git push failed. Check your internet connection and try again."
}

Write-Host "`nStarting v2 pipeline..." -ForegroundColor Cyan

$run = kubectl create -f $templatePath -o name
if ($LASTEXITCODE -ne 0 -or -not $run) {
    throw "Could not create the PipelineRun."
}

Write-Host "Created: $run" -ForegroundColor Green
Write-Host "`nWaiting for pipeline completion (up to 15 minutes)..." -ForegroundColor Yellow

kubectl wait --for=condition=Succeeded $run -n default --timeout=15m
if ($LASTEXITCODE -ne 0) {
    kubectl get pipelineruns -n default
    kubectl get taskruns -n default
    throw "Pipeline failed or timed out."
}

Write-Host "`nVerifying deployment..." -ForegroundColor Green

kubectl rollout status deployment/release-console -n default --timeout=180s
if ($LASTEXITCODE -ne 0) {
    throw "Deployment rollout failed."
}

$image = kubectl get deployment release-console -n default -o jsonpath='{.spec.template.spec.containers[0].image}'
Write-Host "`nDeployed image: $image" -ForegroundColor Cyan

if ($image -ne "docker.io/ba1aj1/release-console:v2") {
    throw "Deployment is not using the expected v2 image."
}

Write-Host "`nRelease v2 deployed successfully!" -ForegroundColor Green
kubectl get pods -n default -l app=release-console

Write-Host "`nOpen http://localhost:3001 and press Ctrl+F5." -ForegroundColor Green
kubectl port-forward service/release-console-service 3001:3000 -n default

```

---

## 13. `scripts/check-prerequisites.ps1`

**Path:** `scripts/check-prerequisites.ps1`  
**Language:** `powershell`

```powershell
<#
.SYNOPSIS
    Inspects environment prerequisites for running the Release Console Tekton CI/CD pipeline.
.DESCRIPTION
    Non-destructive audit of Git, Docker Desktop, Minikube, kubectl, Tekton controller pods,
    and Docker Hub registry secret readiness.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Environment Audit: Local Tekton CI/CD Pipeline" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$passedChecks = 0
$totalChecks = 7

# 1. Git Verification
Write-Host "`n[1/7] Inspecting Git CLI..." -NoNewline
try {
    $gitVersion = git --version 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitVersion) {
        Write-Host " OK ($gitVersion)" -ForegroundColor Green
        $passedChecks++
    } else {
        Write-Host " FAILED (git command not found in PATH)" -ForegroundColor Red
    }
} catch {
    Write-Host " FAILED ($_)" -ForegroundColor Red
}

# 2. Docker Verification
Write-Host "[2/7] Inspecting Docker Desktop Engine..." -NoNewline
try {
    $dockerInfo = docker info --format '{{.ServerVersion}} (Context: {{.ClientInfo.Context}})' 2>$null
    if ($LASTEXITCODE -eq 0 -and $dockerInfo) {
        Write-Host " OK ($dockerInfo)" -ForegroundColor Green
        $passedChecks++
    } else {
        Write-Host " FAILED (Docker engine unreachable. Verify Docker Desktop is running)" -ForegroundColor Red
    }
} catch {
    Write-Host " FAILED ($_)" -ForegroundColor Red
}

# 3. Minikube Status
Write-Host "[3/7] Inspecting Minikube Cluster..." -NoNewline
try {
    $minikubeStatus = minikube status --format '{{.Host}}' 2>$null
    if ($minikubeStatus -like "*Running*") {
        $minikubeIp = minikube ip 2>$null
        Write-Host " OK (Host: Running, IP: $minikubeIp)" -ForegroundColor Green
        $passedChecks++
    } else {
        Write-Host " FAILED (Minikube host is not Running. Run 'minikube start')" -ForegroundColor Red
    }
} catch {
    Write-Host " FAILED ($_)" -ForegroundColor Red
}

# 4. kubectl Context & Node Readiness
Write-Host "[4/7] Inspecting kubectl context and Kubernetes node status..." -NoNewline
try {
    $currentContext = kubectl config current-context 2>$null
    $nodeStatus = kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>$null
    if ($currentContext -eq "minikube" -and $nodeStatus -eq "True") {
        Write-Host " OK (Context: minikube, Node: Ready)" -ForegroundColor Green
        $passedChecks++
    } else {
        Write-Host " WARNING (Context: $currentContext, Node Ready: $nodeStatus)" -ForegroundColor Yellow
        Write-Host "   Hint: Run 'kubectl config use-context minikube'" -ForegroundColor Gray
    }
} catch {
    Write-Host " FAILED ($_)" -ForegroundColor Red
}

# 5. Tekton Pipelines Controller Pods
Write-Host "[5/7] Inspecting Tekton Pipelines controller health..." -NoNewline
try {
    $tektonPods = kubectl get pods -n tekton-pipelines -o jsonpath='{range .items[*]}{.metadata.name}:{.status.phase}{" "}{end}' 2>$null
    if ($tektonPods -like "*tekton-pipelines-controller*Running*" -and $tektonPods -like "*tekton-pipelines-webhook*Running*") {
        Write-Host " OK (Controllers Running)" -ForegroundColor Green
        $passedChecks++
    } else {
        Write-Host " WARNING (Tekton controllers not fully Running in namespace tekton-pipelines)" -ForegroundColor Yellow
        Write-Host "   Observed Pods: $tektonPods" -ForegroundColor Gray
    }
} catch {
    Write-Host " FAILED ($_)" -ForegroundColor Red
}

# 6. Docker Hub Authentication Secret
Write-Host "[6/7] Inspecting Docker Hub registry Secret (dockerhub-auth)..." -NoNewline
try {
    $secretCheck = kubectl get secret dockerhub-auth -n default --ignore-not-found -o jsonpath='{.metadata.name}' 2>$null
    if ($secretCheck -eq "dockerhub-auth") {
        Write-Host " OK (Secret present in default namespace)" -ForegroundColor Green
        $passedChecks++
    } else {
        Write-Host " NOT CONFIGURED (Optional before initial setup)" -ForegroundColor Yellow
        Write-Host "   Hint: Run '.\scripts\setup-registry-secret.ps1' to configure credentials securely." -ForegroundColor Gray
    }
} catch {
    Write-Host " FAILED ($_)" -ForegroundColor Red
}

# 7. Host Resource Inspection (Windows OS, Disk, Memory)
Write-Host "[7/7] Inspecting Local Host Resources..." -NoNewline
try {
    $cDrive = Get-PSDrive C -ErrorAction SilentlyContinue
    $freeGb = [math]::Round($cDrive.Free / 1GB, 1)
    $osInfo = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue)
    $totalRamGb = [math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 1)
    $freeRamGb = [math]::Round($osInfo.FreePhysicalMemory / 1MB, 1)

    Write-Host " OK" -ForegroundColor Green
    Write-Host "   - C Drive Free Space:  $freeGb GB" -ForegroundColor Gray
    Write-Host "   - Total Host Memory:   $totalRamGb GB" -ForegroundColor Gray
    Write-Host "   - Free Host Memory:    $freeRamGb GB" -ForegroundColor Gray
    $passedChecks++
} catch {
    Write-Host " WARNING (Resource query failed: $_)" -ForegroundColor Yellow
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Audit Complete: $passedChecks of $totalChecks checks verified." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

```

---

## 14. `scripts/run-pipeline.ps1`

**Path:** `scripts/run-pipeline.ps1`  
**Language:** `powershell`

```powershell
<#
.SYNOPSIS
    Deploys Tekton manifests and initiates a fresh PipelineRun on the local cluster.
.DESCRIPTION
    Validates prerequisites, applies RBAC/PVC/Tasks/Pipeline resources, creates a uniquely
    named PipelineRun with specified image tag, and outputs diagnostic monitoring commands.
.EXAMPLE
    .\scripts\run-pipeline.ps1 -RepoUrl "https://github.com/myuser/Tekton-Demo.git" -DockerHubUsername "myuser" -ImageTag "v1"
    .\scripts\run-pipeline.ps1 -RepoUrl "https://github.com/myuser/Tekton-Demo.git" -DockerHubUsername "myuser" -ImageTag "v2-fail-demo" -DemoFailTests
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Public GitHub repository URL (e.g. https://github.com/user/repo.git)")]
    [string]$RepoUrl,

    [Parameter(Mandatory = $true, HelpMessage = "Your Docker Hub username")]
    [string]$DockerHubUsername,

    [Parameter(Mandatory = $false, HelpMessage = "Image tag for this release")]
    [string]$ImageTag = "v1",

    [Parameter(Mandatory = $false, HelpMessage = "Git revision / branch")]
    [string]$Revision = "main",

    [Parameter(Mandatory = $false)]
    [string]$Namespace = "default",

    [Parameter(Mandatory = $false, HelpMessage = "Inject one intentional failing test to demonstrate failure gating")]
    [switch]$DemoFailTests
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Launching Release Console Tekton CI/CD PipelineRun" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Target Repository: $RepoUrl" -ForegroundColor Gray
Write-Host "Git Revision:      $Revision" -ForegroundColor Gray
Write-Host "Docker Hub User:   $DockerHubUsername" -ForegroundColor Gray
Write-Host "Target Image Tag:  $ImageTag" -ForegroundColor Gray
Write-Host "Namespace:         $Namespace" -ForegroundColor Gray
$demoFailTestsValue = if ($DemoFailTests) { "true" } else { "false" }
Write-Host "Injected test failure: $demoFailTestsValue" -ForegroundColor Gray
Write-Host ""

$projectRoot = Split-Path -Parent $PSScriptRoot

# 1. Verify Kubernetes Context
$currentContext = kubectl config current-context 2>$null
if ($currentContext -ne "minikube") {
    Write-Warning "Current kubectl context is '$currentContext', expected 'minikube'."
    $proceed = Read-Host "Proceed anyway? (y/N)"
    if ($proceed -notmatch "^[yY]$") {
        Write-Error "Execution cancelled. Switch context with 'kubectl config use-context minikube'."
        exit 1
    }
}

# 2. Verify Docker Hub Registry Secret
Write-Host "Verifying registry authentication secret (dockerhub-auth)..." -ForegroundColor Cyan
$secretExists = kubectl get secret dockerhub-auth -n "$Namespace" --ignore-not-found -o jsonpath='{.metadata.name}' 2>$null
if (-not $secretExists) {
    Write-Error "Secret 'dockerhub-auth' was not found in namespace '$Namespace'. Run '.\scripts\setup-registry-secret.ps1' first to configure credentials."
    exit 1
}

# 3. Apply Tekton Prerequisite Manifests (PVC, RBAC, Tasks, Pipeline)
Write-Host "`nApplying Tekton Pipeline Infrastructure..." -ForegroundColor Cyan
kubectl apply -f (Join-Path $projectRoot "tekton\pvc.yaml") -n "$Namespace"
kubectl apply -f (Join-Path $projectRoot "tekton\rbac.yaml") -n "$Namespace"
kubectl apply -f (Join-Path $projectRoot "tekton\tasks.yaml") -n "$Namespace"
kubectl apply -f (Join-Path $projectRoot "tekton\pipeline.yaml") -n "$Namespace"

# 4. Generate Uniquely Named PipelineRun Manifest
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$pipelineRunName = "release-console-run-$($ImageTag.ToLower())-$timestamp"

Write-Host "`nConstructing PipelineRun: $pipelineRunName..." -ForegroundColor Cyan

$pipelineRunManifest = @"
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: $pipelineRunName
  namespace: $Namespace
  labels:
    app: release-console
    tier: pipeline-execution
    release.version: "$ImageTag"
spec:
  pipelineRef:
    name: release-console-pipeline
  taskRunTemplate:
    serviceAccountName: release-console-pipeline-sa
  params:
    - name: repo-url
      value: "$RepoUrl"
    - name: revision
      value: "$Revision"
    - name: dockerhub-username
      value: "$DockerHubUsername"
    - name: image-tag
      value: "$ImageTag"
    - name: demo-fail-tests
      value: "$demoFailTestsValue"
  workspaces:
    - name: shared-workspace
      persistentVolumeClaim:
        claimName: release-console-pvc
    - name: docker-credentials
      secret:
        secretName: dockerhub-auth
"@

$tempRunFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "$pipelineRunName.yaml")
try {
    [System.IO.File]::WriteAllText($tempRunFile, $pipelineRunManifest, [System.Text.Encoding]::UTF8)
    
    Write-Host "Submitting PipelineRun to Kubernetes cluster..." -ForegroundColor Cyan
    kubectl apply -f "$tempRunFile" -n "$Namespace"

    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host " PipelineRun successfully triggered: $pipelineRunName" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    
    Write-Host "`nUseful commands to monitor execution:" -ForegroundColor Cyan
    Write-Host "  1. Watch overall PipelineRun status:" -ForegroundColor Gray
    Write-Host "     kubectl get pipelinerun $pipelineRunName -n $Namespace" -ForegroundColor White
    Write-Host ""
    Write-Host "  2. List individual TaskRuns:" -ForegroundColor Gray
    Write-Host "     kubectl get taskruns -l tekton.dev/pipelineRun=$pipelineRunName -n $Namespace" -ForegroundColor White
    Write-Host ""
    Write-Host "  3. Stream logs of running Task Pods:" -ForegroundColor Gray
    Write-Host "     kubectl get pods -l tekton.dev/pipelineRun=$pipelineRunName -n $Namespace" -ForegroundColor White
    Write-Host "     kubectl logs -f <pod-name> --all-containers -n $Namespace" -ForegroundColor White
    Write-Host ""
    Write-Host "  4. Verify application deployment upon completion:" -ForegroundColor Gray
    Write-Host "     .\scripts\verify-deployment.ps1 -ExpectedTag $ImageTag" -ForegroundColor White

} finally {
    if (Test-Path $tempRunFile) {
        Remove-Item -Path $tempRunFile -Force -ErrorAction SilentlyContinue
    }
}

```

---

## 15. `scripts/setup-registry-secret.ps1`

**Path:** `scripts/setup-registry-secret.ps1`  
**Language:** `powershell`

```powershell
<#
.SYNOPSIS
    Securely configures the Kubernetes Secret for Docker Hub authentication.
.DESCRIPTION
    Prompts for Docker Hub username and personal access token (PAT), formats
    standard Docker config JSON, and applies the Secret to the local Kubernetes cluster
    without committing or leaking credentials to disk or console.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [string]$Namespace = "default"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Docker Hub Registry Secret Setup for Kaniko & Tekton" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Note: It is strongly recommended to use a Docker Hub Personal Access" -ForegroundColor Gray
Write-Host "Token (Read & Write permissions) rather than your main account password." -ForegroundColor Gray
Write-Host ""

if ([string]::IsNullOrWhiteSpace($Username)) {
    $Username = Read-Host "Enter Docker Hub Username"
}

# Clean and sanitize username input (remove control characters and extract from command if pasted)
if ($Username) {
    $Username = ($Username -replace '[\x00-\x1F\x7F]', '').Trim()
    if ($Username -match '(?i)(?:-u|--username)\s+([a-zA-Z0-9_-]+)') {
        $Username = $Matches[1]
    }
}

if ([string]::IsNullOrWhiteSpace($Username) -or $Username -notmatch '^[a-zA-Z0-9_-]{3,30}$') {
    Write-Error "Invalid Docker Hub username '$Username'. A valid Docker Hub username must be 3-30 alphanumeric characters, underscores, or hyphens with no spaces."
    exit 1
}

$secureToken = Read-Host "Enter Docker Hub Access Token (input hidden)" -AsSecureString
if (-not $secureToken) {
    Write-Error "Access Token cannot be blank."
    exit 1
}

$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
$plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

if ([string]::IsNullOrWhiteSpace($plainToken)) {
    Write-Error "Access Token cannot be blank."
    exit 1
}

# Construct standard Docker auth base64
$pair = "${Username}:${plainToken}"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
$base64Auth = [Convert]::ToBase64String($bytes)

# Generate standard Docker config JSON
$dockerConfig = @{
    auths = @{
        "https://index.docker.io/v1/" = @{
            auth = $base64Auth
        }
    }
} | ConvertTo-Json -Compress

# Generate a valid, unique temporary file on disk
$tempFile = [System.IO.Path]::GetTempFileName()

try {
    # CRITICAL: Write strictly UTF-8 WITHOUT Byte Order Mark (BOM)
    # Kaniko's Go json parser rejects the 0xEF, 0xBB, 0xBF BOM with:
    # "invalid character 'ï' looking for beginning of value"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $dockerConfigBytes = $utf8NoBom.GetBytes($dockerConfig)
    [System.IO.File]::WriteAllBytes($tempFile, $dockerConfigBytes)

    # Sanity check: Ensure file starts with '{' (0x7B) and strictly NO BOM (0xEF, 0xBB, 0xBF)
    $headerBytes = [System.IO.File]::ReadAllBytes($tempFile)
    if ($headerBytes.Length -lt 2 -or $headerBytes[0] -ne 0x7B) {
        Write-Error "Encoding check failed: Temporary file contains BOM or does not begin with '{' (0x7B)."
        exit 1
    }

    Write-Host "`nUpdating Kubernetes Secret 'dockerhub-auth' in namespace '$Namespace'..." -ForegroundColor Cyan

    # Remove previous Secret to purge any obsolete keys (e.g., .dockerconfigjson)
    $null = kubectl delete secret dockerhub-auth --namespace="$Namespace" --ignore-not-found 2>&1

    # Create clean Secret containing exclusively the config.json key for Kaniko (/kaniko/.docker/config.json)
    $applyResult = kubectl create secret generic dockerhub-auth `
        --from-file=config.json="$tempFile" `
        --namespace="$Namespace" 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create Kubernetes secret 'dockerhub-auth': $applyResult"
        exit 1
    }

    # Verify secret exists and contains exclusively the config.json key
    $secretKeys = kubectl get secret dockerhub-auth --namespace="$Namespace" -o jsonpath='{.data}' 2>&1
    if ($LASTEXITCODE -ne 0 -or $secretKeys -notmatch 'config\.json') {
        Write-Error "Kubernetes secret verification failed: Secret does not contain expected config.json key: $secretKeys"
        exit 1
    }

    Write-Host "SUCCESS: Secret 'dockerhub-auth' created and verified in namespace '$Namespace'." -ForegroundColor Green
    Write-Host "Configured for Docker Hub user: $Username" -ForegroundColor Green
    Write-Host "Secret contains UTF-8 (No BOM) config.json ready for Kaniko." -ForegroundColor Green

} finally {
    # Secure cleanup of temporary file and in-memory variables
    if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }
    $plainToken = $null
    $pair = $null
    $base64Auth = $null
    $dockerConfig = $null
    [System.GC]::Collect()
}

Write-Host "==========================================================" -ForegroundColor Cyan

```

---

## 16. `scripts/validate-project.ps1`

**Path:** `scripts/validate-project.ps1`  
**Language:** `powershell`

```powershell
<#
.SYNOPSIS
    Validates project integrity, runs automated unit tests, and verifies Kubernetes/Tekton YAML syntax.
.DESCRIPTION
    Ensures that Node.js code compiles, unit tests pass cleanly, lockfiles are synchronized,
    and all Kubernetes and Tekton manifest structures are compliant.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Release Console: Project Integrity & Test Validation" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$projectRoot = Split-Path -Parent $PSScriptRoot
$failures = 0

# 1. Verify Expected File Structure
Write-Host "`n[Check 1/4] Verifying File Structure..." -ForegroundColor Cyan
$requiredFiles = @(
    "src\index.js",
    "public\index.html",
    "public\styles.css",
    "public\app.js",
    "test\app.test.js",
    "package.json",
    "package-lock.json",
    "Dockerfile",
    ".dockerignore",
    ".gitignore",
    "k8s\deployment.yaml",
    "k8s\service.yaml",
    "tekton\pvc.yaml",
    "tekton\rbac.yaml",
    "tekton\tasks.yaml",
    "tekton\pipeline.yaml",
    "tekton\pipelinerun-template.yaml"
)

foreach ($relPath in $requiredFiles) {
    $fullPath = Join-Path $projectRoot $relPath
    if (Test-Path $fullPath) {
        Write-Host "  [OK] $relPath" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $relPath" -ForegroundColor Red
        $failures++
    }
}

# 2. Validate JavaScript Syntax via Node.js
Write-Host "`n[Check 2/4] Validating JavaScript Code Syntax..." -ForegroundColor Cyan
$jsFiles = @(
    "src\index.js",
    "public\app.js",
    "test\app.test.js"
)

foreach ($relPath in $jsFiles) {
    $fullPath = Join-Path $projectRoot $relPath
    try {
        $check = node --check "$fullPath" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] $relPath syntax is valid" -ForegroundColor Green
        } else {
            Write-Host "  [SYNTAX ERROR] $relPath`: $check" -ForegroundColor Red
            $failures++
        }
    } catch {
        Write-Host "  [ERROR] Failed to run node --check on $relPath`: $_" -ForegroundColor Red
        $failures++
    }
}

# 3. Execute Automated Unit Tests (node:test)
Write-Host "`n[Check 3/4] Running Automated Unit Tests..." -ForegroundColor Cyan
Push-Location $projectRoot
try {
    $testOutput = npm test 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host $testOutput -ForegroundColor Gray
        Write-Host "  [OK] All automated unit tests passed successfully!" -ForegroundColor Green
    } else {
        Write-Host $testOutput -ForegroundColor Red
        Write-Host "  [TEST FAILURE] Unit tests did not pass." -ForegroundColor Red
        $failures++
    }
} finally {
    Pop-Location
}

# 4. Validate Kubernetes and Tekton YAML Manifests
Write-Host "`n[Check 4/4] Validating Kubernetes & Tekton Manifests..." -ForegroundColor Cyan
$yamlFiles = @(
    "k8s\deployment.yaml",
    "k8s\service.yaml",
    "tekton\pvc.yaml",
    "tekton\rbac.yaml",
    "tekton\tasks.yaml",
    "tekton\pipeline.yaml",
    "tekton\pipelinerun-template.yaml"
)

foreach ($relPath in $yamlFiles) {
    $fullPath = Join-Path $projectRoot $relPath
    if (-not (Test-Path $fullPath)) {
        Write-Host "  [FILE NOT FOUND] $relPath" -ForegroundColor Red
        $failures++
        continue
    }

    $content = Get-Content -Path $fullPath -Raw

    # Extract apiVersion immediately after match to ensure $Matches contains group 1
    $apiVersion = $null
    if ($content -match "(?m)^\s*apiVersion:\s*([^\r\n#]+)") {
        $apiVersion = $Matches[1].Trim().Trim('"').Trim("'")
    }

    # Extract kind immediately after match
    $kind = $null
    if ($content -match "(?m)^\s*kind:\s*([^\r\n#]+)") {
        $kind = $Matches[1].Trim().Trim('"').Trim("'")
    }

    # Check for metadata block
    $hasMetadata = $content -match "(?m)^\s*metadata:"

    # Validate that apiVersion, kind, and metadata exist and are non-empty
    if (-not [string]::IsNullOrWhiteSpace($apiVersion) -and -not [string]::IsNullOrWhiteSpace($kind) -and $hasMetadata) {
        Write-Host "  [OK] $relPath (apiVersion: $apiVersion, kind: $kind)" -ForegroundColor Green
    } else {
        $missingComponents = @()
        if ([string]::IsNullOrWhiteSpace($apiVersion)) { $missingComponents += "apiVersion" }
        if ([string]::IsNullOrWhiteSpace($kind)) { $missingComponents += "kind" }
        if (-not $hasMetadata) { $missingComponents += "metadata" }
        Write-Host "  [INVALID YAML FORMAT] $relPath missing: $($missingComponents -join ', ')" -ForegroundColor Red
        $failures++
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
if ($failures -eq 0) {
    Write-Host " Project Validation Succeeded! All checks and tests passed." -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host " Validation FAILED with $failures issue(s). Review above." -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Cyan
    exit 1
}

```

---

## 17. `scripts/verify-deployment.ps1`

**Path:** `scripts/verify-deployment.ps1`  
**Language:** `powershell`

```powershell
<#
.SYNOPSIS
    Verifies that the Release Console application is successfully deployed and operational.
.DESCRIPTION
    Checks Kubernetes Deployment rollout status, Pod readiness, active container image,
    NodePort service connectivity, and queries the live /healthz and /api/info endpoints.
.EXAMPLE
    .\scripts\verify-deployment.ps1 -ExpectedTag "v1"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ExpectedTag,

    [Parameter(Mandatory = $false)]
    [string]$Namespace = "default"
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Release Console: Live Deployment Verification" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Inspect PipelineRun status
Write-Host "`n[Check 1/6] Inspecting Recent PipelineRun Status..." -ForegroundColor Cyan
try {
    $latestRun = $null
    $allRuns = kubectl get pipelinerun -n "$Namespace" --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[*].metadata.name}' 2>$null
    if (-not [string]::IsNullOrWhiteSpace($allRuns)) {
        $runList = $allRuns.Trim().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($runList.Count -gt 0) {
            $latestRun = $runList[-1]
        }
    }

    if ($latestRun) {
        $runStatus = kubectl get pipelinerun "$latestRun" -n "$Namespace" -o jsonpath='{.status.conditions[0].status}:{.status.conditions[0].reason}' 2>$null
        Write-Host "  Latest PipelineRun: $latestRun" -ForegroundColor Gray
        Write-Host "  Status Condition:   $runStatus" -ForegroundColor $(if ($runStatus -like "True*") { "Green" } else { "Yellow" })
    } else {
        Write-Host "  No PipelineRun found yet in namespace '$Namespace'." -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Unable to query PipelineRuns: $_" -ForegroundColor Yellow
}

# 2. Check Deployment Rollout
Write-Host "`n[Check 2/6] Verifying Deployment Rollout Status..." -ForegroundColor Cyan
try {
    $rollout = kubectl rollout status deployment/release-console -n "$Namespace" --timeout=15s 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] $rollout" -ForegroundColor Green
    } else {
        Write-Host "  [NOT READY] Rollout did not report complete: $rollout" -ForegroundColor Red
    }
} catch {
    Write-Host "  [ERROR] Failed to query rollout status: $_" -ForegroundColor Red
}

# 3. Inspect Running Pods
Write-Host "`n[Check 3/6] Inspecting Pod Readiness..." -ForegroundColor Cyan
try {
    $pods = kubectl get pods -l app=release-console -n "$Namespace" -o wide 2>&1
    Write-Host $pods -ForegroundColor Gray
} catch {
    Write-Host "  Failed to query pods: $_" -ForegroundColor Red
}

# 4. Inspect Active Image Reference
Write-Host "`n[Check 4/6] Inspecting Active Deployed Container Image..." -ForegroundColor Cyan
try {
    $activeImage = kubectl get deployment release-console -n "$Namespace" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>$null
    if (-not [string]::IsNullOrWhiteSpace($activeImage)) {
        $activeImage = $activeImage.Trim()
        Write-Host "  Configured Image: $activeImage" -ForegroundColor White

        if ($ExpectedTag) {
            if ($activeImage -like "*:$ExpectedTag") {
                Write-Host "  [MATCH] Deployed image tag matches expected tag '$ExpectedTag'." -ForegroundColor Green
            } else {
                Write-Host "  [MISMATCH] Deployed image does not end with ':$ExpectedTag'." -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "  Deployment 'release-console' not yet created or active." -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Failed to query deployment image: $_" -ForegroundColor Red
}

# 5. Resolve NodePort Service URL
Write-Host "`n[Check 5/6] Resolving Service Access Endpoint..." -ForegroundColor Cyan
$minikubeIp = (minikube ip 2>$null)
if ($minikubeIp) {
    $minikubeIp = $minikubeIp.Trim()
}

$nodePort = (kubectl get service release-console-service -n "$Namespace" -o jsonpath='{.spec.ports[0].nodePort}' 2>$null)
if ($nodePort) {
    $nodePort = $nodePort.Trim()
} else {
    $nodePort = "30080"
}

$serviceUrl = ""
if ($minikubeIp) {
    $serviceUrl = "http://${minikubeIp}:${nodePort}"
    Write-Host "  Minikube Direct Access URL: $serviceUrl" -ForegroundColor Green
} else {
    Write-Host "  Minikube IP not resolved. You can establish port-forwarding:" -ForegroundColor Yellow
    Write-Host "  Run: kubectl port-forward svc/release-console-service 3000:3000 -n $Namespace" -ForegroundColor Gray
    $serviceUrl = "http://localhost:3000"
}

# 6. Perform Live HTTP Health & Info Checks
Write-Host "`n[Check 6/6] Executing HTTP Probes against $serviceUrl..." -ForegroundColor Cyan
if ($serviceUrl) {
    try {
        Write-Host "  Probing GET $serviceUrl/healthz..." -NoNewline
        $healthResponse = Invoke-RestMethod -Uri "$serviceUrl/healthz" -Method Get -TimeoutSec 5 -ErrorAction Stop
        Write-Host " [OK 200]" -ForegroundColor Green
        Write-Host "    Response: $($healthResponse | ConvertTo-Json -Compress)" -ForegroundColor Gray

        Write-Host "  Probing GET $serviceUrl/api/info..." -NoNewline
        $infoResponse = Invoke-RestMethod -Uri "$serviceUrl/api/info" -Method Get -TimeoutSec 5 -ErrorAction Stop
        Write-Host " [OK 200]" -ForegroundColor Green
        Write-Host "    Version:     $($infoResponse.version)" -ForegroundColor White
        Write-Host "    Commit:      $($infoResponse.commit)" -ForegroundColor White
        Write-Host "    Environment: $($infoResponse.environment)" -ForegroundColor White
        Write-Host "    Uptime:      $($infoResponse.uptimeSeconds) seconds" -ForegroundColor Gray

        if ($ExpectedTag -and $infoResponse.version -eq $ExpectedTag) {
            Write-Host "`n  >>> SUCCESS: Live application version '$($infoResponse.version)' matches expected release '$ExpectedTag'!" -ForegroundColor Green
        }

    } catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "  Could not reach $serviceUrl - $($_.Exception.Message)" -ForegroundColor Yellow

        # Fallback check on localhost:3000 if port forwarding is active
        if ($serviceUrl -ne "http://localhost:3000") {
            Write-Host "  Checking fallback on http://localhost:3000 (port-forwarding)..." -NoNewline
            try {
                $fallbackHealth = Invoke-RestMethod -Uri "http://localhost:3000/healthz" -Method Get -TimeoutSec 3 -ErrorAction Stop
                Write-Host " [CONNECTED]" -ForegroundColor Green
                Write-Host "    Application is accessible via port-forwarding on http://localhost:3000" -ForegroundColor Green
                $serviceUrl = "http://localhost:3000"
            } catch {
                Write-Host " [UNREACHABLE]" -ForegroundColor Gray
                Write-Host "  Hint: If Minikube Docker network is not directly routable from Windows host, run:" -ForegroundColor Gray
                Write-Host "    kubectl port-forward svc/release-console-service 3000:3000 -n $Namespace" -ForegroundColor White
                Write-Host "  Then open: http://localhost:3000" -ForegroundColor Gray
            }
        }
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " Verification Check Complete." -ForegroundColor Cyan
Write-Host " Open $serviceUrl in your browser to view the Release Console." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

```

---

## 18. `src/index.js`

**Path:** `src/index.js`  
**Language:** `javascript`

```javascript
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
    title: 'Quality gates passed — candidate ready',
    summary: 'Source checkout succeeds, tests pass, image build and publishing succeed, and deployment completes. (Simulation only: does not run real Tekton Tasks or change the real cluster).',
    priorVersionPreserved: false,
    stages: [
      { name: 'Unit tests', status: 'passed', detail: 'Automated test suite passed clean quality gate.' },
      { name: 'Build and publish image', status: 'passed', detail: 'Kaniko builds and publishes the versioned container image to Docker Hub.' },
      { name: 'Kubernetes rollout', status: 'ready', detail: 'Rolling update deployment completes and pod readiness probes verify health.' }
    ]
  },
  'test-failure': {
    outcome: 'blocked',
    title: 'Candidate blocked at test gate',
    summary: 'Source checkout succeeds, tests fail, image creation and deployment are blocked, and the existing deployment remains unchanged.',
    priorVersionPreserved: true,
    stages: [
      { name: 'Unit tests', status: 'failed', detail: 'A regression was detected by the test suite; pipeline halts immediately.' },
      { name: 'Build and publish image', status: 'blocked', detail: 'Blocked because the test Task failed; Kaniko image build never runs.' },
      { name: 'Kubernetes rollout', status: 'skipped', detail: 'Skipped; currently deployed cluster version remains completely untouched.' }
    ]
  },
  'rollout-failure': {
    outcome: 'recovered',
    title: 'Failed rollout — rollback recovery attempted',
    summary: 'Tests and image build succeed, the new rollout fails, and Kubernetes attempts to restore the previous Deployment revision if one is available. Recovery itself can fail if no prior revision exists. The pipeline reports failure.',
    priorVersionPreserved: true,
    stages: [
      { name: 'Unit tests', status: 'passed', detail: 'Candidate passed the automated test gate.' },
      { name: 'Build and publish image', status: 'passed', detail: 'Candidate container image was built and published to Docker Hub.' },
      { name: 'Kubernetes rollout', status: 'failed', detail: 'Candidate pod failed readiness probes or rollout timed out.' },
      { name: 'Rollback', status: 'restored', detail: 'Kubernetes attempts rollout undo to restore prior revision if available; recovery can fail if no prior revision exists.' }
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

      const noCacheExts = ['.html', '.css', '.js'];
      res.writeHead(200, {
        'Content-Type': contentType,
        'Content-Length': stats.size,
        'X-Content-Type-Options': 'nosniff',
        'Cache-Control': noCacheExts.includes(ext)
          ? 'no-cache, must-revalidate'
          : 'public, max-age=3600'
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

```

---

## 19. `tekton/pipeline.yaml`

**Path:** `tekton/pipeline.yaml`  
**Language:** `yaml`

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: release-console-pipeline
  namespace: default
  labels:
    app: release-console
    tier: cicd-pipeline
spec:
  description: End-to-end non-cloud CI/CD pipeline executing clone, testing, Kaniko container build, and Kubernetes deployment.
  params:
    - name: repo-url
      type: string
      description: Public Git repository URL hosting the Release Console application
    - name: revision
      type: string
      default: main
      description: Git branch, tag, or commit to build
    - name: dockerhub-username
      type: string
      description: Docker Hub username for image publishing and container pull
    - name: image-tag
      type: string
      default: v1
      description: Semantic release tag for the container image (e.g. v1, v2)
    - name: demo-fail-tests
      type: string
      default: "false"
      description: Deliberately inject one failing test to demonstrate pipeline gating
  workspaces:
    - name: shared-workspace
      description: Persistent storage shared across all pipeline tasks
    - name: docker-credentials
      description: Kubernetes secret containing Docker Hub registry authentication
  tasks:
    # Stage 1: Clone Git source code and capture commit SHA
    - name: fetch-source
      taskRef:
        name: clone-source
      workspaces:
        - name: source
          workspace: shared-workspace
      params:
        - name: url
          value: $(params.repo-url)
        - name: revision
          value: $(params.revision)

    # Stage 2: Quality Gate - Run npm ci and automated unit tests
    - name: run-tests
      taskRef:
        name: test-application
      runAfter:
        - fetch-source
      workspaces:
        - name: source
          workspace: shared-workspace
      params:
        - name: demo-fail-tests
          value: $(params.demo-fail-tests)

    # Stage 3: In-cluster OCI build using Kaniko and push to Docker Hub
    - name: build-push
      taskRef:
        name: build-and-push-image
      runAfter:
        - run-tests
      workspaces:
        - name: source
          workspace: shared-workspace
        - name: docker-credentials
          workspace: docker-credentials
      params:
        - name: image-reference
          value: docker.io/$(params.dockerhub-username)/release-console:$(params.image-tag)
        - name: app-version
          value: $(params.image-tag)
        - name: git-commit
          value: $(tasks.fetch-source.results.commit)

    # Stage 4: Kubernetes rolling update deployment and verification
    - name: deploy
      taskRef:
        name: deploy-application
      runAfter:
        - build-push
      workspaces:
        - name: source
          workspace: shared-workspace
      params:
        - name: image-reference
          value: docker.io/$(params.dockerhub-username)/release-console:$(params.image-tag)
        - name: app-version
          value: $(params.image-tag)
        - name: git-commit
          value: $(tasks.fetch-source.results.commit)
        - name: namespace
          value: default

```

---

## 20. `tekton/pipelinerun-template.yaml`

**Path:** `tekton/pipelinerun-template.yaml`  
**Language:** `yaml`

```yaml
﻿apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: release-console-run-
  namespace: default
  labels:
    app: release-console
    tier: pipeline-execution
spec:
  pipelineRef:
    name: release-console-pipeline
  taskRunTemplate:
    serviceAccountName: release-console-pipeline-sa
  params:
    - name: repo-url
      value: "https://github.com/balaji-devx/Tekton-Demo.git"
    - name: revision
      value: "main"
    - name: dockerhub-username
      value: "ba1aj1"
    - name: image-tag
      value: "v1"
    - name: demo-fail-tests
      value: "false"
  workspaces:
    - name: shared-workspace
      persistentVolumeClaim:
        claimName: release-console-pvc
    - name: docker-credentials
      secret:
        secretName: dockerhub-auth





```

---

## 21. `tekton/pvc.yaml`

**Path:** `tekton/pvc.yaml`  
**Language:** `yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: release-console-pvc
  namespace: default
  labels:
    app: release-console
    tier: pipeline-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: standard

```

---

## 22. `tekton/rbac.yaml`

**Path:** `tekton/rbac.yaml`  
**Language:** `yaml`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: release-console-pipeline-sa
  namespace: default
  labels:
    app: release-console
    tier: pipeline-rbac
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: release-console-deployer-role
  namespace: default
  labels:
    app: release-console
rules:
  - apiGroups: ["apps"]
    resources: ["deployments", "deployments/status"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: ["apps"]
    resources: ["replicasets", "replicasets/status"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["services", "pods", "pods/log", "pods/status"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: release-console-deployer-binding
  namespace: default
  labels:
    app: release-console
subjects:
  - kind: ServiceAccount
    name: release-console-pipeline-sa
    namespace: default
roleRef:
  kind: Role
  name: release-console-deployer-role
  apiGroup: rbac.authorization.k8s.io

```

---

## 23. `tekton/tasks.yaml`

**Path:** `tekton/tasks.yaml`  
**Language:** `yaml`

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: clone-source
  namespace: default
  labels:
    app: release-console
    tier: pipeline-task
spec:
  description: Clones the public Git repository and outputs the commit SHA
  params:
    - name: url
      type: string
      description: The public Git repository URL
    - name: revision
      type: string
      default: main
      description: The Git revision (branch, tag, or commit SHA)
    - name: subdirectory
      type: string
      default: release-console
      description: Subdirectory in workspace to clone into
  results:
    - name: commit
      description: The Git commit SHA extracted from the clone
  workspaces:
    - name: source
      description: Shared PersistentVolume workspace
  steps:
    - name: clone-and-extract-sha
      image: alpine/git:v2.45.2
      script: |
        #!/bin/sh
        set -eu
        TARGET_DIR="$(workspaces.source.path)/$(params.subdirectory)"
        echo "=========================================================="
        echo " [Task: clone-source] Cloning repository"
        echo " URL:      $(params.url)"
        echo " Revision: $(params.revision)"
        echo " Target:   ${TARGET_DIR}"
        echo "=========================================================="

        if [ -d "${TARGET_DIR}" ]; then
          echo "Cleaning previous checkout directory..."
          rm -rf "${TARGET_DIR}"
        fi

        mkdir -p "${TARGET_DIR}"
        git clone --branch "$(params.revision)" --depth 1 "$(params.url)" "${TARGET_DIR}"

        cd "${TARGET_DIR}"
        COMMIT_SHA=$(git rev-parse HEAD)
        echo "Successfully checked out commit: ${COMMIT_SHA}"

        # Write result to Tekton output path
        printf "%s" "${COMMIT_SHA}" > "$(results.commit.path)"
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: test-application
  namespace: default
  labels:
    app: release-console
    tier: pipeline-task
spec:
  description: Installs dependencies and executes automated unit test suite
  params:
    - name: subdirectory
      type: string
      default: release-console
      description: Subdirectory in workspace containing the project
    - name: demo-fail-tests
      type: string
      default: "false"
      description: Enable a deliberate failing test for the failure-gate demonstration only
  workspaces:
    - name: source
      description: Shared PersistentVolume workspace
  steps:
    - name: run-unit-tests
      image: node:20-alpine
      env:
        - name: DEMO_FORCE_TEST_FAILURE
          value: "$(params.demo-fail-tests)"
      script: |
        #!/bin/sh
        set -eu
        APP_DIR="$(workspaces.source.path)/$(params.subdirectory)"
        echo "=========================================================="
        echo " [Task: test-application] Quality Gate & Automated Testing"
        echo " Directory: ${APP_DIR}"
        echo "=========================================================="

        cd "${APP_DIR}"

        echo "--- Step 1: Clean Dependency Installation (npm ci) ---"
        npm ci

        echo "--- Step 2: Running Automated Unit Tests (node:test) ---"
        npm test

        echo "=========================================================="
        echo " [Task: test-application] ALL UNIT TESTS PASSED SUCCESSFULLY"
        echo "=========================================================="
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: build-and-push-image
  namespace: default
  labels:
    app: release-console
    tier: pipeline-task
spec:
  description: Builds container image via Kaniko in-cluster and pushes to Docker Hub
  params:
    - name: subdirectory
      type: string
      default: release-console
      description: Subdirectory in workspace containing the Dockerfile
    - name: image-reference
      type: string
      description: Complete destination image reference (e.g. docker.io/user/repo:tag)
    - name: app-version
      type: string
      description: Application release version injected as build arg
    - name: git-commit
      type: string
      description: Git commit SHA injected as build arg
  workspaces:
    - name: source
      description: Shared PersistentVolume workspace
    - name: docker-credentials
      description: Mounted docker config secret containing registry credentials
      mountPath: /kaniko/.docker
  steps:
    - name: build-and-push
      image: martizih/kaniko:v1.28.6
      args:
        - --dockerfile=$(workspaces.source.path)/$(params.subdirectory)/Dockerfile
        - --context=dir://$(workspaces.source.path)/$(params.subdirectory)
        - --destination=$(params.image-reference)
        - --build-arg=APP_VERSION=$(params.app-version)
        - --build-arg=GIT_COMMIT=$(params.git-commit)
        - --cache=false
        - --skip-unused-stages=true
        - --verbosity=info
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: deploy-application
  namespace: default
  labels:
    app: release-console
    tier: pipeline-task
spec:
  description: Deploys updated container image to Kubernetes and monitors rollout status
  params:
    - name: subdirectory
      type: string
      default: release-console
      description: Subdirectory in workspace containing Kubernetes manifests
    - name: image-reference
      type: string
      description: Container image reference to deploy
    - name: app-version
      type: string
      description: Semantic release version for metadata
    - name: git-commit
      type: string
      description: Git commit SHA for metadata
    - name: namespace
      type: string
      default: default
      description: Target Kubernetes namespace
  workspaces:
    - name: source
      description: Shared PersistentVolume workspace
  steps:
    - name: apply-and-verify-rollout
      image: alpine/k8s:1.37.0
      script: |
        #!/bin/sh
        set -eu
        K8S_DIR="$(workspaces.source.path)/$(params.subdirectory)/k8s"
        echo "=========================================================="
        echo " [Task: deploy-application] Kubernetes Deployment Rollout"
        echo " Target Namespace: $(params.namespace)"
        echo " Target Image:     $(params.image-reference)"
        echo " Release Version:  $(params.app-version)"
        echo " Git Commit:       $(params.git-commit)"
        echo "=========================================================="

        cd "${K8S_DIR}"

        # Record whether a prior release exists before changing the Deployment.
        PREVIOUS_DEPLOYMENT="false"
        PREVIOUS_IMAGE=""
        if kubectl get deployment release-console -n "$(params.namespace)" >/dev/null 2>&1; then
          PREVIOUS_DEPLOYMENT="true"
          PREVIOUS_IMAGE="$(kubectl get deployment release-console -n "$(params.namespace)" -o jsonpath='{.spec.template.spec.containers[?(@.name=="release-console")].image}' 2>/dev/null || true)"
          echo "Previous deployment detected; previous image: ${PREVIOUS_IMAGE}"
        else
          echo "No previous deployment exists; rollback will not be possible on a first install."
        fi

        # Deterministically template deployment manifest with pipeline image & metadata
        echo "Preparing deployment manifest..."
        sed -e "s|DOCKERHUB_USERNAME/release-console:v1|$(params.image-reference)|g" \
            -e "s|value: \"v1\"|value: \"$(params.app-version)\"|g" \
            -e "s|value: \"commit-sha-placeholder\"|value: \"$(params.git-commit)\"|g" \
            deployment.yaml > /tmp/deployment.yaml

        echo "Applying Service definition..."
        kubectl apply -f service.yaml -n "$(params.namespace)"

        echo "Applying Deployment definition..."
        kubectl apply -f /tmp/deployment.yaml -n "$(params.namespace)"

        echo "Waiting for Deployment rollout to complete (timeout: 120s)..."
        if kubectl rollout status deployment/release-console -n "$(params.namespace)" --timeout=120s; then
          echo "=========================================================="
          echo " [Task: deploy-application] Rollout Completed Successfully"
          echo "=========================================================="
        else
          echo "ERROR: Candidate rollout failed. The Task will attempt to restore the previous revision."
          if [ "${PREVIOUS_DEPLOYMENT}" = "true" ] && [ -n "${PREVIOUS_IMAGE}" ]; then
            if kubectl rollout undo deployment/release-console -n "$(params.namespace)"; then
              if kubectl rollout status deployment/release-console -n "$(params.namespace)" --timeout=120s; then
                echo "ROLLBACK VERIFIED: previous Deployment revision is available again."
              else
                echo "ERROR: Rollback was requested, but its rollout did not become ready."
              fi
            else
              echo "ERROR: Kubernetes could not roll back to the previous Deployment revision."
            fi
          else
            echo "No prior Deployment revision is available to restore."
          fi
          # Keep the PipelineRun failed so an unsuccessful release is never reported as green.
          exit 1
        fi
        kubectl get deployment,pods,services -l app=release-console -n "$(params.namespace)"

```

---

## 24. `test/app.test.js`

**Path:** `test/app.test.js`  
**Language:** `javascript`

```javascript
/**
 * Release Console - Automated Unit & Integration Tests
 * Validates HTTP contract, health endpoints, static delivery, and failure safety.
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

  test('Static asset cache headers: CSS and JS served with no-cache, must-revalidate', async () => {
    const cssRes = await makeRequest('/styles.css?v=resilience-lab-2');
    assert.equal(cssRes.statusCode, 200);
    assert.match(cssRes.headers['content-type'], /text\/css/);
    assert.equal(cssRes.headers['cache-control'], 'no-cache, must-revalidate');

    const jsRes = await makeRequest('/app.js?v=resilience-lab-2');
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

```

---
