# TNMN Tunnel Client Installer for Windows (PowerShell)
# Run: irm URL -OutFile install.ps1; .\install.ps1 -Token "..." -Server "..."

param(
    [Parameter(Mandatory=$true)]
    [string]$Token,
    [string]$Server = "tnmn.click",
    [ValidateSet("http","tcp","udp")]
    [string]$Proto = "http",
    [string]$Port = "3000",
    [string]$Name = ""
)

$ErrorActionPreference = "Stop"
$Repo = "ngucungcode/tnmn-client"

$Arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
$Asset = "tnmn-windows-${Arch}.exe"
$InstallDir = if ($env:LOCALAPPDATA) { "$env:LOCALAPPDATA\tnmn" } else { "$env:USERPROFILE\.local\bin\tnmn" }
$BinPath = "$InstallDir\tnmn.exe"

Write-Host "[1/4] Platform: Windows / $Arch"
Write-Host "[2/4] Downloading binary..."

$DownloadUrl = "https://github.com/$Repo/releases/latest/download/$Asset"
$TempBin = "$env:TEMP\tnmn_install_$PID.exe"

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
        Write-Host "      Skipping checksum"
    }
} catch {
    Write-Host "      Skipping checksum"
}

Write-Host "[4/4] Installing to $InstallDir..."
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Move-Item -Path $TempBin -Destination $BinPath -Force

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
