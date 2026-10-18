# Hermes offline restore script - portable edition (v2)
#
# Lays down a previously exported offline bundle so the official
# Hermes-Setup.exe can run all 9 stages without reaching the network.
#
# Run it however you like (a .bat wrapper is provided in this kit):
#   powershell -ExecutionPolicy Bypass -File .\restore.ps1
#   powershell -ExecutionPolicy Bypass -File .\restore.ps1 -RepoRoot D:\HermesData
#
# Parameters
#   -OfflineRoot     Where the offline bundle lives. Defaults to this script's
#                    own directory, so the bundle can sit on any drive.
#   -RepoRoot        Where the source repo goes. Defaults to
#                    %LOCALAPPDATA%\hermes\hermes-agent. Put it on another
#                    drive to keep C: small; a junction is created so Hermes
#                    still finds it at the default path.
#   -ResetOnboarding Force first-run onboarding again: remove config.yaml (which
#                    also re-pins the provider to Hermes defaults, i.e. the bundled
#                    Nous free tier) and state.db. .env and auth.json are only
#                    BACKED UP, never deleted - they hold your API keys and the
#                    Nous credential. Everything removed is copied to *.bak-<ts>.
#   -SkipMirrorPin   Do not touch npm mirror settings.
#
# Idempotent: it only copies, never deletes your data. Safe to re-run.

param(
    [string]$OfflineRoot,
    [string]$RepoRoot,
    [switch]$ResetOnboarding,
    [switch]$SkipMirrorPin
)

$ErrorActionPreference = 'Continue'
if (-not $OfflineRoot) { $OfflineRoot = $PSScriptRoot }
$OfflineRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OfflineRoot)
$target  = Join-Path $env:LOCALAPPDATA 'hermes'
$packedHash = ''
$zipName = ''

function Say($m)  { Write-Host "[hermes] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[hermes][WARN] $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "[hermes][FATAL] $m" -ForegroundColor Red; exit 1 }
function RC($from, $to) {
    if (-not (Test-Path $from)) { Warn "SKIP (missing) $from"; return }
    Say "copy -> $to"
    robocopy $from $to /E /NP /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
}

Say "offline root : $OfflineRoot"
Say "install root : $target"

# ---------------------------------------------------------------------------
# 0. sanity: the bundle must be complete enough to be worth running
# ---------------------------------------------------------------------------
foreach ($must in @('tools', 'repo\hermes-agent.bundle', 'bootstrap-cache\install-main.ps1')) {
    if (-not (Test-Path (Join-Path $OfflineRoot $must))) {
        Die "offline bundle looks incomplete, missing: $must`n  (OfflineRoot = $OfflineRoot)"
    }
}

# ---------------------------------------------------------------------------
# 1. decide where the repo lives, and validate the drive
# ---------------------------------------------------------------------------
if (-not $RepoRoot) { $RepoRoot = Join-Path $target 'hermes-agent' }
$driveLetter = (Split-Path $RepoRoot -Qualifier).TrimEnd(':')
if (-not $driveLetter) { Die "cannot work out the drive for -RepoRoot $RepoRoot" }
$psDrive = Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue
if (-not $psDrive) { Die "drive ${driveLetter}: does not exist. Pick a drive that is actually plugged in." }

$disk = Get-CimInstance -Query "SELECT DriveType,Size,FreeSpace FROM Win32_LogicalDisk WHERE DeviceID='$driveLetter`:'" -ErrorAction SilentlyContinue
if ($disk) {
    $typeName = switch ($disk.DriveType) { 2 { 'removable' } 3 { 'fixed' } 4 { 'network' } 5 { 'optical' } default { "type-$($disk.DriveType)" } }
    Say "repo drive   : ${driveLetter}: ($typeName, free $([math]::Round($disk.FreeSpace/1GB,1)) GB)"
    if ($disk.DriveType -ne 3) {
        Warn "${driveLetter}: is $typeName, not a fixed disk. If it is unplugged later the install breaks. Prefer a fixed internal drive."
    }
    if ($disk.FreeSpace -lt 12GB) {
        Warn "${driveLetter}: has less than 12 GB free. The repo plus build output needs roughly 8-12 GB."
    }
}
Say "repo path    : $RepoRoot"

# ---------------------------------------------------------------------------
# 2. toolchain (git/python/node/npm/uv/ffmpeg/ripgrep/chromium/...)
# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $target | Out-Null
RC (Join-Path $OfflineRoot 'tools') (Join-Path $target 'tools')

# ---------------------------------------------------------------------------
# 3. cached install script (skips raw.githubusercontent download)
# ---------------------------------------------------------------------------
$bc = Join-Path $target 'bootstrap-cache'
New-Item -ItemType Directory -Force -Path $bc | Out-Null
Copy-Item (Join-Path $OfflineRoot 'bootstrap-cache\install-main.ps1') $bc -Force

# ---------------------------------------------------------------------------
# 4. runtime cache + npm cache
# ---------------------------------------------------------------------------
RC (Join-Path $OfflineRoot 'hermes-cache') (Join-Path $target 'cache')
RC (Join-Path $OfflineRoot 'npm-cache')    (Join-Path $env:LOCALAPPDATA 'npm-cache')

# ---------------------------------------------------------------------------
# 5. locate git INSIDE the bundle, falling back to whatever is on PATH.
#    Version-agnostic: the original script hardcoded git-2.53.0+3 and broke
#    the moment the bundled git was a different build.
# ---------------------------------------------------------------------------
$gitExe = Get-ChildItem -Path (Join-Path $target 'tools') -Directory -Filter 'git-*' -ErrorAction SilentlyContinue |
    ForEach-Object { Join-Path $_.FullName 'cmd\git.exe' } |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $gitExe) {
    $gitExe = (Get-Command git -ErrorAction SilentlyContinue).Source
    if ($gitExe) { Warn "no bundled git found, using system git: $gitExe" }
    else { Die "no git available, and the bundle did not provide one" }
}
Say "git          : $gitExe"

