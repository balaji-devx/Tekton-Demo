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

if ([string]::IsNullOrWhiteSpace($Username)) {
    Write-Error "Docker Hub Username cannot be blank."
    exit 1
}

$secureToken = Read-Host "Enter Docker Hub Access Token (input hidden)" -AsSecureString
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

# Create standard Docker config JSON
$dockerConfig = @{
    auths = @{
        "https://index.docker.io/v1/" = @{
            auth = $base64Auth
        }
    }
} | ConvertTo-Json -Compress

$tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "docker-config-[guid]::NewGuid().json")

try {
    [System.IO.File]::WriteAllText($tempFile, $dockerConfig, [System.Text.Encoding]::UTF8)

    Write-Host "`nApplying Kubernetes Secret 'dockerhub-auth' in namespace '$Namespace'..." -ForegroundColor Cyan
    
    # Create secret with both config.json (for Kaniko) and .dockerconfigjson (standard k8s)
    $applyResult = kubectl create secret generic dockerhub-auth `
        --from-file=config.json="$tempFile" `
        --from-file=.dockerconfigjson="$tempFile" `
        --namespace="$Namespace" `
        --dry-run=client -o yaml | kubectl apply -f - 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS: Secret 'dockerhub-auth' created/updated in namespace '$Namespace'." -ForegroundColor Green
        Write-Host "Kaniko builds will now authenticate seamlessly to Docker Hub." -ForegroundColor Green
    } else {
        Write-Error "Failed to apply Kubernetes secret: $applyResult"
    }

} finally {
    # Secure cleanup of temporary file and in-memory variables
    if (Test-Path $tempFile) {
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
    }
    $plainToken = $null
    $pair = $null
    $base64Auth = $null
    $dockerConfig = $null
    [System.GC]::Collect()
}

Write-Host "==========================================================" -ForegroundColor Cyan
