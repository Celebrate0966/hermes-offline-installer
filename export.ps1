# Hermes offline export script - portable edition
#
# Produces the offline bundle that restore.ps1 consumes, by copying the
# install artifacts out of a machine that already has Hermes working.
# This keeps the 4 GB of binaries OUT of git - anyone with a working Hermes
# can regenerate the bundle locally with this script.
#
# Run it on the SOURCE machine (the one that already has Hermes installed):
#   powershell -ExecutionPolicy Bypass -File .\export.ps1
#   powershell -ExecutionPolicy Bypass -File .\export.ps1 -Output D:\HermesOffline
#   powershell -ExecutionPolicy Bypass -File .\export.ps1 -RepoRoot K:\HermesData\hermes-agent
#
# Parameters
#   -Output      Where the bundle is written. Defaults to .\HermesOffline next
#                to this script.
#   -InstallRoot The Hermes install root. Defaults to %LOCALAPPDATA%\hermes.
#   -RepoRoot    The source repo. Defaults to <InstallRoot>\hermes-agent.
#   -NoKit       Do not copy the restore/watch scripts + README into the bundle.
#   -Force       Re-create the git bundle even if one already exists.
#
# Idempotent: it only copies, never deletes your source install. Safe to re-run.

param(
    [string]$Output,
    [string]$InstallRoot,
    [string]$RepoRoot,
    [switch]$NoKit,
    [switch]$Force
)

$ErrorActionPreference = 'Continue'
if (-not $InstallRoot) { $InstallRoot = Join-Path $env:LOCALAPPDATA 'hermes' }
if (-not $RepoRoot)    { $RepoRoot    = Join-Path $InstallRoot 'hermes-agent' }
if (-not $Output)      { $Output      = Join-Path $PSScriptRoot 'HermesOffline' }

$InstallRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InstallRoot)
$RepoRoot    = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RepoRoot)
$Output      = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)

function Say($m)  { Write-Host "[export] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[export][WARN] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[export][FATAL] $m" -ForegroundColor Red; exit 1 }
function RC($from, $to) {
    if (-not (Test-Path $from)) { Warn "SKIP (missing) $from"; return }
    New-Item -ItemType Directory -Force -Path $to | Out-Null
    Say "copy -> $to"
    robocopy $from $to /E /NP /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
}

Write-Host ""
Say "install root : $InstallRoot"
Say "repo root    : $RepoRoot"
Say "output       : $Output"
Write-Host ""

# ---------------------------------------------------------------------------
# 0. sanity: the source install must actually exist
# ---------------------------------------------------------------------------
foreach ($must in @(
        (Join-Path $InstallRoot 'tools'),
        (Join-Path $RepoRoot '.git'),
        (Join-Path $InstallRoot 'bootstrap-cache\install-main.ps1'))) {
    if (-not (Test-Path $must)) {
        Die "source install looks incomplete, missing: $must`n  (InstallRoot = $InstallRoot, RepoRoot = $RepoRoot)"
    }
}

New-Item -ItemType Directory -Force -Path $Output | Out-Null

# ---------------------------------------------------------------------------
# 1. toolchain
# ---------------------------------------------------------------------------
RC (Join-Path $InstallRoot 'tools') (Join-Path $Output 'tools')

# ---------------------------------------------------------------------------
# 2. cached install script
# ---------------------------------------------------------------------------
$bc = Join-Path $Output 'bootstrap-cache'
New-Item -ItemType Directory -Force -Path $bc | Out-Null
Copy-Item (Join-Path $InstallRoot 'bootstrap-cache\install-main.ps1') $bc -Force

# ---------------------------------------------------------------------------
# 3. runtime cache + npm cache
# ---------------------------------------------------------------------------
RC (Join-Path $InstallRoot 'cache')          (Join-Path $Output 'hermes-cache')
RC (Join-Path $env:LOCALAPPDATA 'npm-cache') (Join-Path $Output 'npm-cache')

# ---------------------------------------------------------------------------
# 4. prebuilt mirror (optional, only if the source has it)
# ---------------------------------------------------------------------------
RC (Join-Path $InstallRoot 'prebuilt-mirror') (Join-Path $Output 'prebuilt-mirror')

# ---------------------------------------------------------------------------
# 5. desktop packaging inputs (electron + electron-builder binaries)
# ---------------------------------------------------------------------------
RC (Join-Path $RepoRoot '.cache\desktop-inputs')   (Join-Path $Output 'desktop-inputs')
RC (Join-Path $RepoRoot 'apps\desktop\build\packager') (Join-Path $Output 'desktop-packager')

# ---------------------------------------------------------------------------
# 6. git bundle of the repo (the snapshot the installer clones from)
# ---------------------------------------------------------------------------
$bundle = Join-Path $Output 'repo\hermes-agent.bundle'
$gitExe = Get-ChildItem -Path (Join-Path $InstallRoot 'tools') -Directory -Filter 'git-*' -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'cmd\git.exe' } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $gitExe) {
    $gitExe = (Get-Command git -ErrorAction SilentlyContinue).Source
    if (-not $gitExe) { Warn "no git found - the repo bundle will NOT be created. Copy a repo bundle manually." }
}

if ($gitExe) {
    Say "git          : $gitExe"
    if ((Test-Path $bundle) -and -not $Force) {
        Say "bundle already exists (use -Force to rebuild): $bundle"
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $bundle -Parent) | Out-Null
        Say "creating bundle -> $bundle (this is the big ~1.3 GB file, may take a few min)"
        & $gitExe -C $RepoRoot bundle create $bundle --all 2>&1 | Out-Null
        if (Test-Path $bundle) {
            $sz = [math]::Round((Get-Item $bundle).Length / 1GB, 2)
            Say "bundle created: $sz GB"
        } else {
            Warn "bundle creation failed - check that $RepoRoot has a .git and is not corrupt"
        }
    }
}

# ---------------------------------------------------------------------------
# 7. optionally drop the restore/watch scripts + README into the bundle so it
#    is fully self-contained (the README "how to export" step does this by hand)
# ---------------------------------------------------------------------------
if (-not $NoKit) {
    $kitFiles = @('restore.ps1', 'watch-electron-cache.ps1', '1-restore.bat', '2-watch.bat', '3-export.bat', 'README.md')
    foreach ($f in $kitFiles) {
        $src = Join-Path $PSScriptRoot $f
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $Output $f) -Force
            Say "kit file -> $f"
        }
    }
}

# ---------------------------------------------------------------------------
# 8. report
# ---------------------------------------------------------------------------
Write-Host ""
Say "--- bundle contents ---"
Get-ChildItem $Output -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $sz = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
           Measure-Object -Property Length -Sum).Sum
    Write-Host ("  {0,-20} {1,8:N1} MB" -f $_.Name, ($sz / 1MB))
}
$bundleSize = if (Test-Path $bundle) { (Get-Item $bundle).Length } else { 0 }
$total = (Get-ChildItem $Output -Recurse -File -ErrorAction SilentlyContinue |
          Measure-Object -Property Length -Sum).Sum
Write-Host ""
Say ("TOTAL bundle size: {0:N2} GB" -f ($total / 1GB))
Write-Host ""
Write-Host "Done. Copy this whole folder to the target machine, then run" -ForegroundColor Green
Write-Host "  1-restore.bat  ->  2-watch.bat  ->  double-click Hermes-Setup.exe" -ForegroundColor Green
Write-Host ""
Write-Host "NOTE: do NOT push this 4 GB folder to GitHub. The repo holds only the" -ForegroundColor Yellow
Write-Host "scripts + README; regenerate the bundle on demand with export.ps1." -ForegroundColor Yellow
