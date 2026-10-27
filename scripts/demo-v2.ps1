<#
.SYNOPSIS
    Stage 2: Deploys the V2 feature release with a visible DevOps Arena update.
.DESCRIPTION
    Validates V1 baseline state, verifies V1 is active, updates DevOps Arena description
    in public/index.html to 'V2 release: updated challenge instructions', executes local
    unit tests, commits/pushes the change to GitHub, triggers the Tekton pipeline for tag 'v2',
    verifies the rollout, and records V2 image, revision, and PipelineRun in .demo-release-state.json.
.EXAMPLE
    .\scripts\demo-v2.ps1
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
Write-Host " DEMO STAGE 2: Deploy V2 Feature Release" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify Prerequisites
Test-DemoPrerequisites -Namespace $Namespace

# 2. Read and Validate Saved V1 State
Write-Host "`n[1/6] Validating recorded V1 baseline state..." -ForegroundColor Cyan
$state = Get-DemoState
if (-not $state.v1 -or -not $state.v1.revision -or -not $state.v1.image) {
    throw "V1 baseline state not found in .demo-release-state.json. Run .\scripts\demo-v1.ps1 first to establish the baseline."
}
Write-Host "  Found recorded V1 state: Image=$($state.v1.image), Revision=$($state.v1.revision)" -ForegroundColor Green

# 3. Verify V1 is currently running
Write-Host "`n[2/6] Verifying currently deployed Kubernetes image..." -ForegroundColor Cyan
$currentImage = Get-ActiveDeploymentImage -Namespace $Namespace
if ($currentImage -ne $state.v1.image -and $currentImage -ne "docker.io/$DockerHubUsername/release-console:v2") {
    Write-Warning "Active image is '$currentImage', expected V1 image '$($state.v1.image)'."
} else {
    Write-Host "  Active image verified: $currentImage" -ForegroundColor Green
}

# 4. Make visible application change to DevOps Arena
Write-Host "`n[3/6] Applying V2 visible UI change to DevOps Arena in public/index.html..." -ForegroundColor Cyan
$currentDesc = Get-ArenaReleaseDescription
$v1ExpectedDesc = "V1 baseline: test your CI/CD knowledge across Docker, Kubernetes, and Tekton."
$v2ExpectedDesc = "V2 release: updated challenge instructions"

if ($currentDesc -ne $v1ExpectedDesc -and $currentDesc -ne $v2ExpectedDesc) {
    Write-Warning "Existing description is unexpected: '$currentDesc'"
}

$htmlChanged = Set-ArenaReleaseDescription -NewText $v2ExpectedDesc

# 5. Run Automated Unit Tests locally before committing
Write-Host "`n[4/6] Executing local unit tests (node --test test/app.test.js)..." -ForegroundColor Cyan
Push-Location $repoRoot
try {
    $testOutput = & node --test test/app.test.js 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host $testOutput -ForegroundColor Red
        throw "Unit tests failed prior to commit. Aborting V2 release to preserve quality gate."
    }
    Write-Host "  [OK] All unit tests passed locally." -ForegroundColor Green
} finally {
    Pop-Location
}

# 6. Commit and Push V2 application change only
if ($htmlChanged) {
    Write-Host "`n[5/6] Committing and pushing V2 UI update to GitHub..." -ForegroundColor Cyan
    Commit-And-Push-File -FilesToStage @("public\index.html") -CommitMessage "feat(demo): update DevOps Arena description for V2"
} else {
    Write-Host "`n[5/6] V2 UI update already committed and present." -ForegroundColor Green
}

# 7. Invoke and Monitor Tekton Pipeline for tag 'v2'
Write-Host "`n[6/6] Launching and monitoring Tekton PipelineRun for tag 'v2'..." -ForegroundColor Cyan
$pipelineResult = Invoke-And-Monitor-Pipeline `
    -ImageTag "v2" `
    -RepoUrl $RepoUrl `
    -DockerHubUsername $DockerHubUsername `
    -Revision "main" `
    -Namespace $Namespace `
    -TimeoutSeconds 900

# 8. Wait for Kubernetes Deployment Rollout
$expectedImage = "docker.io/$DockerHubUsername/release-console:v2"
Wait-DeploymentRollout -ExpectedImage $expectedImage -TimeoutSeconds 180 -Namespace $Namespace

# 9. Record V2 state
$v2ActiveImage = Get-ActiveDeploymentImage -Namespace $Namespace
$v2ActiveRevision = Get-ActiveDeploymentRevision -Namespace $Namespace

if ($v2ActiveImage -ne $expectedImage) {
    throw "Active image is '$v2ActiveImage', expected '$expectedImage'."
}

$state = Get-DemoState
$state["v2"] = [ordered]@{
    image       = $v2ActiveImage
    revision    = $v2ActiveRevision
    pipelineRun = $pipelineResult.PipelineRunName
    commit      = $pipelineResult.CommitSha
    completedAt = (Get-Date).ToUniversalTime().ToString("o")
}
$state["latestStage"] = "v2"
Save-DemoState -State $state

# 10. Success Output
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " DEMO STAGE 2 COMPLETE: V2 Feature Release Deployed!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Deployed Image:       $v2ActiveImage" -ForegroundColor White
Write-Host "  V1 Baseline Revision: $($state.v1.revision)" -ForegroundColor White
Write-Host "  V2 Current Revision:  $v2ActiveRevision" -ForegroundColor White
Write-Host "  PipelineRun:          $($pipelineResult.PipelineRunName)" -ForegroundColor White
Write-Host "  Source Commit SHA:    $($pipelineResult.CommitSha)" -ForegroundColor White
Write-Host "  State Recorded In:    $(Get-DemoStateFilePath)" -ForegroundColor Gray
Write-Host "`nNext Step: Run '.\scripts\demo-v3-failure.ps1' to demonstrate the automated quality gate." -ForegroundColor Cyan