# ---------------------------------------------------------------------------
# 6. clone the repo from the bundle (no GitHub clone)
# ---------------------------------------------------------------------------
$bundle = Join-Path $OfflineRoot 'repo\hermes-agent.bundle'
if (Test-Path (Join-Path $RepoRoot '.git')) {
    Say "repo already present: $RepoRoot"
} else {
    New-Item -ItemType Directory -Force -Path (Split-Path $RepoRoot -Parent) | Out-Null
    Say "cloning repo from bundle -> $RepoRoot"
    & $gitExe clone $bundle $RepoRoot 2>&1 | Out-Null
    if (-not (Test-Path (Join-Path $RepoRoot '.git'))) { Warn "clone may have failed, check $RepoRoot" }
}
if (Test-Path (Join-Path $RepoRoot '.git')) {
    & $gitExe -C $RepoRoot remote set-url origin https://github.com/NousResearch/hermes-agent.git 2>&1 | Out-Null
    & $gitExe -C $RepoRoot checkout main 2>&1 | Out-Null
}

# ---------------------------------------------------------------------------
# 7. desktop packaging inputs (electron + electron-builder binaries)
# ---------------------------------------------------------------------------
RC (Join-Path $OfflineRoot 'desktop-inputs')   (Join-Path $RepoRoot '.cache\desktop-inputs')
RC (Join-Path $OfflineRoot 'desktop-packager') (Join-Path $RepoRoot 'apps\desktop\build\packager')
RC (Join-Path $OfflineRoot 'prebuilt-mirror')  (Join-Path $target 'prebuilt-mirror')

