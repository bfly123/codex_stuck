Param(
    [switch]$KeepCache,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Resolve-Home {
    if ($HOME) { return $HOME }
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    throw "Cannot determine home directory"
}

function Remove-FromUserPath {
    param([string]$PathToRemove)

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $paths = $currentPath -split ";" | Where-Object { $_ -ne $PathToRemove -and $_ -ne "" }

    if ($paths.Count -lt ($currentPath -split ";").Count) {
        $newPath = $paths -join ";"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "  Removed from PATH: $PathToRemove" -ForegroundColor Green
        return $true
    }
    return $false
}

$HomeDir = Resolve-Home

$InstallDir = Join-Path $HomeDir ".local\bin"
$PriorityDir = Join-Path $InstallDir "priority"
$LibDir = Join-Path $HomeDir ".local\lib\codex-status"
$ShareDir = Join-Path $HomeDir ".local\share\codex-status"
$CacheDir = Join-Path $HomeDir ".cache\codex-status"

Write-Host "Uninstalling codex-status..." -ForegroundColor Cyan
Write-Host ""

$configurePath = $Force
if (-not $Force) {
    $response = Read-Host "Remove from User PATH? [Y/n]"
    $configurePath = ($response -eq "" -or $response -match "^[Yy]")
}

if ($configurePath) {
    Write-Host "Updating PATH..." -ForegroundColor Yellow
    Remove-FromUserPath $PriorityDir | Out-Null
    Remove-FromUserPath $InstallDir | Out-Null
}

Write-Host ""
Write-Host "Removing files..." -ForegroundColor Yellow

$filesToRemove = @(
    (Join-Path $InstallDir "codex-status"),
    (Join-Path $InstallDir "codex-status.cmd"),
    (Join-Path $InstallDir "codex-status-wrapper"),
    (Join-Path $InstallDir "codex-status-wrapper.cmd"),
    (Join-Path $PriorityDir "codex.cmd")
)

foreach ($file in $filesToRemove) {
    if (Test-Path $file) {
        Remove-Item -Force $file
        Write-Host "  Removed: $file" -ForegroundColor Gray
    }
}

if ((Test-Path $PriorityDir) -and (Get-ChildItem $PriorityDir | Measure-Object).Count -eq 0) {
    Remove-Item -Force $PriorityDir
}

if (Test-Path $LibDir) {
    Remove-Item -Recurse -Force $LibDir
    Write-Host "  Removed: $LibDir" -ForegroundColor Gray
}

if (Test-Path $ShareDir) {
    Remove-Item -Recurse -Force $ShareDir
    Write-Host "  Removed: $ShareDir" -ForegroundColor Gray
}

if (-not $KeepCache) {
    $removeCache = $Force
    if (-not $Force) {
        $response = Read-Host "Remove cache ($CacheDir)? [y/N]"
        $removeCache = ($response -match "^[Yy]")
    }

    if ($removeCache -and (Test-Path $CacheDir)) {
        Remove-Item -Recurse -Force $CacheDir
        Write-Host "  Removed: $CacheDir" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Uninstallation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Restart terminal to apply PATH changes." -ForegroundColor Cyan
