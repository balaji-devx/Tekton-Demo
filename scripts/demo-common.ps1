<#
.SYNOPSIS
    Shared helper functions and pipeline monitoring logic for the four Release Console demo scripts.
.DESCRIPTION
    Provides prerequisite validation, release state management (.demo-release-state.json),
    deterministic HTML modifications, Git synchronization, and PipelineRun discovery/monitoring.
#>

$ErrorActionPreference = "Stop"

function Get-DemoRepoRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Get-DemoStateFilePath {
    return (Join-Path (Get-DemoRepoRoot) ".demo-release-state.json")
}

function Get-DemoState {
    $statePath = Get-DemoStateFilePath
    if (Test-Path $statePath) {
        try {
            $content = Get-Content -Path $statePath -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($content)) {
                $obj = $content | ConvertFrom-Json
                $hash = [ordered]@{}
                foreach ($prop in $obj.PSObject.Properties) {
                    $hash[$prop.Name] = $prop.Value
                }
                return $hash
            }
        } catch {
            Write-Warning "Could not parse existing state file ($statePath): $_"
        }
    }
    return [ordered]@{
        project           = "Tekton-Demo"
        repository        = "https://github.com/balaji-devx/Tekton-Demo.git"
        dockerHubUsername = "ba1aj1"
        latestStage       = "none"
        lastUpdated       = (Get-Date).ToUniversalTime().ToString("o")
    }
}

function Save-DemoState {
    param(
        [Parameter(Mandatory = $true)]
        $State
    )
    $statePath = Get-DemoStateFilePath
    $tempPath = "$statePath.tmp"
    
    # Update timestamp
    if ($State -is [System.Collections.IDictionary]) {
        $State["lastUpdated"] = (Get-Date).ToUniversalTime().ToString("o")
    } elseif ($State.PSObject.Properties['lastUpdated']) {
        $State.lastUpdated = (Get-Date).ToUniversalTime().ToString("o")
    }
    
    $json = $State | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($tempPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    
    if (Test-Path $statePath) {
        Remove-Item -Path $statePath -Force
    }
    Move-Item -Path $tempPath -Destination $statePath -Force
    Write-Host "  [State] Recorded release state to $statePath" -ForegroundColor DarkGray
}

function Test-DemoPrerequisites {
    param(
        [string]$Namespace = "default"
    )
    $repoRoot = Get-DemoRepoRoot
    Write-Host "Verifying environment prerequisites..." -ForegroundColor Cyan

    # 1. Git CLI
    $gitVer = git --version 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $gitVer) {
        throw "Prerequisite check failed: git CLI is not available in PATH."
    }

    # 2. kubectl CLI
    $kubectlVer = kubectl version --client 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $kubectlVer) {
        throw "Prerequisite check failed: kubectl CLI is not available in PATH."
    }

    # 3. Context is minikube
    $currentContext = (kubectl config current-context 2>$null)
    if ($currentContext) { $currentContext = $currentContext.Trim() }
    if ($currentContext -ne "minikube") {
        throw "Prerequisite check failed: kubectl context is '$currentContext', expected 'minikube'. Switch with 'kubectl config use-context minikube'."
    }

    # 4. Kubernetes Node Ready
    $nodesJson = kubectl get nodes -o json 2>$null | Out-String | ConvertFrom-Json
    $nodeReady = ($nodesJson.items[0].status.conditions | Where-Object { $_.type -eq "Ready" }).status
    if ($nodeReady -ne "True") {
        throw "Prerequisite check failed: Minikube node is not Ready (status: '$nodeReady'). Run 'minikube status'."
    }

    # 5. Tekton Pipeline controllers
    $tektonPodsJson = kubectl get pods -n tekton-pipelines -o json 2>$null | Out-String | ConvertFrom-Json
    $controllerRunning = $false
    foreach ($pod in $tektonPodsJson.items) {
        if ($pod.metadata.name -like "*tekton-pipelines-controller*" -and $pod.status.phase -eq "Running") {
            $controllerRunning = $true
            break
        }
    }
    if (-not $controllerRunning) {
        throw "Prerequisite check failed: Tekton Pipelines controller is not Running in namespace 'tekton-pipelines'."
    }

    # 6. Deployment release-console exists
    $depExists = kubectl get deployment release-console -n "$Namespace" --ignore-not-found -o jsonpath='{.metadata.name}' 2>$null
    if (-not $depExists) {
        throw "Prerequisite check failed: Deployment 'release-console' was not found in namespace '$Namespace'."
    }

    # 7. Docker Hub Secret exists
    $secretExists = kubectl get secret dockerhub-auth -n "$Namespace" --ignore-not-found -o jsonpath='{.metadata.name}' 2>$null
    if (-not $secretExists) {
        throw "Prerequisite check failed: Secret 'dockerhub-auth' was not found in namespace '$Namespace'."
    }

    # 8. Scripts exist
    $runPipelineScript = Join-Path $repoRoot "scripts\run-pipeline.ps1"
    if (-not (Test-Path $runPipelineScript)) {
        throw "Prerequisite check failed: Script 'scripts/run-pipeline.ps1' not found."
    }

    Write-Host "  [OK] Git, kubectl, Minikube context, node, Tekton, deployment, and secret verified." -ForegroundColor Green
}

