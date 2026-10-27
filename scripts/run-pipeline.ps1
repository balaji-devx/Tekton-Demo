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
