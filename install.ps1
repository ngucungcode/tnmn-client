# TNMN Tunnel Client Installer for Windows (PowerShell)
# Usage (pipeline): irm https://raw.githubusercontent.com/ngucungcode/tnmn-client/main/install.ps1 | iex -Token "..." -Server "..."
# Usage (direct):   .\install.ps1 -Token "..." -Server "..."
# Usage (env vars): $env:TNMN_TOKEN="..."; irm URL | iex

# Env vars (pipeline install)
$Token  = if ($env:TNMN_TOKEN)  { $env:TNMN_TOKEN  } else { $null }
$Server = if ($env:TNMN_SERVER) { $env:TNMN_SERVER } else { "tnmn.click" }
$Proto  = if ($env:TNMN_PROTO)  { $env:TNMN_PROTO  } else { "http" }
$Port   = if ($env:TNMN_PORT)   { $env:TNMN_PORT   } else { "3000" }
$Name   = if ($env:TNMN_NAME)   { $env:TNMN_NAME   } else { "" }

# Named params (direct install)
param(
    [string]$TokenParam,
    [string]$ServerParam,
    [string]$ProtoParam,
    [string]$PortParam,
    [string]$NameParam
)
if ($TokenParam)  { $Token  = $TokenParam }
if ($ServerParam) { $Server = $ServerParam }
if ($ProtoParam)  { $Proto  = $ProtoParam }
if ($PortParam)   { $Port   = $PortParam }
if ($NameParam)   { $Name   = $NameParam }

# Validate
if (-not $Token) {
    Write-Host "ERROR: Token required. Use -Token param or set $env:TNMN_TOKEN"
    exit 1
}

$ErrorActionPreference = "Stop"
$Repo = "ngucungcode/tnmn-client"

# Detect arch
$Arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
$Asset = "tnmn-windows-${Arch}.exe"
$InstallDir = if ($env:LOCALAPPDATA) { "$env:LOCALAPPDATA	nmn" } else { "$env:USERPROFILE\.localin	nmn" }
$BinPath = "$InstallDir	nmn.exe"

$DownloadUrl = "https://github.com/$Repo/releases/latest/download/$Asset"
$TempBin = "$env:TEMP	nmn_install_$PID.exe"

Write-Host "[1/4] Platform: Windows / $Arch"
Write-Host "[2/4] Downloading binary..."

try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempBin -UseBasicParsing
} catch {
    Write-Host "ERROR: Download failed from $DownloadUrl"
    Write-Host " $_"
    exit 1
}

Write-Host "[3/4] Verifying checksum..."
try {
    $ChecksumsUrl = "https://github.com/$Repo/releases/latest/download/checksums.txt"
    $Checksums = (Invoke-WebRequest -Uri $ChecksumsUrl -UseBasicParsing).Content
    $ExpectedLine = $Checksums -split "`n" | Where-Object { $_ -match " $Asset$" }
    if ($ExpectedLine) {
        $ExpectedHash = ($ExpectedLine -split '\s+')[0].Trim()
        $ActualHash = (Get-FileHash -Path $TempBin -Algorithm SHA256).Hash.ToLower()
        if ($ActualHash -ne $ExpectedHash.ToLower()) {
            Write-Host "ERROR: checksum mismatch!"
            Write-Host "  expected: $ExpectedHash"
            Write-Host "  actual:   $ActualHash"
            Remove-Item $TempBin -Force -EA SilentlyContinue
            exit 1
        }
        Write-Host "      Checksum OK"
    } else {
        Write-Host "      Skipping checksum (not found)"
    }
} catch {
    Write-Host "      Skipping checksum verification"
}

Write-Host "[4/4] Installing to $InstallDir..."
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Move-Item -Path $TempBin -Destination $BinPath -Force

# Add to PATH
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($CurrentPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$CurrentPath;$InstallDir", "User")
    $env:Path = "$env:Path;$InstallDir"
}

Write-Host ""
Write-Host "[OK] Installed: $BinPath"
Write-Host ""

if ($Name) {
    Write-Host "Logging in..."
    & $BinPath login --token $Token --server $Server 2>$null
    Write-Host "Starting tunnel..."
    & $BinPath $Proto $Port --name $Name
} else {
    Write-Host "Setup done. To connect:"
    Write-Host "  tnmn.exe login --token `$Token --server $Server"
    Write-Host "  tnmn.exe $Proto $Port --name <SUBDOMAIN>"
}
