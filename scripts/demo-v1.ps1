<#
.SYNOPSIS
    Stage 1: Establishes the V1 baseline release for the Tekton CI/CD demonstration.
.DESCRIPTION
    Verifies prerequisites, ensures imagePullPolicy is Always, sets the DevOps Arena
    baseline description, commits/pushes configuration changes, triggers the Tekton
    pipeline for tag 'v1', monitors rollout, verifies the active image, and records
    the baseline revision and image in .demo-release-state.json.
.EXAMPLE
    .\scripts\demo-v1.ps1
#>

[CmdletBinding()]
param(
    [string]$RepoUrl = "https://github.com/balaji-devx/Tekton-Demo.git",
    [string]$DockerHubUsername = "ba1aj1",
    [string]$Namespace = "default"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "demo-common.ps1")

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " DEMO STAGE 1: Deploy V1 Baseline Release" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify Prerequisites
Test-DemoPrerequisites -Namespace $Namespace

# 2. Ensure imagePullPolicy: Always
Write-Host "`n[1/5] Verifying Deployment manifest imagePullPolicy..." -ForegroundColor Cyan
$yamlChanged = Ensure-DeploymentPullPolicyAlways

# 3. Establish V1 baseline description in DevOps Arena UI
Write-Host "`n[2/5] Establishing V1 baseline description in public/index.html..." -ForegroundColor Cyan
$v1Desc = "V1 baseline: test your CI/CD knowledge across Docker, Kubernetes, and Tekton."
$htmlChanged = Set-ArenaReleaseDescription -NewText $v1Desc

# 4. Commit and push only intentional configuration changes if needed
$filesToCommit = @()
if ($yamlChanged) { $filesToCommit += "k8s\deployment.yaml" }
if ($htmlChanged) { $filesToCommit += "public\index.html" }

if ($filesToCommit.Count -gt 0) {
    Write-Host "`n[3/5] Pushing V1 baseline changes to GitHub..." -ForegroundColor Cyan
    Commit-And-Push-File -FilesToStage $filesToCommit -CommitMessage "feat(demo): establish V1 baseline in DevOps Arena"
} else {
    Write-Host "`n[3/5] V1 baseline and deployment configurations are already up-to-date on GitHub." -ForegroundColor Green
}

# 5. Invoke Tekton Pipeline for tag 'v1' and monitor to completion
Write-Host "`n[4/5] Launching and monitoring Tekton PipelineRun for tag 'v1'..." -ForegroundColor Cyan
$pipelineResult = Invoke-And-Monitor-Pipeline `
    -ImageTag "v1" `
    -RepoUrl $RepoUrl `
    -DockerHubUsername $DockerHubUsername `
    -Revision "main" `
    -Namespace $Namespace `
    -TimeoutSeconds 900

# 6. Wait for Kubernetes Deployment Rollout
Write-Host "`n[5/5] Verifying Kubernetes Deployment rollout..." -ForegroundColor Cyan
$expectedImage = "docker.io/$DockerHubUsername/release-console:v1"
Wait-DeploymentRollout -ExpectedImage $expectedImage -TimeoutSeconds 180 -Namespace $Namespace

# 7. Record V1 state
$v1ActiveImage = Get-ActiveDeploymentImage -Namespace $Namespace
$v1ActiveRevision = Get-ActiveDeploymentRevision -Namespace $Namespace

if ($v1ActiveImage -ne $expectedImage) {
    throw "Active image is '$v1ActiveImage', expected '$expectedImage'."
}
if (-not $v1ActiveRevision) {
    throw "Unable to query deployment revision annotation for release-console."
}

$state = Get-DemoState
$state["project"] = "Tekton-Demo"
$state["repository"] = $RepoUrl
$state["dockerHubUsername"] = $DockerHubUsername
$state["v1"] = [ordered]@{
    image       = $v1ActiveImage
    revision    = $v1ActiveRevision
    pipelineRun = $pipelineResult.PipelineRunName
    commit      = $pipelineResult.CommitSha
    completedAt = (Get-Date).ToUniversalTime().ToString("o")
}
$state["latestStage"] = "v1"
Save-DemoState -State $state

# 8. Success Output
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " DEMO STAGE 1 COMPLETE: V1 Baseline Successfully Deployed!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Deployed Image:       $v1ActiveImage" -ForegroundColor White
Write-Host "  Deployment Revision:  $v1ActiveRevision" -ForegroundColor White
Write-Host "  PipelineRun:          $($pipelineResult.PipelineRunName)" -ForegroundColor White
Write-Host "  Source Commit SHA:    $($pipelineResult.CommitSha)" -ForegroundColor White
Write-Host "  State Recorded In:    $(Get-DemoStateFilePath)" -ForegroundColor Gray
Write-Host "`nNext Step: Run '.\scripts\demo-v2.ps1' to deploy the V2 feature update." -ForegroundColor Cyan
