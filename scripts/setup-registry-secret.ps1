<#
.SYNOPSIS
    Securely configures the Kubernetes Secret for Docker Hub authentication.
.DESCRIPTION
    Prompts for Docker Hub username and personal access token (PAT), formats
    standard Docker config JSON, and applies the Secret to the local Kubernetes cluster
    without committing or leaking credentials to disk or console.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Username,

    [Parameter(Mandatory = $false)]
    [string]$Namespace = "default"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Docker Hub Registry Secret Setup for Kaniko & Tekton" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Note: It is strongly recommended to use a Docker Hub Personal Access" -ForegroundColor Gray
Write-Host "Token (Read & Write permissions) rather than your main account password." -ForegroundColor Gray
Write-Host ""

if ([string]::IsNullOrWhiteSpace($Username)) {
    $Username = Read-Host "Enter Docker Hub Username"
}

# Clean and sanitize username input (remove control characters and extract from command if pasted)
if ($Username) {
    $Username = ($Username -replace '[\x00-\x1F\x7F]', '').Trim()
    if ($Username -match '(?i)(?:-u|--username)\s+([a-zA-Z0-9_-]+)') {
        $Username = $Matches[1]
    }
}

if ([string]::IsNullOrWhiteSpace($Username) -or $Username -notmatch '^[a-zA-Z0-9_-]{3,30}$') {
    Write-Error "Invalid Docker Hub username '$Username'. A valid Docker Hub username must be 3-30 alphanumeric characters, underscores, or hyphens with no spaces."
    exit 1
}

$secureToken = Read-Host "Enter Docker Hub Access Token (input hidden)" -AsSecureString
if (-not $secureToken) {
    Write-Error "Access Token cannot be blank."
    exit 1
}

$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
$plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

if ([string]::IsNullOrWhiteSpace($plainToken)) {
    Write-Error "Access Token cannot be blank."
    exit 1
}

# Construct standard Docker auth base64
$pair = "${Username}:${plainToken}"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
$base64Auth = [Convert]::ToBase64String($bytes)

# Generate standard Docker config JSON
$dockerConfig = @{
    auths = @{
        "https://index.docker.io/v1/" = @{
            auth = $base64Auth
        }
    }
} | ConvertTo-Json -Compress

# Generate a valid, unique temporary file on disk
$tempFile = [System.IO.Path]::GetTempFileName()

try {
    # CRITICAL: Write strictly UTF-8 WITHOUT Byte Order Mark (BOM)
    # Kaniko's Go json parser rejects the 0xEF, 0xBB, 0xBF BOM with:
    # "invalid character 'ï' looking for beginning of value"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $dockerConfigBytes = $utf8NoBom.GetBytes($dockerConfig)
    [System.IO.File]::WriteAllBytes($tempFile, $dockerConfigBytes)

    # Sanity check: Ensure file starts with '{' (0x7B) and strictly NO BOM (0xEF, 0xBB, 0xBF)
    $headerBytes = [System.IO.File]::ReadAllBytes($tempFile)
    if ($headerBytes.Length -lt 2 -or $headerBytes[0] -ne 0x7B) {
        Write-Error "Encoding check failed: Temporary file contains BOM or does not begin with '{' (0x7B)."
        exit 1
    }

    Write-Host "`nUpdating Kubernetes Secret 'dockerhub-auth' in namespace '$Namespace'..." -ForegroundColor Cyan

    # Remove previous Secret to purge any obsolete keys (e.g., .dockerconfigjson)
    $null = kubectl delete secret dockerhub-auth --namespace="$Namespace" --ignore-not-found 2>&1

    # Create clean Secret containing exclusively the config.json key for Kaniko (/kaniko/.docker/config.json)
    $applyResult = kubectl create secret generic dockerhub-auth `
        --from-file=config.json="$tempFile" `
        --namespace="$Namespace" 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create Kubernetes secret 'dockerhub-auth': $applyResult"
        exit 1
    }

    # Verify secret exists and contains exclusively the config.json key
    $secretKeys = kubectl get secret dockerhub-auth --namespace="$Namespace" -o jsonpath='{.data}' 2>&1
    if ($LASTEXITCODE -ne 0 -or $secretKeys -notmatch 'config\.json') {
        Write-Error "Kubernetes secret verification failed: Secret does not contain expected config.json key: $secretKeys"
        exit 1
    }

    Write-Host "SUCCESS: Secret 'dockerhub-auth' created and verified in namespace '$Namespace'." -ForegroundColor Green
    Write-Host "Configured for Docker Hub user: $Username" -ForegroundColor Green
    Write-Host "Secret contains UTF-8 (No BOM) config.json ready for Kaniko." -ForegroundColor Green

} finally {
    # Secure cleanup of temporary file and in-memory variables
    if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }
    $plainToken = $null
    $pair = $null
    $base64Auth = $null
    $dockerConfig = $null
    [System.GC]::Collect()
}

Write-Host "==========================================================" -ForegroundColor Cyan
