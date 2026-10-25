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