# ---------------------------------------------------------------------------
# 8. THE electron fix.
#
#    The cache directory name is a hash of the download URL, so it differs per
#    machine. Two different locations matter:
#
#      (a) the repo-local cache dir passed as --cache to electron-builder,
#          <repo>\.cache\desktop-inputs\packager\electron
#      (b) the fallback %LOCALAPPDATA%\electron\Cache that the downloader
#          consults when (a) misses.
#
#    Observed on a real install: the installer hashed to f8e28233... , missed
#    in (a), then found the zip in (b) and copied it across - fully offline.
#    On a brand new machine neither directory exists yet, so we seed BOTH with
#    the packed hash and also top up every hash dir already present.
# ---------------------------------------------------------------------------
$offlineElectronDir = Join-Path $OfflineRoot 'desktop-inputs\packager\electron'
$cacheDirElectron   = Join-Path $RepoRoot '.cache\desktop-inputs\packager\electron'
$defaultElectron    = Join-Path $env:LOCALAPPDATA 'electron\Cache'

if (Test-Path $offlineElectronDir) {
    $zip = Get-ChildItem -Path $offlineElectronDir -Recurse -File -Filter 'electron-*.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($zip) {
        $packedHash = $zip.Directory.Name
        $zipName    = $zip.Name
        Say "electron zip : $zipName ($([math]::Round($zip.Length/1MB)) MB)"
        Say "packed hash  : $packedHash"

        foreach ($root in @($cacheDirElectron, $defaultElectron)) {
            $d = Join-Path $root $packedHash
            New-Item -ItemType Directory -Force -Path $d | Out-Null
            Copy-Item $zip.FullName -Destination (Join-Path $d $zipName) -Force
            Say "seeded -> $d"
            if (Test-Path $root) {
                Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                    Copy-Item $zip.FullName -Destination (Join-Path $_.FullName $zipName) -Force
                }
            }
        }
    } else { Warn "no electron-*.zip under $offlineElectronDir" }
} else { Warn "SKIP (missing) $offlineElectronDir" }

# ---------------------------------------------------------------------------
# 9. version guard: does the bundled electron match what this repo wants?
#    A bundle exported months ago can carry a stale electron, which then gets
#    ignored and triggers a network fetch.
# ---------------------------------------------------------------------------
$pkgJson = Join-Path $RepoRoot 'apps\desktop\package.json'
if ((Test-Path $pkgJson) -and $zipName) {
    try {
        $pkg  = Get-Content $pkgJson -Raw | ConvertFrom-Json
        $want = $pkg.devDependencies.electron
        if (-not $want) { $want = $pkg.dependencies.electron }
        if ($want -and $zipName -match 'electron-v(\d+\.\d+\.\d+)') {
            $have = $Matches[1]
            $wantClean = $want -replace '[\^~=<>\s]', ''
            if ($wantClean -eq $have) {
                Say "electron version match: repo wants $want, bundle has $have"
            } else {
                Warn "electron VERSION MISMATCH: repo wants $want, bundle has $have. The offline zip will be ignored and the installer will try the network. Re-export the bundle from a machine running this version."
            }
        }
    } catch { Warn "could not parse $pkgJson for the electron version check" }
}

