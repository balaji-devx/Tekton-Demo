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
