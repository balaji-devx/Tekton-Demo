<#
.SYNOPSIS
    Stage 4: Rolls back the Kubernetes Deployment to the recorded V1 baseline revision.
.DESCRIPTION
    Validates saved V1 and V2 state, confirms the recorded V1 revision exists, executes
    targeted Kubernetes rollback with 'kubectl rollout undo --to-revision=<v1-revision>',
    waits for rollout completion, and verifies the restored deployment image matches V1.
.EXAMPLE
    .\scripts\demo-rollback-v1.ps1
#>

[CmdletBinding()]
param(
    [string]$Namespace = "default"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "demo-common.ps1")

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " DEMO STAGE 4: Roll Back Kubernetes Deployment to V1" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify Prerequisites
Test-DemoPrerequisites -Namespace $Namespace

# 2. Read and Validate Saved State
Write-Host "`n[1/4] Reading saved release state from .demo-release-state.json..." -ForegroundColor Cyan
$state = Get-DemoState

if (-not $state.v1 -or -not $state.v1.revision -or -not $state.v1.image) {
    throw "Recorded V1 baseline state missing from .demo-release-state.json. Rollback requires an explicit recorded V1 revision."
}

$v1TargetRevision = [string]$state.v1.revision
$v1TargetImage    = [string]$state.v1.image
$v2Image          = if ($state.v2) { [string]$state.v2.image } else { "" }

Write-Host "  Recorded V1 Baseline: Image=$v1TargetImage, Target Revision=$v1TargetRevision" -ForegroundColor Green
if ($v2Image) {
    Write-Host "  Recorded V2 Release:  Image=$v2Image, Revision=$($state.v2.revision)" -ForegroundColor Gray
}

# 3. Inspect Current Deployment State
Write-Host "`n[2/4] Inspecting current live Deployment state..." -ForegroundColor Cyan
$currentImage = Get-ActiveDeploymentImage -Namespace $Namespace
$currentRevision = Get-ActiveDeploymentRevision -Namespace $Namespace

Write-Host "  Live Active Image:    $currentImage" -ForegroundColor White
Write-Host "  Live Active Revision: $currentRevision" -ForegroundColor White

if ($currentImage -eq $v1TargetImage) {
    Write-Host "  Notice: Live deployment is already running image '$v1TargetImage'." -ForegroundColor Yellow
}

# 4. Execute Targeted Kubernetes Rollout Undo
Write-Host "`n[3/4] Executing: kubectl rollout undo deployment/release-console --to-revision=$v1TargetRevision..." -ForegroundColor Cyan
$undoCmd = "kubectl rollout undo deployment/release-console -n `"$Namespace`" --to-revision=$v1TargetRevision"
Write-Host "  Running: $undoCmd" -ForegroundColor Gray

$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$undoOutput = kubectl rollout undo deployment/release-console -n "$Namespace" --to-revision=$v1TargetRevision 2>&1
$undoExit = $LASTEXITCODE
$ErrorActionPreference = $prevEAP

if ($undoExit -ne 0) {
    throw "kubectl rollout undo failed: $undoOutput"
}
$cleanOutput = $undoOutput | Where-Object { $_ -notlike "Warning: *" -and $_ -notlike "warning: *" }
Write-Host "  $($cleanOutput -join "`n  ")" -ForegroundColor Green

# 5. Wait for Rollout Completion & Verify Restored Image
Write-Host "`n[4/4] Monitoring rollback completion and verifying active image..." -ForegroundColor Cyan
Wait-DeploymentRollout -ExpectedImage $v1TargetImage -TimeoutSeconds 180 -Namespace $Namespace

$restoredImage = Get-ActiveDeploymentImage -Namespace $Namespace
$restoredRevision = Get-ActiveDeploymentRevision -Namespace $Namespace

if ($restoredImage -ne $v1TargetImage) {
    throw "Rollback verification failed: Active image is '$restoredImage', expected '$v1TargetImage'."
}

# 6. Update State File
$state = Get-DemoState
$state["rollback"] = [ordered]@{
    restoredImage        = $restoredImage
    restoredFromRevision = $v1TargetRevision
    newActiveRevision    = $restoredRevision
    completedAt          = (Get-Date).ToUniversalTime().ToString("o")
}
$state["latestStage"] = "rollback-v1"
Save-DemoState -State $state

# 7. Final Verification Summary
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " DEMO STAGE 4 COMPLETE: Rollback to V1 Verified!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  Restored Active Image:    $restoredImage" -ForegroundColor White
Write-Host "  Original V1 Revision:     $v1TargetRevision" -ForegroundColor White
Write-Host "  Current Active Revision:  $restoredRevision" -ForegroundColor White
Write-Host "  Deployment Rollout:       Complete & Healthy (1/1 pods running)" -ForegroundColor White
Write-Host "  State Recorded In:        $(Get-DemoStateFilePath)" -ForegroundColor Gray
Write-Host "`nDemonstration cycle completed: V1 Baseline -> V2 Feature -> V3 Quality Gate -> Rollback to V1." -ForegroundColor Green
