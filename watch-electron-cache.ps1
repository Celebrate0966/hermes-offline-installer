# Watches BOTH electron cache locations while Hermes-Setup.exe runs.
#
# Why this exists
# ---------------
# The electron cache directory name is a hash of the download URL, so it
# changes whenever the resolved mirror changes. restore.ps1 seeds the hash
# directory shipped in the bundle, but the installer may hash to something
# else and create a NEW directory mid-run. It looks there, finds nothing,
# decides the cache missed, and falls back to the network - which hangs and
# eventually dies with "fetch failed".
#
# There are two places it can look, and observed behaviour shows it falls
# back from the first to the second:
#   (a) <repo>\.cache\desktop-inputs\packager\electron   (passed as --cache)
#   (b) %LOCALAPPDATA%\electron\Cache                    (downloader fallback)
#
# This polls both every 2 seconds and drops the offline zip into any hash
# directory that does not have one yet. It only ever writes inside the
# electron caches - it deletes nothing.
#
# Usage - start this BEFORE double-clicking the installer, keep it running:
#   powershell -ExecutionPolicy Bypass -File .\watch-electron-cache.ps1
#   powershell -ExecutionPolicy Bypass -File .\watch-electron-cache.ps1 -RepoRoot D:\HermesData\hermes-agent

param(
    [string]$OfflineRoot,
    [string]$RepoRoot,
    [int]$Seconds = 3600
)

$ErrorActionPreference = 'Continue'
if (-not $OfflineRoot) { $OfflineRoot = $PSScriptRoot }
if (-not $RepoRoot)    { $RepoRoot = Join-Path $env:LOCALAPPDATA 'hermes\hermes-agent' }

$cacheDirElectron = Join-Path $RepoRoot '.cache\desktop-inputs\packager\electron'
$defaultElectron  = Join-Path $env:LOCALAPPDATA 'electron\Cache'
$log              = Join-Path $env:TEMP 'hermes-electron-watch.log'
$deadline         = (Get-Date).AddSeconds($Seconds)
$known            = @{}

$zip = Get-ChildItem -Path (Join-Path $OfflineRoot 'desktop-inputs\packager\electron') -Recurse -File -Filter 'electron-*.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $zip) {
    Write-Host "no offline electron-*.zip found under $OfflineRoot\desktop-inputs\packager\electron" -ForegroundColor Red
    exit 1
}

"=== watcher start $(Get-Date -Format 'o') ===" | Out-File $log -Encoding utf8
"offline zip : $($zip.FullName)" | Out-File $log -Append -Encoding utf8
"repo cache  : $cacheDirElectron" | Out-File $log -Append -Encoding utf8
"fallback    : $defaultElectron"  | Out-File $log -Append -Encoding utf8

Write-Host "watching for $Seconds s, log: $log" -ForegroundColor Cyan
Write-Host "  repo cache : $cacheDirElectron" -ForegroundColor DarkGray
Write-Host "  fallback   : $defaultElectron" -ForegroundColor DarkGray

while ((Get-Date) -lt $deadline) {
    foreach ($root in @($cacheDirElectron, $defaultElectron)) {
        if (-not (Test-Path $root)) { continue }
        Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $dir  = $_.FullName
            $here = Get-ChildItem -Path $dir -File -Filter 'electron-*.zip' -ErrorAction SilentlyContinue
            if (-not $here) {
                Copy-Item -Path $zip.FullName -Destination (Join-Path $dir $zip.Name) -Force
                $msg = "[{0}] FILLED -> {1}" -f (Get-Date -Format 'HH:mm:ss'), $dir
                Write-Host $msg -ForegroundColor Green
                $msg | Out-File $log -Append -Encoding utf8
            }
            elseif (-not $known.ContainsKey($dir)) {
                $known[$dir] = $true
                $msg = "[{0}] ok {1} ({2} bytes) in {3}" -f (Get-Date -Format 'HH:mm:ss'), $here[0].Name, $here[0].Length, $_.Name
                Write-Host $msg -ForegroundColor DarkGray
                $msg | Out-File $log -Append -Encoding utf8
            }
        }
    }
    Start-Sleep -Seconds 2
}

"=== watcher end $(Get-Date -Format 'o') ===" | Out-File $log -Append -Encoding utf8
