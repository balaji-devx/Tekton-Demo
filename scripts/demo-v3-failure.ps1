<#
.SYNOPSIS
    Stage 3: Demonstrates the automated CI quality gate by injecting an intentional test failure.
.DESCRIPTION
    Validates V2 deployment, captures pre-test active image, triggers the Tekton pipeline with
    tag 'v3-fail-demo' and -DemoFailTests, verifies the PipelineRun fails at 'run-tests', confirms
    downstream build-push and deploy tasks are blocked, and proves the active Kubernetes Deployment
    remains untouched on the healthy V2 release.
.EXAMPLE
    .\scripts\demo-v3-failure.ps1
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
Write-Host " DEMO STAGE 3: Test Quality Gate & Pipeline Blocking" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify Prerequisites
Test-DemoPrerequisites -Namespace $Namespace

# 2. Read Release State and Ensure V2 is deployed
Write-Host "`n[1/5] Validating recorded V2 release state..." -ForegroundColor Cyan
$state = Get-DemoState
if (-not $state.v2 -or -not $state.v2.image) {
    throw "V2 release state not found in .demo-release-state.json. Run .\scripts\demo-v2.ps1 first."
}
Write-Host "  Found recorded V2 release: Image=$($state.v2.image), Revision=$($state.v2.revision)" -ForegroundColor Green

# 3. Capture Active Image Immediately Before the Test
Write-Host "`n[2/5] Recording active Deployment image prior to pipeline execution..." -ForegroundColor Cyan
$preTestImage = Get-ActiveDeploymentImage -Namespace $Namespace
$preTestRevision = Get-ActiveDeploymentRevision -Namespace $Namespace

if ($preTestImage -ne $state.v2.image) {
    Write-Warning "Active image '$preTestImage' does not match recorded V2 image '$($state.v2.image)'."
}
Write-Host "  Pre-test Active Image:    $preTestImage" -ForegroundColor White
Write-Host "  Pre-test Active Revision: $preTestRevision" -ForegroundColor White

# 4. Verify Launcher Supports -DemoFailTests
Write-Host "`n[3/5] Verifying pipeline launcher supports -DemoFailTests switch..." -ForegroundColor Cyan
$launcherPath = Join-Path $repoRoot "scripts\run-pipeline.ps1"
$cmdInfo = Get-Command $launcherPath -ErrorAction Stop
if (-not $cmdInfo.Parameters.ContainsKey("DemoFailTests")) {
    throw "Launcher $launcherPath does not expose the required '-DemoFailTests' parameter."
}
Write-Host "  [OK] Launcher supports -DemoFailTests switch." -ForegroundColor Green

# 5. Launch PipelineRun with -DemoFailTests and Monitor (Expecting Failure)
Write-Host "`n[4/5] Launching pipeline with -DemoFailTests (expecting quality gate failure)..." -ForegroundColor Cyan
$pipelineResult = Invoke-And-Monitor-Pipeline `
    -ImageTag "v3-fail-demo" `
    -DemoFailTests `
    -ExpectFailure `
    -RepoUrl $RepoUrl `
    -DockerHubUsername $DockerHubUsername `
    -Revision "main" `
    -Namespace $Namespace `
    -TimeoutSeconds 900

# 6. Verify TaskRun Execution Semantics
Write-Host "`n[5/5] Auditing TaskRun gate enforcement..." -ForegroundColor Cyan
$tasks = $pipelineResult.TaskSummary

$fetchOk = ($tasks["fetch-source"].Reason -eq "Succeeded")
$testsFailed = ($tasks["run-tests"].Reason -eq "Failed")
$buildBlocked = (-not $tasks["build-push"].Executed)
$deployBlocked = (-not $tasks["deploy"].Executed)

Write-Host "  Audit Checklist:" -ForegroundColor Gray
Write-Host "   - [fetch-source] Succeeded:          $fetchOk" -ForegroundColor $(if ($fetchOk) { "Green" } else { "Red" })
Write-Host "   - [run-tests]    Failed (Gated):     $testsFailed" -ForegroundColor $(if ($testsFailed) { "Green" } else { "Red" })
Write-Host "   - [build-push]   Blocked / Not Run:  $buildBlocked" -ForegroundColor $(if ($buildBlocked) { "Green" } else { "Red" })
Write-Host "   - [deploy]       Blocked / Not Run:  $deployBlocked" -ForegroundColor $(if ($deployBlocked) { "Green" } else { "Red" })

if (-not $fetchOk) {
    throw "Stage 'fetch-source' was expected to succeed, but finished with status: $($tasks['fetch-source'].Reason)"
}
if (-not $testsFailed) {
    throw "Stage 'run-tests' was expected to fail, but finished with status: $($tasks['run-tests'].Reason)"
}
if (-not $buildBlocked) {
    throw "Stage 'build-push' was executed! The quality gate failed to prevent container image build."
}
if (-not $deployBlocked) {
    throw "Stage 'deploy' was executed! The quality gate failed to prevent Kubernetes deployment."
}

# 7. Verify Deployment Image Is Unchanged
$postTestImage = Get-ActiveDeploymentImage -Namespace $Namespace
$postTestRevision = Get-ActiveDeploymentRevision -Namespace $Namespace

Write-Host "`nPost-test Active Image:    $postTestImage" -ForegroundColor White
Write-Host "Post-test Active Revision: $postTestRevision" -ForegroundColor White

if ($postTestImage -ne $preTestImage) {
    throw "CRITICAL FAILURE: Deployed image changed from '$preTestImage' to '$postTestImage' despite pipeline failure!"
}
if ($postTestRevision -ne $preTestRevision) {
    throw "CRITICAL FAILURE: Deployment revision changed from '$preTestRevision' to '$postTestRevision'!"
}

# 8. Record State
$state = Get-DemoState
$state["v3Failure"] = [ordered]@{
    pipelineRun          = $pipelineResult.PipelineRunName
    imageTagTested       = "v3-fail-demo"
    testGateResult       = "Failed (Expected)"
    activeImagePreserved = $postTestImage
    activeRevision       = $postTestRevision
    completedAt          = (Get-Date).ToUniversalTime().ToString("o")
}
$state["latestStage"] = "v3-failure"
Save-DemoState -State $state

# 9. Explicit Confirmation
Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " PASS: V3 failed the test gate. V2 remains deployed." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "  PipelineRun:          $($pipelineResult.PipelineRunName)" -ForegroundColor White
Write-Host "  Blocked Stages:       build-push, deploy (No image pushed or deployed)" -ForegroundColor White
Write-Host "  Preserved Image:      $postTestImage (Revision $postTestRevision)" -ForegroundColor White
Write-Host "`nNext Step: Run '.\scripts\demo-rollback-v1.ps1' to demonstrate Kubernetes revision rollback." -ForegroundColor Cyan