# ---------------------------------------------------------------------------
# 10. optional: reset first-run onboarding
# ---------------------------------------------------------------------------
if ($ResetOnboarding) {
    Say "resetting onboarding state"
    Get-Process python*, hermes*, gateway* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    # Only the two things that actually suppress first-run onboarding:
    #   config.yaml  -> onboarding.seen.profile_build_offered (and it also pins a provider)
    #   state.db     -> any stored message makes "very first message ever" false
    # Removing config.yaml also lets Hermes regenerate its DEFAULTS, which puts the
    # bundled Nous free tier back in charge - exactly the out-of-the-box experience.
    #
    # We deliberately BACK UP (not delete) .env and auth.json:
    #   .env      -> the user's own API keys; deleting them is data loss
    #   auth.json -> the Nous anonymous/free-tier credential and any sign-in
    # Deleting these used to be part of the reset; it is not required for onboarding
    # and it throws away credentials the user may still want.
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    foreach ($p in @("$env:LOCALAPPDATA\hermes\config.yaml",
                     "$env:LOCALAPPDATA\hermes\.env",
                     "$env:LOCALAPPDATA\hermes\auth.json",
                     "$env:LOCALAPPDATA\hermes\state.db")) {
        if (Test-Path $p) {
            $bak = "$p.bak-$stamp"
            Copy-Item $p $bak -Force -ErrorAction SilentlyContinue
        }
    }
    foreach ($p in @("$env:LOCALAPPDATA\hermes\config.yaml",
                     "$env:LOCALAPPDATA\hermes\state.db")) {
        if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
    }

    Write-Host ""
    Write-Host "  config.yaml and state.db removed (backed up as *.bak-$stamp)." -ForegroundColor Yellow
    Write-Host "  .env and auth.json were KEPT so your keys and the Nous free-tier" -ForegroundColor Yellow
    Write-Host "  credential survive. Next start falls back to Hermes defaults (Nous)." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  If first-run onboarding still does not appear, a key in .env is" -ForegroundColor Yellow
    Write-Host "  overriding the default provider - comment it out and try again." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 11. junction so Hermes finds the repo at its default path
# ---------------------------------------------------------------------------
if ($RepoRoot -ne (Join-Path $target 'hermes-agent')) {
    $link = Join-Path $target 'hermes-agent'
    if (Test-Path $link) {
        Warn "$link already exists, leaving it alone (delete it manually if it is stale)"
    } else {
        New-Item -ItemType Junction -Path $link -Target $RepoRoot | Out-Null
        Say "junction: $link -> $RepoRoot"
    }
}

# ---------------------------------------------------------------------------
# 12. pin mirrors so npm and electron resolve the same URLs every run
# ---------------------------------------------------------------------------
if (-not $SkipMirrorPin) {
    try {
        npm config set registry https://registry.npmmirror.com 2>$null
        npm config set electron_mirror https://npmmirror.com/mirrors/electron/ 2>$null
        npm config set electron_builder_binaries_mirror https://npmmirror.com/mirrors/electron-builder-binaries/ 2>$null
    } catch { Warn "could not write npm config (non-fatal, continuing)" }
}

# ---------------------------------------------------------------------------
# 13. self check
# ---------------------------------------------------------------------------
Say "--- self check ---"
$packagerDest = Join-Path $RepoRoot 'apps\desktop\build\packager'
$items = @(
    @{ Name = 'tools';          Path = (Join-Path $target 'tools') },
    @{ Name = 'install-main';   Path = (Join-Path $target 'bootstrap-cache\install-main.ps1') },
    @{ Name = 'cache';          Path = (Join-Path $target 'cache') },
    @{ Name = 'repo(.git)';     Path = (Join-Path $RepoRoot '.git') },
    @{ Name = 'desktop-inputs'; Path = (Join-Path $RepoRoot '.cache\desktop-inputs') },
    @{ Name = 'desktop-packager'; Path = $packagerDest }
)
if ($packedHash -and $zipName) {
    $items += @{ Name = 'electron zip (repo cache)';  Path = (Join-Path $cacheDirElectron "$packedHash\$zipName") }
    $items += @{ Name = 'electron zip (fallback)';    Path = (Join-Path $defaultElectron  "$packedHash\$zipName") }
}
$missing = 0
foreach ($i in $items) {
    if (Test-Path $i.Path) {
        Write-Host ("  OK       {0}" -f $i.Name) -ForegroundColor Green
    } else {
        Write-Host ("  MISSING  {0}   <- {1}" -f $i.Name, $i.Path) -ForegroundColor Red
        $missing++
    }
}

Say "DONE"
Write-Host ""
if ($missing -gt 0) {
    Write-Host "$missing item(s) MISSING - fix them before running the installer." -ForegroundColor Red
} else {
    Write-Host "All checks passed. Next: run watch-electron-cache.ps1, THEN double-click" -ForegroundColor Green
    Write-Host "Hermes-Setup.exe (NOT a .cmd launcher) and let all 9 stages finish." -ForegroundColor Green
}
Write-Host ""
Write-Host "The installer hashes the electron URL at runtime, and on a fresh machine" -ForegroundColor Yellow
Write-Host "that hash may not match the one in this bundle. Keep the watcher running" -ForegroundColor Yellow
Write-Host "during the install - it fills any new hash directory within 2 seconds." -ForegroundColor Yellow

