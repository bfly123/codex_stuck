Param(
  [switch]$NoProfileHint
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

$HomeDir = Resolve-Home
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$InstallDir = Join-Path $HomeDir ".local\bin"
$PriorityDir = Join-Path $InstallDir "priority"
$LibDir = Join-Path $HomeDir ".local\lib\codex-status"
$ShareDir = Join-Path $HomeDir ".local\share\codex-status"
$CacheDir = Join-Path $HomeDir ".cache\codex-status"

Write-Host "Installing codex-status (Windows)..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $PriorityDir | Out-Null
New-Item -ItemType Directory -Force -Path $LibDir | Out-Null
New-Item -ItemType Directory -Force -Path $ShareDir | Out-Null
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

# Copy library + templates
Copy-Item -Force -Recurse (Join-Path $ScriptDir "lib\*") $LibDir
Copy-Item -Force (Join-Path $ScriptDir "config\ccbdone_instructions.txt") (Join-Path $ShareDir "ccbdone_instructions.txt")
Copy-Item -Force (Join-Path $ScriptDir "config\done_tag_instructions.txt") (Join-Path $ShareDir "done_tag_instructions.txt")

# Copy python entrypoints (no extension)
Copy-Item -Force (Join-Path $ScriptDir "bin\codex-status") (Join-Path $InstallDir "codex-status")
Copy-Item -Force (Join-Path $ScriptDir "bin\codex-status-wrapper") (Join-Path $InstallDir "codex-status-wrapper")

# .cmd shims for Windows execution
Write-CmdShim -Path (Join-Path $InstallDir "codex-status.cmd") -TargetScript (Join-Path $InstallDir "codex-status")
Write-CmdShim -Path (Join-Path $InstallDir "codex-status-wrapper.cmd") -TargetScript (Join-Path $InstallDir "codex-status-wrapper")

# Optional: a priority codex shim that routes to codex-status-wrapper while avoiding recursion
Write-CodexShim -Path (Join-Path $PriorityDir "codex.cmd") -WrapperCmd (Join-Path $InstallDir "codex-status-wrapper.cmd")

Write-Host "Installed:" -ForegroundColor Green
Write-Host "  $InstallDir"
Write-Host "  $LibDir"
Write-Host "  $ShareDir"
Write-Host ""
Write-Host "Next steps (WezTerm + PowerShell):" -ForegroundColor Yellow
Write-Host "  1) Add to PATH (User):"
Write-Host "     - $PriorityDir"
Write-Host "     - $InstallDir"
Write-Host "  2) Restart the terminal."
Write-Host ""
Write-Host "Tip: In WezTerm, `codex` (from priority PATH) will run with DONE injection + title updates."
if (-not $NoProfileHint) {
  Write-Host "If you prefer not to change PATH, run: `codex-status-wrapper ...`"
}
