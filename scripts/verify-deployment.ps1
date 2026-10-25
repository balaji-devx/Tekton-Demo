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
