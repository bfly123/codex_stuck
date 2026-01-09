Param(
    [switch]$NoAutoConfig,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Resolve-Home {
    if ($HOME) { return $HOME }
    if ($env:USERPROFILE) { return $env:USERPROFILE }
    throw "Cannot determine home directory"
}

function Write-CmdShim {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$TargetScript
    )
    $content = @"
@echo off
setlocal
set "SCRIPT=$TargetScript"
where py >nul 2>nul
if %errorlevel%==0 (
    py -3 "%SCRIPT%" %*
    exit /b %errorlevel%
)
where python >nul 2>nul
if %errorlevel%==0 (
    python "%SCRIPT%" %*
    exit /b %errorlevel%
)
echo Python not found. Install Python 3 and ensure it is in PATH. 1>&2
exit /b 127
"@
    Set-Content -Path $Path -Value $content -Encoding ASCII
}

function Write-CodexShim {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$WrapperCmd
    )
    $content = @"
@echo off
setlocal enabledelayedexpansion
set "ME=%~f0"
set "REAL="
for /f "delims=" %%P in ('where codex 2^>nul') do (
    if /i not "%%~fP"=="!ME!" (
        set "REAL=%%~fP"
        goto :found
    )
)
:found
if "!REAL!"=="" (
    echo Cannot find real codex in PATH. 1>&2
    exit /b 127
)
set "CODEX_STATUS_REAL_CODEX=!REAL!"
call "$WrapperCmd" %*
exit /b %errorlevel%
"@
    Set-Content -Path $Path -Value $content -Encoding ASCII
}

function Add-ToUserPath {
    param([string]$PathToAdd)

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -split ";" | Where-Object { $_ -eq $PathToAdd }) {
        Write-Host "  Already in PATH: $PathToAdd" -ForegroundColor Gray
        return $false
    }

    $newPath = "$PathToAdd;$currentPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "  Added to PATH: $PathToAdd" -ForegroundColor Green
    return $true
}

$HomeDir = Resolve-Home
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$InstallDir = Join-Path $HomeDir ".local\bin"
$PriorityDir = Join-Path $InstallDir "priority"
$LibDir = Join-Path $HomeDir ".local\lib\codex-status"
$ShareDir = Join-Path $HomeDir ".local\share\codex-status"
$CacheDir = Join-Path $HomeDir ".cache\codex-status"

Write-Host "Installing codex-status (Windows)..." -ForegroundColor Cyan
Write-Host ""

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $PriorityDir | Out-Null
New-Item -ItemType Directory -Force -Path $LibDir | Out-Null
New-Item -ItemType Directory -Force -Path $ShareDir | Out-Null
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

Copy-Item -Force -Recurse (Join-Path $ScriptDir "lib\*") $LibDir
Copy-Item -Force (Join-Path $ScriptDir "config\ccbdone_instructions.txt") (Join-Path $ShareDir "ccbdone_instructions.txt")
Copy-Item -Force (Join-Path $ScriptDir "config\done_tag_instructions.txt") (Join-Path $ShareDir "done_tag_instructions.txt")

Copy-Item -Force (Join-Path $ScriptDir "bin\codex-status") (Join-Path $InstallDir "codex-status")
Copy-Item -Force (Join-Path $ScriptDir "bin\codex-status-wrapper") (Join-Path $InstallDir "codex-status-wrapper")

Write-CmdShim -Path (Join-Path $InstallDir "codex-status.cmd") -TargetScript (Join-Path $InstallDir "codex-status")
Write-CmdShim -Path (Join-Path $InstallDir "codex-status-wrapper.cmd") -TargetScript (Join-Path $InstallDir "codex-status-wrapper")

Write-CodexShim -Path (Join-Path $PriorityDir "codex.cmd") -WrapperCmd (Join-Path $InstallDir "codex-status-wrapper.cmd")

Write-Host "Files installed:" -ForegroundColor Green
Write-Host "  $InstallDir"
Write-Host "  $LibDir"
Write-Host "  $ShareDir"
Write-Host ""

if (-not $NoAutoConfig) {
    $configureNow = $Force
    if (-not $Force) {
        $response = Read-Host "Auto-configure PATH? (add to User environment) [Y/n]"
        $configureNow = ($response -eq "" -or $response -match "^[Yy]")
    }

    if ($configureNow) {
        Write-Host "Configuring PATH..." -ForegroundColor Yellow
        $pathChanged = $false
        $pathChanged = (Add-ToUserPath $PriorityDir) -or $pathChanged
        $pathChanged = (Add-ToUserPath $InstallDir) -or $pathChanged

        if ($pathChanged) {
            Write-Host ""
            Write-Host "PATH updated. Restart terminal to apply changes." -ForegroundColor Cyan
        }
    } else {
        Write-Host "Skipped auto-configuration." -ForegroundColor Gray
        Write-Host ""
        Write-Host "Manual setup - add to User PATH:" -ForegroundColor Yellow
        Write-Host "  $PriorityDir"
        Write-Host "  $InstallDir"
    }
} else {
    Write-Host "Manual setup - add to User PATH:" -ForegroundColor Yellow
    Write-Host "  $PriorityDir"
    Write-Host "  $InstallDir"
}

Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Commands available (after PATH update):"
Write-Host "  codex           # Auto status monitor + done-tag injection"
Write-Host "  codex-status    # Check current status"
Write-Host ""
Write-Host "To uninstall: $ScriptDir\uninstall.ps1" -ForegroundColor Gray