function Get-ActiveDeploymentImage {
    param([string]$Namespace = "default")
    $img = kubectl get deployment release-console -n "$Namespace" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>$null
    if ($img) { return $img.Trim() }
    return ""
}

function Get-ActiveDeploymentRevision {
    param([string]$Namespace = "default")
    $rev = kubectl get deployment release-console -n "$Namespace" -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' 2>$null
    if ($rev) { return $rev.Trim() }
    return ""
}

function Ensure-DeploymentPullPolicyAlways {
    $repoRoot = Get-DemoRepoRoot
    $yamlPath = Join-Path $repoRoot "k8s\deployment.yaml"
    if (-not (Test-Path $yamlPath)) {
        throw "Manifest k8s/deployment.yaml not found at $yamlPath"
    }

    $content = Get-Content -Path $yamlPath -Raw -Encoding UTF8
    if ($content -match 'imagePullPolicy:\s*Always') {
        Write-Host "  k8s/deployment.yaml already uses 'imagePullPolicy: Always'." -ForegroundColor DarkGray
        return $false
    }

    Write-Host "  Updating k8s/deployment.yaml to use 'imagePullPolicy: Always'..." -ForegroundColor Cyan
    $newContent = [regex]::Replace($content, 'imagePullPolicy:\s*\w+', 'imagePullPolicy: Always')
    [System.IO.File]::WriteAllText($yamlPath, $newContent, (New-Object System.Text.UTF8Encoding($false)))
    return $true
}

function Get-ArenaReleaseDescription {
    $repoRoot = Get-DemoRepoRoot
    $htmlPath = Join-Path $repoRoot "public\index.html"
    if (-not (Test-Path $htmlPath)) {
        throw "public/index.html not found at $htmlPath"
    }

    $content = Get-Content -Path $htmlPath -Raw -Encoding UTF8
    $pattern = '(?s)<p\s+class="arena-intro-desc"[^>]*>(.*?)</p>'
    if ($content -match $pattern) {
        return $Matches[1].Trim()
    }
    return ""
}

function Set-ArenaReleaseDescription {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewText
    )
    $repoRoot = Get-DemoRepoRoot
    $htmlPath = Join-Path $repoRoot "public\index.html"
    if (-not (Test-Path $htmlPath)) {
        throw "public/index.html not found at $htmlPath"
    }

    $content = Get-Content -Path $htmlPath -Raw -Encoding UTF8
    $pattern = '(?s)(<p\s+class="arena-intro-desc"[^>]*>)(.*?)(</p>)'
    if (-not ($content -match $pattern)) {
        throw "Could not locate '<p class=""arena-intro-desc"">' element in $htmlPath. Aborting to avoid corrupting HTML."
    }

    $currentText = $Matches[2].Trim()
    if ($currentText -eq $NewText.Trim()) {
        Write-Host "  DevOps Arena release description already matches: '$NewText'" -ForegroundColor DarkGray
        return $false
    }

    $targetTag = '<p class="arena-intro-desc" id="arena-release-desc">'
    $newContent = [regex]::Replace($content, $pattern, "${targetTag}${NewText}</p>")
    [System.IO.File]::WriteAllText($htmlPath, $newContent, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  Updated DevOps Arena release description to: '$NewText'" -ForegroundColor Green
    return $true
}

