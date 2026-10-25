# Design and Implementation of a Non-Cloud CI/CD Pipeline Using Tekton, Docker and Kubernetes

## 1. Project Title and Objective

**Title:** Design and Implementation of a Non-Cloud CI/CD Pipeline Using Tekton, Docker and Kubernetes  
**Project Application:** Release Console  
**Domain:** DevOps, Cloud-Native Engineering, Container Orchestration  

The primary objective of this project is to design, implement, and demonstrate a completely functional, local Kubernetes-native Continuous Integration and Continuous Deployment (CI/CD) pipeline running on **Minikube** without reliance on managed cloud infrastructure (e.g., AWS, GCP, Azure). 

Using **Tekton Pipelines**, **Docker**, and **Kubernetes**, this project automates the entire software delivery lifecycle:
1. Cloning source code directly from a public Git repository upon developer commit.
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

### Step 2: Introduce an Intentional Test Failure
In `test/app.test.js`, edit line 70 to make an assertion deliberately fail:
```javascript
// Change:
assert.equal(res.statusCode, 200);
// To:
assert.equal(res.statusCode, 500); // Intentionally broken test
```

### Step 3: Push the Broken Test
```powershell
git commit -am "test: introduce intentional failing test for gate demonstration"
git push origin main
```

### Step 4: Run Pipeline with Tag `v2`
```powershell
.\scripts\run-pipeline.ps1 `
  -RepoUrl "https://github.com/YOUR_GITHUB_USERNAME/Tekton-Demo.git" `
  -DockerHubUsername "YOUR_DOCKERHUB_USERNAME" `
  -ImageTag "v2"
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

## 24. Official Technical References

- [Tekton Pipelines Documentation](https://tekton.dev/docs/pipelines/)
- [Kubernetes Documentation: Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Minikube Official Handbook](https://minikube.sigs.k8s.io/docs/)
- [Kaniko Container Engine (GitHub Archive & Reference)](https://github.com/GoogleContainerTools/kaniko)
- [Node.js Native Test Runner (node:test)](https://nodejs.org/api/test.html)