function Commit-And-Push-File {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$FilesToStage,
        [Parameter(Mandatory = $true)]
        [string]$CommitMessage
    )
    $repoRoot = Get-DemoRepoRoot
    Push-Location $repoRoot
    try {
        $status = & git status --porcelain -- $FilesToStage 2>&1
        if ([string]::IsNullOrWhiteSpace($status)) {
            Write-Host "  No changes detected in [$($FilesToStage -join ', ')]. Skipping commit." -ForegroundColor DarkGray
            return $false
        }

        Write-Host "  Staging modified file(s): $($FilesToStage -join ', ')..." -ForegroundColor Cyan
        & git add -- $FilesToStage
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to stage files: $($FilesToStage -join ', ')"
        }

        & git diff --cached --quiet -- $FilesToStage
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Committing: '$CommitMessage'..." -ForegroundColor Cyan
            & git commit -m "$CommitMessage" -- $FilesToStage
            if ($LASTEXITCODE -ne 0) {
                throw "Git commit failed for: $($FilesToStage -join ', ')"
            }

            Write-Host "  Pushing commit to origin main..." -ForegroundColor Cyan
            & git push origin main
            if ($LASTEXITCODE -ne 0) {
                throw "Git push failed. Ensure network connectivity and GitHub push permissions."
            }
            Write-Host "  [OK] Successfully pushed commit to GitHub." -ForegroundColor Green
            return $true
        }
        return $false
    } finally {
        Pop-Location
    }
}

function Wait-DeploymentRollout {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExpectedImage,
        [int]$TimeoutSeconds = 180,
        [string]$Namespace = "default"
    )
    Write-Host "Waiting for Deployment rollout to complete (timeout: ${TimeoutSeconds}s)..." -ForegroundColor Cyan
    $rolloutOut = kubectl rollout status deployment/release-console -n "$Namespace" --timeout="${TimeoutSeconds}s" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Deployment rollout failed or timed out: $rolloutOut"
    }

    $activeImage = Get-ActiveDeploymentImage -Namespace "$Namespace"
    if ($activeImage -ne $ExpectedImage) {
        throw "Deployment rolled out, but active image is '$activeImage' instead of expected '$ExpectedImage'."
    }
    Write-Host "  [OK] Rollout verified. Active image is '$activeImage'." -ForegroundColor Green
}

function Get-PipelineTaskRunSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PipelineRunName,
        [string]$Namespace = "default"
    )
    $orderedStages = @("fetch-source", "run-tests", "build-push", "deploy")
    $summary = [ordered]@{}

    $trRaw = kubectl get taskruns -l "tekton.dev/pipelineRun=$PipelineRunName" -n "$Namespace" -o json 2>$null | Out-String
    $trMap = @{}
    if (-not [string]::IsNullOrWhiteSpace($trRaw)) {
        try {
            $trJson = $trRaw | ConvertFrom-Json
            if ($trJson.items) {
                foreach ($tr in $trJson.items) {
                    $taskName = $tr.metadata.labels.'tekton.dev/pipelineTask'
                    if ($taskName) {
                        $trMap[$taskName] = $tr
                    }
                }
            }
        } catch {
            Write-Warning "Could not parse TaskRun JSON for $PipelineRunName"
        }
    }

    foreach ($stg in $orderedStages) {
        if ($trMap.ContainsKey($stg)) {
            $trObj = $trMap[$stg]
            $cond = $trObj.status.conditions | Where-Object { $_.type -eq "Succeeded" } | Select-Object -First 1
            $summary[$stg] = [ordered]@{
                Name     = $trObj.metadata.name
                Executed = $true
                Status   = if ($cond) { $cond.status } else { "Unknown" }
                Reason   = if ($cond) { $cond.reason } else { "Unknown" }
                Message  = if ($cond) { $cond.message } else { "" }
            }
        } else {
            $summary[$stg] = [ordered]@{
                Name     = $null
                Executed = $false
                Status   = "NotExecuted"
                Reason   = "SkippedOrBlocked"
                Message  = "Stage was not executed because an upstream gate halted pipeline execution."
            }
        }
    }
    return $summary
}

function Invoke-And-Monitor-Pipeline {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ImageTag,
        [switch]$DemoFailTests,
        [switch]$ExpectFailure,
        [string]$RepoUrl = "https://github.com/balaji-devx/Tekton-Demo.git",
        [string]$DockerHubUsername = "ba1aj1",
        [string]$Revision = "main",
        [string]$Namespace = "default",
        [int]$TimeoutSeconds = 900
    )
    $repoRoot = Get-DemoRepoRoot
    $launcher = Join-Path $repoRoot "scripts\run-pipeline.ps1"
    if (-not (Test-Path $launcher)) {
        throw "Pipeline launcher script not found at $launcher"
    }

    # Verify -DemoFailTests flag support if requested
    if ($DemoFailTests) {
        $cmdInfo = Get-Command $launcher -ErrorAction Stop
        if (-not $cmdInfo.Parameters.ContainsKey("DemoFailTests")) {
            throw "Launcher $launcher does not support parameter -DemoFailTests."
        }
    }

    # Record invoke timestamp in UTC and snapshot existing runs
    $invokeTimeUtc = [DateTime]::UtcNow.AddSeconds(-5)
    $existingRuns = @()
    $existingJson = kubectl get pipelinerun -n "$Namespace" -l app=release-console -o json 2>$null | Out-String
    if (-not [string]::IsNullOrWhiteSpace($existingJson)) {
        try {
            $parsedRuns = $existingJson | ConvertFrom-Json
            if ($parsedRuns.items) {
                $existingRuns = @($parsedRuns.items | ForEach-Object { $_.metadata.name })
            }
        } catch {}
    }

    Write-Host "`n--- Triggering PipelineRun for tag '$ImageTag' ---" -ForegroundColor Cyan
    $launcherParams = @{
        RepoUrl           = $RepoUrl
        DockerHubUsername = $DockerHubUsername
        ImageTag          = $ImageTag
        Revision          = $Revision
        Namespace         = $Namespace
    }
    if ($DemoFailTests) {
        $launcherParams["DemoFailTests"] = $true
    }

    & $launcher @launcherParams
    if ($LASTEXITCODE -ne 0) {
        throw "scripts/run-pipeline.ps1 exited with code $LASTEXITCODE."
    }

    # Discover newly created PipelineRun
    Write-Host "Discovering newly created PipelineRun in cluster..." -ForegroundColor Cyan
    $expectedPrefix = "release-console-run-$($ImageTag.ToLower())-"
    $pipelineRunName = $null
    $discoveryDeadline = [DateTime]::UtcNow.AddSeconds(30)

    while ([DateTime]::UtcNow -lt $discoveryDeadline) {
        Start-Sleep -Seconds 2
        $prJsonRaw = kubectl get pipelinerun -n "$Namespace" -o json 2>$null | Out-String
        if (-not [string]::IsNullOrWhiteSpace($prJsonRaw)) {
            $prJson = $prJsonRaw | ConvertFrom-Json
            $candidates = @($prJson.items | Where-Object {
                $_.metadata.name.StartsWith($expectedPrefix) -and
                ($_.metadata.name -notin $existingRuns)
            })

            if ($candidates.Count -eq 0) {
                # Fallback: check creation timestamp
                $candidates = @($prJson.items | Where-Object {
                    $_.metadata.name.StartsWith($expectedPrefix)
                })
                $candidates = @($candidates | Where-Object {
                    try {
                        [DateTime]::Parse($_.metadata.creationTimestamp).ToUniversalTime() -ge $invokeTimeUtc
                    } catch { $true }
                })
            }

            if ($candidates.Count -gt 0) {
                # Pick newest candidate
                $sorted = $candidates | Sort-Object { [DateTime]::Parse($_.metadata.creationTimestamp) }
                $pipelineRunName = $sorted[-1].metadata.name
                break
            }
        }
    }

    if (-not $pipelineRunName) {
        throw "Could not discover newly created PipelineRun with prefix '$expectedPrefix' within 30 seconds."
    }

    Write-Host "Discovered PipelineRun: $pipelineRunName" -ForegroundColor Green
    Write-Host "Monitoring execution until completion (timeout: ${TimeoutSeconds}s)..." -ForegroundColor Cyan

    # Monitor loop
    $startTime = Get-Date
    $deadline = $startTime.AddSeconds($TimeoutSeconds)
    $lastReportText = ""
    $finalStatus = $null
    $finalReason = $null

    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 6
        $prRaw = kubectl get pipelinerun "$pipelineRunName" -n "$Namespace" -o json 2>$null | Out-String
        if ([string]::IsNullOrWhiteSpace($prRaw)) {
            continue
        }

        $pr = $prRaw | ConvertFrom-Json
        $succeededCond = $pr.status.conditions | Where-Object { $_.type -eq "Succeeded" } | Select-Object -First 1

        $currStatus = if ($succeededCond) { $succeededCond.status } else { "Unknown" }
        $currReason = if ($succeededCond) { $succeededCond.reason } else { "Running" }

        # Query TaskRuns for brief progress display
        $taskSummary = Get-PipelineTaskRunSummary -PipelineRunName $pipelineRunName -Namespace $Namespace
        $stageSummaryStrs = @()
        foreach ($stgKey in $taskSummary.Keys) {
            $stgInfo = $taskSummary[$stgKey]
            if ($stgInfo.Executed) {
                $stageSummaryStrs += "$($stgKey): $($stgInfo.Reason)"
            }
        }
        $tasksProgress = if ($stageSummaryStrs.Count -gt 0) { $stageSummaryStrs -join " | " } else { "Initializing tasks..." }

        $elapsedSecTotal = [int]((Get-Date) - $startTime).TotalSeconds
        $elapsedMin = [int]($elapsedSecTotal / 60)
        $elapsedSec = [int]($elapsedSecTotal % 60)
        $elapsedStr = "{0:00}:{1:00}" -f $elapsedMin, $elapsedSec

        $reportText = "[$elapsedStr] PipelineRun: $pipelineRunName | $tasksProgress"
        if ($reportText -ne $lastReportText) {
            Write-Host "  $reportText" -ForegroundColor Gray
            $lastReportText = $reportText
        }

        if ($currStatus -ne "Unknown") {
            $finalStatus = $currStatus
            $finalReason = $currReason
            break
        }
    }

    if (-not $finalStatus) {
        throw "PipelineRun $pipelineRunName timed out after $TimeoutSeconds seconds."
    }

    Write-Host "`nPipelineRun '$pipelineRunName' finished with Status: $finalStatus ($finalReason)" -ForegroundColor $(if ($finalStatus -eq "True") { "Green" } else { "Yellow" })

    # Final TaskRun audit
    $finalTaskSummary = Get-PipelineTaskRunSummary -PipelineRunName $pipelineRunName -Namespace $Namespace
    Write-Host "`nStage Execution Summary:" -ForegroundColor Cyan
    foreach ($stgKey in $finalTaskSummary.Keys) {
        $stgInfo = $finalTaskSummary[$stgKey]
        $color = if ($stgInfo.Reason -eq "Succeeded") { "Green" } elseif ($stgInfo.Reason -eq "Failed") { "Red" } else { "DarkGray" }
        Write-Host ("  - {0,-14} : {1}" -f $stgKey, $stgInfo.Reason) -ForegroundColor $color
    }

    # Extract source commit SHA from fetch-source task result
    $commitSha = $null
    $trFetchRaw = kubectl get taskrun -l "tekton.dev/pipelineRun=$pipelineRunName,tekton.dev/pipelineTask=fetch-source" -n "$Namespace" -o json 2>$null | Out-String
    if (-not [string]::IsNullOrWhiteSpace($trFetchRaw)) {
        try {
            $trFetch = $trFetchRaw | ConvertFrom-Json
            if ($trFetch.items -and $trFetch.items.Count -gt 0) {
                $results = $trFetch.items[0].status.results
                if ($results) {
                    $commitObj = $results | Where-Object { $_.name -eq "commit" } | Select-Object -First 1
                    if ($commitObj) { $commitSha = $commitObj.value }
                }
            }
        } catch {}
    }
    if (-not $commitSha) {
        $commitSha = (& git rev-parse HEAD 2>$null)
        if ($commitSha) { $commitSha = $commitSha.Trim() }
    }

    # Outcome evaluation
    if ($ExpectFailure) {
        if ($finalStatus -eq "True") {
            throw "Expected PipelineRun to FAIL at the test gate, but it SUCCEEDED unexpectedly."
        }
        if ($finalTaskSummary["run-tests"].Reason -ne "Failed") {
            throw "Pipeline failed, but not at the expected 'run-tests' stage (run-tests status: $($finalTaskSummary['run-tests'].Reason))."
        }
        if ($finalTaskSummary["build-push"].Executed -or $finalTaskSummary["deploy"].Executed) {
            throw "Downstream stages were unexpectedly executed despite test failure."
        }
    } else {
        if ($finalStatus -ne "True") {
            # Print logs of failed pod for immediate diagnostics
            Write-Host "`nFetching diagnostics for failed PipelineRun..." -ForegroundColor Red
            kubectl logs -l "tekton.dev/pipelineRun=$pipelineRunName" -n "$Namespace" --all-containers --tail=40 2>$null
            throw "PipelineRun $pipelineRunName failed at stage '$($finalTaskSummary.Keys | Where-Object { $finalTaskSummary[$_].Reason -eq 'Failed' })'."
        }
    }

    return [PSCustomObject]@{
        PipelineRunName = $pipelineRunName
        Status          = $finalStatus
        Reason          = $finalReason
        TaskSummary     = $finalTaskSummary
        CommitSha       = $commitSha
    }
}
